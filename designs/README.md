# Designs

Source of the **Workout Tracker** design canvas (claude.ai Design artifact),
downloaded on 2026-11-21. The app's UI is built to match these.

| File | What it is |
|---|---|
| `MainThemed.dc.html` | The whole app in one interactive artboard, with every screen, the palette switcher, Settings, CSV export/import. **Reference for the app.** |
| `Main.dc.html`, `MainOcean.dc.html`, `MainGold.dc.html`, `MainRose.dc.html` | The same app fixed to one palette (Lime, Ocean blue, Gold & gunmetal, Rosewood & aqua). |
| `<Palette><Screen>.dc.html` | One screen in one state, e.g. `WarmupActive`, `LiftsDone`, `QuitSheet`, `History`, `EditAddExercise`. Prefixless = Lime; `Ocean…`, `Gold…`, `Rose…` = other palettes; `Switch…` = the switchable-palette page (Settings, export/import states). These are thin wrappers that import a `Main*` file with demo props. |
| `canvas.json` | Canvas layout: artboard positions and sizes, pages, and the notes (screen behaviour, data model, CSV format). |

## Images

`images/` has PNG exports of the artboards (780×1688, i.e. the 390×844 phone
frame at 2×), one folder per palette:

| Folder | Palette | Screens |
|---|---|---|
| `images/lime/` | Lime | 1.1–1.6 plan / edit / history, 2.1–2.8 workout flow |
| `images/ocean/` | Ocean blue | same 14 screens |
| `images/gold/` | Gold & gunmetal | same 14 screens |
| `images/rose/` | Rosewood & aqua | same 14 screens |
| `images/switchable/` | Switchable palette | 1–10: gear → Settings, palette & unit, export / import states |

## Viewing

These are Design Component (`.dc.html`) files. They load `./support.js`, the
canvas runtime, which only exists in the Design artifact, so opening them
straight from disk shows unstyled markup. To see them rendered, open the canvas
artifact on claude.ai. Use these files for reading markup, colours and copy,
and for diffing design changes in git.

When the design changes, download the files again into this folder and commit,
so the diff shows exactly what changed.
