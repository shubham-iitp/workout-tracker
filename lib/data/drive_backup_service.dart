import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../app/format.dart';
import '../app/google_config.dart';
import 'csv_backup_service.dart';
import 'csv_codec.dart';

/// Only files and folders this app creates are visible to it.
const driveFileScope = drive.DriveApi.driveFileScope;
const driveFolderName = 'Workout';
const _folderMime = 'application/vnd.google-apps.folder';

/// Why a backup failed. Nothing on the phone has changed.
enum DriveFailureKind {
  cancelled,
  signIn,
  offline,
  accessRemoved,
  driveFull,
  other,
}

class DriveFailure implements Exception {
  const DriveFailure(this.kind, [this.detail]);

  final DriveFailureKind kind;
  final String? detail;

  /// The text shown in the red alert (spec §6.2 step 5).
  String get message => switch (kind) {
    DriveFailureKind.cancelled => 'Google sign-in was cancelled.',
    DriveFailureKind.signIn => "Couldn't sign in to Google",
    DriveFailureKind.offline =>
      "Couldn't upload to Google Drive: no internet connection. Your data is "
          'still safe on this phone. Tap Back up now to try again.',
    DriveFailureKind.accessRemoved =>
      'Google Drive access was removed. Tap Back up now to connect again.',
    DriveFailureKind.driveFull =>
      'Your Google Drive is full. Free up space, then tap Back up now.',
    DriveFailureKind.other =>
      "Couldn't upload to Google Drive${detail == null ? '' : ': $detail'}. "
          'Your data is still safe on this phone. Tap Back up now to try again.',
  };

  @override
  String toString() => message;
}

/// A finished upload.
class DriveUpload {
  const DriveUpload({
    required this.folderId,
    required this.fileName,
    required this.bytes,
    required this.at,
  });

  final String folderId;
  final String fileName;
  final int bytes;
  final DateTime at;
}

// ---- Auth ---------------------------------------------------------------------

/// Google sign-in + Drive authorization. Faked in tests.
abstract class DriveAuth {
  /// Shows the account picker and the Drive consent screen. Returns the
  /// account's email.
  Future<String> connect();

  /// An HTTP client that sends the Drive access token. With [interactive]
  /// false it never shows UI and returns null if the user must act first.
  Future<http.Client?> client({required bool interactive});

  /// Drops a cached access token that Drive rejected (HTTP 401).
  Future<void> forgetToken();

  /// Revokes the app's access and signs out.
  Future<void> disconnect();
}

class GoogleDriveAuth implements DriveAuth {
  static Future<void>? _init;
  String? _lastToken;

  GoogleSignIn get _gs => GoogleSignIn.instance;

  Future<void> _ready() =>
      _init ??= _gs.initialize(serverClientId: googleWebClientId);

  @override
  Future<String> connect() async {
    await _ready();
    final account = await _gs.authenticate(scopeHint: const [driveFileScope]);
    await account.authorizationClient.authorizeScopes(const [driveFileScope]);
    return account.email;
  }

  @override
  Future<http.Client?> client({required bool interactive}) async {
    await _ready();
    final authz = _gs.authorizationClient;
    final token =
        await authz.authorizationForScopes(const [driveFileScope]) ??
        (interactive
            ? await authz.authorizeScopes(const [driveFileScope])
            : null);
    if (token == null) return null;
    _lastToken = token.accessToken;
    return token.authClient(scopes: const [driveFileScope]);
  }

  @override
  Future<void> forgetToken() async {
    final t = _lastToken;
    if (t != null) {
      await _gs.authorizationClient.clearAuthorizationToken(accessToken: t);
    }
    _lastToken = null;
  }

  @override
  Future<void> disconnect() async {
    await _ready();
    await _gs.disconnect();
  }
}

// ---- Backup -------------------------------------------------------------------

/// Uploads the Export CSV into My Drive › Workout (spec §6).
class DriveBackupService {
  DriveBackupService({required this.csv, required this.auth});

  final CsvBackupService csv;
  final DriveAuth auth;

  /// `workout-tracker-YYYY-MM-DD.csv`, the same name Export uses.
  static String fileNameFor(DateTime d) =>
      'workout-tracker-${fmtFileDate(d)}.csv';

  /// Shows Google sign-in + Drive consent. Returns the account email.
  Future<String> connect() async {
    try {
      return await auth.connect();
    } on GoogleSignInException catch (e) {
      if (_isCancel(e)) throw const DriveFailure(DriveFailureKind.cancelled);
      throw DriveFailure(DriveFailureKind.signIn, signInDetail(e));
    } catch (e) {
      throw _map(e);
    }
  }

  static bool _isCancel(GoogleSignInException e) => switch (e.code) {
    GoogleSignInExceptionCode.canceled ||
    GoogleSignInExceptionCode.interrupted ||
    GoogleSignInExceptionCode.uiUnavailable => true,
    _ => false,
  };

