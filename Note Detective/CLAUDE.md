# Note Detective

Finds the notes of a separated bass item, shows them in a list to check, and writes them as markers, as text items on
a "Notes" track, or both (the Write dropdown). For a player who learns the part in REAPER. A preparation tool; Chart Cue
look, 1 window, no tabs. Plan and answers: decided 23 November 2026.

## Files

- `Note Detective.lua`; no actions. Version: `@version` and `CFG.VERSION` together. Release: tag
  `notedetective-vX.Y`, title "Note Detective X.Y" (the `release` skill). Not released: `@noindex`.
- `Guitar Pro.lua`: the shared Guitar Pro reader (`GP`), from `Tab Viewer\` (see Tab Viewer/CLAUDE.md); ReaPack and
  `deploy.ps1` put a copy next to the script.

## Architecture and data

- `P` (ProjExtState "Note Detective"/"cfg"; nothing saved when it is empty): `key=`, `mode=` (only when not "bar"),
  `src=` (the GUID of the bass item), `row=` time, doubtful 0 / 1, the time of each note, the text (tabs between), `mk=`
  the GUIDs of the written markers (also of older writes: Ctrl+Z brings those back). Finish removes all of it.
  `P_EXT:NoteDetective` = 1 on the Notes track and on its text items.
- `S` (ExtState "Note Detective"): `light`, `dock`, `out` ("markers", "track", "both"), `tempo` (the Tempo and bars
  section open, 1 / 0; default open), `frets` (Settings > Notes > String and fret for high notes, default on),
  `finger` (Settings > Notes > Fingering for runs, default on), `strings` ("letters" / "numbers", Settings > Notes >
  String names), `counts` (Settings > Notes > Beat count in the Notes track, default on). `P.tuning` (`tuning=`, only
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
- Simple mode (`S.simple`, Settings > Notes, ON by default, decided 23 November 2026): `List.opt()` gives only the
  string and fret of high notes (no fingering of runs, no slide mark), no beat counts; the window hides Tempo and bars,
  View (Tab) and Export; Settings > Notes shows only Simple mode and String names. The tests set it off at the start.
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
- Decided 23 November 2026 ("1 2 3"): `S.splits` (Settings > Notes > Split repeated notes, full mode, default on:
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
  Finish), `Beat` (tempo, beats, bar 1, the plan of the tempo markers; no REAPER calls), `Tempo` (Tempo and bars:
  Find tempo in steps, Set tempo, Play with click), `UI`.
- Tempo and bars (step 1 of the 23 November 2026 wishes): `R.tempo` only (runtime, nothing saved; the result is
  REAPER's tempo map). Beats from: metronome tracks (`Util.is_click`), then drum tracks, then the others. Find tempo:
  `Beat.onset` (the rise of the log level), `Beat.tempo` (Fourier, 60-200 BPM, folded into 90-180), `Beat.track`
  (dynamic programming), `Beat.bar1` = the first beat with sound. Style suggested by `Beat.fit` (9 of 10 beats within
  30 ms: "1 tempo", else "Follow the song": 1 marker per bar).
- Set tempo aligns (decided 23 November 2026 by the user): `Tempo.write(name, true)` -> `Tempo.align` in the same undo
  step: `Tempo.first_note` (the first found note when the list is of this item, else `Det.first_sound` in the item's
  first `CFG.ALIGN_SCAN` s: the first pluck missed the first note of song 2), then every item at least half inside the song moves so that note is on the nearest beat;
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

- `.\tools\deploy.ps1` copies it to `Scripts\Thunderfork Scripts\Note Detective\` (ReaPack), else `Scripts\Note Detective\`.
- Tests: `tests\notedetective.lua` (`.\tools\test.ps1 -Script "Note Detective"`). The audio tests use generated WAV
  files. The import test uses a small made-up score (never the user's files).
