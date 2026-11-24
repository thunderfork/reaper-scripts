# Thunderfork scripts: plan

## Handoff (24 November 2026)

- Branch `script/tab-viewer`. The earlier work is committed (2 commits, 24 November 2026). NOT COMMITTED (deployed,
  Tab Viewer 32 tests): segment A, loop and speed (`Tabs.loop`, `Tabs.loop_off`, `Tabs.speed`). Manual test of
  segment A: PASSED (24 November 2026). Also not committed: the Play / Stop icon in the toolbar (before the gear;
  Space in the window plays / stops, decided 24 November 2026) and segment B, playing marks in the Guitar Pro look (Tab Viewer 33 tests). Both PASSED (24 November 2026).
  Next: segment C1. Another tab or closing the window also ends the loop.
- .gpx (segment 1b): done (the user, 24 November 2026).
- Next (decided 24 November 2026), before the release of Tab Viewer, each a segment, ask before each:
  - B: playing marks (h, p, / \, b, ~, PM, <12>, x dead notes; small and grey; Settings > Tab > Playing marks, on;
    fixed notes keep their marks, new notes none).
  - C1 (also: remove the beat numbers under the tab, the user 24 November 2026): note lengths drawn under the tab (stems, 8ths / 16ths joined per beat, dots, rests, the "3" of triplets;
    Settings > Tab > Note lengths, on); a bar with a 32nd gets 2 columns per 16th (only that bar wider).
  - C2: the keys of a selected note (or in its box): + / - double / halve (32nd ... whole; never past the next note
    on its string or the bar end: a notice), "." dotted on / off (x1.5), "/" turns the beat of the note into a
    triplet (its notes to the 3 (or 6) triplet places; a new note or a move there uses those places), "/" again back
    to 16ths. A new note stays 1 16th.
  The user's question still open: the stronger fix for the tag `imgui-input` (click rules into plain functions with
  a test; recommended "Later").
- Then: the release of Tab Viewer (debug-time, README, ReaPack). Later: the list from the tab (step 5, Note
  Detective), chord detection (6), drums (on hold), Note Detective's Find tempo as in Tab Viewer.
- Last checkup: none as 1 full run (see below).

### The handoff before (23 November 2026)

- State: 8 scripts; REAPER 7 ReaScript, Lua 5.4, ReaImGui pinned to 0.9.3 (the shim). Chart Cue is Windows only.

  | Script | Version | State |
  |---|---|---|
  | Chart Cue | 1.7 | released 11 November 2026 |
  | Segue | 1.3.1 | released 11 November 2026 |
  | MIDI Pilot | 1.4 | released 11 November 2026 |
  | FX Link | 1.1.1 | released 11 November 2026 |
  | Session Prep | 1.0.1 | released 17 November 2026 |
  | SFX Drop | 1.0 | committed, not released (hidden with @noindex; the user wants more work first) |
  | Mono Merge | 1.0 | released 17 November 2026 |
  | Note Detective | 1.0 | not committed, not released (hidden with @noindex) |

- 21 November 2026: the project follows the newest global process (from the Athens Bus project): Size full,
  `LESSONS-RULES.md` loaded by CLAUDE.md, this PLAN.md format, the rules from Claude's memory moved into the
  CLAUDE.md files, a pre-commit hook with the checks and tests. Together with the 19 November 2026 process changes
  (Users section, release checks instead of the global checkup, security review before a push): committed
  21 November 2026, not pushed. The duplicate rules in Claude's memory were deleted (the user's choice).
- Last checkup: none as 1 full run (17 November 2026: housekeeping and a full Session Prep review).
- Checkup in progress (21 November 2026): before it, the cached text cuts (UI.trunc_c) in the MIDI Pilot and FX
  Link lists and the dead code removed: committed 23 November 2026 (checks and tests passed; deployed). Steps 1-4 read (6 review
  agents; the main findings confirmed in the code). Stopped at the user's weekly limit, before the user's answer.
  Next session: ask the 3 questions of Open now 9 (bugs go, saved data 25 / 26, notes), then fix (bugs with a test
  first, the `lessons` skill), then "Last checkup: <date>".
- More than 3 manual tests are open: no new feature until they are tested (global rule). Exception, decided
  23 November 2026: Note Detective starts now; the tests stay open.
