# SFX Drop

Puts sound effects from a library (impacts, risers, drops, atmospheres) on the beat of the backing tracks: it finds
the hit point of each sound, so the user never nudges an item. A preparation tool: no live features; in the
project only the Soundcheck settings (P, below). Chart Cue look with a tab strip: Sounds, Spots, Soundcheck, Settings (gear), Help ("?"); Settings has collapsing sections,
1 open at a time (`S.settings_open`): Appearance, Library, Insert (headings Items, Files, Tracks, Levels), Window, with the bold
label column (`UI.form_label`, `UI.form_toggle`), as in Session Prep.

## Files

- `SFX Drop.lua` only. Version: `@version` and `CFG.VERSION` together. Release: tag `sfxdrop-vX.Y`,
  title "SFX Drop X.Y" (the `release` skill).

## Architecture and data

- `P` (ProjExtState "SFX Drop"/"soundcheck", only what differs from the defaults; all defaults: no key): the
  Soundcheck settings "src={GUID};len=90;steps=3;imp=0;rep=2" (src the source track; len 60-300 s; steps 3-8; imp the
  impacts zone, on; rep 1/2/4/8, default 4). Loaded on each project switch (tab or file).
- `S` (ExtState "SFX Drop"; a key is written only when it differs from its default): `light`, `dock`,
  `tab`, `settings_open` (2), `library` (the folder, "/" paths), `place` (cursor / bar / regions), `trim` (on),
  `fades` (on), `fade_ms` (5), `color` (on), `select_item` (on), `riser_bars` (0 = Off; 1 / 2 / 4 / 8),
  `level_on` (off), `spot_sens` (6 dB), `sort` (name), `sort_desc` (off), `copy` (off), `copy_asked` (off: the first-start
  question comes when the library is set), `copy_warn` (500 MB), `spot_off` (the types that are off in Spots > Add, "Drops,Atmos"), `spot_words`
  (Spots > Sounds with), `fx_out` (0 = master, k = hardware outputs 2k-1/2k), `vary` (off),  `lvl_<Type>` (the target of a type) and `lvm_<Type>` (lufs / peak); their
  defaults from `TYPES[].level` / `.mode` (Impacts, Drops: Peak -6; Risers LUFS -18; Atmos LUFS -24; Other LUFS -18).
- The index: `Data\SFX Drop\library.txt` (REAPER resource folder). Line 1 "SFX Drop library<TAB><folder>" (another
  folder: the index is not used); then 1 line per sound: type, len, start, peak, tail, own ("" = automatic), fav
  (0 / 1), level (dB), top (the peak, dB), path. A line of another format is skipped (no migration: the library is
  read again).
- Modules: `Util` (also the settings and the folder picker, as MIDI Pilot's), `Lib` (scan, type, hit points,
  index, search view, favourites, `Lib.by_type`), `Drop` (targets, layout, riser length, levels, the FX tracks,
  put / insert_list / insert, learn), `Spots` (Find spots), `Prev` (SWS preview), `UI`.
- Type (`Lib.type_of`): the closest folder first, then the folders above, then the file name; per part the types in
  `TYPE_ORDER` (Risers, Drops, Impacts, Atmos); a word of 3 letters or less matches only a whole word (or + "s").
- Hit points (`Lib.analyse` -> `Lib.measure`, no REAPER calls in measure): the file's peaks (`PCM_Source_BuildPeaks`,
  `PCM_Source_GetPeaks`, 1000 per s, at most 60000 per file); start = first peak above -26 dB under the top; peak =
  the loudest 20 ms (the last when equal); tail = last peak above -60 dB under the top. `Lib.hit`: own, else the
  type's default (Risers: peak; others: start).
- Insert (`Drop.insert`, 1 undo point "SFX Drop: insert <name>"): `Drop.layout` (pure) puts the hit point on each
  target; Trim silence = 3 ms before the start, 50 ms after the tail; before the project start the start is cut.
  Targets (`Drop.targets`): the edit cursor, the nearest bar line (halfway: the earlier one), the region starts in
  the time selection (none: all regions).
