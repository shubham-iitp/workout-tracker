# Workout Tracker — Tech Spec (Android, offline)

Based on the "Workout Tracker" design canvas (Lime / Ocean blue / Gold & gunmetal / Rosewood & aqua themes).
Target: Android APK only. All data stored on the phone. No server, no accounts.
Development environment: **VS Code only, no Android Studio** (see §7). All instructions, commands and tooling must work from VS Code and its terminal.

## 1. Stack

| Need | Choice |
|---|---|
| Framework | Flutter (Dart) |
| Database | SQLite via **drift** (+ `drift_flutter`) |
| Small settings | `shared_preferences` |
| State management | `flutter_riverpod` |
| Navigation | `go_router` (bottom tabs: Workouts, History, Settings) |
| Open video links | `url_launcher` |
| Keep screen on during workout | `wakelock_plus` |
| Export / import | `csv` (read/write) + `share_plus` (export) + `file_picker` (import, `.csv` only) |
| Fonts | Space Grotesk (headings), Inter (body) bundled as assets |

Alternative if you prefer native Android: Kotlin + Jetpack Compose + Room. Same schema applies.

## 2. Database tables

All ids are integers (autoincrement). `position` keeps user ordering.

### Plan (what the user edits)

**split_day**
- id, position, name ("Day 1")
- 1–14 days allowed (design limit)

**routine_item** (warm-up and cool-down)
- id, day_id → split_day, kind (`warmup` | `cooldown`), position
- name, detail (free text: "30 sec each way", "2 × 15"), video_url (nullable)

**body_part**
- id, day_id → split_day, position, name ("Chest")

**exercise**
- id, body_part_id → body_part, position, name, video_url (nullable)

