# Tab Viewer

Guitar Pro tabs in the project (the Guitar Pro direction, decided 23 November 2026): Open tab... (a tab per
region), the Track dropdown, the tab on the bars of the song (Find tempo, Start), chord names, playing marks, note
lengths, fixes of the tab (saved in the project), loop and speed. Chart Cue look, 1 window, no tabs. Drums: later.

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
- Segment 2e (23 November 2026), redesigned 24 November 2026: Find tempo is a toolbar button next to Open tab...
  (`UI.draw_find_tempo`): its menu (`UI.draw_tempo_menu`) has "From tab" (`R.tsrc_audio` false), a separator, then
  the tracks; a choice starts at once. With a result the menu also has the fine controls (`UI.draw_tempo_fine`) and
  the toolbar a blue Set tempo (it clears `R.tempo`: the button goes away, the notice is the feedback); while it
  listens: the progress and Cancel. The panel rows Tab, Track, the file line, Start share the label column
  (`CFG.LABEL_W`, `UI.field`).
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
  from there (`UI.play_from`). Bar widths: `Tabs.min_slot` (the texts on 1 string do not touch; `b.slot`, once
  per build), `Tabs.x_of` / `Tabs.x_end`; held parts "(4)" grey (the user, 24 November 2026). Triplets: a bracket
  with the "3" in a gap, as Guitar Pro (24 November 2026).
- Repeats as written (decided 24 November 2026: the default; written bar numbers; a click while stopped = the first
  pass): `tab.bars` stay the bars as they play (times, edits, rhythm); `Tabs.view` makes `tab.view` (the bars drawn:
  each written bar at its first pass), `b.shown` / `b.vp` / `b.drawn = false` (a later pass draws on its first one),
  `b.rs`, `b.re`, `b.times` ("x3"), `b.alt` ("1.") with `alt_first` / `alt_last`, `tab.end_row` (`CFG.TAB_ENDING`
  row at the top). Lines hold places of the view (`Tabs.vbar`); `Tabs.neighbour` walks the view (Left / Right);
  `Tabs.pass_near` (a click while playing: the pass nearest the one that plays); `UI.tab_repeat` draws |: :| (room:
  `CFG.TAB_REPEAT`, `b.tail`). An ending runs from its marked bar to its :| (`GP.endings`; 24 November 2026).
  Each line fills the width exactly (only the 16ths and pads stretch; the last line at most `CFG.TAB_STRETCH`);
  rests in the middle of the strings; a frame around the tab (24 November 2026). `S.written` (Settings > Tab > Repeats as written, ExtState `written`, on). D.S., Coda
  and Fine are not read (the bars play in file order with the repeats). Checked only with made-up data.
- Line breaks (decided 24 November 2026, as in Guitar Pro): "&" (the typed character, `UI.len_char`) pulls the
  next line's first bar up, Ctrl+Enter moves the bars after the selected one down (`Tabs.line_starts`, a plain
  function; `Tabs.set_lines`, 1 Undo step: `R.undo` entry with `lines` and `joins`). Saved per tab (only yours,
  decided 24 November 2026: the lines after a break fill again): `lines=` (your breaks: written bars; `e.lines`),
  `joins=` (the "&" bars kept on the line before; `e.joins`); `Tabs.view` makes `tab.starts` / `tab.joins`;
  `Tabs.layout` breaks there and where a bar does not fit, never before a joined bar (a too wide line shrinks). Only with Repeats as written (played out: automatic lines). Tab dropdown > Reset line
  breaks, replaced 24 November 2026 by Tab dropdown > Layout... (`UI.draw_layout`, as Guitar Pro's Score system
  layout: Bars per line Automatic / 1-8, `layout=` = `e.per`, `tab.per`; Reset of your breaks and joins; OK =
  `Tabs.set_layout`, 1 Undo step with `Tabs.lines_state`).
- Section names (24 November 2026): `mb.section` (.gp: `<Section>` Text, else Letter; .gp3/4/5: the marker name);
  `Tabs.view` gives each bar shown `b.section` and `tab.sec_row` (`CFG.TAB_SECTION`, the top row: then the endings,
  P.M., the bar numbers). The old formats' markers: checked only with made-up data.
- Score marks (24 November 2026, as in Guitar Pro): `Tabs.view(..., tl)` (tl = `GP.timeline`) gives `b.sig` (the time
  signature at bar 1 and where it changes; room: `CFG.TAB_SIG`, `Tabs.head_w`), `b.tempo` ({ q, "= 120" } where the
  rounded tempo changes; in the top row, so `tab.sec_row` is always on with a tempo; a later pass is not drawn) and
  `b.final` (the double bar on the last bar, not after a :|; room: `b.tail`). `UI.tab_score` draws them. No switch.