- Tracks (`Drop.folder`, `Drop.type_track`): the folder track "FX" (depth 1, found by name in any case) and a direct
  child per type, found by name; a new child goes after the last child and takes over its closing depth.
- Learn (`Drop.learn`): the last insert (`R.last`) -> own = (target - item position) * play rate + take offset.
- Riser length: no stretching (the user found it changed the samples too much). `Lib.riser_fit`: a riser whose
  length in bars (the Bars column; the build-up was tried, but the soft start of a riser made it wrong) is within 10 % of `S.riser_bars` bars (`Lib.bar_sec`: the tempo and time signature
  at the edit cursor) comes first in `Lib.view` and in `Spots.fill`. The Bars column: length / `Lib.bar_sec()`
  (blue when the riser fits).
- Levels (`Drop.gain`, when `S.level_on`): item `D_VOL` = the type's target - the sound's LUFS (`level`:
  `Lib.measure`, the average from start to tail, peak envelope - 3 dB; no K filter) or its peak (`top`), per
  `S.lvl_mode`, within +-24 dB.
- Find spots (Spots tab): `Spots.find_begin` (the selected tracks with items, else all; never the FX folder,
  `Drop.fx_tracks`; the time selection, else the project; its bars and regions), `Spots.find_step` (a track audio
  accessor per track, 1 read per bar at 2000 Hz, the power of the tracks added; 30 ms per frame), `Spots.analyse`
  (pure: bars below -60 dB count as -60; a jump = the 2 bars after a bar line against the 2 before, at least the
  sensitivity, the largest of its neighbours of the same sign -> rise (Risers + Impacts) / fall (Drops); a quiet part
  of 4+ bars 12 dB under the average -> Atmos; a region start that is no spot -> Impacts; quiet and region not
  ticked), `Spots.fill` (per type the first sound of `Lib.by_type`, favourites first; a sensitivity change keeps the
  choices), `Spots.insert` (1 undo point "SFX Drop: insert spots").
- Scan in steps (`Lib.scan_begin`, `Lib.scan_step`: 30 ms per frame; "list" then "read"); Rescan keeps the entries
  of known paths, "Read all again" (full) reads every file and keeps `own`. `Lib.scan` does it at once (the tests).
- Hot paths: `Lib.view` is cached in `R.view` (nil after a search, filter or library change); the list uses a
  ListClipper; names cut with `UI.trunc_c`.
- Keys: Enter inserts the selected sound (Sounds tab). Ctrl+Z / Ctrl+Y go to REAPER.
- Favourites: the star column (`UI.star_button`), Type > Favourites (`R.filter` -1), saved in the index.
- Copy into the project (`S.copy`): `Drop.source` copies a sound once into "<project folder>/SFX Drop"
  (`Drop.copy_target`: the same name and size is used again, else "Name (2).wav"); an unsaved project or a failed copy
  uses the library file (a notice). `UI.guarded` asks first (Copy / Use the library file / Cancel) when the folder
  would grow above `S.copy_warn` MB (`Drop.copy_need`). Clean up (`Drop.cleanup_list`, `UI.cleanup`): the files of
  the folder that no take of this project uses (parent sources too) and that no other .rpp of the project folder
  names (its file name in the text); asks, then `os.remove`.
- Fades: the fade-in ends at the start of the sound (`e.start - offs`), so it never softens a hit.
- The spots belong to the project of the last Find (`R.spot_proj`); another project tab clears them. `Lib.find`
  uses a lookup table (`R.by_path`, reset by `Lib.changed`).
- Modal questions: `UI.ask(text, {label, fn}, {label, fn})` + Cancel, drawn by `UI.draw_ask`.
- Scan Pause / Stop on the status line (`R.scan.paused`, `Lib.scan_stop`: keeps the sounds read so far and the
  known sounds not reached; Rescan reads the rest).
