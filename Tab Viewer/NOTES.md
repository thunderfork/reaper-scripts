# The Detection tab of Tab Viewer (`Notes.lua`)

Finds the notes of a separated bass item (or takes them from the tab: Import to list), shows them in a list to check,
and writes them as markers, as text items on a "Notes" track, or both. For a player who learns the part in REAPER.
It was the script Note Detective (never released; now inside Tab Viewer; its old keys are not read).
The history of every decision: git.

## Files and the host

- `Notes.lua` = `return function(host)`: Tab Viewer makes the module `Notes` (`[nomain]` in its `@provides`, `Uses` in
  `tools\scripts.psd1`). The host gives GP, TP, CFG (CTRL_GAP, SP_ROW, EXT, LABEL_W), COL, ImGui, UI (the module's `UI`
  falls back to Tab Viewer's helpers), R (Find tempo, the notices), `notes_changed`, `loop_off`, `entry_line`,
  `entry_text`, `gp_song` (`Tabs.found_song`).
- What Tab Viewer calls: `N.attach`, `N.step`, `N.draw(h)`, `N.draw_popups`, `N.keys`, `N.draw_settings`,
  `N.HELP_TOPICS`, `N.save`, `N.exit`, `N.busy`, `N.import`, `N.found_doc`, `N.found_entry`, `N.touch`, the toolbar
  (`N.undo`, `N.has_undo`, `N.go`, `N.has_rows`, `N.loop_off`) and the Find tempo hooks (`N.first_note`, `N.shift`,
  `N.set_extra`, `N.written`). `N.test` hands the modules to the tests.
- Modules: `Util`, `Key` (keys and note names, places, fingering), `Det` (the detection), `Group` (notes -> bars ->
  rows), `List` (the rows, corrections, Undo), `Project`, `Find` (reads the item in steps), `Out` (Write with the song
  region, Clear), `Export` (MIDI, .mid, .gp5), `Imp` (the tab and the list), `UI`. Tempo and bars: the shared `Tempo.lua`.

## Data

- 1 list per song (decided 26 November 2026; `Songs`, `Lists`): ProjExtState "Tab Viewer"/"notes" holds a block per
  song, `song=<id>` (a region's GUID, a bass item's GUID, or "" in a project without songs), then the lines of its
  list. An older text without `song=` lines is not read (no migration). A song is a region, or an audio item of the
  Track row's track whose middle is in no region (`Songs.make`). `R.lists` (the saved blocks), `R.song` (the shown
  list `P`), `R.hist` (the Undo steps of the other songs, this session). `Lists.follow` (every frame): the list of the
  song at the play position (stopped: the edit cursor), only when that song changes; not while Find notes listens or
  a window of the list is open; between songs the last one stays. `Lists.adopt`: a list whose song is gone goes to
  the song at its first line, when that song has none (a lost list stays saved). Find notes (`UI.find`) fills the
  song of the item (`Songs.for_item`; another song: its list shows first); a region song reads only its part of the
  item (`Find.part`). Write, Clear and Export delete only the marked items whose middle is in the song
  (`Out.delete_marked`). Write makes a region only for a song that is a bass item; a region song keeps its name
  (`Out.region`). `N.shift` moves the lists of other songs on the same item too.
