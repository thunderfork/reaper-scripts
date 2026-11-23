# Tab Viewer

Guitar Pro tabs in the project. Step 1 of the Guitar Pro direction (PLAN.md, "Later"; decided 23 November 2026):
"Open tab..." and the list of the tracks of the tab (name, instrument and strings, tuning, capo; the bars, time
signature and tempo of the file). Chart Cue look, 1 window, no tabs yet. Next steps: the tab drawing, the track
dropdown, the tab on the bars of the song (step 2).

## Files

- Formats: .gp (Guitar Pro 7 / 8), .gpx (Guitar Pro 6, segment 1b), .gp5, .gp4, .gp3 (segment 1c); 23 November 2026.
- `Tab Viewer.lua`; no actions. Version: `@version` and `CFG.VERSION` together. Release: tag `tabviewer-vX.Y`, title
  "Tab Viewer X.Y" (the `release` skill). Not released: `@noindex`.
- `Guitar Pro.lua`: the 1 shared Guitar Pro reader (plain Lua 5.4, no REAPER calls; a plain `lua` runs it). Note
  Detective uses it too: its `@provides` takes it from here (`[nomain] ../Tab Viewer/Guitar Pro.lua > Guitar Pro.lua`),
  so ReaPack installs a copy next to each script (each package needs its own target name: the ReaPack index refuses 2
  packages with the same file; checked in the reapack-index source, 23 November 2026; the ReaPack client itself is
  checked at the first release). `tools\scripts.psd1` `Uses` makes `deploy.ps1` and `release.ps1` copy it too (both
  copy `<Name>*.lua`, then the `Uses` files). Each script loads it from its own folder (`debug.getinfo`); the Note
  Detective tests hand it over (`NoteDetectiveTest.GP`).

- `Tempo.lua` (`TP`, segment 2d, 23 November 2026): Tempo and bars, moved from Note Detective unchanged (find the
  beats: `TP.Beat`; the audio reader `TP.reader`; `TP.first_sound`; `TP.new(host)` = the section's functions: Find
  tempo in steps, 1/2 x2, bar 1, short bars, Play with click, Set tempo with `hold` / `map` / `align`). The host gives
  R (the state lives in R.tempo, R.tsrc, R.tsrc_sel), name, undo_try, note, notice, song, and optionally first_note,
  shift, written, set_extra. Note Detective and Tab Viewer use it (both @provides and `Uses`).
  Its tests are Note Detective's (tests\notedetective.lua: the beats, the plan, Set tempo, Play with click), and the
  tab part in tests\tabviewer.lua.
- Segment 2e (23 November 2026): Tab Viewer's "Tempo and bars" section above Track (`UI.draw_tempo`, `S.tempo`,
  ExtState `tempo`, open). Beats from: "The tab (its tempo)" first (`R.tsrc_audio` false), then the tracks.
  From the tab: `GP.timeline(doc)` (the bars as they play: len, num, den, tempos { q, bpm }; from `doc.tmap`: .gp
  Tempo automations with Bar / Position (a part of the bar) and the unit (1 an 8th ... 5 a dotted half; the unit
  was not checked on a real file); .gp3/4/5 mix table tempos at their bar and place), `Tempo.from_tab` (bar 1 =
  the first sound of the song less the time to the first note of the chosen track: `Tabs.first_qn`), `Beat.tab_plan`
  (a marker only where the tempo or the time signature changes; a change inside a bar: `beat` in beats of den),
  `Beat.tab_time`. Set tempo from the tab does not move the audio (`Tempo.write`: d = 0). After Set tempo the tab
  starts on the new bar 1 (`Tabs.set_tempo` -> `Tabs.set_bar`). The song: the selected audio item, else the longest
  one (`Tabs.song_item`). REAPER's tempo is in quarter notes: a 6/8 tab was not checked.

## The reader (`Guitar Pro.lua`, `GP`)

