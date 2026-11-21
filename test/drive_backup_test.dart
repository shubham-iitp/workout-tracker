import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:workout_tracker/data/csv_backup_service.dart';
import 'package:workout_tracker/data/database.dart';
import 'package:workout_tracker/data/drive_backup_service.dart';

/// A tiny in-memory Google Drive: enough of files.get / list / create /
/// update for DriveBackupService.
class FakeDrive {
  final files = <String, Map<String, dynamic>>{};
  var _next = 0;
  final requests = <String>[];

  /// Status codes to return (once each) before handling normally.
  final failNext = <int>[];

  Map<String, dynamic> add(Map<String, dynamic> f) {
    final id = 'id${_next++}';
    files[id] = {'id': id, 'trashed': false, ...f};
    return files[id]!;
  }

  Iterable<Map<String, dynamic>> byName(String name) =>
      files.values.where((f) => f['name'] == name);

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  http.Response _error(int code, String reason) => _json({
    'error': {
      'code': code,
      'message': reason,
      'errors': [
        {'reason': reason, 'message': reason},
      ],
    },
  }, code);

  /// Splits a multipart/related upload into its JSON metadata and content.
  (Map<String, dynamic>, String) _multipart(http.Request r) {
    final boundary = RegExp(r'boundary="?([^";]+)"?')
        .firstMatch(r.headers['content-type']!)!
        .group(1)!;
    // Each part: headers, blank line, body.
    final parts = r.body
        .split('--$boundary')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty && p != '--')
        .map((p) {
          final split = p.indexOf(RegExp(r'\r?\n\r?\n'));
          return (
            p.substring(0, split).toLowerCase(),
            p.substring(split).trim(),
          );
        })
        .toList();
    final meta = jsonDecode(parts[0].$2) as Map<String, dynamic>;
    final (headers, data) = parts[1];
    final content = headers.contains('base64')
        ? utf8.decode(base64.decode(data.replaceAll(RegExp(r'\s'), '')))
        : data;
    return (meta, content);
  }

  Future<http.Response> handle(http.Request r) async {
    requests.add('${r.method} ${r.url.path}');
    if (failNext.isNotEmpty) {
      final code = failNext.removeAt(0);
      return _error(code, code == 401 ? 'authError' : 'storageQuotaExceeded');
    }
    final path = r.url.path;
    final q = r.url.queryParameters;

    if (r.method == 'GET' && path == '/drive/v3/files') {
      final query = q['q']!;
      final name = RegExp(r"name = '([^']*)'").firstMatch(query)!.group(1);
      final parent = RegExp(r"'([^']*)' in parents")
          .firstMatch(query)!
          .group(1);
      final hits = files.values.where(
        (f) =>
            f['name'] == name &&
            f['trashed'] == false &&
            (f['parents'] as List).contains(parent),
      );
      return _json({
        'files': [
          for (final f in hits) {'id': f['id']},
        ],
      });
    }
    if (r.method == 'GET' && path.startsWith('/drive/v3/files/')) {
      final f = files[path.split('/').last];
      if (f == null) return _error(404, 'notFound');
      return _json({'id': f['id'], 'trashed': f['trashed']});
    }
    if (r.method == 'POST' && path == '/drive/v3/files') {
      final meta = jsonDecode(r.body) as Map<String, dynamic>;
      return _json({'id': add(meta)['id']});
    }
    if (r.method == 'POST' && path == '/upload/drive/v3/files') {
      final (meta, content) = _multipart(r);
      return _json({
        'id': add({...meta, 'content': content})['id'],
      });
    }
    if (r.method == 'PATCH' && path.startsWith('/upload/drive/v3/files/')) {
      final f = files[path.split('/').last]!;
      f['content'] = r.headers['content-type']!.startsWith('multipart')
          ? _multipart(r).$2
          : r.body;
      return _json({'id': f['id']});
    }
    return _error(400, 'unexpected ${r.method} $path');
  }
}