- `P` (the list of 1 song; nothing saved when empty): `key=`, `mode=` (only when not "bar"), `tuning=`
  (only when not "std"), `src=` (the GUID of the bass item), `row=` (time, doubtful 0 / 1, the time of each note, the
  text), `keyat=` (a key change from the line at that time), `note=` (t, t1, pc, midi, doubt, slide, s (a string you
  chose), man (from a tab: Export.delay leaves it)), `tend=`, `mk=` (the GUIDs of the written markers, also of older
  writes: Ctrl+Z brings those back), `tab.<key>=` (the tab of the found notes, an entry as Tab Viewer's tabs: `P.tab`).
  Clear removes the list of its song. `P_EXT:TabViewer` = 1 on the Notes track and its items ("midi": the Bass MIDI track).
- `S` (ExtState "Tab Viewer"; keys that do not meet Tab Viewer's): `out` ("markers", "track", "both"), `frets`
  (String for high notes, on), `finger` (Fingering for runs, on), `strings` ("letters" / "numbers"), `splits` (Split
  repeated notes, OFF by default), `export_dir` ("" = the project folder), `song_follow` (Follow the song, on),
  `write_fx` and `write_clicks` (Write removes the bass plugins / deletes the metronome track, both off), `bars`
  ("song": the Bar column from the song's first bar line, `Group.bar_base`, as the Tab tab counts in a region;
  "project": REAPER's bars).
- 1 mode: no Simple mode, no beat count, no slide mark.
- `R` (runtime): the selection, the edit box, `undo` / `redo` (`List.step`: the list text, or `{ reaper = the undo
  name, list }` for Write, Clear and Export: their undo is REAPER's undo too, when that step is REAPER's next one), the
  view cache `R.view` (`UI.view`), the loop of a line `R.loop`, the running `R.find`.

## Detection (`Find`, `Det`)

- `Find.source`: the track of the Track row (`Find.track`: your choice, else the track of the last bass item, else
  of the selected item), its selected audio item, else the longest. The samples are read outside the coroutine (the
  audio accessor gives silence inside one); only `Det.analyse` runs in it. A 3:42 song: about 16 s.
- `Det.analyse`: mono at 4000 Hz. Onsets: `Det.onsets_of` (the band flux of 9 bands 50-800 Hz, relative to the
  loudest band of the moment; nothing below the loud level of the whole item: `CFG.ON_GATE`, `CFG.GATE_DB`). A note
  starts at an onset, or at a pitch change without one; 1 pitch per note (YIN, `Det.yin`, the pitch class; a harmonic
  sum `Det.harm_pc` checks it: they disagree = doubtful); it ends before a gap (`CFG.END_GAP`); `CFG.START_COMP`
  moves the starts 30 ms earlier. The octave: `Det.odd_even` (odd against even harmonics of the low octave) with a
  limit per song (`Det.octave_limit`). `Det.glitches` removes a short 5th glitch; `Det.slides` finds a glide into a
  note (no mark; a slide into the same note is still its own note). `Det.repeats` (only with
  `S.splits` and a tempo marker: `Find.grid`) splits a held note at a pluck on its 16ths. `n.why` -> `List.why` (the
  tip of a yellow line). A new Tuning: `Find.retune` hears only the notes that can now be an octave lower.
- What the trials showed (the user's songs, never in git; most rules tuned on 1 song, song 2,
  steady 160 BPM 8ths): isolated bass far better than the mix (95.8% against 90% with a harmonic sum, 62.5% YIN);
  pitch right about 96%, the octave 96-99% (depends on the song); starts within half a 16th about 80%, with the 16th
  grid 86%; held notes and repeated plucks look the same in a Moises stem (the limit of the method); the separated
  file starts about 40 ms late. Tried, not better by the user's ear: pYIN paths, prime-harmonic octave, a
  probabilistic rhythm grid, the librosa / Boeck onset limit, a 16 kHz band, the octave from the neighbouring notes, a
  brightness jump for repeats, joining a fading note's overtone. The user thinks a limit is reached (see PLAN.md).
  Unlike common practice: the onset limit (1 s mean x 2, not 100 ms mean + delta), the onset range (50-800 Hz), the
  automatic whole-16th offset (`Export.delay`), and the measuring (own percentages on 1-2 songs, not mir_eval with
  onset +-50 ms, pitch +-50 cents, precision and recall on songs not used for tuning).

## Lines (`Group`, `List`)

- Lines (`P.mode`): "1 per bar" (`Group.project_bars`), "Every note change" (`Group.change_bars`). A saved older
  mode is read as "1 per bar".
- Strict bars: a note is in the bar where it starts; a start up to `CFG.BAR_TOL` (30 ms)
  before a bar line is the 1 of that bar. A note of an earlier bar that rings `CFG.HELD_MIN` (0.15 s) into a bar is
  its first note too, a plain name ("(G)" was tried and removed: repeated 8ths heard as 1 long note). A bar with the
  same notes as the bar before gets no line (a long C stays 1 marker), except at the start of a section
  (`Group.sections`: a block of `CFG.SECTION_BARS` bars that comes back).
- Names: `Key.names` (the key decides Ab or G#; `Key.find` from the file name; `Key.guess` after Find notes: "Sounds
  like C minor. Use it?"); `Key.respell` keeps text in brackets. A key change: right-click > New key from here (a blue
  line in the list, a marker "Key: ..." at Write). Places: `Key.place` (a note above the lowest octave: "(string
  fret)" on the lowest string with fret 7 or less), `Key.finger` (the fingering of the whole song: the fewest hand
  moves, `CFG.FINGER` costs; a line of `CFG.RUN_MIN` notes or more shows every place); `List.places` = 1 fingering
  for the list, the found tab and the export.
- Editing: type the notes (double-click, F2; then "the same notes in other lines too?"), Join, Split, + Add, Delete,
  Move to the edit cursor, Sure / OK, Next not sure (N). A click on a line plays from it (`UI.play_row`); with the
  toolbar's Loop on (`N.loop_toggle`, `R.loop_on`; decided 27 November 2026) it loops that line (`UI.loop_row`:
  REAPER's time selection and repeat; `UI.loop_off` gives back the old ones; it stays while stopped, until Loop is
  off, Escape, another song or project; 1 loop at a time with the Tab tab's bar loop).
  Undo / Redo: the toolbar arrows and Ctrl+Z / Ctrl+Shift+Z (`List.undo(redo)`).
- A changed Key, Tuning or Lines makes the lines again; a line you corrected keeps your text (`List.remake`).

## Output (`Out`, `Export`)

- Write (`Out.write`): markers, text items on a "Notes" track above the bass, or both; only what this tab wrote is
  replaced; in the same undo step the song region (`Out.region`: "Artist - Title - Key" from the file names, only for
  a song that is a bass item and has a file name) and, when switched on, `Out.tidy` (`S.write_fx`: the bass track's
  plugins, `S.write_clicks`: the metronome tracks); the list stays (Done: clean up merged into Write, decided 27
  November 2026). "Written (n markers)" in green until the list changes. Clear... (`Out.clear`, asks; 1 undo step).
- Export... (bottom right): a MIDI item on a "Bass MIDI" track, a .mid file (`Export.smf`, written by hand; the tempo and
  time signatures of `Export.tempos`), and a Guitar Pro file (.gp5: `GP.write_gp5` with
  `Tabs.found_song`: the found tab as the Tab tab shows it, your time signatures and fixes, notes over a bar line
  tied, the tempo of the project at each bar; an edited bar has no ties into the next bar). The MIDI: `Export.notes`
  (on the grid of the Rhythm dropdown; `Export.delay` takes the common delay of the found starts away first, a lesson). The files: `Export.path` (the project folder or `S.export_dir`; the same name, .mid / .gp5).
  The export uses the notes, not the typed texts.

## The found notes as a tab (Tab Viewer's Tab tab)

- Where the song has no Guitar Pro tab, `Tabs.load` shows `Imp.found_doc()` (`doc.found`: 1 bass track in the
  list's tuning, the bars of the project from the bar of the first note; `doc.tab()` = the notes on the grid,
  `Imp.grid` and `Imp.legato`, with the places of the list; `over` = the part after the bar line). `R.found_e` =
  `P.tab`: the fixes, line breaks and start bar of that tab are saved with the list (`N.touch`), so the list's Undo
  brings them back too. The list or the tempo changed: `host.notes_changed` -> `Tabs.notes_step` makes it again.
- Import to list (the Tab tab, next to Track; the same as Import from tab on the Detection tab's Track row, shown
  only with a tab): `Tabs.notes_of_tab` -> `N.import` (asks when the list has lines) ->
  `Imp.apply` (the notes with `man`, the strings of the tab, the tuning); it bakes the found tab's fixes into the
  notes (`P.tab` goes). Find notes and Clear start a new tab.

## The screen

- Above the sections: Tab Viewer's song header (`UI.draw_song_head`, also in the Tab tab; `N.song_head`,
  `N.song_go`, `N.song_list`; decided 26 November 2026, the UI/UX review "A"). Settings > Detection > Follow the
  song (`S.song_follow`, on) switches `Lists.follow` off; the arrows and the list still change the song.
- The sections in the order of the work (decided 26 November 2026; no numbers in the headings): "Tempo" (Tab
  Viewer's `UI.draw_tempo_step`), "Bass", "Notes"; Tempo and Bass fold (`UI.FOLD_TEMPO`, `UI.FOLD_SONG` in
  `S.closed`). Each heading: its status after the title, its step's button at the right end (also when folded;
  `UI.heading` with 1 button or a list). Blue is the 1 next step: Find tempo (no tempo yet), Set tempo (a result, in
  Find tempo's place), Import from tab (with a tab) or Find notes (no list), Write. The Tempo section is done when
  the song of the header has a tempo marker of its own (`Tabs.tempo_state`, `UI.tempo_ok`; `Tabs.song_item`: the
  audio in that song, cut to its range; "The tempo is right" puts one at the song start); until then Find notes and
  Import from tab are grey, with a grey line. Another song drops a Find tempo result (`host.song_changed`).
- Bass: Import from tab (with a tab) and Find notes in the heading (while it listens: Cancel, the progress under
  the Notes heading), Track, Key and Tuning on 1 row (`CFG.KEY_W`, `CFG.TUNE_LABEL_W`; narrower than `CFG.TUNE_MIN_W`: 2 rows), Lines
  with an example. Notes: the count and Next not sure at its right. Without a list: the grey hint, no bottom
  rows. With a list: Join, Split, + Add, Delete, Clear... (Delete and Clear red: `UI.button` kind "danger"); then the
  blue Write, its dropdown, Export... at the right (no More... menu: decided 27 November 2026).
- Settings > Detection: Follow the song, String for high notes, Fingering for runs, Split repeated notes, String
  names, Bar numbers, Write removes the bass plugins, Write deletes the metronome track.

## REAPER facts

- REAPER's undo does not change ProjExtState (checked); markers keep their GUID after undo and redo.
- A project change: the saved text decides (`Project.update`), so "Save as" keeps the list.
- Set tempo (Tempo.lua) aligns the first found note on the beat and moves the list with the audio (`N.shift`).

## Tests

- `tests\notes.lua` (it returns a function; `tests\tabviewer.lua` runs it: `.\tools\test.ps1 -Script "Tab Viewer"`).
  The audio tests use generated WAV files, never the user's files.

## Later (ideas, not approved)

- The detection decision (PLAN.md): a measuring tool on 5-8 stems with tabs, "Use a MIDI item" (Melodyne / Basic
  Pitch), or stop.
- From the bass player review: ghost notes as "x", "C (8ths)" for pumping notes; no answer yet:
  hammer-on / pull-off, a single note keeps the hand position of the run, velocity from the level.
- Chord detection; the complete song as the source (doubtful lines); a large "Now / Next" view; larger text in the
  Notes track items; the 40 ms of a separated file; MusicXML.
