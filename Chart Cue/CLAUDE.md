# Chart Cue

A Windows-only REAPER Lua / ReaImGui script that shows and scrolls PDF charts during playback. The UI style guide
of the other scripts (see the root CLAUDE.md). Screens: the toolbar, the right-click menus; Settings sections
Viewer, Playback, Control, Appearance, General.

## Files

- `Chart Cue.lua` (the script) and the action scripts `Chart Cue - Next page.lua`, `Chart Cue - Previous page.lua`,
  `Chart Cue - Toggle performance mode.lua`, `Chart Cue - Next song.lua` (`@provides`).
- Version: `@version` and `CFG.VERSION` together; 1-3 user-facing `@changelog` lines. Release: tag `vX.Y`, title
  "Chart Cue X.Y" (the `release` skill).

## Architecture

- `CFG`: constants, paths, defaults and named sizes in pixels (CFG.UI_SCALE: the icons; use a named size, not a
  new plain number, for a size that repeats). `COL`: the colours (THEMES / apply_theme).
- `S`: global settings in `settings.ini`. `R`: runtime state. `P`: project data (ProjExtState "ChartCue"/"cfg").
- `Util` (paths, files, time, settings load / save), `PDF` (info, rendering, cache, page images), `Project`
  (regions, markers, library, project data), `Cues` (the cue list per region and its undo), `Notes` (P.notes),
  `Setlist` (P.setlists, stop / continue / pauses, undo; the same logic as Segue's), `Nav` (page, scroll, zoom,
  autoscroll), `Midi` (MIDI input, CCs, the action scripts' commands), `Msg` (messages, errors, diagnostic log),
  `Dock` (docking, window, resize edges), `Autostart` ("Open automatically": the block in `__startup.lua` and
  `autostart.lua`), `UI` (the interface and the deferred loop).
- Poll background PDF jobs at most every 100 ms.
- `Setlist` and `UI.draw_now_view` are the same in Segue: a fix or a change in one, list it for the other and ask.

## Deployment and data

- `.\tools\deploy.ps1` copies the scripts to the first folder that exists: `%APPDATA%\REAPER\Scripts\Thunderfork
  Scripts\Chart Cue\` (ReaPack), else `%APPDATA%\REAPER\Scripts\`.
- The data folder (on every user's computer): `%APPDATA%\REAPER\Data\Chart Cue\` (`settings.ini`, `cache\`,
  `tmp\`, `autostart.lua`, `Chart Cue Guide.html`). Reading it is OK. Never change, move or delete anything there
  without asking me: it holds my real settings, and the `__startup.lua` block points to `autostart.lua` in it.

## Tests

- `tests\run.lua` (`.\tools\test.ps1 -Script "Chart Cue"`; result in `tests\result.txt`). Its PDF:
  `tests\test.pdf` (`tests\make_pdf.lua` makes it; run it with the normal Lua, not REAPER).
- The UI test (`.\tools\ui-test.ps1`, steps in `tools\ui-test.lua`; the `ui-test` skill) covers menus, popups,
  tabs, Settings sections and views; add a step for each new one.
- Before a release (sharing a new version): the release checklist below, in REAPER.

## Release checklist (in REAPER)

1. Version: @version and CFG.VERSION are equal; @changelog has 1–3 user-facing lines.
2. Start: Chart Cue starts without errors; the last tab and the open Settings section come back.
3. Project data: set a mode, Seconds, "Turn pages", "Scroll", a PDF; close and open Chart Cue, then save, close and
   reopen the project: all values come back.
4. Save as: "Save as" keeps Chart Cue open with the same data; File > Open of another project in the same tab loads
   that project's data (or closes Chart Cue with "Close with project").
5. Project tabs: switch between 2 open projects; each shows its own library and cues.
6. PDFs: add a PDF and a folder; copy into the project; replace a PDF (same name, and "Replace PDF..."); relocate a
   missing PDF. Use a Greek folder and file name with spaces and an apostrophe.
7. Engines: open a PDF with the Windows engine and with Poppler; clear the page cache while a PDF is open.
8. Regions: rename, move, undo, save and reopen: the PDF assignment stays. "Keep last page" during playback in a
   region without a PDF; the page can be turned.
9. Cues: record page turns and scroll points (Record on and off, Lock on); "+ below" and "Use current view" (also on
   the Start row); Undo and Ctrl+Z; switch Beats / Seconds; a wrong value shows a red border; Scroll Smooth / Jump.
10. Markers: PDFPAGE / PDFSCROLL markers scroll the page; "Remove PDF markers..." asks first and Ctrl+Z brings them
    back.
11. Control: keys (window active); the 4 actions (window not active, also in lock mode), and Assign... in
    Settings > Control; MIDI absolute and relative; MIDI page turns and cue buttons; every right-click menu.
12. Stage: performance mode on / off (also with Page area Setlist); lock; hide panel when playing; page brightness
    (slider and toolbar button); page-turn countdown; notes (add, drag, edit, colour, size).
13. Setlist: make, reorder (drag, arrows, menu), skip, remove and undo, pauses, Stop / Continue (adjacent and far
    songs), play buttons, Next song action, Lock setlist, Page area Setlist and Setlist and PDF, duplicate with a
    pause, another project.
14. Window: dock and undock (menu); resize the floating window at each edge and the corner; collapse and open; hide
    tabs and toolbar items.
15. Large set: a 300-page PDF and a project with 30 regions: start time, page cache size and limit, smooth playback.
16. Automatic tests: `.\tools\test.ps1` ("0 failed") and `.\tools\ui-test.ps1` ("no errors").

## Later (ideas, moved from PLAN.md 24 November 2026)

- Guitar Pro files: convert to PDF with MuseScore's command line (optional external program, like Poppler).
- REAPER forum button in Help > About (disabled until there is a forum thread).
- No way to show the mode hint again after "Not now".
- A "Sharper page available" hint after the zoom stays the same (instead of an automatic DPI match).
- Setlist: "Loop" as a song ending (loops until Next song).
- Night mode: the page inverted (white notes on black) for very dark stages.
- Undo for a deleted note.
- PDF 2: a "(both)" view of the 2 cue lists in the Cues tab, and MIDI CCs for PDF 2.
- UI scale 100 / 125 / 150 %: the drawn icons already use CFG.UI_SCALE, and the repeated sizes have names in CFG.
  Still needed: the fonts rebuilt between frames, every pixel size in CFG times the scale, and a test of every
  screen at each scale. Ask the user first.
