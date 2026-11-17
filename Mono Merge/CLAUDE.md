# Mono Merge

Joins 2 selected mono items into 1 new stereo file: the top item left (on 1 track: the earlier item), the other
right. No window and no ReaImGui: 2 actions. A ReaImGui version (drop areas) is a possible later step.

## Files

- `Mono Merge.lua`: the action "make stereo (with edits)" and all the logic. `Mono Merge - Make stereo (raw
  files).lua`: sets `MonoMergeMode = "raw"` and runs `Mono Merge.lua`. Version: `@version` and `CFG.VERSION`
  together. Release: tag `monomerge-vX.Y`, title "Mono Merge X.Y" (the `release` skill).

## Behaviour and data

- No saved data (no ExtState, no ProjExtState).
- A new track below the lower of the 2 tracks, named after the common part of the 2 track names (on 1 track: the
  item names), else "A + B". On it: a copy of each item, panned hard left / right (take pan), glued by REAPER
  (action 40362) into 1 stereo item. The file name and format come from REAPER's glue settings (for example
  "01-Kick-glued.wav"); the take is renamed to the common name. The pan law does not change hard-panned takes (test).
- With edits: what you hear (trims, fades, item and take volume, take FX, rate; a muted item is read too); a gap
  between the items stays silent. A stereo item is allowed when its take channel mode is mono (downmix, left, right).
- Raw files: the whole source files, start aligned where the left file starts on the timeline (not before 0).
  A stereo file that plays as mono (take channel mode) asks first (Yes / No); Yes keeps only its channel mode.
- The shorter side gets silence. The 2 mono items are muted (not their tracks); only the new item is selected.
  1 undo step. Blocking, but short (REAPER's glue: about 0.4 s for a 3-minute pair).
- Never delete a glued file: REAPER then asks on save whether to delete unused files (the glue happens on the
  new track, so nothing is deleted).
- The new track stays inside a folder when the lower track closed it. The copies are unlocked and a take pan
  envelope is turned off on them (else no glue, or mixed sides). A missing file (not on the disk) stops it.
- Modules: `Util` (the common name), `Merge` (check, order, name, run).

## Deployment and tests

- `.\tools\deploy.ps1` copies it to `Scripts\Thunderfork Scripts\Mono Merge\` (ReaPack), else `Scripts\Mono Merge\`.
- Tests: `tests\monomerge.lua` (`.\tools\test.ps1 -Script "Mono Merge"`; result in `tests\result_monomerge.txt`).