**exercise_set** (the plan's target for each set)
- id, exercise_id → exercise, position
- weight (REAL, stored in kg, 0 = bodyweight "BW"), reps (INT)
- last_weight, last_reps (nullable) — what was actually done last time; drives "Last time: …" and "+2.5 kg vs last time"

On delete: cascade from day → parts → exercises → sets, and day → routine items.

### History (snapshots — editing the plan never changes past sessions)

**session**
- id, day_id (nullable, SET NULL on delete), day_name, parts_label ("Chest & Triceps")
- started_at, finished_at, minutes
- total_sets (planned), warm_done, warm_total, cool_done, cool_total

**session_exercise**
- id, session_id → session, position, name, improved (bool, shows "up" badge)

**session_set**
- id, session_exercise_id → session_exercise, position, weight, reps

### In-progress workout (so a crash / app kill doesn't lose a workout)

**active_workout** (0 or 1 row)
- day_id, started_at, phase (`warmup` | `lifts` | `cooldown`)
- done_ids (JSON list of checked set / routine item ids)

### Settings (shared_preferences)
- `unit`: `kg` | `lb` (convert for display; always store kg)
- `theme`: `lime` (#C8F03C, default) | `ocean` | `gold` | `rose` (Rosewood & aqua: accent #8EE3EF, dark #254E70, badges #C33C54, "up" #37718E, background #EEFBF8, text #142B3E)
- Each theme is one full set of colour tokens (ink, dark, badge, ground, muted, line, border, accent, up…); screens only use tokens, never raw colours.

## 3. Key logic (from the design)

- **Start workout** only enabled when the day has ≥ 1 exercise.
- **Phases**: warm-up → workout (lifts) → cool-down. Empty phases are skipped ("None today").
- Checking a set / item marks it done; tap again to undo.
- During lifts, +/− adjusts weight (step 0.1) and reps; this **updates the plan** for next time.
- Green weight/reps = higher than last time.
- **Delta label** per exercise: "+X kg vs last time" if max weight rose, else "Heavier sets", else "+N reps".
- **Save session** (auto when everything is checked, or "Finish & save" / quit sheet):
  1. Insert session + session_exercise + session_set for done sets only.
  2. Copy each done set's weight/reps into exercise_set.last_weight/last_reps.
  3. Clear active_workout.
- **Quit sheet**: save partial workout or discard.
- **History**: newest first; card shows date, time, duration, volume (Σ weight×reps), sets done/total, "N up"; expandable to per-exercise "60×8 · 62.5×8". Header: sessions this week, lifts up this week.

## 4. Screens

1. **Workouts** (tab) — "N-day rotation" stepper (+/−), one card per day: parts summary, counts, Edit / Set up day, Start workout.
2. **Day editor** — Warm-up list (name, detail, video link) · Body parts → exercises → sets (weight, reps, add/remove set) · "Add exercise" form (name, sets 1–12, reps, weight, video) · Add body part · Cool-down list · empty state.
3. **Active workout** — phase stepper with progress %, checklist, last-time line, video button, phase-done card ("Next up…"), progress footer with undo, quit sheet.
4. **Complete** — summary per phase, lifts up, Save.
5. **History** (tab) — weekly stats, expandable session cards, empty state.
6. **Settings** (tab) — colour palette, weight unit, **Your data: Export CSV / Import CSV** (see §5).

## 5. Export / import (CSV)

Designs: canvas page "All palettes · switchable", artboards 7–10.

**Export CSV**
- Writes one UTF-8 CSV (`workout-tracker-YYYY-MM-DD.csv`) with the whole plan and the whole history, then opens the Android share sheet (`share_plus`).
- After sharing, show a banner: file name + "N days, N exercises and N workouts".

**Import CSV**
- Opens the file picker limited to `.csv`.
- Parse and validate the whole file *before* touching the database.
- Valid → bottom sheet: file name, size, and what was found (days, exercises + sets, warm-up/cool-down items, workouts in history), with **Replace with this file** and **Cancel**. Import replaces the current plan and history in one transaction.
- Success → banner "Imported <file>" with the new counts.
- Invalid → red banner naming the file, the row and the column that failed (e.g. "Row 14 has no value in the reps column"), change nothing, and expand the "CSV format" help.

**CSV format** — header row, then one row per item. The first column `type` says what the row is; unused cells are left empty. Every row has exactly 20 columns. Weights are always kg.

```
type,day,section,body_part,exercise,set,weight_kg,reps,detail,video_url,last_weight_kg,last_reps,session_id,started_at,minutes,improved,warm_done,warm_total,cool_done,cool_total
```

| type | Columns used |
|---|---|
| `day` | day (name; row order = position) |
| `routine` | day, section (`warmup` / `cooldown`), exercise (item name), detail, video_url |
| `set` | day, body_part, exercise, set (1-based), weight_kg, reps, video_url (exercise link, repeated on each set), last_weight_kg, last_reps |
| `session` | session_id, started_at (ISO 8601), minutes, day (day name at the time), body_part (parts label at the time, e.g. "Chest & Triceps"), set (total planned sets), warm_done, warm_total, cool_done, cool_total |
| `session_set` | session_id, exercise, set, weight_kg, reps, improved (`true`/`false`, same for every set of that exercise) |

Rules: body parts and exercises are created in the order they first appear; `session_set` rows must follow their `session` row's `session_id`; quote any cell containing a comma (or a double quote, doubled as `""`). Row numbers in error messages count the header as row 1.

### 5.1 Sample file (what Export writes, and a valid Import)

`workout-tracker-2026-11-20.csv`:

```csv
type,day,section,body_part,exercise,set,weight_kg,reps,detail,video_url,last_weight_kg,last_reps,session_id,started_at,minutes,improved,warm_done,warm_total,cool_done,cool_total
day,Day 1,,,,,,,,,,,,,,,,,,
day,Day 2,,,,,,,,,,,,,,,,,,
routine,Day 1,warmup,,Arm circles,,,,30 sec each way,https://www.youtube.com/results?search_query=arm+circles,,,,,,,,,,
routine,Day 1,warmup,,Band pull-aparts,,,,2 × 15,,,,,,,,,,,
routine,Day 1,cooldown,,Doorway chest stretch,,,,"30 sec, each side",,,,,,,,,,,
set,Day 1,,Chest,Bench press,1,60,8,,https://www.youtube.com/results?search_query=bench+press,60,8,,,,,,,,
set,Day 1,,Chest,Bench press,2,62.5,8,,https://www.youtube.com/results?search_query=bench+press,60,8,,,,,,,,
set,Day 1,,Chest,Cable fly,1,15,12,,,15,12,,,,,,,,
set,Day 1,,Chest,Cable fly,2,15,12,,,15,12,,,,,,,,
set,Day 1,,Triceps,Rope pushdown,1,20,12,,,,,,,,,,,,
set,Day 1,,Triceps,Rope pushdown,2,20,12,,,,,,,,,,,,
session,Day 1,,Chest & Triceps,,6,,,,,,,s1,2026-11-16T06:55:00,49,,2,2,1,1
session_set,,,,Bench press,1,60,8,,,,,s1,,,false,,,,
session_set,,,,Bench press,2,60,8,,,,,s1,,,false,,,,
session_set,,,,Cable fly,1,15,12,,,,,s1,,,false,,,,
session_set,,,,Cable fly,2,15,12,,,,,s1,,,false,,,,
```

What this file contains:
- **Day 1** (Chest & Triceps): 2 warm-up items, 1 cool-down item, Chest → Bench press (2 sets) + Cable fly (2 sets), Triceps → Rope pushdown (2 sets).
- **Day 2**: empty day (shows "Set up day").
- Bench press set 2 is planned at 62.5 kg but last time was 60 kg → shown green during the workout, "+2.5 kg vs last time".
- Rope pushdown has no last values → "First time: set your baseline".
- **History**: one workout (16 Nov 2026, 6:55 AM, 49 min) where 4 of 6 sets were done (Rope pushdown skipped), warm-up 2/2, cool-down 1/1, volume 60×8×2 + 15×12×2 = 1,320 kg.

Expected Import sheet for this file: "2 days · 3 exercises, 6 sets · 2 warm-up + 1 cool-down items · 1 workout in history".
Expected Export banner when this is the app's data: "workout-tracker-2026-11-20.csv · 2 days, 3 exercises and 1 workout".

Round-trip test: import this file, export, and the exported file must be identical (same row order, same values).

### 5.2 Invalid samples (Import must reject, database unchanged)

Missing reps:
```csv
type,day,section,body_part,exercise,set,weight_kg,reps,detail,video_url,last_weight_kg,last_reps,session_id,started_at,minutes,improved,warm_done,warm_total,cool_done,cool_total
day,Day 1,,,,,,,,,,,,,,,,,,
set,Day 1,,Chest,Bench press,1,60,,,,,,,,,,,,,
```
→ "Row 3 has no value in the reps column"

Other cases that must fail with a row + column message:

| Problem | Example message |
|---|---|
| Header missing or columns renamed / reordered | "Row 1 is not the Workout Tracker header" |
| Row with fewer or more than 20 columns | "Row 5 has 18 columns, expected 20" |
| Unknown `type` | "Row 4 has an unknown type 'exercise'" |
| `set` / `routine` row for a day with no `day` row above it | "Row 6 uses day 'Day 9', which has no day row" |
| Number column not a number (weight, reps, minutes…) | "Row 7 has 'sixty' in the weight_kg column" |
| `section` not warmup/cooldown | "Row 4 has 'stretch' in the section column" |
| `session_set` before / without its `session` row | "Row 12 uses session 's9', which has no session row" |
| `started_at` not ISO 8601 | "Row 11 has '16/11/2026' in the started_at column" |
| More than 14 days | "Row 16 is day 15; the app allows up to 14 days" |

## 6. Project structure

```
lib/
  main.dart
  app/        router.dart, theme.dart (4 colour themes)
  data/       database.dart (drift tables), daos/, csv_backup_service.dart
  features/
    plan/     workouts_screen.dart, day_editor_screen.dart
    workout/  active_workout_screen.dart, quit_sheet.dart, complete_screen.dart
    history/  history_screen.dart
    settings/ settings_screen.dart, import_sheet.dart
  widgets/    set_row.dart, stepper_button.dart, phase_stepper.dart
test/
  fixtures/   sample_valid.csv (§5.1), sample_missing_reps.csv (§5.2)
```

## 7. Dev environment, build & install (VS Code only, no Android Studio)

Testing is on a real Android phone over USB, so no emulator is needed.

### 7.1 One-time setup on the PC

1. **Flutter SDK** — install Flutter (stable channel) and add its `bin` folder to `PATH`. Check with `flutter --version`.
2. **VS Code** — install the **Flutter** extension (it installs the Dart extension too).
3. **Java JDK** — install a JDK (17 is the safe default; use whatever version `flutter doctor` asks for). Set `JAVA_HOME` to it, or run `flutter config --jdk-dir <path-to-jdk>`.
4. **Android SDK without Android Studio**
   - Download the Android **"Command line tools only"** zip from developer.android.com/studio (bottom of the page).
   - Create an SDK folder, e.g. `C:\Android\sdk` (Windows) or `~/Android/sdk` (macOS/Linux).
   - Unzip so the layout is exactly `<sdk>/cmdline-tools/latest/bin/sdkmanager` (rename the extracted `cmdline-tools` folder to `latest` and put it inside a new `cmdline-tools` folder).
   - Set `ANDROID_HOME=<sdk>` and add `<sdk>/cmdline-tools/latest/bin` and `<sdk>/platform-tools` to `PATH`.
   - Install the packages:
     ```
     sdkmanager "platform-tools" "platforms;android-<latest>" "build-tools;<latest>"
     ```
     (Run `sdkmanager --list` to see the latest version numbers. If Gradle later asks for a different platform or build-tools version, install that one the same way.)
   - Tell Flutter where the SDK is: `flutter config --android-sdk <sdk>`
   - Accept licences: `flutter doctor --android-licenses`
5. Run `flutter doctor` until the **Flutter** and **Android toolchain** lines are green. It is fine for "Android Studio" to show as not installed.
6. **Phone** — Settings → About phone → tap Build number 7× → Developer options → enable **USB debugging**. Connect via USB and accept the prompt. `adb devices` (or `flutter devices`) should list the phone.

### 7.2 Daily development in VS Code

- Create the project: `flutter create --org com.yourname --platforms=android workout_tracker`
- Open the folder in VS Code, pick the phone in the device selector (bottom-right status bar), press **F5** to run with hot reload.
- drift code generation: `dart run build_runner watch --delete-conflicting-outputs` in a VS Code terminal.
- Testing CSV import on the phone: copy `test/fixtures/sample_valid.csv` to the phone (`adb push test/fixtures/sample_valid.csv /sdcard/Download/`), then Settings → Import CSV → Downloads.

### 7.3 Make a real APK

- `flutter build apk --release`
- Output: `build/app/outputs/flutter-apk/app-release.apk`
- Install with `flutter install`, or copy the APK to the phone and allow "Install unknown apps".
- Tip: `flutter build apk --split-per-abi` gives smaller APKs (use the `arm64-v8a` one on modern phones).
- For personal testing the default debug signing is fine; create your own keystore (`keytool`, comes with the JDK) before sharing widely or publishing to Play Store.

Note: uninstalling the app deletes all data — use Settings → Export CSV first.