- Spots tab layout: Find, Sensitivity and the track count in 1 line; 1 line per spot (`UI.spot_line`: tick, bar,
  `Spots.short`, the sounds as combos without arrow); per region (`Spots.groups`: the regions of the last Find with
  `t_end`, cached in `R.spot_groups`; spots outside the regions last; a heading with a fold arrow `R.spot_fold`, a
  tick for all and the count). No regions: 1 plain list.
- Spots > Add: type chips (`UI.type_chip`: the type's color when on, grey when off; never blue), `Spots.type_on`,
  `Spots.visible` (a spot shows when one of its types is on), `Spots.list` skips the types that are off. Sounds with:
  `Spots.words`, `Spots.pick` (a sound with one of the words, favourites first; a riser that fits first);
  `Spots.repick` after an edit (the ticks stay).
- Soundcheck (`Sc`): `Sc.find_begin` / `Sc.find_step` read the source track bar by bar (500 Hz: the power, the peak
  and its time) over the songs (the regions; no regions: the project); `Sc.make_plan` (pure): the impacts zone (each
  different sound of the Impacts and Drops tracks, `Sc.fx_sounds`, then the `SC_SRC_HITS` strongest hits of the source,
  `Sc.source_hits`: a peak 10 dB above the bar before), each `rep` times, at most 60 % of the full length (the rest is
  dropped, a notice); the steps share the rest (`L`); `Sc.pick_areas` (pure): windows of L s from a bar line inside one
  song with no silent bar, spread over the levels (the 10 % quietest up to the loudest) without overlap, sorted quiet to
  loud. `Sc.build` (1 undo point "SFX Drop: build soundcheck"): `Sc.remove_old` (the marked track and items, the region
  "Soundcheck" and its markers), `Sc.make_track` (a copy of the source track's chunk with new TRACKID / FXID, no items,
  at the end of the track list, depth 0, mark `P_EXT:SFXDropSC`), the steps with a marker each, then the zone (1 s apart),
  then the region (2 bars after the project end). Copies: `Sc.copy_part` (the item chunk without GUIDs, offsets moved,
  10 ms fades on cut edges). The plan list texts are made once in `Sc.find_done`.
- Soundcheck from a folder: `Sc.members` (the folder track and its tracks); Find reads every member with items (their
  powers add up, the peak is the largest); `Sc.make_tracks` copies all members at the end (the same depths, the last one
  closes only the new folder; the top is named "Soundcheck"); the steps are copied per member to its copy; the FX
  sounds go on the top copy.
- Check the show (`Chk`, the Sounds tab status line): `Chk.run` lists missing files (any item), library files (an FX
  item whose file is in `S.library`; Copy), other sample rates (FX items; the project rate or the device rate) and tails
  into the next region (FX items; Cut at the end of their song, 50 ms fade). `Chk.fix` (1 undo point "SFX Drop: check
  the show"), `Chk.go`. The window: `UI.draw_check` (a modal; Enter is off while it is open).
- FX output (`Drop.apply_output`): the FX folder's hardware outputs are replaced by 1 pair (master send off), or none
  (master send on); set when SFX Drop makes the folder, or by "Apply to the FX folder" (its own undo point).
- Vary (`Lib.variants`): the sounds of the same type in the same folder in turn, starting at the selected one;
  `Drop.insert` (several targets) and `Spots.list` (a sound used at several spots).
- Sort: a click on a column title (`UI.sort_header`, `SORT_HEADS`) sets `S.sort` (name / type / len / bars / hit; bars
  sorts as len) and `S.sort_desc`; `Lib.sort` in `Lib.view` (the cache follows the sort). A Riser length other than
  Off sets the sort to Length, short to long; the fitting risers stay first.

## Deployment and tests

- `.\tools\deploy.ps1` copies it to `Scripts\Thunderfork Scripts\SFX Drop\` (ReaPack), else `Scripts\SFX Drop\`.
- Tests: `tests\sfxdrop.lua` (`.\tools\test.ps1 -Script "SFX Drop"`; result in `tests\result_sfxdrop.txt`). They
  write 2 WAV files in the test REAPER's resource folder.