class FakeAuth implements DriveAuth {
  FakeAuth(this.httpClient);

  final http.Client? httpClient;
  var forgot = 0;
  var disconnected = false;

  @override
  Future<String> connect() async => 'me@example.com';

  @override
  Future<http.Client?> client({required bool interactive}) async => httpClient;

  @override
  Future<void> forgetToken() async => forgot++;

  @override
  Future<void> disconnect() async => disconnected = true;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late FakeDrive drive;
  late FakeAuth auth;
  late DriveBackupService service;
  final day1 = DateTime(2026, 11, 21, 7, 40);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    drive = FakeDrive();
    auth = FakeAuth(MockClient(drive.handle));
    service = DriveBackupService(csv: CsvBackupService(db), auth: auth);
  });
  tearDown(() => db.close());

  Map<String, dynamic> folder() => drive.byName('Workout').single;

  test('first backup creates the Workout folder and today\'s CSV', () async {
    final up = await service.backup(
      folderId: null,
      interactive: true,
      now: day1,
    );

    expect(up.fileName, 'workout-tracker-2026-11-21.csv');
    expect(folder()['mimeType'], 'application/vnd.google-apps.folder');
    expect(folder()['parents'], ['root']);
    expect(up.folderId, folder()['id']);
    final file = drive.byName(up.fileName).single;
    expect(file['parents'], [up.folderId]);
    expect(file['content'], startsWith('type,day,section,'));
    expect(up.bytes, greaterThan(0));
  });

  test('same day: updates the file instead of adding another', () async {
    final a = await service.backup(
      folderId: null,
      interactive: true,
      now: day1,
    );
    await service.backup(folderId: a.folderId, interactive: true, now: day1);

    expect(drive.byName('Workout'), hasLength(1));
    expect(drive.byName(a.fileName), hasLength(1));
    expect(
      drive.requests,
      contains(startsWith('PATCH /upload/drive/v3/files/')),
    );
  });

  test('next day: a new file in the same folder', () async {
    final a = await service.backup(
      folderId: null,
      interactive: true,
      now: day1,
    );
    final b = await service.backup(
      folderId: a.folderId,
      interactive: true,
      now: day1.add(const Duration(days: 1)),
    );
    expect(b.folderId, a.folderId);
    expect(drive.byName('workout-tracker-2026-11-22.csv'), hasLength(1));
  });

  test('reuses an existing Workout folder after a reinstall', () async {
    final existing = drive.add({
      'name': 'Workout',
      'mimeType': 'application/vnd.google-apps.folder',
      'parents': ['root'],
    });
    final up = await service.backup(
      folderId: null,
      interactive: true,
      now: day1,
    );
    expect(up.folderId, existing['id']);
    expect(drive.byName('Workout'), hasLength(1));
  });

  test('saved folder deleted or trashed: finds or creates a new one', () async {
    final a = await service.backup(
      folderId: null,
      interactive: true,
      now: day1,
    );
    folder()['trashed'] = true;
    final b = await service.backup(
      folderId: a.folderId,
      interactive: true,
      now: day1,
    );
    expect(b.folderId, isNot(a.folderId));

    drive.files.remove(b.folderId);
    final c = await service.backup(
      folderId: b.folderId,
      interactive: true,
      now: day1,
    );
    expect(drive.files[c.folderId]!['name'], 'Workout');
  });

  test('expired token: forgets it and retries once', () async {
    drive.failNext.add(401);
    final up = await service.backup(
      folderId: null,
      interactive: false,
      now: day1,
    );
    expect(auth.forgot, 1);
    expect(drive.byName(up.fileName), hasLength(1));
  });

  test('401 twice: access removed', () async {
    drive.failNext.addAll([401, 401]);
    await expectLater(
      service.backup(folderId: null, interactive: false, now: day1),
      throwsA(
        isA<DriveFailure>().having(
          (f) => f.kind,
          'kind',
          DriveFailureKind.accessRemoved,
        ),
      ),
    );
  });

  test('no token without UI (auto backup): access removed', () async {
    service = DriveBackupService(
      csv: CsvBackupService(db),
      auth: FakeAuth(null),
    );
    await expectLater(
      service.backup(folderId: null, interactive: false),
      throwsA(
        isA<DriveFailure>().having(
          (f) => f.kind,
          'kind',
          DriveFailureKind.accessRemoved,
        ),
      ),
    );
  });

  test('Drive full', () async {
    drive.failNext.add(403);
    await expectLater(
      service.backup(folderId: null, interactive: true),
      throwsA(
        isA<DriveFailure>().having(
          (f) => f.kind,
          'kind',
          DriveFailureKind.driveFull,
        ),
      ),
    );
  });

  test('offline: the design\'s no-internet message', () async {
    service = DriveBackupService(
      csv: CsvBackupService(db),
      auth: FakeAuth(
        MockClient(
          (_) async => throw http.ClientException('Failed host lookup'),
        ),
      ),
    );
    await expectLater(
      service.backup(folderId: null, interactive: true),
      throwsA(
        isA<DriveFailure>()
            .having((f) => f.kind, 'kind', DriveFailureKind.offline)
            .having(
              (f) => f.message,
              'message',
              startsWith(
                "Couldn't upload to Google Drive: no internet connection.",
              ),
            ),
      ),
    );
  });

  group('sign-in failed (design state 5)', () {
    GoogleSignInException ex(GoogleSignInExceptionCode c, String? d) =>
        GoogleSignInException(code: c, description: d);

    test('SHA-1 / package mismatch, Play services form', () {
      expect(
        DriveBackupService.signInDetail(
          ex(
            GoogleSignInExceptionCode.unknownError,
            'SDK reported an exception: 10: ',
          ),
        ),
        startsWith('Error 10 (DEVELOPER_ERROR)'),
      );
      expect(
        DriveBackupService.signInDetail(
          ex(GoogleSignInExceptionCode.unknownError, '10: '),
        ),
        "Error 10 (DEVELOPER_ERROR): the app's SHA-1 or package name doesn't "
        'match its Google OAuth client.',
      );
    });

    test('SHA-1 mismatch, Credential Manager form', () {
      expect(
        DriveBackupService.signInDetail(
          ex(
            GoogleSignInExceptionCode.unknownError,
            '[28444] Developer console is not set up correctly.',
          ),
        ),
        startsWith('Error 28444 (DEVELOPER_ERROR):'),
      );
    });

    test('other errors: code + message as-is', () {
      expect(
        DriveBackupService.signInDetail(
          ex(GoogleSignInExceptionCode.unknownError, '7: '),
        ),
        'Error 7: ',
      );
      expect(
        DriveBackupService.signInDetail(
          ex(
            GoogleSignInExceptionCode.providerConfigurationError,
            'Credential Manager not supported.',
          ),
        ),
        'providerConfigurationError: Credential Manager not supported.',
      );
    });

    test('connect: cancel vs failure', () async {
      Future<DriveFailure> fail(GoogleSignInException e) async {
        final s = DriveBackupService(
          csv: CsvBackupService(db),
          auth: _ThrowingAuth(e),
        );
        try {
          await s.connect();
        } on DriveFailure catch (f) {
          return f;
        }
        throw StateError('no failure');
      }

      expect(
        (await fail(ex(GoogleSignInExceptionCode.canceled, 'user cancelled')))
            .kind,
        DriveFailureKind.cancelled,
      );
      final f = await fail(ex(GoogleSignInExceptionCode.unknownError, '10: '));
      expect(f.kind, DriveFailureKind.signIn);
      expect(f.detail, startsWith('Error 10 (DEVELOPER_ERROR)'));
    });
  });
}

class _ThrowingAuth extends FakeAuth {
  _ThrowingAuth(this.error) : super(null);

  final Object error;

  @override
  Future<String> connect() async => throw error;
}
