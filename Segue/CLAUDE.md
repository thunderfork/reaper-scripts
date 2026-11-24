# Segue

A setlist-only script (no PDFs), with its own window and its own data. It uses `reaper.*` and ReaImGui, and `io`
only for its files in `Data\Segue` (backups, the autostart watcher `autostart.lua`) and the marked block in
`__startup.lua` (Open automatically, as FX Link; backup `__startup.lua.segue-backup`). It is not Windows-only.
Gear menu: Look, Automatic open and close (Open automatically, Close with project: S `close_proj`, default on),
Window, Backup.

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

## Later (ideas, moved from PLAN.md 24 November 2026)

- Segue: a thin countdown bar, a UI test for Segue. From the ReaSet changelog: repeat a song N times; region colours
  in the list; a note per song; the next marker / section in the now playing area, with a 2nd thinner progress bar;
  an option that forces an immediate jump when REAPER's smooth seek is on.
