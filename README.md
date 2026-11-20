# Workout Tracker

An offline workout tracker for Android, built with Flutter. Everything lives on
the phone: no server, no accounts.

- **Split-day plan**: a 1–14 day rotation. Each day has a warm-up, body parts →
  exercises → sets (weight × reps), and a cool-down.
- **Live workout**: the warm-up → workout → cool-down phases, a check for each
  set, and +/− weight and reps controls (these also update the plan for next
  time). It shows "Last time: …", marks lifts that are higher than last time in
  green, and the screen stays on during a workout.
- **Crash-safe**: an in-progress workout is saved to the database, so killing
  the app doesn't lose it.
- **History**: past workouts with volume, sets done, the lifts that went up and
  weekly stats.
- **CSV backup**: export the whole plan and history through the share sheet,
  then import it again later. The whole file is validated before anything
  changes.
- **Four colour palettes** (Lime, Ocean blue, Gold & gunmetal, Rosewood & aqua)
  and kg / lb units.

The full spec is in [`docs/tech-spec.md`](docs/tech-spec.md).

## Stack

Flutter 3.50 (Dart 3.14) · drift (SQLite) · flutter_riverpod · go_router ·
shared_preferences · url_launcher · wakelock_plus · share_plus · file_picker.
The fonts (Space Grotesk and Inter, both OFL) are bundled in `assets/fonts/`.

## Project layout

```
lib/
  main.dart
  app/        router, theme (4 palettes as tokens), providers, formatting
  data/       drift tables (database.dart), daos/, CSV codec + backup service
  features/
    plan/     workouts_screen, day_editor_screen
    workout/  active_workout_screen (phases, quit sheet, complete card), workout_logic
    history/  history_screen
    settings/ settings_screen, import_sheet
  widgets/    ui (design icons, buttons, fields, sheets), async_view
test/
  fixtures/   sample_valid.csv, sample_missing_reps.csv
  csv_codec_test.dart, database_test.dart, screens_test.dart
```

The UI follows the "Workout Tracker" design canvas (MainThemed artboards):
two tabs (Workouts, History), Settings behind the gear button, palette tokens
copied exactly. To render every screen at 390×844 for comparison with the
design:

```sh
flutter test test/screens_test.dart --update-goldens   # PNGs in build/screens/
```

## Setup (VS Code only, no Android Studio)

You need the Flutter SDK, JDK 17+ (21 is used here) and the Android SDK
command-line tools. See [spec §7.1](docs/tech-spec.md) for a step-by-step guide.
`flutter doctor` should show **Flutter** and **Android toolchain** as green.
It's fine for Android Studio to show as missing.

> **Newer `sdkmanager` (cmdline-tools 23+) uses `/` instead of `;`** in package
> names. Gradle can't auto-install the NDK with the old syntax, so install
> these yourself once:
>
> ```sh
> sdkmanager platform-tools platforms/android-36 build-tools/36.0.0 ndk/28.2.13676358
> ```
>
> If a build says a different NDK version is missing, install that version the
> same way.

```sh
flutter pub get
dart run build_runner build     # regenerates lib/data/database.g.dart (committed)
flutter test                    # CSV + database tests
```

### Run on a phone

Turn on USB debugging on the phone and connect it (`flutter devices` should
list it). Then press **F5** in VS Code, or run:

```sh
flutter run
```

While you edit the drift tables, keep `dart run build_runner watch` running in
a terminal.

### Build an APK

```sh
flutter build apk --release                 # build/app/outputs/flutter-apk/app-release.apk
flutter build apk --release --split-per-abi # smaller; use the arm64-v8a one
flutter install                             # installs onto the connected phone
```

Release builds are signed with the debug key for now. Before you share the app
widely or publish it, create your own keystore and keep it, plus
`key.properties`, out of git (both are already in `.gitignore`).

### Try CSV import

```sh
adb push test/fixtures/sample_valid.csv /sdcard/Download/
```

Then go to **Settings → Import CSV → Downloads**.

> Uninstalling the app deletes all of its data. Use **Settings → Export CSV**
> first.

## Notes

- Weights are always stored in kg and converted for display.
- The generated `database.g.dart` file is committed, so a fresh clone builds
  without running build_runner first.
- CSV reading and writing is a small built-in codec (`lib/data/csv_codec.dart`)
  rather than the `csv` package. This gives exact control over quoting, number
  formatting and row/column error messages, so the spec's round-trip test
  (import → export gives an identical file) holds.
