# Segue

A setlist-only script (no PDFs), with its own window and its own data. It uses only `reaper.*` and ReaImGui (no
`io` / `os`, no files of its own), so it is not Windows-only.

## Files

- `Segue.lua` and the action `Segue - Next song.lua` (`@provides`).
- Version: `@version` and `CFG.VERSION` together; its own `@changelog`. Release: tag `segue-vX.Y`, title
  "Segue X.Y" (the `release` skill).

## Architecture and data

- Modules: `CFG`, `COL`, `S` (this computer: ExtState "Segue", persistent), `R` (runtime), `P` (project data,
  ProjExtState "Segue"/"cfg"), `Util`, `Project`, `Setlist`, `UI`.
- Project data: new keys only, written only when they differ from the default.
- Segue never writes Chart Cue's data, and Chart Cue never reads Segue's. The 1 exception, for the conflict check
  (`Setlist.conflict`): Segue reads Chart Cue's heartbeat and the `setlist_on` line of its project data, and
  "Use Segue" sends Chart Cue the `setlistoff` command (its `cmd_q`).
- `Setlist` and `UI.draw_now_view` are the same in Chart Cue: a fix or a change in one, list it for the other
  script and ask me before you make it there.

## Deployment and tests

- `.\tools\deploy.ps1` copies Segue to `Scripts\Thunderfork Scripts\Segue\` (ReaPack), else `Scripts\Segue\`.
- Tests: `tests\segue.lua` (`.\tools\test.ps1 -Script "Segue"`; result in `tests\result_segue.txt`).