- Your time signatures (segment 1, 24 November 2026; the user's tab: written in 4/4 at 125, really 6/8 at 93.75):
  `meter=<written bar> <num>/<den>` per tab (`e.meters`, all tracks); `Tabs.meters(doc, meters)` sets `mb.num` /
  `mb.den` (the file's in `num0` / `den0`) and `mb.fit` (new length / old): the notes stay in their bar and fit it
  (`GP.notes`), the tempo times fit (`GP.timeline`: the bar lasts as long). `Tabs.meter_bars` (this bar, or up to the
  file's next change: decided), `Tabs.set_meter` (1 Undo step). Segment 2: right-click a bar > Time signature...
  (`R.bar_menu`, `UI.draw_meter`, `R.meter`). "Keep their time (move bar lines)": PLAN.md > Later (the user). An
  edited bar keeps its saved places (not fitted).
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
- The editable tab (step 4, segment 1 built 24 November 2026; decided: the written bar changes, so its repeats too;
  undo in the window): `edit=<track> <written bar> q/s/fret/len ...` in the tab's block (`e.edits[track][wb]` = the
  notes of that bar, replacing the file's; `GP.tab` gives each played bar its `wb`). `Tabs.edit(bi, fn)` (1 step of
  `R.undo`; `Tabs.undo(-1 / 1)`, this session only: REAPER's undo does not restore ProjExtState), `Tabs.set_fret`,
  `Tabs.move_string`, `Tabs.delete`, `Tabs.next_note`, `Tabs.note_at`. Stopped: a click selects a note (`R.tsel`
  = bi, q, s) and moves the edit cursor; playing: a click plays from there. `UI.tab_keys` (Ctrl+Z / Ctrl+Shift+Z: the
  tab edits first, then REAPER's), the Undo ghost button on the Start row. Segment 2: `UI.tab_box` (`R.tbox`; a double-click:
  the selected note's fret, Left / Right = `Tabs.move` inside its bar; a double-click on an empty place of a string: a new
  note, `Tabs.add`, 1 16th). `Tabs.click` decides (a plain function, tested): the box opens only on a double-click on
  the same place (`R.tlast`; lessons 24 November 2026). Segment 3: `Tabs.undo_all` (Tab dropdown > Undo all fixes > Undo
  all fixes of this track; 1 Undo step: `R.undo` entry with `all`), `nt.mine` (a note of an edited bar that the file
  does not have at that place, string and fret) drawn green when `S.marks` (Settings > Tab > Mark my fixes, ExtState
  `marks`, on).
- Loop and speed (segment A, 24 November 2026): Shift+click a bar = `Tabs.loop(bi)` (REAPER's time selection from
  the selected note or the edit cursor, `Tabs.loop_start`, to the bar end; repeat on; `R.loop` keeps the repeat and
  time selection from before); the same bar again, Escape, another tab or closing: `Tabs.loop_off` (both as before).
  The band: `COL.HEADER_ACTIVE` over the bar numbers. The speed dropdown on the Start row: `Tabs.speed` (the master
  play rate; action 40671 preserve pitch on while slower, `R.pitch_old`); 100% again at close. Nothing saved.
- Playing marks (segment B, 24 November 2026): `GP.fx` (.gp / .gpx note properties HopoOrigin, Slide flags, Bended,
  PalmMuted, HarmonicType, Muted, `<Vibrato>`) and `note_effects` of `GP.read_old` (.gp3/4/5 flags; the .gp4 slide is a
  value: `SLIDE4`; a beat vibrato goes to its notes) give each note `fx`. Dead notes are kept (`fx.dead`): only
  `GP.notes(doc, track, true)` (GP.tab) returns them, so Note Detective gets none. The Guitar Pro look (decided
  24 November 2026, from the user's screenshots): `GP.notes` gives each tied note `ties` (where its held parts start);
  `GP.tab` puts them in `bar.ties` ({ q, s, fret, tie }), drawn "(4)", not selectable. `Tabs.link` (after the edits):
  `nx` / `nxb` = the next item on the string; a held part is off when a note is at its place or the note before has
  another fret; `tab.pm` = the palm-mute runs. `UI.tab_marks`: an arc to `nx` (a tie always; a hammer-on / pull-off),
  a sloped line (a slide), stubs (slide in / out), a bend arrow, a vibrato wave, tremolo picking (`fx.trem` 1-3: .gp
  beat `<Tremolo>1/4</Tremolo>` = 16ths (a part of a quarter; checked on a real file), .gp4/5 note byte; 1-3 slashes above the note, the user, 24 November 2026; with `S.tremnotes` (Settings > Tab > Tremolo as notes,
  ExtState `tremnotes`, on) `Tabs.tremolo` writes it out as the picked notes instead (`fx.tup`: a triplet; held parts
  `t.trem`); Note Detective: still 1 marker per note, its own decision later); `UI.tab_pm`: the "P.M. - - -|" row
  above the bar numbers (`CFG.TAB_PM`, only with palm mutes). `Tabs.note_txt`: x (always), `<12>` with the marks. A
  note of an edited bar at a file note's place and string keeps its marks (a dead note with a new fret: none).
  `S.pmarks` (Settings > Tab > Playing marks, ExtState `pmarks`, on). Checked only with made-up data: the first real
  tab is the check.
- Note lengths (segment C1, 24 November 2026; they replace the beat numbers): `GP.notes` keeps `w` (the written
  length; `len` rings on with the ties) and each held part `{ q, w }`; `GP.tab` gives them to the bar notes and
  `bar.ties`; an edited note takes `w` of the file note at its place and string, else its `len`. `Tabs.rhythm(b)`
  (after `Tabs.link`): `b.rh` (the notes that start together = 1 event, cut at the next one; the gaps = rests, split
  at the beats, `Tabs.rest_value`; `join` = a beam to the next one in the same beat, `flag`, `t3` = the triplet
  group's last index), `b.fine` (a 32nd or 16th triplet: `Tabs.layout` doubles the 16th width of that bar).
  `UI.tab_rhythm` / `UI.tab_rest` draw it (`CFG.TAB_RHYTHM`, `CFG.TAB_STEM`). `S.lengths` (Settings > Tab > Note
  lengths, ExtState `lengths`, on). Checked only with made-up data. The rhythm is made also when it is not drawn
  (the click grid).
- Length keys (segment C2, 24 November 2026): the saved `len` of an edit is the written length (decided 24 November
  2026; it was how long a tied note rings). `UI.len_char` reads the typed character (`GetInputQueueCharacter`: any
  layout), `UI.len_op`: `Tabs.length` (+ - .: the whole chord, decided 24 November 2026; 32nd to whole; never past
  `next_start`), `Tabs.triplet` ("/", as in Guitar Pro: the beat's notes in order on the 3 or 6 triplet places, each 1
  place long, the rest a rest; back: in order on the 16ths, each to the next note; lessons 24 November 2026).
  A triplet beat is known from its note places or its triplet lengths (`Tabs.step`); the "3" closes at a whole
  beat (16th triplets: half a beat). The grid of a beat: `Tabs.step` (1/3, 1/6 from its notes; 1/8 in a `b.fine` bar; else 1/4),
  `Tabs.snap` (Tabs.hit, Tabs.move, a new note's length); `Tabs.note_at` compares the exact place. In the box a
  length key gives the box a new id (`a.gen`), so the typed key is not in it.
- Checkup 24 November 2026 (all decided by the user): Up / Down selects the note or the empty place on the next
  string, as in Guitar Pro; Alt+Up / Down moves the note (`Tabs.move_string`). An empty place can be selected
  (`R.tsel.empty`: a click on it, Up / Down, Left / Right = `Tabs.next_place`, after Delete); a number there adds a
  note (`UI.digit`). A new note is as long as the note before it in the bar (`Tabs.new_len`; a triplet beat: 1
  place; never past the next note). The Undo button always shows (grey: nothing to take back). The speed dropdown
  is yellow below 100%, and a project that plays at another rate gets a notice when it loads. Another tab, track or
  project clears the selection (`Tabs.unselect`); another project, "<" / ">" and Set tempo end the loop; the loop
  gives back the old time selection only when it is still the loop's. `Util.grid`: the places read from `edit=` on
  the 1/48 grid. `GP.notes`: a tie joins only the note that ends where it starts.
- `S` (ExtState "Tab Viewer"): `light`, `dock`, `follow`, `chords`, `marks`, `pmarks`, `lengths`, `written` (`tempo` removed 24 November 2026 with
  the Tempo and bars section).
- `R.rows` / `R.info` (`Tabs.rows`): the Track dropdown texts and the grey line under it, made once per tab. Another project tab:
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
