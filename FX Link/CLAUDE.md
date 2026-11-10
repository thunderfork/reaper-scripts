# FX Link

Links plugin instances across tracks: a change in one instance of a link group is copied to the other instances
(Exact: the same value; Relative: the same change). Small Chart Cue look: a toolbar (Show plugins, search, gear, "?"),
one panel with foldable sections (Link groups, Link settings, Linked parameters, Plugins), no tabs.

## Files

- `FX Link.lua`; the actions `FX Link - Show plugins.lua` and `FX Link - Toggle group.lua` (ExtState "cmd_q"). Version: `@version` and `CFG.VERSION` together (1.0, not released yet). Release: tag
  `fxlink-vX.Y`, title "FX Link X.Y" (the `release` skill).

## Architecture and data

- `P` (ProjExtState "FX Link"/"cfg"): the groups (`group=` on, mode, parameters: "all", the picked list, or "x" +
  the list that is not linked (All except), plugin identity, short plugin name, name), `g_sort=name` and
  `g_bypass=1` (only when not the default), their instances (`fx=` FX GUID, track name, plugin name: for Find
  again), the snapshots (`g_snap=A|B` + time, then `sv=` FX GUID + `param:value` list), the selected group (`cur`).
- `S` (ExtState "FX Link"): `light`, `dock`, `closed` (the folded sections), `close_proj` (Close with project, default
  on), `backup_dir` (the Back up / Restore folder; "" = the data folder); also `cmd` (the command ID for the
  watcher) and `heartbeat` (not kept). The data folder is REAPER's Data\FX Link: the default backup folder, and `autostart.lua` (the watcher; "Open automatically" adds a marked block to `__startup.lua`, with the
  backup `__startup.lua.fxlink-backup`). Gear menu: Look, Automatic open and close, Window, Backup.
- Modules: `Util` (also the settings and backups), `Project`, `Fx` (find the instances by FX GUID, add them, select
  their tracks), `Link` (copy the changes), `Autostart`, `UI`.
- The source of a change is REAPER's last touched FX (`GetLastTouchedFX`). Each frame only that instance is read
  and compared with its snapshot (`R.rt[member].val`); `virt` keeps the unclamped Relative value. The snapshots are
  read again after undo / redo. After linked changes, 1 undo point ("FX Link: linked plugin change").
- REAPER's Bypass, Wet and Delta parameters are never linked. FX inside FX Containers: `Fx.each` walks them; their
  index is REAPER's container address (>= 0x2000000).
- Relative uses real units (dB, ms / s, %) from `TrackFX_FormatParamValueNormalized` and a search for the knob
  position (`Link.find_unit`); else the knob's range. Hz stays on the knob's range (already logarithmic).
- Out of sync (`Link.check_sync`): 1 Exact group every 0.5 s against the plugin moved last.

## Deployment and tests

- `.\tools\deploy.ps1` copies it to `Scripts\Thunderfork Scripts\FX Link\` (ReaPack), else `Scripts\FX Link\`.
- Tests: `tests\fxlink.lua` (`.\tools\test.ps1 -Script "FX Link"`; result in `tests\result_fxlink.txt`).
