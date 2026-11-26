# Segue

A setlist-only script (no PDFs), with its own window and its own data. It uses `reaper.*` and ReaImGui, and `io`
only for its files in `Data\Segue` (backups, the autostart watcher `autostart.lua`) and the marked block in
`__startup.lua` (Open automatically, as FX Link; backup `__startup.lua.segue-backup`). It is not Windows-only.
Screens: the setlist, the now playing view, the gear menu: Look, Automatic open and close (Open automatically,
Close with project: S `close_proj`, default on), Window, Backup.

## Files

- `Segue.lua` and the action `Segue - Next song.lua` (`@provides`).

## Architecture and data

- Modules: `CFG`, `COL`, `S` (this computer: ExtState "Segue", persistent), `R` (runtime), `P` (project data,
  ProjExtState "Segue"/"cfg"), `Util`, `Project`, `Setlist`, `UI`.
- Project data: new keys only, written only when they differ from the default.
- Segue never writes Chart Cue's data, and Chart Cue never reads Segue's. The 1 exception, for the conflict check
  (`Setlist.conflict`): Segue reads Chart Cue's heartbeat and the `setlist_on` line of its project data, and
  "Use Segue" sends Chart Cue the `setlistoff` command (its `cmd_q`).
- `Setlist` and `UI.draw_now_view` are the same in Chart Cue: a fix or a change in one, list it for the other
  script and ask me before you make it there.

## Later (ideas)

- Segue: a thin countdown bar, a UI test for Segue. From the ReaSet changelog: repeat a song N times; region colours
  in the list; a note per song; the next marker / section in the now playing area, with a 2nd thinner progress bar;
  an option that forces an immediate jump when REAPER's smooth seek is on.

## Open findings (from a checkup; not decided: ask before a fix)

- Bugs: `Setlist.read_cmds`: old `cmd_q` presses run at the start (clear `cmd_q` at the start and in on_exit, as
  Chart Cue does). The pause bar and `Setlist.length`, and `Setlist.next_cmd` on a REAPER pause: as in Chart Cue
  (its folder CLAUDE.md).
- Per-frame costs: the row names are cut every frame. Tidy: `UI.draw_ask` OK branch.
- Ideas: no pcall guard around the loop; no "move only by title bar" option.
