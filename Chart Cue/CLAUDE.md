# Chart Cue

A Windows-only REAPER Lua / ReaImGui script that shows and scrolls PDF charts during playback. The UI style guide
of the other scripts (see the root CLAUDE.md). Screens: the toolbar, the right-click menus; Settings sections
Viewer, Playback, Control, Appearance, General.

## Files

- `Chart Cue.lua` (the script) and the action scripts `Chart Cue - Next page.lua`, `Chart Cue - Previous page.lua`,
  `Chart Cue - Toggle performance mode.lua`, `Chart Cue - Next song.lua` (`@provides`).

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

## Data

- The data folder (on every user's computer): `%APPDATA%\REAPER\Data\Chart Cue\` (`settings.ini`, `cache\`,
  `tmp\`, `autostart.lua`, `Chart Cue Guide.html`). Reading it is OK. Never change, move or delete anything there
  without asking me: it holds my real settings, and the `__startup.lua` block points to `autostart.lua` in it.

## Tests

- The PDF of `tests\run.lua`: `tests\test.pdf` (`tests\make_pdf.lua` makes it; run it with the normal Lua, not REAPER).
- The UI test (`.\tools\ui-test.ps1`, steps in `tools\ui-test.lua`; the `ui-test` skill) covers menus, popups,
  tabs, Settings sections and views; add a step for each new one.
## Later (ideas)

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

## Open findings (from a checkup; not decided: ask before a fix)

- Bugs: `Project.remap_pdf` / `remove_from_library` do not remap or clear `P.assign2`; `UI.ask_remove_pdf` and
  `Project.region_use_count` count only PDF 1. `draw_now_view`: the pause bar uses the nearest pause row (also a
  skipped one; keep `sec` in the hold at song_ended); `Setlist.length` counts pauses that never play.
  `Setlist.next_cmd`: on a REAPER pause it resumes the current song (press Play only after the setlist's own stop; fix
  the Help line too). The last 2: the same in Segue.
- Per-frame costs: region_counts, tab strip variants, draw_status parts, mode_hint, cue list entries, lib_name_w key.
- Tidy: `UI.button_pair2` unused, CUE_START twice.
- Ideas: "Close Chart Cue" in the right-click menu while playing asks no question; a missing PDF during playback
  keeps the old chart with the warning hidden; empty-region PDF buttons clickable while playing / locked; blue as
  the "on" state (Lock, Hide panel, Play); Help text errors.