  /// The monospace line under "Couldn't sign in to Google" (design state 5):
  /// the platform's error code + message as-is, with a plain explanation for
  /// the SHA-1 / package-name mismatch.
  static String signInDetail(GoogleSignInException e) {
    final msg = (e.description ?? '').trim();
    // Play services: "10: …" (maybe after "SDK reported an exception: ");
    // Credential Manager: "[28444] …".
    final m = RegExp(r'(?:^|:\s)\[?(\d+)\]?(?::\s*|\s+|$)').firstMatch(msg);
    final num = m?.group(1);
    if (num == '10' || num == '28444' || msg.contains('DEVELOPER_ERROR')) {
      return "Error ${num ?? 10} (DEVELOPER_ERROR): the app's SHA-1 or "
          "package name doesn't match its Google OAuth client.";
    }
    if (msg.isEmpty) return e.code.name;
    if (num != null) return 'Error $num: ${msg.substring(m!.end)}';
    return '${e.code.name}: $msg';
  }

  /// Uploads today's file. [folderId] is the saved "Workout" folder, if any.
  /// Throws [DriveFailure].
  Future<DriveUpload> backup({
    required String? folderId,
    required bool interactive,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final bytes = utf8.encode(encodeBackup(await csv.snapshot()));
    final name = fileNameFor(at);

    // One retry with a fresh token if Drive says the cached one expired.
    for (var attempt = 0; ; attempt++) {
      http.Client? client;
      try {
        client = await auth.client(interactive: interactive);
        if (client == null) {
          throw const DriveFailure(DriveFailureKind.accessRemoved);
        }
        final api = drive.DriveApi(client);
        final folder = await _folder(api, folderId);
        await _upsert(api, folder, name, bytes);
        return DriveUpload(
          folderId: folder,
          fileName: name,
          bytes: bytes.length,
          at: at,
        );
      } on drive.DetailedApiRequestError catch (e) {
        if (e.status == 401 && attempt == 0) {
          await auth.forgetToken();
          continue;
        }
        throw _map(e);
      } catch (e) {
        throw _map(e);
      } finally {
        client?.close();
      }
    }
  }

  Future<void> disconnect() => auth.disconnect();

  /// The saved folder if it still exists, else the app's "Workout" folder in
  /// My Drive, else a new one.
  Future<String> _folder(drive.DriveApi api, String? savedId) async {
    if (savedId != null) {
      try {
        final f =
            await api.files.get(savedId, $fields: 'id,trashed') as drive.File;
        if (f.trashed != true) return savedId;
      } on drive.DetailedApiRequestError catch (e) {
        if (e.status != 404) rethrow;
      }
    }
    final found = await api.files.list(
      q:
          "name = '$driveFolderName' and mimeType = '$_folderMime' "
          "and 'root' in parents and trashed = false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    final existing = found.files?.firstOrNull?.id;
    if (existing != null) return existing;
    final created = await api.files.create(
      drive.File()
        ..name = driveFolderName
        ..mimeType = _folderMime
        ..parents = ['root'],
      $fields: 'id',
    );
    return created.id!;
  }

  /// Replaces today's file if it exists, else creates it.
  Future<void> _upsert(
    drive.DriveApi api,
    String folderId,
    String name,
    List<int> bytes,
  ) async {
    drive.Media media() =>
        drive.Media(Stream.value(bytes), bytes.length, contentType: 'text/csv');
    final found = await api.files.list(
      q: "name = '$name' and '$folderId' in parents and trashed = false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    final id = found.files?.firstOrNull?.id;
    if (id != null) {
      await api.files.update(drive.File(), id, uploadMedia: media());
    } else {
      await api.files.create(
        drive.File()
          ..name = name
          ..mimeType = 'text/csv'
          ..parents = [folderId],
        uploadMedia: media(),
        $fields: 'id',
      );
    }
  }

  static DriveFailure _map(Object e) {
    if (e is DriveFailure) return e;
    if (e is GoogleSignInException) {
      return switch (e.code) {
        GoogleSignInExceptionCode.canceled ||
        GoogleSignInExceptionCode.interrupted ||
        GoogleSignInExceptionCode.uiUnavailable => const DriveFailure(
          DriveFailureKind.cancelled,
        ),
        _ => DriveFailure(DriveFailureKind.other, e.description ?? e.code.name),
      };
    }
    if (e is SocketException ||
        e is http.ClientException ||
        e is TimeoutException) {
      return const DriveFailure(DriveFailureKind.offline);
    }
    if (e is drive.DetailedApiRequestError) {
      final reasons = e.errors.map((x) => x.reason).toSet();
      if (reasons.contains('storageQuotaExceeded')) {
        return const DriveFailure(DriveFailureKind.driveFull);
      }
      if (e.status == 401 ||
          (e.status == 403 && reasons.contains('insufficientPermissions'))) {
        return const DriveFailure(DriveFailureKind.accessRemoved);
      }
      return DriveFailure(DriveFailureKind.other, e.message);
    }
    return DriveFailure(DriveFailureKind.other, '$e');
  }
}
