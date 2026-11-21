import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/drive_backup_service.dart';
import '../../widgets/ui.dart';

const _cloud =
    '<path d="M7 18a4.5 4.5 0 01-.9-8.9A6 6 0 0117.8 8.5 4.75 4.75 0 0117.5 18H7z"/>';
const _folder =
    '<path d="M3 7a2 2 0 012-2h4l2 2h8a2 2 0 012 2v8a2 2 0 01-2 2H5a2 2 0 01-2-2V7z"/>';

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

Widget _strokeSvg(String body, Color color, double size) => SvgPicture.string(
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
  'stroke="${_hex(color)}" stroke-width="2" stroke-linecap="round" '
  'stroke-linejoin="round">$body</svg>',
  width: size,
  height: size,
);

/// "14 KB": whole kilobytes, at least 1.
String _kb(int bytes) => '${(bytes / 1024).round().clamp(1, 1 << 30)} KB';

/// "Today, 7:40 AM" · "Yesterday, 6:58 PM" · "Thu, 20 Nov, 7:40 AM".
String fmtWhen(DateTime at, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  final prefix = switch (diff) {
    0 => 'Today',
    1 => 'Yesterday',
    _ => fmtDate(at),
  };
  return '$prefix, ${fmtTime(at)}';
}

/// Settings › "Backup on Drive" (design page "Sync with Google").
class DriveSection extends ConsumerWidget {
  const DriveSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final s = ref.watch(driveBackupProvider);
    final n = ref.read(driveBackupProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'BACKUP ON DRIVE',
          style: inter(
            12,
            weight: FontWeight.w700,
            letterSpacing: 0.1,
            color: t.muted,
          ),
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            style: inter(13, color: t.muted),
            children: [
              const TextSpan(text: 'Creates a '),
              TextSpan(
                text: driveFolderName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(
                text: ' folder in your Google Drive and uploads your CSV there as a backup.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (!s.connected) ...[
          Btn(
            onTap: n.connect,
            height: 52,
            color: Fixed.white,
            border: BorderSide(color: t.border),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/google.png',
                  width: 24,
                  height: 24,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 10),
                Text(
                  'Backup on Drive',
                  style: inter(15, weight: FontWeight.w600, color: t.ink),
                ),
              ],
            ),
          ),
          if (s.signInError != null) ...[
            const SizedBox(height: 10),
            _SignInError(s.signInError!),
          ],
        ] else
          _ConnectedCard(state: s, notifier: n),
      ],
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  const _ConnectedCard({required this.state, required this.notifier});

  final DriveState state;
  final DriveBackupNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = state;
    final busy = s.status == DriveStatus.busy;
    final error = s.status == DriveStatus.error;

    final last = s.lastAt == null
        ? 'No backup yet'
        : 'Last backup: ${fmtWhen(s.lastAt!)}'
              '${!error && s.lastBytes != null ? ' · ${_kb(s.lastBytes!)}' : ''}';
    final (title, sub, iconBg, iconColor, mark) = switch (s.status) {
      DriveStatus.busy => (
        'Backing up…',
        'Uploading ${s.uploading ?? ''}',
        t.ground,
        t.ink,
        '<path d="M12 15v-4M10 13l2-2 2 2"/>',
      ),
      DriveStatus.error => (
        'Backup failed',
        last,
        Fixed.dangerBg,
        Fixed.dangerText,
        '<path d="M12 11v2.5M12 15.5h.01"/>',
      ),
      _ => (
        'Backed up to Google Drive',
        last,
        t.ground,
        t.up,
        '<path d="M9.5 13l2 2 3.5-3.5"/>',
      ),
    };
    final file = DriveBackupService.fileNameFor(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Fixed.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _strokeSvg('$_cloud$mark', iconColor, 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: inter(15, weight: FontWeight.w700, color: t.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(sub, style: inter(13, color: t.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (busy) ...[
            const SizedBox(height: 12),
            Semantics(
              label: 'Uploading backup',
              value: 'Uploading',
              child: const _SlidingBar(),
            ),
          ],
          if (error && s.error != null) ...[
            const SizedBox(height: 12),
            _Alert(s.error!),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: t.ground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _strokeSvg(_folder, t.ink, 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: inter(12, color: t.ink),
                      children: [
                        const TextSpan(text: 'My Drive › '),
                        const TextSpan(
                          text: driveFolderName,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: ' › $file'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MergeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Back up after every workout',
                        style: inter(14, weight: FontWeight.w600, color: t.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Uploads a fresh CSV when a workout is saved.',
                        style: inter(12, color: t.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _Switch(value: s.auto, onChanged: notifier.setAuto),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Opacity(
                  opacity: busy ? 0.6 : 1,
                  child: Btn(
                    onTap: busy ? null : notifier.backupNow,
                    height: 48,
                    radius: 12,
                    color: t.dark,
                    child: Text(
                      busy ? 'Backing up…' : 'Back up now',
                      style: inter(
                        14,
                        weight: FontWeight.w600,
                        color: Fixed.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Btn(
                  onTap: notifier.disconnect,
                  height: 48,
                  radius: 12,
                  color: Fixed.white,
                  border: BorderSide(color: t.border),
                  child: Text(
                    'Disconnect',
                    style: inter(14, weight: FontWeight.w600, color: t.ink),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 52×32 switch from the design: `dark` when on, `border2` when off.
class _Switch extends StatelessWidget {
  const _Switch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 52,
          height: 32,
          padding: const EdgeInsets.all(3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? t.dark : t.border2,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Fixed.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Alert extends StatelessWidget {
  const _Alert(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Fixed.dangerBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Fixed.dangerBorder),
        ),
        child: Text(text, style: inter(13, color: Fixed.dangerTitle)),
      ),
    );
  }
}

/// Indeterminate bar (design state 3): a 30%-wide `dark` segment slides
/// across the 6px `line` track every 1.2 s and loops.
class _SlidingBar extends StatefulWidget {
  const _SlidingBar();

  @override
  State<_SlidingBar> createState() => _SlidingBarState();
}

class _SlidingBarState extends State<_SlidingBar>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 6,
        color: t.line,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final seg = w * 0.3;
            return AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: -seg + (w + seg) * _c.value,
                    top: 0,
                    bottom: 0,
                    width: seg,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: t.dark,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// "Couldn't sign in to Google" box under the button (design state 5).
class _SignInError extends StatelessWidget {
  const _SignInError(this.detail);

  final String detail;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Fixed.dangerBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Fixed.dangerBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Couldn't sign in to Google",
              style: inter(
                14,
                weight: FontWeight.w700,
                color: Fixed.dangerTitle,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Nothing was backed up. Tap Backup on Drive to try again. If it '
              "keeps failing, the app's Google setup needs fixing.",
              style: inter(13, color: Fixed.dangerTitle),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF6B2A22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