- `GP.read(path)` -> doc, or nil and a text for the user. .gp (Guitar Pro 7 / 8: a zip; `GP.unzip` + `GP.inflate`,
  its own deflate unpacker, no PowerShell) and .gpif.
  Measured on 3 real tabs (23 November 2026, the user's files, never in git): a 2 MB score in 0.29 s (plain Lua).
- .gpx (`GP.gpx`): "BCFZ" (packed: `GP.bcfz`, the unpacked size, then a bit stream: 1 = a copy (4 bits word size,
  offset and size with the lowest bit first; at most `offset` bytes), 0 = 1-3 plain bytes; a stream that ends early
  gives what it has) or "BCFS" (`GP.bcfs`: 4096-byte sectors, sector 0 empty; a file entry: type 2, name at 4, size at
  0x8c, data sectors from 0x94). Its score.gpif goes to `GP.parse`. Guitar Pro 6 names the instrument with a ref
  ("e-bass4", "e-gtr6", "drmkt": `GP.kind`) and can leave out the MIDI number of a note: `GP.bar_notes` takes the
  pitch from the tuning and the fret. Only made-up files (the tests); no real .gpx yet: the first real one is the
  check.
- `GP.read_old(data)`: .gp3, .gp4, .gp5 (Guitar Pro 3.00 to 5.10, binary, read in the order of the file: song,
  bar headers, tracks, then each bar track after track; the parts that are not needed are skipped by their size).
  The same doc as `GP.parse`, but each bar is the list of its notes (`GP.bar_notes` takes either). Track kind
  (`GP.old_kind`): the drum flag or MIDI channel 10, the MIDI program (24-31 guitars, 32-39 basses), else the name.
  The strings are written from the highest in the file (`s` 1 = the lowest here). A repeat end: Guitar Pro 5 keeps
  how often it plays, 3 / 4 how often it repeats; an alternate ending: 5 keeps bits, 3 / 4 the number of the ending.
  A Guitar Pro 5.1 mix table change ends with 2 texts (the RSE effect and its category). Guitar Pro 5 can leave out
  the last byte of the last bar (a real file did): up to 3 missing bytes at the end read as 0, more is "damaged".
  `doc.rest` = the bytes left after the last bar (0 when read right). Checked on 1 real .gp5 (5.10: 4 tracks, 118
  bars, 4236 beats to the last byte; the notes, tunings and drum notes make sense). .gp3 / .gp4: only made-up files
  (the tests), no real file yet: the first real one is the check. PyGuitarPro (Python) as a 2nd opinion was not
  installed (the install was blocked; the user decides).
- `GP.notes` sorts notes that start together from the lowest (a fixed order for chords and 2 voices).
- `GP.parse(xml)`: tracks { name, kind (`GP.kind`: "bass", "guitar", "drums", "other" from the instrument type, e.g.
  electricBass, synthBass, electricGuitar, steelGuitar, drumKit, electricPiano), inst, open (MIDI from the lowest
  string; none for drums: their "tuning" is all zeros), capo (`CapoFret`) }, tempo (the 1st Tempo automation of the
  MasterTrack, "106 2" = 106 BPM), tempos (how many), mbars, and the tables bars, voices, beats, notes, rhythms.
- `GP.order` (repeats, alternate endings), `GP.notes(doc, track)` (ties, dots, tuplets, grace notes left out, muted
  notes left out, "%" repeat bars): moved from Note Detective's `Imp` unchanged.
- Chord names (step 3, 24 November 2026): the file's (.gp / .gpx: the track's diagram Items `<Item id name>`, a
  beat's `<Chord>id</Chord>`; .gp5: the name at byte 17 of the 107-byte chord; .gp4 / .gp3 new format: at 16 / 25
  after its first byte; the old format: its first text) via `out.chords` of a bar and the 2nd value of `GP.notes`;
  else `GP.chord_name(midis)` for notes that start together and ring at least 1 beat (fast riffs: no names, decided
  24 November 2026). `GP.tab` puts them in `bar.chords` only where the name changes (`tab.has_chords`). Checked
  on 4 real tabs: none had names in the file (empty diagram lists), so the file names are checked only with
  made-up files. Tab Viewer: a row under the bar numbers (`CFG.TAB_CHORDS`, `tab.top` / `tab.lh` from
  `Tabs.build`), Settings > Tab > Chord names (`S.chords`, ExtState `chords`, on).
- `GP.tuning_text(open, kind, capo)`: "Standard" (an octave higher too), "Eb Standard", "Drop D", else the notes
  ("Bb E A D"); ", capo 2". A bass: all strings a 4th apart; a guitar: the 2nd highest string a major 3rd below the top.

## Architecture and data

