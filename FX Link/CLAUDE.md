# FX Link

Links plugin instances across tracks: a change in one instance of a link group is copied to the other instances
(Exact: the same value; Relative: the same change). Small Chart Cue look: a toolbar (Show plugins, search, gear, "?"),
one panel with foldable sections (Link groups, Link settings, Linked parameters, Plugins), no tabs. The gear menu:
Look, Automatic open and close, Window, Backup.

## Files

- `FX Link.lua`; the actions `FX Link - Show plugins.lua`, `FX Link - Toggle group.lua` and
  `FX Link - Group focused plugin on selected tracks.lua` (ExtState "cmd_q": show, toggle, quick).

## Architecture and data

- `P` (ProjExtState "FX Link"/"cfg"): the groups (`group=` on, mode, parameters: "all", the picked list, or "x" +
  the list that is not linked (All except), plugin identity, short plugin name, name), `g_sort=name` and
  `g_bypass=1` (only when not the default), their instances (`fx=` FX GUID, track name, plugin name: for Find
  again; `fx_off=1` after it when that plugin is paused), the snapshots (`g_snap=A|B` + time, then `sv=` FX GUID + `param:value` list), the selected group (`cur`).
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
- Known limit (as Chart Cue): File > New project in the same tab over a never-saved project is not seen.
- To watch: plugins that show meters as parameters would link and show "differ"; the workaround is All except.

## Open findings (from a checkup; not decided: ask before a fix)

- Bugs: `Link.read_cmds`: old `cmd_q` presses run at the start (clear `cmd_q` at the start, as Chart Cue does).
  `Link.learn` / `Link.tick`: the knob touched last before Learn is never added (store its value).
  `UI.draw_picker`: R.pnames of the old group after a group change (keep R.pick_g); changes in the 0.75 s after a
  snapshot recall are lost (`Link.snap_tick` calls group_changed).
- Saved data (ask): `Project.save` writes "version=1" for an empty project, so Open automatically still opens it.
- Per-frame costs: picker labels, "Missing" strings, the A/B table; the UI.trunc_c key without the font, never
  cleared. Tidy: `UI.draw_ask` OK branch, `R.picked_cache`.
- Ideas: no empty / taken check for group names; a group click changes the track selection and marks the project
  changed; Help text errors.
