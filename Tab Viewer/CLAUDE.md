# Tab Viewer

Guitar Pro tabs in the project: Open tab... (a tab per region), the Track dropdown, the tab on the bars of the song
(Find tempo, Start), chord names, playing marks, note lengths, fixes of the tab (saved in the project), loop and speed.
Chart Cue look, 1 window. Drums: later. The Note Detection tab (`Notes.lua`, was the script Note Detective): the bass
notes as markers to learn the part; read `Tab Viewer/NOTES.md` before work on it. The history of every decision: git.

## Files

- `Tab Viewer.lua` (no actions). Version: `@version` and `CFG.VERSION` together. Release: tag `tabviewer-vX.Y`, title
  "Tab Viewer X.Y" (the `release` skill). Not released: `@noindex`.
- `Guitar Pro.lua` (`GP`): reads .gp (Guitar Pro 7 / 8), .gpx (6), .gp5, .gp4, .gp3, and writes .gp5
  (`GP.write_gp5`). Plain Lua 5.4, no REAPER calls (a plain `lua` runs it). Another script can use it with
  `[nomain] ../Tab Viewer/Guitar Pro.lua > Guitar Pro.lua` in its `@provides` (each package needs its own target name:
  the ReaPack index refuses 2 packages with the same file).
- `Tempo.lua` (`TP`): Tempo and bars (`TP.Beat` finds the beats; `TP.reader`, `TP.first_sound`; `TP.new(host)` = Find
  tempo, 1/2 x2, bar 1, short bars, Play with click, Set tempo with `hold` / `map` / `align`). The host gives R (the
  state: R.tempo, R.tsrc, R.tsrc_sel), name, undo_try, note, notice, song, and first_note, shift, written, set_extra
  (from the Notes list).
- `Notes.lua`: the Note Detection tab (NOTES.md).
- `tools\scripts.psd1` `Uses`: `deploy.ps1` and `release.ps1` copy the 3 files next to the script (`[nomain]` in its
  `@provides`); Tab Viewer loads them from its own folder (`debug.getinfo`).

## The window

- The tab strip (`UI.draw_tabs`, as MIDI Pilot): Tab, Note Detection, Settings (gear), Help ("?") (`R.page`, not
  saved; `PAGE_NAMES`, `UI.PAGE_NOTES`, `UI.PAGE_SETTINGS`, `UI.PAGE_HELP`); icons when narrow; right-click a text tab
  > Hide this tab (Settings > Look > Tabs). The tab keys work only in the Tab tab, the list keys only in the Note
  Detection tab.