- Modules: `Util`, `Tabs` (the tab of the project), `Project` (the project data), `UI`.
- `P.tabs` (ProjExtState "Tab Viewer"/"cfg"; nothing saved without a tab; tabs per region, decided 23 November
  2026): 1 block per tab: `tab=` the file, relative to the project folder ("Tabs/Song.gp") or a full path (a project
  that is not saved yet); `region=` the GUID of its region (none: the whole project); `track=` the chosen track (only
  when it is not the default: `Tabs.default_track`, the first bass, else the first guitar); `bar=` the start bar,
  counted from the region's first bar (`Tabs.base`: the first bar line at or after the region start). `R.cur` = the
  tab in the window (`Tabs.cur()`); Open tab... links the new tab to the region at the edit cursor and replaces that
  region's tab (`Tabs.open`); `Tabs.regions` (R.rgns, again at each project change: a moved region moves its tab),
  `Tabs.at(t)`, `Tabs.relist` (the Tab dropdown texts), `Tabs.set_region`, `Tabs.remove`. The tabs read in a
  project are kept in `R.docs` (by full path). Segment 2 (24 November 2026): `Tabs.follow(t)` every frame (the play
  position, stopped the edit cursor) changes the tab only when the place has another tab than the frame before
  (`R.follow_last`; a dropdown choice stays until then); a region without a tab: none (`Tabs.at` gives nil there,
  never the tab without a region); between regions without a whole-project tab: the last tab stays. Another tab
  resets Tempo and bars (`Tabs.select`). `Tabs.song_item`: the selected item, else the longest audio item that
  overlaps the tab's region.
- The tab (step 2a, 23 November 2026): `GP.tab(doc, track)` (the shared reader: the bars as they play, the notes with
  q in the bar, s, fret; the string names, the top "e" when it has the name of the lowest); `Tabs.build` (R.tab, or
  R.tab_why for drums and "other"; the texts made once), `Tabs.layout` (lines of bars for the width, as Note
  Detective's), `Tabs.hit` (a point -> the bar and its 16th). `UI.draw_tab`: only the lines in view; a click plays
  from there (`UI.play_from`). The drawing moves into a shared file with segment 2c (Note Detective).
- The tab on the song (step 2b, 23 November 2026): `P.bar` (`bar=`, only when not 1; a new Open tab clears it) = the
  song bar (REAPER's, from 1) of bar 1 of the tab; `Tabs.set_bar` ("<" / ">", `UI.repeat_button`: hold = repeat),
  `Tabs.relabel` (the bar numbers = the song's, the bar line text). From that bar the tab follows the project's
  quarter notes (`Tabs.start_qn`, `Tabs.time_of`, `Tabs.place_of`: a binary search, asked every frame), with the bar
  lengths of the tab: a 3/4 bar of the tab fits where REAPER has 4/4 (decided by Claude: beats, not REAPER's bar
  lines). The position line: blue, playing at the play position, stopped at the edit cursor (no dashed line: decided 24
  November 2026); `S.follow`
  (Settings > Tab > Follow playback, ExtState `follow`, on) scrolls to the playing line once per line change.
- `Tabs.keep`: a saved project keeps a copy of its tab in `<project folder>\Tabs` (the same name with other content:
  " (2)"; the same tab again: no copy). `Tabs.moved`: the 1st save and Save as (the project file changes, the project
  data stays) copy it into the new folder (`Tabs.keep(from)`: a relative path from the old folder); the window keeps
  the list (no 2nd read). The project then shows as changed once more (the new place): kept so, decided 23 November
  2026. `Tabs.show` puts a tab (or why not) into the window. A missing file: a grey line in the window (`R.err`); a file that can not be
  read at Open tab...: an orange notice, the project does not change.
- `S` (ExtState "Tab Viewer"): `light`, `dock`, `follow`, `chords`, `tempo`.
- `R.rows` / `R.info` (`Tabs.rows`): the Track dropdown texts and the line below the tab, made once per tab. Another project tab:
  its tab is read again (0.3 s for a 2 MB score; no cache: decided in the simplify round, 23 November 2026).

## Deployment and tests

- `.\tools\deploy.ps1` copies `Tab Viewer.lua` and `Guitar Pro.lua` to `Scripts\Thunderfork Scripts\Tab Viewer\`
  (ReaPack), else `Scripts\Tab Viewer\`.
- Tests: `tests\tabviewer.lua` (`.\tools\test.ps1 -Script "Tab Viewer"`): the reader (deflate: stored, fixed and
  dynamic blocks; zip; tracks; notes; tunings; the errors; a small .gp3 / .gp4 / .gp5 (5.00 and 5.10) song that
  `old_file` in the test writes: repeats with 2 endings, 3/4, ties, dead notes, triplets, chords, effects, a tempo
  change, a 2nd voice, a missing last byte; a .gpx, packed and not, that `bcfs` and `bcfz` in the test write) and Tab Viewer (the list, open, the Tabs copies, another
  project, a missing file, the 1st save, Save as). The data is made up (`tests\tabviewer_data.lua`, made once with
  Python's zlib and zipfile; never a real song).