- 23 November 2026: Note Detective 1.0 on the branch `script/note-detective` (from main), deployed, NOT COMMITTED
  (the uncommitted files of the checkup above are in the same working folder: commit them apart). Built this day:
  Tempo and bars, octaves and strings, fingering, MIDI export, Simple mode, the Tab view with editing, the J join,
  Split repeated notes, Import tab (Guitar Pro 7 / 8: repeats, "%" bars, grace notes, bar 1 matched to the found
  notes), and the new detection of the sound engineer review (Dev 1-5, UX 1: onsets, 1 pitch per note, the octave
  limit of each song, the reason of a yellow line; song 2: 86.3% of the tab notes found with the grid, before 78.8%).
  Note Detective/CLAUDE.md has the measurements (trials 7-10; the trial files are in the old session's scratchpad).
- 23 November 2026, later: the user found that the new detection "falls apart" on other bass stems and thinks it is
  worse. Decided: keep it for now, no more detection work until the user brings it up (to go back: the detection of
  before the review is in git history only after a commit; it is NOT committed, so the old code exists only in the
  old session's transcript). New project rule (CLAUDE.md): build a change with many parts in segments and ask
  before each.
- Segment 1 (done, PASSED by the user): Import tab puts the first tab note exactly on the very first found note
  (`Imp.start`; the bar search `Imp.best` removed).
- Segment 2 (built): Set tempo moves the song's items so the first bass note sits on the nearest beat (`Tempo.align`,
  1 undo step; the list moves with `List.shift`). Manual test 27 FAILED ("moved to the wrong place"): cause found
  and fixed (the first note was found in the bleed before the bass; lessons entry), deployed, 73 tests pass. NOT
  yet retested by the user: Open now 27.
- Segment 1a built 23 November 2026 on the branch `script/tab-viewer` (from `script/note-detective`): Tab Viewer 1.0
  (new script, not released: Open tab..., the track list, the Tabs copy), the shared reader `Tab Viewer\Guitar Pro.lua`
  (own zip / deflate unpacker; Note Detective's import uses it, no PowerShell any more), `Uses` in
  `tools\scripts.psd1` (deploy and release copy the shared file). Checks and tests pass (Tab Viewer 12, Note
  Detective 72); deployed; manual test PASSED (the user, 23 November 2026); NOT COMMITTED (the user: commit later).
- Segment 1c built 23 November 2026: the shared reader reads .gp5, .gp4, .gp3 (`GP.read_old`); Tab Viewer and Note
  Detective's import take them. Checked on the user's real .gp5 (to the last byte); .gp3 / .gp4 only with made-up
  files. Tests pass (Tab Viewer 13, Note Detective 72); deployed; manual test PASSED (the user, 23 November 2026);
  NOT COMMITTED. A real .gp3 / .gp4 file is still unchecked.
- Segment 1b built 23 November 2026: .gpx (Guitar Pro 6, packed and not). Only made-up files: no real .gpx on this
  computer. Tests pass (Tab Viewer 14, Note Detective 72); deployed; NOT COMMITTED. Step 1 is complete.
- Debug round (debug-time) 23 November 2026 on step 1: 3 bugs with damaged files fixed (a .gpx sector list that
  points back looped forever; a damaged .gp zip index stopped the script with a Lua error; a negative text length in
  a .gp3/4/5 moved the reader back), 2 tests added (Tab Viewer 15). Simplify (4 agents) the same day: 1 byte-to-text
  helper, 1 track-kind name match, padding instead of the "end + 3" rule, the unzip without a copy, a repeated bar
  read once, Tabs.show / Tabs.keep(from) (no 2nd read after a save), Util.read_all / write_all as in FX Link, the Note
  Detective tests hand over the shared reader, release.ps1 copies like deploy.ps1. Skipped: 1 shape for the bars of
  all formats (more parse time at open), reading @provides instead of `Uses`, a cache for project tab switches.
  Committed 23 November 2026 (2 commits). Decided 23 November 2026: after the 1st save or Save as of a project with
  a tab, the project shows as changed once more (the tab's new place); kept as it is.
- Step 2 decided 23 November 2026 (the tab in the window): Tab Viewer: a track dropdown above the tab (no Tracks
  tab); the tab read only, any number of strings, chords stacked, bar numbers, repeats played out, a click plays from
  there; drums: a grey line (later). Saved in the project: the chosen track (`track=`) and the tab's start bar
  (`bar=`; default: the first bass track, bar 1). A "Follow playback" switch in a new Tab section of Settings (this
  computer, on; segment 2b). Segments: 2a
  the tab (Tab Viewer), 2b "Bar 1 of the tab = bar N of the song" and following playback, 2c Note Detective List |
  Tab tabs with the same drawing. Guitar tab editing and drums later. The exception of the open manual tests covers
  this direction (assumed; the user did not object).
- Segment 2a built 23 November 2026: Tab Viewer's Track dropdown and the tab (read only, chords, any strings, a click
  plays from there; bar 1 of the tab = bar 1 of the project until 2b). Tests pass (Tab Viewer 18, Note Detective 72);
  deployed; manual test PASSED (the user, 23 November 2026); NOT COMMITTED.
- Segment 2b built 23 November 2026: "Bar 1 of the tab = bar N of the song" (< and >, hold = repeat; saved as
  `bar=`), the tab follows the song's beats from there (its own bar lengths), the bar numbers are the song's; the
  blue play line, the dashed edit cursor; Settings > Tab > Follow playback (on). Tests pass (Tab Viewer 20);
  deployed; NOT COMMITTED. Manual test 23 November 2026: the tab plays and follows, but not the song's tempo: the
  project was at REAPER's default tempo (expected, not a bug). Added: a yellow line when the project's tempo where
  the tab starts is not the tab's (`Tabs.tempo_check`).
- Tempo in Tab Viewer, decided 23 November 2026: 2d = Note Detective's tempo code (Beat, Tempo: find the beats, the
  bar plan, writing REAPER's tempo with the items held in place) into a shared file, Note Detective unchanged; 2e =
  Tab Viewer gets the same foldable "Tempo and bars" section above Track (as the mockup), "Beats from" gets a first
  choice "The tab (its tempo)" (the tab's tempo, tempo changes and time signatures, no listening; Bar 1, Play with
  click and Set tempo the same); after Set tempo the tab starts on the new bar 1 (< > still move it). Order: 2d, 2e,
  then 2c. 2a and 2b committed 23 November 2026.
- Segment 2d built 23 November 2026: `Tab Viewer\Tempo.lua` (shared) holds Note Detective's Tempo and bars, its audio
  reader and first-sound search; Note Detective uses it through a small host (no visible change). Tests pass (Note
  Detective 72, Tab Viewer 20); deployed; NOT COMMITTED. A bug in it (CFG.BPM_MIN still read by the window) fixed,
  with check.ps1 step 2b; manual test PASSED after the fix (the user, 23 November 2026). Next (ask first): 2e. Next (ask
  first): step 2 (the window: List and Tab tabs, the tab drawing, the track dropdown, the tab on the bars; with the
  new-feature skill and a mockup).
- Segment 2e built 23 November 2026: Tab Viewer's "Tempo and bars" (Beats from "The tab (its tempo)" first, then
  the tracks as in Note Detective); shared code in Guitar Pro.lua (`GP.timeline`, `doc.tmap`) and Tempo.lua
  (`Tempo.from_tab`, `Beat.tab_plan`). Tests pass (Tab Viewer 22, Note Detective 72); deployed; NOT COMMITTED.
  Manual test PASSED (the user, 23 November 2026). Next (ask first): 2c.
- Tabs per region, decided 23 November 2026 (not built; a change of saved data: a list of tabs instead of 1
  `file=`): many tabs in 1 project, each linked to 1 region; the window shows the tab of the region at the play or
  edit cursor (a dropdown chooses another one when stopped); the tab moves with its region, its start inside the
  region found automatically as now (Tempo and bars), with < > to correct it by hand. Mockup approved 23 November
  2026. Segment 1 built 23 November 2026 (the Tab dropdown with Region and Remove this tab, Open tab for the region
  at the edit cursor, the start bar counted from the region, the saved list `tab=`/`region=`); tests pass (Tab
  Viewer 24); deployed; NOT COMMITTED; manual test PASSED (the user, 24 November 2026). Segment 2 built 24 November
  2026 (the window follows the play / edit cursor; Find tempo uses the audio in the tab's region); tests pass (Tab
  Viewer 25); deployed; NOT COMMITTED; manual test PASSED (the user, 24 November 2026).
- Tab Viewer next, decided 24 November 2026: step 3 (chord names in a row above the tab, at the beat where the chord
  changes; from the file, else named from the notes; Settings > Tab > Chord names, on), then the editable tab (notes
  on the 16th grid of guitar and bass: fret, string, add, delete, as in Note Detective; the changes saved in the
  project on top of the tab, the file and its copy unchanged; "Undo all changes" in the Tab dropdown). Drums (step 6):
  delayed, the user thinks about it. Step 3 built 24 November 2026 (only chords that ring at least 1 beat get a
  name from the notes: decided 24 November 2026); tests pass (Tab Viewer 26, Note Detective 72); deployed; NOT
  COMMITTED; manual test PASSED (the user, 24 November 2026). The stopped position line is blue too (no dashed
  line; decided 24 November 2026). Layout review and Find tempo in the toolbar (24 November 2026): deployed, NOT
  COMMITTED; manual test PASSED (the user, 24 November 2026). The editable tab, decided 24 November 2026: the written bar changes (repeats too), a new
  note the easiest length, the new saved key `edit=` (approved), Undo all changes = the track in the window, undo =
  Ctrl+Z in the window and an Undo button. Segment 1 built 24 November 2026 (select, Left / Right, Up / Down, fret,
  Delete, saved, Undo / Redo); tests pass (Tab Viewer 28); deployed; NOT COMMITTED; manual test PASSED (the user,
  24 November 2026). Segment 2 built 24 November 2026 (the note box: fret, Left / Right moves inside the bar; a click
  on an empty place: a new note, 1 16th); tests pass (Tab Viewer 29); deployed; NOT COMMITTED; manual test: the
  box opened after 2 clicks on different places (lessons, fixed 24 November 2026: only a double-click on the same
  place opens it, also for a new note; Tab Viewer 30 tests); the other steps PASSED; the re-test PASSED (24 November 2026). Note Detective got the same
  fix (the user's choice); its manual test PASSED (24 November 2026). Segment 3 built 24 November 2026 (Tab dropdown >
  Undo all changes, the green fixed notes, Settings > Tab > Mark my fixes, on); tests pass (Tab Viewer 31); deployed;
  NOT COMMITTED; manual test PASSED (24 November 2026). The editable tab is complete. .gpx (segment 1b): done
  (the user, 24 November 2026).
- Step 0 done 23 November 2026: Note Detective committed as it was (the user's choice, without the debug-time round
  first: it is the rollback point before the Guitar Pro work). The debug-time round comes before its release.
- 23 November 2026, new direction (decided by the user): the Guitar Pro tab becomes the main feature, the detection
  the second one (see "Later": "Guitar Pro direction"). Next: step 0 (commit Note Detective as it is), then step 1
  (the shared Guitar Pro part in a new standalone script), in segments. The open Note Detective manual tests
  (Open now 15-26) can go out of date with the new window (step 2): the user decides then. Detection work only when
  the user asks.

## Open now

Answer by number. Manual tests: in question windows, 1 question per test (Passed / Failed / Skip for now); a
skipped or failed test stays here; remove it when it passed.

1. Manual test (Session Prep, 12 November 2026): Mono button on a fake stereo track (grey -> orange on click; Apply
   plays one side; Ctrl+Z undoes it). Skipped twice.
2. Manual test (Session Prep, 12 November 2026): file check: a 44.1 kHz file in a 48 kHz project (or an item that
   starts later) shows an orange "44.1k" / "late" tag in the Prep table.
3. Manual test (Session Prep, 12 November 2026): dual pan: a track in dual pan (or a project whose default pan mode
   is dual pan) with its knobs not at full L / R shows "kept" and keeps its pans after Apply.
4. Manual test (Session Prep, 17 November 2026): Gain staging on, Scan with hi-hat / OH / cymbal tracks: no
   "silent" tag, normal Gain values.
5. Manual test (Session Prep, 17 November 2026): a client's return (no items, receives a send): no "empty" tag, no
   Delete button.
6. Manual test (Session Prep, 17 November 2026): rename a return to empty, then to "Delay" (taken): the old name
   comes back each time.
7. Manual test (Session Prep, 17 November 2026): "Electric Piano" / "Acoustic Piano" become KEYS / PIANO.
8. Manual test (Session Prep, 17 November 2026): Scan speed with Gain staging on (a large session; the 1st Scan of
   new files builds peaks).
9. Checkup of 21 November 2026: the findings, waiting for the user's answer (numbers as given to the user).
   Bugs (fix after a "go", each with a test first):
   - 9.1 Segue (`Setlist.read_cmds`, start) and FX Link (`Link.read_cmds`, start): old `cmd_q` presses run at the
     start; clear `cmd_q` at the start (and in Segue's on_exit), as Chart Cue does.
   - 9.2 MIDI Pilot `Project.update`: File > Open in the same tab not seen (only the pointer); use the file name /
     saved text check as FX Link / Segue.
   - 9.3 SFX Drop loop: spots and a running Find compare only the pointer (use proj + file name); `R.check` not
     cleared on a project switch.
   - 9.4 Chart Cue `Project.remap_pdf` / `remove_from_library`: `P.assign2` not remapped or cleared; also
     `UI.ask_remove_pdf` and `Project.region_use_count` count only PDF 1.
   - 9.5 Chart Cue + Segue `draw_now_view`: the pause bar uses the nearest pause row (also a skipped one): keep
     `sec` in the hold at song_ended. `Setlist.length` counts pauses that never play.
   - 9.6 Chart Cue + Segue `Setlist.next_cmd`: on a REAPER pause it resumes the current song (the Next button goes
     to the next song); press Play only after the setlist's own stop. Fix the Help line too.
   - 9.7 MIDI Pilot `Midi.take_at`: extends the first item over all later items (use the nearest item before t).
   - 9.8 MIDI Pilot `Util.reset_settings`: undocks and jumps to Songs (keep S.dock, S.tab, R.dock_req).
   - 9.9 MIDI Pilot track mode change: `Dev.apply_latency` with latency 0 wipes the user's playback offset (guard
     `d.latency > 0` as in `Dev.use_selected_track`). Channel combo in Settings > Devices does not clear `R.pcs`.
   - 9.10 MIDI Pilot: empty undo points (`Midi.fill_item_starts` in scene_edit, fill_starts, match_* with n == 0).
   - 9.11 FX Link `Link.learn` / `Link.tick`: the knob touched last before Learn is never added (store its value).
   - 9.12 FX Link `UI.draw_picker`: R.pnames of the old group after a group change (keep R.pick_g); changes in the
     0.75 s after a snapshot recall are lost (`Link.snap_tick` calls group_changed).
   - 9.13 Session Prep `Prep.add_chain`: `^%s*<FXCHAIN` also matches `<FXCHAIN_REC` (use `^%s*<FXCHAIN%s*$`).
   - 9.14 Session Prep `Rules.undo`: no `Rules.update_dirty(p)`; undo of a rule rename does not restore tfx / bus
     members / return Out.
   - 9.15 Session Prep `UI.draw_returns`: rename moves `p.sends` on every key (move once at deactivation).
   - 9.16 Session Prep `Prep.apply_rows`: Delete without `row.on`; a Delete row still renamed, put in a folder,
     routed (empty folder stays).
   - 9.17 Session Prep: equal final names in `Prep.plan` (add each row's final name to the used set); the "send
     skipped" count counts rows (`R.loops`); the Pan L / R switch does not call `Rules.changed()`.
   - 9.18 Session Prep: a deleted bus leaves returns with Out "b:<name>" (set them to "m"); a bus named like a
     folder shares `p.fx`.
   - 9.19 SFX Drop `Drop.targets` / `Spots.find_begin`: the Soundcheck region counts as a song (and its tracks).
   - 9.20 SFX Drop `UI.draw_sc`: Source combo enabled during Build; `Sc.build` uses the new source (use `sc.tr`).
   - 9.21 SFX Drop `Chk.run`: Soundcheck items not checked for library files; `Drop.copy_target` reuses a copy by
     name + size only.
   - 9.22 SFX Drop: `Drop.find_folder` needs depth 1 (FX folder made twice); `UI.keys` Enter repeats
     (`IsKeyPressed(..., false)`); Sort by Hit not updated (`Lib.changed()` in `UI.sound_menu` / `Drop.learn`);
     `UI.sort_header` 2-value call not wrapped; `Spots.analyse` labels a region before the selection "Bar 1".
   - 9.23 Mono Merge `Merge.run`: a failed glue leaves the folder depth moved (put it back before DeleteTrack); the
     undo point is made also on a failure; raw path `"\\Mono Merge.lua"`; raw `place_copy` length can be <= 0.
   - 9.24 Per-frame costs: Chart Cue (region_counts, tab strip variants, draw_status parts, mode_hint, cue list
     entries, lib_name_w key), MIDI Pilot (scene strip blocks, scene list rows + sort, Preset list UI.trunc),
     FX Link (picker labels, "Missing" strings, A/B table; UI.trunc_c key without the font, never cleared),
     Session Prep (`r.file_exists` per return per frame), SFX Drop (`Drop.find_folder` in Settings > Insert, tables
     at the chips / headers / copies), Segue (row names cut every frame).
   Saved data (ask): 9.25 FX Link `Project.save`: an empty project still writes "version=1", so Open automatically
   still opens it (write ""). 9.26 Session Prep: the prep mark is the same on client tracks and made tracks, so
   `Prep.find_track` can reuse a client's "Delay" (a "made:" mark).
   Tidy (after a "go"): 9.27 dead code (Chart Cue `UI.button_pair2` now unused, CUE_START twice; Segue and FX Link
   `UI.draw_ask` OK branch; FX Link `R.picked_cache`; Session Prep `t.guid`, `CFG.PEAK_MARGIN`; SFX Drop
   `R.sc_scan.tr/proj`), repeated code and old comments in all scripts.
   Improvements (the user chooses): 9.28 Chart Cue "Close Chart Cue" in the right-click menu while playing, no
   question. 9.29 Chart Cue: a missing PDF during playback keeps the old chart, warning hidden. 9.30 Chart Cue:
   empty-region PDF buttons clickable while playing / locked. 9.31 Chart Cue: blue as the "on" state (Lock, Hide
   panel, Play). 9.32 Segue: no pcall guard around the loop. 9.33 Segue: no "move only by title bar" option.
   9.34 MIDI Pilot "Check new MIDI items" changes the device channel; the Help says the reverse. 9.35 MIDI Pilot:
   no empty / taken check for device, folder, Preset names and control CCs (rule `saved-data`). 9.36 FX Link: the
   same for group names. 9.37 FX Link: a group click changes the track selection and marks the project changed.
   9.38 SFX Drop: a new library folder drops the favourites and own hit points without a question. 9.39 SFX Drop:
   the Soundcheck copy has no sends (in-ears). 9.40 Help text errors in Chart Cue, MIDI Pilot, FX Link, Session
   Prep (orange vs teal Mono button) and SFX Drop.
   Notes (housekeeping): 9.41 `Chart Cue/CLAUDE.md` "6 scripts" -> 7. 9.42 root CLAUDE.md test list: add
   `monomerge.lua`. 9.43 2 commits here and 4 in the global repository are not pushed.
10. Lessons rule (`stale-state`, accepted 17 November 2026): add an "another project" test to Chart Cue, Segue,
    MIDI Pilot and FX Link for the data they keep from a project.
11. Session Prep feedback, not decided yet (17 November 2026): deleting a return does not ask (a bus does); the Prep
    table does not show a row's bus, sends or Track FX (the Help promises "you see everything first").
12. SFX Drop, before its release: Find spots reads at 2000 Hz and Soundcheck at 500 Hz, so cymbal parts count too
    little (found 17 November 2026). Lessons rule (`audio-measure`): its measurements get tests with generated WAV
    files.
13. SFX Drop, before its release: the flaky test "find spots on real tracks" failed once ("a rise at bar 5") in a
    full `test.ps1 -Coverage` run, then passed 3 times (17 November 2026). Find the cause (the WAV peaks not ready
    yet?).
14. Note Detective's manual tests 15-27 are set aside until its next version (decided 23 November 2026). Then
    check which of them are still relevant.
15. Set-aside test (Note Detective, 23 November 2026): click a line (plays), double-click and type, "Change all", Join,
    Split, + Add, Undo, the keys (Up / Down, N, Space, F2, Delete).
16. Set-aside test (Note Detective, 23 November 2026): Write with Markers, Notes track and both; Ctrl+Z; are the text items
    readable for the learner?
17. Set-aside test (Note Detective, 23 November 2026): Finish on a copy: the region, the plugins, the metronome track; Ctrl+Z.
18. Set-aside test (Note Detective, 23 November 2026): a song with no steady tempo, Markers = "About 2 seconds".
19. Set-aside test (Note Detective, lessons, 23 November 2026): Export the song with the 16ths that were 1 16th off and
    open the .mid in Guitar Pro again: on the right 16th now? (The repeated 16ths are still 1 note: not fixed.)
20. Set-aside test (Note Detective, bass review 3, 5, 2, 23 November 2026): right-click a line > New key from here > a
    key: the blue "Key: ..." line, the names after it; Write with Markers and Notes track: the "Key: ..." marker and
    the beat counts ("1 F · 2& Eb") in the text items; Settings > Notes > String names = Numbers, Find notes again.
21. Set-aside test (Note Detective, 23 November 2026): Export > Folder > Change... (a folder of your own), Export; Clear...
    (asks; then Undo and Ctrl+Z); Set tempo on a song with a count-in (bars before bar 1 from the item start); View >
    Tab: click a note, play (the blue note, the line follows); close and reopen the project: the tab is still there.
22. Set-aside test (Note Detective, slides and 8ths / 16ths, 23 November 2026): Set tempo, Find notes on a song with slides
    and pumping 8ths: are the "/G" marks real slides (very short slides are missed)? "C (8ths)" and "8ths: Ab - A"
    right? View > Tab and the .mid: the repeated notes as separate notes? Try Settings > Notes > Slide mark.
23. Set-aside test (Note Detective, 23 November 2026): Simple mode (the default): Find notes, the markers only notes and
    "E (A 7)"-style places; the window without Tempo and bars, Tab and Export. Simple mode off: View > Tab, right-click
    a note (Octave up / down, another string, Delete); Undo. A song that had beat 1 on 4a: on beat 1 now?
24. Set-aside test (Note Detective, tab editing, changed 23 November 2026 by the user's wishes; the user runs the tests):
    stopped, View > Tab: click a note (blue box, the edit cursor goes there); Left / Right = the note before / after;
    Up / Down; type 1 then 2 (fret 12); Delete; double-click a note: its box (Enter = new fret, Left / Right move it,
    never onto another note); click an empty place on a string, type a fret, Enter (not on a 16th that has a note);
    Undo; play: the blue line; "Update the list", then Write.
25. Set-aside test (Note Detective, "1 2 3", 23 November 2026): Simple mode off. Set tempo and Find notes on Burning
    Roads, then "Import tab..." with its .gp: the bass track chosen, bar 1 right at once (bar 5 of the tab on the
    first bass note), Import; the tab
    and the list follow the song; Undo brings the found notes back. Turn off Settings > Notes > Split repeated notes, Find
    notes: no split held notes. A tab with "%" bars (repeat bar): those bars have their notes.
26. Set-aside test (Note Detective, the new detection, 23 November 2026): Find notes on 2-3 songs (Simple mode on and
    off): fast repeated notes (16ths) as separate notes, held notes not cut, the octaves; point at a yellow line: the
    reason; the time of Find notes (song 2: 16 s). A song with a soft part: its notes found too.
27. Set-aside test (Note Detective, Set tempo aligns, 23 November 2026): Find tempo, Set tempo: the notice says how far
    the audio moved; the first bass note sits on a beat (zoom in); the other stems moved with it, other songs and a
    long backing track did not; one Ctrl+Z takes back the grid and the move. With a list: it moved too. In the tab: select the 2nd piece of a split note, press J.
28. Decided 23 November 2026: segment 2c (Note Detective List | Tab) later. The song inside a .gp file (its audio
    and sync points) as the alignment reference: not wanted (the user).
29. Decided 23 November 2026 (Later): the shared alignment test (the tab's first note on the song's first note, empty
    bars and a pickup, a random item position) for Tab Viewer and Note Detective; the user checks Note Detective's
    import for the same error with segment 2c.

## Later

Ideas, not started.

- On hold (do NOT ask until the user brings it up):
  - SFX Drop: Find spots "does not work well with what I had in mind; work on it later" (13 November 2026): ask what
    they expect when they bring it up.
  - MIDI Pilot: own playback offset kept by "Use selected track" with Latency 0 ("skip until i tell you",
    7 November 2026).
  - Session Prep: full run on a real client multitrack (Scan all, Apply, 1x Ctrl+Z, speed) ("skip until i say so,
    don't bring it up", 12 November 2026).
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
  Settings > Notes > "String and fret for high notes" (on by default). Built 23 November 2026 (41 tests; real songs:
  song 1 54 / 57 octaves right, song 2 94%, half of the wrong ones yellow); not looked at on the screen: the user
  decided 23 November 2026 to add more features first, then take the screenshots and test.
  Step 3 approved 23 November 2026: fingering for runs. A row with 4 notes or more: every note gets its string and fret
  from the fewest hand moves over the whole song ("F (D 3) - Eb (D 1) - C (A 3) - Bb (A 1)"); other rows: the step 2
  rule. Settings > Notes > "Fingering for runs" (on by default). Built 23 November 2026 (43 tests; 398 / 410 the same
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
- Note Detective, decided 23 November 2026: slides ("/C", Settings > Notes > Slide mark: "/C", "sl. C", "C (slide)",
  Off; no slides in the 2 songs to measure: generated notes and the user's ear) and the 8th / 16th notes: repeated
  notes split on the 16th grid (only when the project has a tempo marker, e.g. after Set tempo; trial 6d song 2:
  dip + 0.5 x rise >= 4 dB: 47% of the repeats found, 4% of held 16ths split wrongly), separate in the tab and the
  export, and the label "C (8ths)" / "(16ths)" in the markers (Settings switch, on).
- Note Detective, tab review decided 23 November 2026: yes to Dev 3 (right-click a note in the tab: Octave up / down,
  Other string, Delete; saved in the notes), Dev 1 + Bass 3 (an unsure octave from the neighbouring notes; never a
  clear pattern; measured first), Dev 2 (1 fingering for the list and the tab), Dev 5 (a tab hint without a tempo);
  no to the time-aware fingering and open strings. Bug: notes 1 16th early in the tab (beat 1 on 4a). The 8th / 16th
  labels leave the markers (the repeats stay for the tab and export only). Simple mode (Settings > Notes, ON by
  default): the markers show only the notes and the string and fret of high notes; the window hides Tempo and bars,
  View (Tab) and Export. Built 23 November 2026 (60 tests, screenshots checked), deployed, NOT COMMITTED. The octave
  from the neighbours: built, measured (no gain: song 2 902 -> 902-903, song 1 the same), removed.
- Note Detective, decided 23 November 2026: editing the tab while stopped (full mode): click an empty 16th on a
  string, type the fret, Enter (the note lasts until the next one, at most 1 bar); click a note = select (blue box),
  Left / Right = 1 16th, Up / Down = the same pitch on the next string, Delete, digits = a new fret; double-click =
  play from it; right-click = the menu. The play position is a blue line (no note highlight); stopped: a grey line
  at the edit cursor. "Update the list" makes the list again from the notes (asks; Undo). Built 23 November 2026
  (62 tests, screenshots: the selected note, the dashed edit cursor, the blue play line), deployed, NOT COMMITTED.
- Note Detective, decided 23 November 2026 (after trial 7 on song 2): (1) Settings > Notes > Split repeated notes (full
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
  isolated bass. So: isolated bass first, the mix only as a fallback. The separated file starts about 40 ms late.- API name check (not built, the user's choice, 17 November 2026): a generator of the REAPER and ReaImGui 0.9.3
  function names from the test REAPER, so the check reports a wrong function name. Build it only when such a bug
  appears (the `lessons` skill). No maintained ready-made definition files exist.
- Coverage (17 November 2026, `test.ps1 -Coverage`): Chart Cue 27%, Segue 36%, Session Prep 45%, FX Link 51%,
  SFX Drop 56%, MIDI Pilot 57% of the functions (the UI functions count too; the logic tests do not reach them).
- REAPER crashes inside reaper_imgui-x64.dll 0.10.0.5 (offset 0x9fd1c, access violation) when a docked script
  window closes (middle-click on its dock tab) or its dock tab is switched; seen with Chart Cue and MIDI Pilot,
  4 times on 6-7 November 2026. Not in the scripts' code. Workaround: close with the toolbar button. A report for
  the ReaImGui author can be written again from these facts.
- Mono Merge: a drop window (REAPER gfx, no ReaImGui) for 2 files from Explorer.
- SFX Drop: templates, key match, tags, mono check, sub limit, a pink noise / sweep step, cue markers, Move with
  region.
- Session Prep version 2: time alignment of close mics, a measured polarity check, routing / bus templates.
- MIDI Pilot version 2: Record (a real pedal move into Lanes, from the unit's Preset MIDI Out expression messages)
  and Learn, copy Scenes between songs, a check report, a cue sheet, import / export of the names, Looper X
  (CC#48-61) in its own section. Only if a user asks: "Scenes like..." (copy another song's Scenes). The Line 6
  profiles are untested (no units).
- Segue: a thin countdown bar, a UI test for Segue. From the ReaSet changelog: repeat a song N times; region colours
  in the list; a note per song; the next marker / section in the now playing area, with a 2nd thinner progress bar;
  an option that forces an immediate jump when REAPER's smooth seek is on.
- Chart Cue:
  - Guitar Pro files: convert to PDF with MuseScore's command line (optional external program, like Poppler).
  - REAPER forum button in Help > About (disabled until there is a forum thread).
  - No way to show the mode hint again after "Not now".
  - A "Sharper page available" hint after the zoom stays the same (instead of an automatic DPI match).
  - Setlist: "Loop" as a song ending (loops until Next song).
  - Night mode: the page inverted (white notes on black) for very dark stages.
  - Undo for a deleted note.
  - PDF 2: a "(both)" view of the 2 cue lists in the Cues tab, and MIDI CCs for PDF 2.
  - UI scale 100 / 125 / 150 %: the drawn icons already use CFG.UI_SCALE, and the repeated sizes have names in CFG.
    Still needed: the fonts rebuilt between frames, every pixel size in CFG times the scale, and a test of every
    screen at each scale. Ask the user first.
