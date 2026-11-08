# Chart Cue

A Windows-only REAPER Lua / ReaImGui script that shows and scrolls PDF charts during playback. The UI style guide
of all 3 scripts (see the root CLAUDE.md).

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

- `tests\run.lua` (`.\tools\test.ps1 -Script "Chart Cue"`; result in `tests\result.txt`).
- The UI test (`.\tools\ui-test.ps1`, steps in `tools\ui-test.lua`; the `ui-test` skill) covers menus, popups,
  tabs, Settings sections and views; add a step for each new one.
- Before a release: the release checklist in PLAN.md (in REAPER).
