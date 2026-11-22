# Workout Tracker — Tech Spec (Android, offline)

Based on the "Workout Tracker" design canvas (Lime / Ocean blue / Gold & gunmetal / Rosewood & aqua themes).
Target: Android APK only. All data stored on the phone. No server of our own. The only account is the optional Google sign-in for **Backup on Drive** (§6); the app works fully without it.
Development environment: **VS Code only, no Android Studio** (see §8). All instructions, commands and tooling must work from VS Code and its terminal.

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
| Backup on Drive (§6) | `google_sign_in` 7 (sign-in + `drive.file` scope) + `googleapis` (Drive v3) + `extension_google_sign_in_as_googleapis_auth` (turns the authorization into an API client) + `http` |

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

### Saved random palettes (§4.1)

**custom_palette**
- id, position, name (unique ignoring case, ≤ 24 chars, never a preset name)
- scheme (`analogous` | `complementary` | `triad`), hue (0–359)
- colors (JSON: every token → `#RRGGBB`: ink, dark, badge, ground, muted, line, border, border2, divider, field, darkMuted, darkText, darkTrack, darkLine, checkIdle, up, accent)

Added in schema version 2 (the upgrade creates the table; nothing else changes).

### Settings (shared_preferences)
- `unit`: `kg` | `lb` (convert for display; always store kg)
- `theme`: `lime` (#C8F03C, default) | `ocean` | `gold` | `rose` (Rosewood & aqua: accent #8EE3EF, dark #254E70, badges #C33C54, "up" #37718E, background #EEFBF8, text #142B3E) | `custom` (a saved palette: `theme_custom` = its name, `theme_colors` = its colours as JSON, cached so the app opens in it without waiting for the database). If the saved palette disappears (e.g. an import without it), the app falls back to Lime. The selection is also written to the CSV (`theme` row, §5) and restored by Import.
- Each theme is one full set of colour tokens (ink, dark, badge, ground, muted, line, border, accent, up…); screens only use tokens, never raw colours.
- Drive backup (§6): `drive_connected` (bool), `drive_account` (email, display only), `drive_folder_id` (id of the "Workout" folder), `drive_auto` (bool, default `true`), `drive_last_at` (ISO time of last successful upload), `drive_last_bytes` (int), `drive_last_file` (name of the last uploaded file), `drive_last_error` (string, nullable). No tokens are stored by the app; `google_sign_in` keeps them in Google Play services.

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
6. **Settings** (tab) — colour palette (4 presets + saved random palettes, **Random palette**, see §4.1), weight unit, **Your data: Export CSV / Import CSV** (see §5), **Backup on Drive** (see §6).

### 4.1 Random palette

Designs: canvas page "Random palette · Settings → Colour palette", artboards 7.1–7.10. Code: `lib/app/random_palette.dart` (generator, pure Dart), `lib/data/daos/palette_dao.dart`, `lib/features/settings/settings_screen.dart` + `palette_name_sheet.dart`.

- **Random palette** button (dice icon, dashed border) under the presets and saved palettes. Tap → a palette is generated on the phone (no internet) and previewed straight away (7.2); the button then reads **Roll again** (7.5).
- **Generator** (bit-exact port of the canvas's `generatePalette`; seed 7 = "Analogous · hue 4°"): mulberry32 RNG from a random 32-bit seed. Pick a base hue 0–359 and a scheme (analogous ±30°, complementary +180°, triad +120°/+240°). Five HSL colours: a pale ground, two darks, a bright accent, a mid badge. Sorted by lightness → ink, dark, ground; the other two by saturation → accent, badge. muted = ink mixed 35% towards ground; line/border/border2/divider/checkIdle = ground 4/12/20/2/28 points darker; field, darkMuted, darkText, darkTrack, darkLine = mixes with white. `up` = accent darkened in 2-point steps until it reads 4.5:1 on white and ground.
- **Readability checks** (WCAG contrast): ink on ground and on white, muted on white, white on dark, ink on accent, white on badge, up on white and on ground all ≥ 4.5:1; accent on dark ≥ 3:1. A palette that fails is thrown away. 50 failures in a row (very rare) → red line "Couldn't find a readable palette, try again." and the current palette stays (7.10).
- **Preview card**: "Previewing a random palette", the scheme + base hue, five swatches (ground, ink, dark, accent, badge) with hex codes, "Not saved yet…", **Save this palette** / **Back to Lime**. The preview themes the whole Settings screen. It isn't saved: leaving Settings drops it and the last saved palette comes back.
- **Save this palette** → bottom sheet "Name this palette" (7.3): the swatches, a name field (prefilled "My palette N", max 24 characters, counter), **Save palette** / **Cancel**. Empty names and the preset names (case-insensitive) can't be saved. A name that matches a saved palette shows "You already have a palette called …. Saving will replace it." and the button reads **Replace palette** (7.4); replacing keeps its place in the list.
- After saving, the palette appears in the list under its name, selected, with "Saved as “Sunset”. Pick it any time from the list above." (7.6). Every screen uses it (7.7–7.9).
- **Storage**: table `custom_palette` (§2). The selected palette is a preference (§2 Settings). Saved palettes and the selected palette are part of the CSV (§5, `palette` rows and one `theme` row), so **Export**, **Import** and **Backup on Drive** (§6) include them; saving one, or picking a different palette, triggers the auto backup.

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
| `palette` | exercise (saved palette name), detail (`scheme=analogous;hue=4;ink=#…;dark=#…;…`, all 17 colour tokens, §4.1). Written after the history rows; files without any still import. |
| `theme` | exercise (the selected palette: a preset's name, e.g. `Ocean blue`, or a saved palette's name). At most one, written last. Import selects it; files without one keep the current selection. |

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
| Two `palette` rows with the same name | "Row 21 repeats palette 'Sunset'; palette names must be unique" |
| `palette` named like a preset | "Row 20 uses the built-in palette name 'Lime'" |
| `palette` colour missing / not `#RRGGBB` | "Row 20 has 'red' as the ink colour in the detail column" |
| `theme` names neither a preset nor a `palette` row in the file | "Row 22 selects palette 'Sunset', which is not a built-in palette or a palette row in the file" |
| Two `theme` rows | "Row 23 is a second theme row; a file selects one palette" |

## 6. Backup on Google Drive

Designs: canvas page "Sync with Google", artboards 1–5 (`DriveOff`, `DriveOn`, `DriveBusy`, `DriveError`, `DriveSigninError`). It is a new section at the bottom of Settings, under "Your data".

**What it does:** it creates a folder called **Workout** in the user's My Drive and uploads the same CSV that Export CSV writes (plan, history, saved palettes and the selected palette) (`workout-tracker-YYYY-MM-DD.csv`, §5). It is a one-way backup: phone → Drive. Restoring is done by downloading the file from Drive and using Import CSV. There's no automatic restore or two-way sync.

### 6.1 States (from the design)

| State | UI |
|---|---|
| Off (not connected) | Section title "Backup on Drive", one line of help, an outlined **Backup on Drive** button with Google's official "G" logo. The dashed "G" in the design is a placeholder: use the asset from Google's sign-in branding guidelines and don't redraw it. |
| On (connected) | Card with a cloud ✓ icon, "Backed up to Google Drive", "Last backup: Today, 7:40 AM · 14 KB", path chip "My Drive › **Workout** › workout-tracker-YYYY-MM-DD.csv", switch **Back up automatically** ("Uploads a fresh CSV after every workout and whenever your plan or history changes.", on by default), **Back up now** (dark) and **Disconnect** (outlined). |
| Busy | Title "Backing up…", sub-line "Uploading workout-tracker-YYYY-MM-DD.csv", an indeterminate bar (a 30%-wide `dark` segment slides across the `line` track every 1.2 s and loops; Drive reports no upload progress, so never a fixed %), **Back up now** disabled at 60% opacity and labelled "Backing up…". |
| Error | Red-tinted icon, "Backup failed", the last *successful* backup time, red alert: "Couldn't upload to Google Drive: no internet connection. Your data is still safe on this phone. Tap Back up now to try again." |
| Sign-in failed | Still the **Backup on Drive** button, with a red box under it: "Couldn't sign in to Google" (14/700), "Nothing was backed up. Tap Backup on Drive to try again. If it keeps failing, the app's Google setup needs fixing." (13), then the technical reason in 12px monospace. |

### 6.2 Flow

1. **Connect** (first tap on "Backup on Drive"):
   1. `google_sign_in` sign-in, then request the scope `https://www.googleapis.com/auth/drive.file`. With this scope the app can only see files and folders it created itself, never the rest of the user's Drive.
   2. Find or create the folder: `files.list` with `q = name = 'Workout' and mimeType = 'application/vnd.google-apps.folder' and 'root' in parents and trashed = false`. Because of `drive.file`, this only finds a folder this app made earlier (e.g. before a reinstall). If there are none, `files.create` the folder. Save its id as `drive_folder_id`.
   3. Run a backup (below) and switch to **On**.
2. **Back up** (Back up now, or automatically):
   1. `CsvBackupService.snapshot()` + `encodeBackup()`. This is the same code as Export, so the Drive file and the exported file are byte-identical.
   2. Look in the folder for today's file name. If it exists, `files.update` its content; if not, `files.create` it with `parents = [drive_folder_id]` and `mimeType = text/csv`. Result: one file per day, holding the latest data for that day.
   3. On success, save `drive_last_at` and `drive_last_bytes` and clear `drive_last_error`.
   4. If the saved folder id returns 404 (the user deleted or trashed it), clear the id, re-run step 1.2 and retry once.
3. **Auto backup:** after anything in the CSV changes: a session saved (full or partial), a workout deleted from History, the day editor closed with **Save**, a day added or removed on Workouts, a workout discarded (its +/− weight and reps stay in the plan), a random palette saved or a different palette picked (§4.1), or a CSV imported. Day-editor edits are written to the database as you type, so they also upload, once, when the app goes to the background with the editor open, and when **Start Day N** leaves the editor without the save sheet. Day-editor **Discard** puts the day back as it was: it uploads nothing unless the edits already reached Drive that way, in which case it uploads again to undo them. Then, if `drive_connected && drive_auto` is true, start a backup in the background. Never block or delay the Complete / History screen. On failure, store the error and show the **Error** state in Settings; nothing on the phone changes, and the next saved workout retries.
4. **Disconnect:** `GoogleSignIn.disconnect()`, which revokes access. Clear all `drive_*` prefs and go back to **Off**. Files already on Drive stay there.
5. **Errors to map to a message:** no internet (`SocketException`) → the design's message. Sign-in cancelled → stay **Off**, no error. Token expired (401) → clear the cached token and retry once. Still 401, a 403 `insufficientPermissions`, or no token available without UI during an auto backup → "Google Drive access was removed. Tap Back up now to connect again." (stays connected; Back up now is interactive and shows Google's consent again). Sign-in cancelled (12501) → stays **Off**, nothing shown. Any other sign-in failure → stays **Off** with the box from state 5 under the button: "Couldn't sign in to Google", the retry hint, and the platform code + message in monospace; Error 10 / [28444] reads "Error 10 (DEVELOPER_ERROR): the app's SHA-1 or package name doesn't match its Google OAuth client." Drive full (403 `storageQuotaExceeded`) → "Your Google Drive is full."

### 6.3 Code

- `lib/app/google_config.dart`: the Web client id (`serverClientId`). Public; the client secret is never used or committed.
- `lib/data/drive_backup_service.dart`: `DriveAuth` (interface) + `GoogleDriveAuth` (google_sign_in); `DriveBackupService.connect()` / `backup()` / `disconnect()` on the `googleapis` `DriveApi`, taking `CsvBackupService` for the CSV bytes; `DriveFailure` maps errors to the messages above.
- `lib/app/providers.dart`: `driveBackupProvider` (`DriveBackupNotifier`) holds the state (`off` / `on` / `busy` / `error`) and the prefs above; `afterDataChanged()` runs the auto backup; a change that lands mid-upload queues one more upload.
- `lib/features/settings/drive_section.dart`: the "Backup on Drive" section (4 states), placed at the bottom of Settings. The switch is token-coloured (`dark` on, `border2` off). Google "G" = `assets/images/google.png` (24×24). Disconnect works immediately, even mid-upload (the upload's result is then ignored).
- Call sites, each firing `afterDataChanged()` without awaiting it: active workout `_save()` and `_discard()`, History delete (long-press → Delete), day editor Save (and Discard after a background upload), day editor `_backupUnsaved()` (app hidden via `AppLifecycleListener`, and **Start Day N**; skipped when the day matches what was last uploaded), Workouts +/− day, Settings Import, Settings palette save and palette pick.
- `test/drive_backup_test.dart`: an in-memory fake Drive behind `MockClient`. Covers new vs reused folder, create vs update today's file, next-day file, trashed/deleted folder recovery, 401 retry, access removed, Drive full and offline.

### 6.4 Setup outside the code (one-time)

1. **Google Cloud project** (console.cloud.google.com, free): create a project and **enable the Google Drive API**.
2. **OAuth consent screen** (Google Auth Platform → Branding / Audience / Data access): app name, support email, and the scope `.../auth/drive.file`. This is a non-sensitive scope, so no Google security review is needed. While the app is in **Testing**, only the Google accounts added as test users can sign in. Move it to **In production** before sharing the APK widely.
3. **Android OAuth client** (Credentials → Create OAuth client ID → Android): package name `com.shubham.workout_tracker` plus the **SHA-1 of the signing key**. Make one client per key:
   - Debug key: `keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android`
   - Release: today `android/app/build.gradle.kts` signs release builds with the **debug** key, so the same SHA-1 works for now. Once a real release keystore is made (§8.3), add a second Android client with its SHA-1. Google sign-in fails with error 10 (`DEVELOPER_ERROR`) when the SHA-1 or package name doesn't match.
4. **Web OAuth client** (same project, type "Web application"): its client id is passed to `google_sign_in` as `serverClientId`. Current versions of the plugin (Credential Manager) need it on Android. No `google-services.json` or Firebase is needed.
5. **AndroidManifest:** add `<uses-permission android:name="android.permission.INTERNET"/>` to `android/app/src/main/AndroidManifest.xml`. Flutter only adds it to the debug/profile manifests, so without it release builds can't reach Drive.
6. **Phone:** needs Google Play services and a Google account.

## 7. Project structure

```
lib/
  main.dart
  app/        router.dart, theme.dart (4 colour themes)
  data/       database.dart (drift tables), daos/, csv_backup_service.dart, drive_backup_service.dart
  features/
    plan/     workouts_screen.dart, day_editor_screen.dart
    workout/  active_workout_screen.dart, quit_sheet.dart, complete_screen.dart
    history/  history_screen.dart
    settings/ settings_screen.dart, import_sheet.dart
  widgets/    set_row.dart, stepper_button.dart, phase_stepper.dart
test/
  fixtures/   sample_valid.csv (§5.1), sample_missing_reps.csv (§5.2)
```

## 8. Dev environment, build & install (VS Code only, no Android Studio)

Testing is on a real Android phone over USB, so no emulator is needed.

### 8.1 One-time setup on the PC

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

### 8.2 Daily development in VS Code

- Create the project: `flutter create --org com.yourname --platforms=android workout_tracker`
- Open the folder in VS Code, pick the phone in the device selector (bottom-right status bar), press **F5** to run with hot reload.
- drift code generation: `dart run build_runner watch --delete-conflicting-outputs` in a VS Code terminal.
- Testing CSV import on the phone: copy `test/fixtures/sample_valid.csv` to the phone (`adb push test/fixtures/sample_valid.csv /sdcard/Download/`), then Settings → Import CSV → Downloads.

### 8.3 Make a real APK

- `flutter build apk --release`
- Output: `build/app/outputs/flutter-apk/app-release.apk`
- Install with `flutter install`, or copy the APK to the phone and allow "Install unknown apps".
- Tip: `flutter build apk --split-per-abi` gives smaller APKs (use the `arm64-v8a` one on modern phones).
- For personal testing the default debug signing is fine; create your own keystore (`keytool`, comes with the JDK) before sharing widely or publishing to Play Store.

Note: uninstalling the app deletes all data. Use Settings → Export CSV first, or make sure Backup on Drive has a recent backup.