- The toolbar (25 November 2026, inspired by Guitar Pro's): `UI.draw_toolbar`, 3 groups placed by
  `Tabs.toolbar_rows` (a group without room goes to the next row): left Undo / Redo (`UI.undo`: the open tab's steps
  first, the tab fixes `Tabs.undo` or the list `Notes.undo`, then REAPER's; Ctrl+Z too), the size, Find tempo; center
  |<, <, play / stop, > (`UI.go`: by bars, `Tabs.go`, `R.tab_jump` scrolls to the line; in the Note Detection tab by
  lines, `Notes.go`); right the speed with a note icon. Icons: `UI.tb_icon`, `ICON` (drawn, as Chart Cue's). Next:
  loop, metronome and count-in, transpose (PLAN.md).
- The tab size: -, the percent (a click: the list `ZOOMS`), + (only in the Tab tab; right-click: 100%), `S.zoom`,
  10% steps (`Tabs.zoom_step`, `CFG.ZOOM_MIN` .. `CFG.ZOOM_MAX`). **Rule:** the sizes of the tab are read from
  `TZ.<name>` (= `CFG.TAB_<name>` x zoom, `Tabs.set_zoom`, the list `TAB_SIZES`), never `CFG.TAB_<name>`; small fixed
  sizes in the drawing are times `TZ.z`. The tab's fonts `TF` (per zoom step, made by `UI.zoom_fonts` at the start of
  a frame, used from the next one); `UI.draw_tab` pushes `TF.font` for the layout and the drawing, not for its menus,
  tooltips and the note box.
- Find tempo (`UI.draw_find_tempo`, its menu `UI.draw_tempo_menu`): "From tab", then the tracks (a choice starts at
  once); with a result the fine controls (`UI.draw_tempo_fine`) and a blue Set tempo in the toolbar. From the tab:
  `GP.timeline(doc)`, `Tempo.from_tab` (bar 1 = the first sound of the song less the time to the first note:
  `Tabs.first_qn`), `Beat.tab_plan` (a marker only where the tempo or time signature changes); it does not move the
  audio; then the tab starts on the new bar 1. The song: the selected audio item, else the longest
  (`Tabs.song_item`). REAPER's tempo is in quarter notes: a 6/8 tab is not checked yet.
- The panel rows Tab (the dropdown: the tabs, Region, Undo all fixes, Layout..., Remove; Open tab...), Track (and
  Import to list), the file line, Start (< >) share the label column (`CFG.LABEL_W`, `UI.field`).

## The reader (`Guitar Pro.lua`)

- `GP.read(path)` -> doc, or nil and a text for the user. .gp: a zip (`GP.unzip`, its own deflate `GP.inflate`).
  .gpx (`GP.gpx`): "BCFZ" (`GP.bcfz`) or "BCFS" (`GP.bcfs`), then its score.gpif. Both -> `GP.parse(xml)`: tracks
  { name, kind (`GP.kind`: bass, guitar, drums, other), inst, open (MIDI from the lowest string), capo }, tempo,
  mbars, bars, voices, beats, notes, rhythms. Guitar Pro 6 names the instrument with a ref ("e-bass4") and can leave
  out a note's MIDI number (taken from the tuning and fret).
- `GP.read_old(data)`: .gp3 / .gp4 / .gp5 in file order (song, bar headers, tracks, then each bar track after
  track; unused parts skipped by size). Strings in the file from the highest. A repeat end: GP5 keeps how often it
  plays, GP3/4 how often it repeats; an ending: GP5 bits, GP3/4 its number. GP 5.1 mix tables end with 2 texts. GP5
  can leave out up to 3 bytes at the end (read as 0); `doc.rest` = the bytes left (0 when read right).
- `GP.order` (repeats, alternate endings: an ending runs from its marked bar to its :|), `GP.notes(doc, track, dead)`
  (ties, dots, tuplets; grace notes and muted notes left out; "%" repeat bars; dead notes only with `dead`; `w` =
  the written length, `ties` = the held parts), `GP.tab(doc, track)` (the bars as they play, `wb` = the written bar),
  `GP.timeline(doc)` (bar lengths, time signatures, tempos), `GP.fx` (playing marks), `GP.chord_name`,
  `GP.tuning_text` ("Standard", "Drop D", "Eb Standard", else the notes; ", capo 2").
- Checked on real files (the user's, never in git; the `file-format` rule): .gp (3 tabs; a 2 MB score in 0.29 s),
  1 real .gp5 (5.10), tremolo `1/4` = 16ths. Only made-up files: .gpx, .gp3, .gp4, chord names in the file, section
  markers of the old formats, the .gp tempo unit, the playing marks. The first real file of each is the check.
- `GP.write_gp5(song)` (25 November 2026): Guitar Pro 5.10 in the layout `GP.read_old` reads, with real values (track
  visible, tab and notation shown, channel volume); `GP.values` splits a length into tied note values. A trial file
  opened right in the user's Guitar Pro.

## Data

- `P.tabs` (ProjExtState "Tab Viewer"/"cfg"; nothing saved without a tab): 1 block per tab: `tab=` the file (relative
  to the project folder, "Tabs/Song.gp", or a full path in an unsaved project), `region=` the GUID of its region
  (none: the whole project), `track=` (only when not `Tabs.default_track`: the first bass, else the first guitar),
  `bar=` (the song bar of tab bar 1, from the region's first bar line, only when not 1), `edit=<track> <written bar>
  q/s/fret/len ...` (your fixes: the notes of that written bar; `len` = the written length; places on the 1/48 grid,
  `Util.grid`), `meter=<written bar> <num>/<den>` (your time signatures), `lines=` / `joins=` (your line breaks),
  `layout=` (bars per line). `Project.entry_line` / `Project.entry_text`: 1 tab's block (also the found notes' tab,
  saved with the Notes list).
- Tabs per region: Open tab... links the new tab to the region at the edit cursor (`Tabs.open`); `Tabs.follow(t)`
  every frame changes the tab when the play position (stopped: the edit cursor) enters another tab's region; a
  region without a tab: none; between regions: the last tab stays. `R.docs` (the tabs read in a project, by path).
- The copy: a saved project keeps its tab in `<project folder>\Tabs` (`Tabs.keep`; the same name with other content:
  " (2)"); the 1st save and Save as copy it into the new folder (`Tabs.moved`). A missing file: a grey line; a file
  that can not be read at Open tab...: an orange notice, nothing changes.
- `S` (ExtState "Tab Viewer"): `light`, `dock`, `follow`, `chords`, `marks`, `pmarks`, `lengths`, `written`,
  `tremnotes`, `tab_hide`, `zoom` (only when not 100%), `closed` (the folded Settings sections: Tab, Note Detection,
  Look, Window). The Note Detection tab keeps its own keys in the same section (NOTES.md).
- Not saved: the loop and the speed (100% again at close), the selection, `R.page`.

## The tab

- `Tabs.build` -> `Tabs.make` in a pcall (a failure: `Tabs.failed`, the grey line and an orange notice); the tab of a
  track (`GP.tab`, or `doc.tab()` for the found notes), your time signatures (`Tabs.meters`: `mb.num` / `mb.den`, the
  file's in `num0` / `den0`, `mb.fit` = new length / old: the notes fit the bar), your fixes (`Tabs.apply_edits`,
  shared with the Guitar Pro export `Tabs.found_song`), `Tabs.link` (the next item on each string: arcs, slides; the
  held parts "(4)"; the P.M. runs), `Tabs.rhythm` (the note values under the tab; also the click grid), `Tabs.view`.
- Repeats as written (`S.written`, on): `tab.bars` stay the bars as they play (times, edits, rhythm); `Tabs.view`
  makes `tab.view` (each written bar at its first pass; `b.shown`, `b.drawn = false` for a later pass), repeat signs,
  "x3", endings, section names, time signatures, tempo marks, the final double bar. D.S., Coda and Fine are not read.
- `Tabs.layout` (lines of bars for the width; each line fills the width; your breaks and joins; never before a joined
  bar), `Tabs.hit` (a point -> the bar and its place), `Tabs.min_slot`, `Tabs.x_of`, `Tabs.step` (the grid of a beat:
  1/4, 1/8 in a bar with 32nds, 1/3 or 1/6 in a triplet beat), `Tabs.snap`. `UI.draw_tab` draws only the lines in
  view; each bar (`UI.tab_bar`) and each P.M. row in a pcall: a bar that fails is an orange "?" and a notice once.
- The tab on the song: `P.bar` (Start, < >), `Tabs.start_qn`, `Tabs.time_of`, `Tabs.place_of` (a binary search, asked
  every frame): from that bar the tab follows the project's quarter notes, with the bar lengths of the tab. The
  position line: blue (playing: the play position; stopped: the edit cursor); Follow playback scrolls once per line.
- Fixes (stopped only): a click selects a note or an empty place (`R.tsel`) and moves the edit cursor; playing: a
  click plays from there. `Tabs.click` decides (a plain function, tested): the box opens only on a double-click on the
  same place. Keys (`UI.tab_keys`): digits (a fret), Delete, Left / Right, Up / Down (the next string), Alt+Up / Down
  (move the note), + - . / (lengths and triplets, `UI.len_char`: any keyboard layout), & and Ctrl+Enter (line
  breaks), Space. Each fix is 1 step of `R.undo` (`Tabs.edit`, `Tabs.undo`; this session only: REAPER's undo does
  not restore ProjExtState). `nt.mine` (green, Mark my fixes). Right-click a bar > Time signature... (`UI.draw_meter`).
- Loop and speed: Shift+click a bar = `Tabs.loop` (REAPER's time selection from the selected note or the edit cursor
  to the bar end, repeat on; `Tabs.loop_off` gives back the old ones; 1 loop at a time with the Note Detection tab);
  the speed dropdown = `Tabs.speed` (the master play rate, preserve pitch on while slower; yellow below 100%).
- Playing marks (`GP.fx`): hammer-on / pull-off, slides, bends, vibrato, palm mute (the P.M. row), harmonics,
  tremolo picking (slashes, or written out as notes with `S.tremnotes`), dead notes "x". Chord names: from the file,
  else `GP.chord_name` for notes that ring at least 1 beat (a row under the bar numbers; `S.chords`).

## Tests and deployment

- `.\tools\test.ps1 -Script "Tab Viewer"`: `tests\tabviewer.lua` (the reader: deflate, zip, .gpx, a .gp3 / .gp4 /
  .gp5 that `old_file` writes, the .gp5 writer read back; Tab Viewer: the list, open, copies, another project, a
  missing file, Save as, the tab, fixes, repeats, rhythm, the toolbar), then `tests\notes.lua`. The data is made up
  (`tests\tabviewer_data.lua`, never a real song). The tests load the UI with a stand-in for ReaImGui
  (`TabViewerTest.ImGui`: nothing is clicked); every test file and track is drawn.
- `.\tools\deploy.ps1` copies `Tab Viewer.lua`, `Guitar Pro.lua`, `Tempo.lua` and `Notes.lua` to
  `Scripts\Thunderfork Scripts\Tab Viewer\` (ReaPack), else `Scripts\Tab Viewer\`.
