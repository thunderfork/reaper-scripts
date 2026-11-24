# The Note Detection tab of Tab Viewer (`Notes.lua`; it was the script Note Detective)

Finds the notes of a separated bass item (or takes them from the tab: Import to list), shows them in a list to check,
and writes them as markers, as text items on a "Notes" track, or both (the Write dropdown). For a player who learns the
part in REAPER. Plan and answers: decided 23 November 2026; into Tab Viewer: decided and built 24 November 2026 (see
"Into Tab Viewer" below). The history of a part below may still say "Note Detective": that is this tab now.

## Files

- `Tab Viewer/Notes.lua` (`return function(host)`: Tab Viewer makes the module `Notes`; `[nomain]` in Tab Viewer's
  `@provides`, `Uses` in `tools\scripts.psd1`). The host gives GP, TP, CFG (CTRL_GAP, SP_ROW, EXT), COL, ImGui, UI (its
  helpers: the module's `UI` falls back to them), R (Find tempo, the notices), `notes_changed`, `entry_line`,
  `entry_text`. What Tab Viewer calls: `N.attach`, `N.step`, `N.draw(h)`, `N.draw_popups`, `N.keys`, `N.draw_settings`,
  `N.HELP_TOPICS`, `N.save`, `N.exit`, `N.busy`, `N.import`, `N.found_doc`, `N.found_entry`, `N.touch`, and the Find
  tempo hooks `N.first_note`, `N.shift`, `N.set_extra`, `N.written`. `N.test` hands the modules to the tests.

## Architecture and data

- `P` (ProjExtState "Tab Viewer"/"notes"; nothing saved when it is empty): `key=`, `mode=` (only when not "bar"),
  `src=` (the GUID of the bass item), `row=` time, doubtful 0 / 1, the time of each note, the text (tabs between), `mk=`
  the GUIDs of the written markers (also of older writes: Ctrl+Z brings those back), `tab.<key>=` the tab of the found
  notes (an entry as Tab Viewer's tabs: `tab.edit=`, `tab.bar=`, `tab.lines=` ...; `P.tab`). Finish removes all of it.
  `P_EXT:TabViewer` = 1 on the Notes track and on its text items ("midi" on the Bass MIDI track).
- `S` (ExtState "Tab Viewer", Tab Viewer's section; the keys do not meet Tab Viewer's): `out` ("markers", "track",
  "both"), `frets` (Settings > Note Detection > String and fret for high notes, default on),
  `finger` (Settings > Note Detection > Fingering for runs, default on), `strings` ("letters" / "numbers", Settings > Note Detection >
  String names), `counts` (Settings > Note Detection > Beat count in the Notes track, default on). `P.tuning` (`tuning=`, only
  when not "std"); `P.keys` (`keyat=` time, tab, key: a key change from the line at that time; `List.key_at`,
  `List.respell` after every regroup, a blue line in the list (`UI.view` items), a marker "Key: ..." at Write, or the
  first line of the Notes item when no markers are written). Beat count: `Group.count` ("1 e & a"), `Out.item_text`.
- Octaves and strings (step 2): `Det.analyse(x, tick, lowest)` gives each note a `midi`: YIN's votes and
  `Det.odd_even` (odd against even harmonics of the low octave, from the note start, 0.15 s, below `CFG.OCT_DB`: the
  higher octave); they disagree: the harmonics win and the note is doubtful (better on the user's own fret texts;
  YIN alone is a little better on song 2). `Key.place`: plain name in the lowest octave (from the lowest open string),
  else "(string fret)" on the lowest string with fret <= 7. The strings keep the names of their places (E A D G, B E A D G).
- Export (step 4): `Export.notes` (the found notes `R.notes` on the QN grid, no overlaps; `Export.delay` takes the
  common delay of the found starts away first: the fine part on the 16th grid (a circle), then of it and 1 16th
  earlier / later the one with the most notes on the beats; lessons 23 November 2026), `Export.item` (a MIDI item on
  the "Bass MIDI" track, `P_EXT:NoteDetective` = "midi"; its old item, mark "1", is replaced), `Export.smf` (a format 0
  .mid file written by hand: the tempo and time signature changes of `Export.tempos`, tick 0 = the bar of the first
  note), `Export.path` (the project folder; nil when the project is not saved). Checked 23 November 2026: a song with
  139 tempo markers, the file read back gives the same 622 note times as the MIDI item. Only the found notes: the text
  corrections of the list are not in it (the user knows).
- Decided 23 November 2026: `P.notes` (`note=` t, t1, pc, midi, doubt) and `P.t_end` (`tend=`) are saved with the
  list (no `R.notes` any more): the Markers choice, the export and the tab work after a reopen; Undo of the list
  brings them back too. `S.export_dir` (Export > Folder > Change..., `Util.browse_folder` as in MIDI Pilot; "" = the
  project folder). `Out.clear` ("Clear..." asks): its markers, Notes items, Bass MIDI item (1 undo step), then the
  list, key changes and notes (the key, mode, tuning and marker IDs stay). Set tempo: bars at the song tempo before
  bar 1 back to the bass item start (`Tempo.map` t_item). Tab view (`R.tab_view`, not saved): `Tab.build` (the notes
  of `Export.notes` on the 16th grid, `Key.finger` over the song, bars by measure, empty bars too), `Tab.layout`
  (lines of bars for the width), `UI.draw_tab` (only the visible lines; click = play from the nearest note; the
  playing note blue and its line scrolled into view); `R.tab` is rebuilt after a list, project or tempo change.
- Simple mode (`S.simple`, Settings > Note Detection, ON by default, decided 23 November 2026): `List.opt()` gives only the
  string and fret of high notes (no fingering of runs, no slide mark), no beat counts; the window hides Tempo and bars,
  View (Tab) and Export; Settings > Note Detection shows only Simple mode and String names. The tests set it off at the start.
- 1 fingering (Dev 2, 23 November 2026): `List.places(notes, tun)` = `Key.finger` over the saved notes (a string the
  user chose: `n.s`, the 7th field of `note=`); the list (a high note, a run) and the tab (`x.i` of `Export.notes`)
  use it. Tab corrections (Dev 3): right-click a note: `UI.tab_menu` -> `List.note_edit` / `List.note_delete`
  (Undo of the list). The 8th / 16th labels were removed from the markers (decided 23 November 2026); `Det.repeats`
  stays for the tab and the export. Tried and removed (no gain on song 1 / 2): the octave from the neighbouring notes.
- Tab editing (decided 23 November 2026; stopped only): `Tab.hit` (a note, an empty 16th of a string, or nothing),
  `UI.tab_add_box` (the fret of a new note: `List.note_add`, until the next note, at most 1 bar; after a double-click
  the box of a note: Enter = `List.note_fret`, Left / Right = `UI.tab_move`, never onto another note: `Tab.free`, it
  ends where the next note starts), `UI.tab_keys` (Left / Right select the note before / after, `UI.tab_cursor` moves
  the edit cursor or the playback there; `List.note_string`, `List.note_fret`, Delete); `R.tab_sel` keeps the note
  table. A click selects and moves the cursor (changed 23 November 2026 by the user). Notes of
  the tab have `man = true` (8th field of `note=`): the export delay does not count or move them. The play position:
  a blue line (`Tab.x_at`, less `tab.delay`, as the notes); stopped: a dashed line at the edit cursor. "Update the
  list" = `List.from_notes` (asks; Undo of the list).
- Measurement against the tab of song 2 (trial 7, 23 November 2026; the user's files, never in git): with the grid
  62% of the tab notes found, 582 of 610 in the right octave; 88 splits of held notes (repeats), ~200 "other pitches"
  inside tab notes (mostly the next note found early, 2-3 semitones, not glitches). The 4-bar low C at the end: the
  pitch jumps to its overtone (G); `Det.glitches` removes a short 5th glitch (no loss on the song). Tried and dropped:
  the brightness jump for repeats (no difference in the stem), a fading note's overtone joined, gaps bridged (both
  removed real notes). The repeats and held notes look the same in a Moises stem: the limit of this method.
- Slides and repeated notes (23 November 2026): `Det.slides` (no attack; the YIN pitch moves steadily, without a jump,
  for `CFG.SLIDE_STEPS` frames and `CFG.SLIDE_MIN` semitones into the note: `slide`, the note starts at the glide; its
  checks use `tp`, where the pitch is steady; song 2: 3 slides, no loss). `Det.repeats` (only when the project has a
  tempo marker: `Find.grid`, the 16ths; the level with 1 period of the note per window; dip + 0.5 x rise >= 4 dB
  splits; trial 6d; song 2 with the grid: 75.5% of the notes on the right 16th, against 62-65%). `Group.value`
  ("(8ths)", "(16ths)": 3 or more notes in a part, evenly). `S.slide` (`SLIDE_TEXT`), `S.reps`; `note=` has a 6th
  field (slide). `List.opt()` always gives a table now.
- Decided 23 November 2026 ("1 2 3"): `S.splits` (Settings > Note Detection > Split repeated notes, full mode, default on:
  `Det.repeats` only when on). J in the tab: `List.note_join` (the selected note joins the note before it, same pitch;
  Undo of the list). Import tab (`Imp`, full mode, "Import tab..." next to Find notes): the shared reader reads the file
  (`GP.read`, `GP.notes`; Tab Viewer/CLAUDE.md; since 23 November 2026 no PowerShell), `Imp.bass_track` (the first
  track of kind "bass"), `Imp.start` (the quarter note
  where the tab starts: its first note exactly on the very first found note, only Find's notes, never `man` (decided
  23 November 2026 by the user; a best-matching bar on the grid did not line up); no found notes: bar 1 of Set tempo,
  else the edit cursor; again for each track of the window; grace notes take no time), `Imp.apply` (replaces
  `P.notes` with `man = true` and the string of the tab, the tuning, then the rows; Undo of the list). The import
  window: `UI.draw_import` (`R.import`). Checked on the user's tab of song 2: 981 notes, the same as the earlier
  extraction. Guitar Pro 3 to 8 (the shared reader; no MusicXML yet).
- The detection review (a pro sound engineer, 23 November 2026; Dev 1-5 and UX 1 done, trial 9: song 2 against its
  tab, the notes found within half a 16th 66.6% -> 79.7%, with the 16th grid 78.8% -> 86.3%; false splits of held notes
  without the grid 10 -> 28, with it 70 -> 69; the octave right 96% -> 98.9%). `Det.onsets_of`: the band flux (9
  bandpass bands 50-800 Hz on the 4 kHz signal, each at least `CFG.ON_BW` wide and smoothed over 1 period, the rise
  relative to the loudest band of the moment: no level window, so a soft part counts as a loud one; but no pluck and
  no pitch below the loud level of the whole item - `CFG.ON_GATE` / `CFG.GATE_DB`: the bleed of a stem before the bass
  made Set tempo align a noise, lessons 23 November 2026). `Det.analyse`:
  the notes start at the onsets, or at a pitch change without an onset near it; 1 pitch per note from its frames after
  the attack; it ends at its own last frame before a gap (`CFG.END_GAP`); a piece too short for a note joins the
  next note (its pitch or none) or the note before (its pitch). `Det.octave_limit`: the octave limit of each song in
  the emptiest place between the 2 groups (song 2: -12 dB, not -6). `n.why` (not saved) -> `List.why` (the tooltip of
  a yellow line). Measured and dropped: a high band from a 16 kHz read (1 point, not worth a 2nd read); a stronger
  onset for the same note again (lost 2 real repeats per wrong one); a band floor that follows a 2 s level (it makes
  false onsets when the loud part leaves the window). Known limit: a loud note straight into a much softer one hides
  the soft start (it starts at its pitch change instead). With perfect starts the pitch step finds 90% (the limit of
  the onsets). Find notes on a 3:42 song: 16 s in REAPER.
- Fingering (step 3): `Key.finger` (dynamic programming, `CFG.FINGER` costs, the whole song in order) for the rows
  with `CFG.RUN_MIN` parts or more; `Group.rows(notes, bars, key, opt)`, `opt = List.opt()`.
- Modules: `Util`, `Key` (the key in a file name, the note names of a key), `Det` (the detection), `Group` (notes ->
  bars -> rows), `List` (the rows, corrections, Undo), `Project`, `Find` (reads the item in steps), `Out` (Write and
  Finish), `Beat` and `Tempo` (Tempo and bars: since 23 November 2026 (segment 2d) the shared `Tempo.lua` in
  `Tab Viewer\`, `TP.Beat` and `TP.new(host)`; Note Detective gives it the song (the bass item), the first note (the
  first found note of the list), the list shift, the extra Set tempo text; the audio reader `TP.reader` and
  `TP.first_sound` are there too), `UI`.
- Tempo and bars (step 1 of the 23 November 2026 wishes): `R.tempo` only (runtime, nothing saved; the result is
  REAPER's tempo map). Beats from: metronome tracks (`TP.is_click`), then drum tracks, then the others. Find tempo:
  `Beat.onset` (the rise of the log level), `Beat.tempo` (Fourier, 60-200 BPM, folded into 90-180), `Beat.track`
  (dynamic programming), `Beat.bar1` = the first beat with sound. Style suggested by `Beat.fit` (9 of 10 beats within
  30 ms: "1 tempo", else "Follow the song": 1 marker per bar).
- Set tempo aligns (decided 23 November 2026 by the user): `Tempo.write(name, true)` -> `Tempo.align` in the same undo
  step: `Tempo.first_note` (the first found note when the list is of this item, else `TP.first_sound` in the item's
  first `TP.CFG.ALIGN_SCAN` s: the first pluck missed the first note of song 2), then every item at least half inside the song moves so that note is on the nearest beat;
  `List.shift` moves the list (its own Undo step: REAPER's undo does not change ProjExtState). Not for Play with click.
- `Tempo.write` (1 undo step): REAPER's default timebase is beats, so `Tempo.hold` puts every item in time mode for a
  moment and puts the markers, regions and envelope points back at their times. `Tempo.map`: a bar from the old bar line
  before bar 1 that ends on bar 1, the song, a bar up to the next old bar line after the song, the old tempo there,
  then the old later markers. A time signature marker jumps to the start of its measure, so they are put by measure
  (`Tempo.measure_at`); REAPER has no partial measure in the API (checked). Play with click = an undo step
  `CFG.UNDO_TRY`, taken back (`Undo_DoUndo2`, only when it is the last step) by the next try, Set tempo or closing.
  An undo makes new item pointers: `R.tempo.song` keeps the GUID.
- `Det.analyse`: mono at 4000 Hz, YIN (the pitch class only), then a harmonic sum for each note: doubtful when the 2
  disagree, when the pitch is unsure, or when a fading note turns into its 5th (an overtone).
- REAPER's undo does not change ProjExtState (checked); the markers keep their GUID after undo and redo.
- `reaper.array` / `GetAudioAccessorSamples` give silence inside a Lua coroutine: `Find` reads the samples outside, and
  only `Det.analyse` runs in the coroutine.
- A project change: the saved text decides (`Project.update`), so "Save as" keeps the list.
- After Finish the script no longer knows its markers (a new Write adds new ones).

## Deployment and tests

- `.\tools\deploy.ps1` copies `Notes.lua` with Tab Viewer (`Uses`).
- Tests: `tests\notes.lua` (it returns a function; `tests\tabviewer.lua` adds its tests to its own run:
  `.\tools\test.ps1 -Script "Tab Viewer"`). The audio tests use generated WAV files; never the user's files.

## Into Tab Viewer (decided 24 November 2026, built the same day while the user was away)

- The script Note Detective is gone (the user agreed): its engine (detection, key names, fingering, markers, Export,
  Finish) is `Notes.lua`, its window the Note Detection tab. No migration (not released): its old ProjExtState "Note
  Detective"/"cfg", ExtState "Note Detective" and the mark `P_EXT:NoteDetective` are no longer read.
- The tab row as in Chart Cue and MIDI Pilot: Tab, Note Detection, Settings, Help; icons when narrow; right-click a text tab >
  Hide this tab, Settings > Look > Tabs shows it again (`S.tab_hide`, ExtState `tab_hide`, "2" = Notes hidden).
- Gone with the old window: its own toolbar, its "Tempo and bars" section (Tab Viewer's Find tempo button does it,
  also without a tab; its hooks keep "the first found note on the beat" and "the list moves with the audio"), the old
  read-only Tab view and its editing (`List.note_*`, J join, the octave menu), the "Import tab..." window
  (`Imp.start`, `Imp.bass_track`), Look and Window settings (Tab Viewer's).
- Import to list (the Tab tab, next to Track; hidden with the Note Detection tab): `Tabs.notes_of_tab` (the notes as they
  play, with your fixes, no dead notes, in project time) -> `Notes.import` (asks when the list has lines) ->
  `Imp.apply(list, open)`; then the window shows the Note Detection tab.
- The found notes as a tab: where the song has no Guitar Pro tab, `Tabs.load` shows `Imp.found_doc()` (`doc.found`;
  1 bass track with the list's tuning; the bars of the project from the bar of the first note; `doc.tab()` = the notes
  on the 16th grid with the fingering of the list). `R.found_e` = `P.tab` of the list: Tab Viewer's fixes, line breaks
  and start bar of it are saved with the list (`N.touch`), so the list's Undo brings them back too. Import to list
  bakes them into the notes (`P.tab` goes); Find notes and Clear start a new tab. The list changed
  (`host.notes_changed` -> `R.notes_dirty`, or the project's tempo): `Tabs.notes_step` makes it again. No "From tab"
  tempo for it; its bar numbers are always the song's.
- Not checked on the screen by the user yet; the new manual tests: PLAN.md, Open now.

## Later (ideas, moved from PLAN.md 24 November 2026)

- Note Detective, asked 23 November 2026 (feedback given, not approved): (1) find the tempo and set it, (2) line the
  song up with the bars, (3) octaves / strings ("E" or "E (A 7)"), (4) a comfortable fingering for runs, (5) export as
  MIDI / MusicXML. Trial 4: beats from the drums (attack curve of the log level, Fourier tempo, dynamic programming):
  song 1 166.35 (by hand 166.56 / 166.23 / 165.26; it drifts: the grid by hand is up to 0.1 s off the drums), song 2
  159.99 (true 160); bar 1 from the bass changes: right in 1 of 2 songs. Octave from the odd harmonics (1, 3, 5) of
  the low octave against 2, 4, 6 (limit -6 dB, chosen afterwards): song 1 fret texts 16 / 18 (before 9 / 18), song 2
  962 / 1002 (the YIN octave 98.6%). Fingering (dynamic programming; move 0.5, shift 3, string 0.3, high 0.2, open 1,
  stretch 0.3; 4 frets per hand): 398 / 410 the same place as the score (3 settings tried on this 1 song).
  The user's answers (23 November 2026): tunings vary, mostly standard (default: standard); a project can hold more
  than 1 song (the tempo change stays inside the song; other songs keep their places); order: tempo and bars first.
  Beat source: the Moises metronome track when the project has one (Finish already finds it), else the drums.
  Step 1 approved 23 November 2026: a foldable "Tempo and bars" section above Find notes (Beats from, Find tempo,
  Tempo with 1/2 and x2, Style, Bar 1 with 1 beat earlier / later and Play with click, Short bars + Add, Set tempo);
  bar 1 = a new bar line (tempo and time signature marker at beat 1; the audio does not move); Style: the script
  suggests (steady: 1 tempo; drifting: 1 tempo marker per bar), a dropdown changes it. Step 1 passed the user's
  manual test 23 November 2026.
  Step 2 approved 23 November 2026: octaves and strings. A Tuning dropdown next to Key, per song (project data key,
  default Standard; Half step down, Drop D, Drop C, 5-string); the lowest octave keeps the plain name, a higher note
  gets "(string fret)" on the lowest string with fret 7 or less ("E (A 7)", "G (D 5)"); doubtful octave = yellow;
  Settings > Note Detection > "String and fret for high notes" (on by default). Built 23 November 2026 (41 tests; real songs:
  song 1 54 / 57 octaves right, song 2 94%, half of the wrong ones yellow); not looked at on the screen: the user
  decided 23 November 2026 to add more features first, then take the screenshots and test.
  Step 3 approved 23 November 2026: fingering for runs. A row with 4 notes or more: every note gets its string and fret
  from the fewest hand moves over the whole song ("F (D 3) - Eb (D 1) - C (A 3) - Bb (A 1)"); other rows: the step 2
  rule. Settings > Note Detection > "Fingering for runs" (on by default). Built 23 November 2026 (43 tests; 398 / 410 the same
  place as the Guitar Pro score of song 2), deployed, not committed, not looked at on the screen.
  Step 4 approved 23 November 2026: MIDI export. "Export..." next to Finish: a MIDI item on a "Bass MIDI" track
  (no plugin) and a .mid file in the project folder; the found notes, quantized to 16th notes (a Rhythm dropdown in
  the Export window). MusicXML later, after a test in the user's Guitar Pro. Built 23 November 2026 (45 tests; the
  .mid file of song 1 read back: the same 622 notes and times as the MIDI item), deployed, not committed.
- Note Detective, bass player review (23 November 2026), decided the same day: Bass 1 yes with an off switch (a held
  note or pumping 8ths: "C (8ths)"; after the repeated-notes fix), Bass 2 yes with an off switch (the beat of each
  note in the Notes track text items), Bass 3 yes (a key change from a line), Bass 4 yes with an off switch (ghost
  notes as "x"), Bass 5 yes (string names "E A D G" or "4 3 2 1" in Settings). No answer: Bass 6 (hammer-on /
  pull-off), Bass 7 (a single note keeps the hand position of the run), Bass 8 (velocity from the level).
  Details decided 23 November 2026: Bass 2 counts "1 e & a" ("1 F · 2& Eb · 3 C", Notes track items only); Bass 3 =
  right-click a line > New key from here: a blue line "Key: D major" in the list and a marker "Key: D major" at Write
  (saved in the project data); the 3 new switches on by default; order 3, 5, 2, then 4 and 1 (measured first).
  Bass 3, 5, 2 built 23 November 2026 (52 tests, screenshots checked), deployed, not committed. Bass 4 (ghost notes
  "x") and Bass 1 ("C (8ths)"): later (decided 23 November 2026).
- Note Detective, decided 23 November 2026: (a) Export folder: Change... in the Export window, saved on this computer
  (ExtState), empty = the project folder; (b) "Clear..." asks, then removes the list (with key changes) and what Note
  Detective wrote (its markers, Notes track items, Bass MIDI item; 1 undo step); (c) Set tempo covers the whole bass
  item: steady song tempo in whole bars before bar 1, back to the item start; (d) a Tab view (View: List / Tab):
  the found notes as tab on the 16th grid with the fingering, click plays, the playing note blue, read only; (e) the
  found notes are saved in the project data with the list (`note=` lines, about 10-20 KB per song). All 5 built
  23 November 2026 (55 tests, screenshots checked), deployed, NOT COMMITTED.
- Note Detective, decided 23 November 2026: slides ("/C", Settings > Note Detection > Slide mark: "/C", "sl. C", "C (slide)",
  Off; no slides in the 2 songs to measure: generated notes and the user's ear) and the 8th / 16th notes: repeated
  notes split on the 16th grid (only when the project has a tempo marker, e.g. after Set tempo; trial 6d song 2:
  dip + 0.5 x rise >= 4 dB: 47% of the repeats found, 4% of held 16ths split wrongly), separate in the tab and the
  export, and the label "C (8ths)" / "(16ths)" in the markers (Settings switch, on).
- Note Detective, tab review decided 23 November 2026: yes to Dev 3 (right-click a note in the tab: Octave up / down,
  Other string, Delete; saved in the notes), Dev 1 + Bass 3 (an unsure octave from the neighbouring notes; never a
  clear pattern; measured first), Dev 2 (1 fingering for the list and the tab), Dev 5 (a tab hint without a tempo);
  no to the time-aware fingering and open strings. Bug: notes 1 16th early in the tab (beat 1 on 4a). The 8th / 16th
  labels leave the markers (the repeats stay for the tab and export only). Simple mode (Settings > Note Detection, ON by
  default): the markers show only the notes and the string and fret of high notes; the window hides Tempo and bars,
  View (Tab) and Export. Built 23 November 2026 (60 tests, screenshots checked), deployed, NOT COMMITTED. The octave
  from the neighbours: built, measured (no gain: song 2 902 -> 902-903, song 1 the same), removed.
- Note Detective, decided 23 November 2026: editing the tab while stopped (full mode): click an empty 16th on a
  string, type the fret, Enter (the note lasts until the next one, at most 1 bar); click a note = select (blue box),
  Left / Right = 1 16th, Up / Down = the same pitch on the next string, Delete, digits = a new fret; double-click =
  play from it; right-click = the menu. The play position is a blue line (no note highlight); stopped: a grey line
  at the edit cursor. "Update the list" makes the list again from the notes (asks; Undo). Built 23 November 2026
  (62 tests, screenshots: the selected note, the dashed edit cursor, the blue play line), deployed, NOT COMMITTED.
- Note Detective, decided 23 November 2026 (after trial 7 on song 2): (1) Settings > Note Detection > Split repeated notes (full
  mode, on by default); (2) J in the tab joins the selected note with the note before (the same pitch); (3) "Import
  tab..." next to Find notes (full mode): a .gp (Windows unpacks it) or MusicXML file, its bass track; bar 1 of the tab =
  bar 1 of the song (Set tempo's bar 1, else the bar of the first found note); the repeats played out; the found notes
  are replaced by the tab's notes, strings and frets, the tuning from the tab; Undo brings them back.
- Note Detective, 23 November 2026: the .mid file works in Guitar Pro; 2 problems there (lessons): repeated 16ths as
  1 note (open, see LESSONS.md) and notes 1 16th off (fixed: Export.delay, song 2 70.9% -> 86.6%). The slide mark:
  a choice in Settings (decided 23 November 2026). Next (not approved yet): bar lengths and time signatures, pickup
  notes, slides; repeated notes with the rhythm grid; each measured on the song 2 score (trial 6, scratchpad).
- Note Detective, asked 23 November 2026 (steps 2-4 tested by the user the same day): more accurate detection. The user: a repeat can really differ, so never correct it
  (only a hint); odd meters and a single 2/4 bar in the middle break the bars; a slide or pickup notes before bar 1 /
  before a bar line. Ideas given (not approved): a measurement against the song 2 score first; any bar length and a
  song time signature in Tempo and bars, with suggested places (the user confirms); pickup notes join the next bar;
  slides as 1 note with a mark; an odd repeat yellow only when the detection was unsure too.
- Guitar Pro direction (decided 23 November 2026 by the user). The workflow: a client asks for a song; stems or the
  full song go in; the script finds the tempo (1 tempo with a click, else 1 marker per bar); it finds the bass notes
  or the chords (the user's choice); a Guitar Pro file when there is one; any track of it in a Tab tab (guitar and
  bass tunings); the list updated from the tab. The window: List and Tab as 2 tabs, a track dropdown in the Tab tab.
  Later: the same in Chart Cue and in a standalone script (like Segue). The answers: (1) the tab goes on by bars (tab
  bar 1 = Set tempo's bar 1, the song's tempo map wins) with a "Tab bar 1 = song bar N" control; (2) the guitar tab is
  editable; (3) .gp5 and .gpx too (a plain-Lua unpacker: no PowerShell); (4) the project keeps the path of the .gp
  file, and the import copies the file into the project folder; (5) 1 shared Guitar Pro file for the 3 scripts, the
  standalone script first; (6) the markers of a guitar part = the chord names. Chords: from the Guitar Pro file first
  (its names, else named from the notes); chord detection from audio later. Drums: a drum grid, last. Order: 0 commit,
  1 the shared Guitar Pro part, 2 the window (2 tabs, the track dropdown, bars), 3 chords in the tab, 4 the list from
  the tab, 5 chord detection, 6 drums, 7 the standalone script, then Chart Cue. The name "Note Detective" may change
  (before the first release). The detection review of 23 November 2026 (not approved, for later): measure on the
  user's finished marker projects; start at a pluck or at a pitch change (kick bleed); each layer off once.
  Step 1 decided 23 November 2026: the standalone script is "Tab Viewer"; its 1st window = Open tab..., the file name,
  1 line per track (name, instrument and strings, tuning, capo), the bars, time signature and tempo of the file;
  segments 1a (.gp, the shared reader, the window), 1c before 1b (.gp5, .gp3, .gp4 first, then .gpx). The opened tab
  is copied into a "Tabs" folder of the project folder (an unsaved project: the original path, the copy at the 1st
  save).
- Note Detective (1.0 built 23 November 2026). Later: Find tempo as in Tab Viewer (decided 24 November 2026): a
  toolbar button instead of the "Tempo and bars" section, its menu = the tracks (a choice starts at once), then the fine
  controls; a blue Set tempo next to it after a result. Later too: the tab's position line blue when stopped too, as in Tab Viewer
  (no dashed line; decided 24 November 2026); the complete song as the source (doubtful lines), a large "Now / Next" view, larger text in the Notes track items, the 40 ms of a separated file.
  The trials that its detection comes from: trial 1, 23 November 2026, on 1 finished project (86 markers made by hand), in plain Lua, no plugin: first note
  right 83 / 86; about 125 of 131 marker notes found (the 6 missed ones are in fast fills); 10 s for 196 s of audio;
  tuning measured right (441 Hz). Method: take accessor at 4000 Hz mono, YIN (window 200 samples, hop 40, lags 8-130,
  threshold 0.15), pitch class only, the most common of 7 frames, notes of 80 ms or more. The octave is not reliable
  (string / fret texts right 9 / 18: half of them an octave low). The user's answers (23 November 2026): about 1 marker
  per bar; the same notes again at each section; note names correct for the key; the learner uses REAPER on a screen.
  Trial 2 (same day, detector unchanged, a steady 160 BPM song with fast 8th notes, against a Guitar Pro score of
  1040 notes): pitch right 96.4%, of these the octave right 98.6% (so the octave depends on the song); in the note
  changes 31 missed, 8 extra, 24 wrong of 606; 16th notes 24 / 32; a fading low C is heard as its 3rd harmonic (G).
  Trial 3 (same song, the complete mix): the YIN detector 62.5% of the score notes; with a 180 Hz low-pass 77.9%; a
  harmonic sum (notes C1-B2, harmonics 1-4, 150 ms Hann window, weights 1 / 0.8 / 0.5 / 0.4) 90.0%, and 95.8% on the
  isolated bass. So: isolated bass first, the mix only as a fallback. The separated file starts about 40 ms late.
