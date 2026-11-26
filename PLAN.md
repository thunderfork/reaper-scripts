# Thunderfork scripts: plan

## Handoff (26 November 2026)

- NOT COMMITTED (26 November 2026), all tested: Tab Viewer 1.2 (UI review, toolbar segment 1, Note Detection
  layout, 1 mode, .gp5 export; manual tests passed 25-26 November 2026); tools (`check.ps1` only the changed scripts,
  pass stamps `tools\stamp.ps1`); process and skills audits; housekeeping (no script counts in the notes, old Note
  Detective entries removed). Next: commit and release Tab Viewer 1.2 when the user asks; then the toolbar segments
  2 and 3 (Later > Tab Viewer).
- Open decisions (the user's): the detection (a measuring tool on 5-8 stems with tabs, "Use a MIDI item", or stop;
  NOTES.md); chord and guitar detection (asked 25 November 2026: chords medium, guitar notes hard; 3 questions open:
  what guitar detection means, what audio, where the chord names go). Not wanted: a real tab editor.
- Lessons: stronger fixes to propose: `stale-state` (5 entries), `imgui-input` (recommended "Later"), `edge-case` (1
  function for the x of a bar).
- Decided by Claude (say if wrong): the open tab is not saved (always Tab); a tuning not in the Notes list imports
  with Standard's names; the old deployed "Note Detective" folder in REAPER's Scripts is still there (delete it).
  Not fixed (low risk): the speed of a project left in another project tab; in the reader: 2 voices sharing a tie,
  tempo automations out of order, a repeat without a start mark.
- Versions: Chart Cue 1.7, Segue 1.3.1, MIDI Pilot 1.4, FX Link 1.1.1, Session Prep 1.0.1, Mono Merge 1.0, Tab Viewer
  1.1.1; SFX Drop 1.0 committed, not released (more work first). The checkup of 21 November 2026 (all scripts) stopped
  before the user's answers: Open now 9.
- Last checkup: 24 November 2026, Tab Viewer only. The other scripts: none as 1 full run yet.

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
14. Manual test (Tab Viewer, 6/8 and Set tempo, 24 November 2026): in the tab with your 6/8 bars, Find tempo > From
    tab, then Set tempo: REAPER's tempo changes to 93.75 at the first 6/8 bar and back to 125 after the last one; the
    tab stays on the music while it plays. (REAPER counts the tempo in quarter notes: not checked with a 6/8 tab.)
19. Real files for the reader (Dev 5 of the developer review, decided 24 November 2026): 1 real .gpx, .gp3 and .gp4
    file each (none found in Documents, Downloads, Desktop, Music). Tell me where they are; Claude checks them on your
    computer only (never in git), as the `file-format` rule says. Skipped by the user 25 November 2026 (for later).

## Later

Ideas, not started.

- Tab Viewer, the toolbar (decided 25 November 2026; segment 1 built): segment 2 = loop (the selected bar or the bar
  at the cursor / the selected line; on = the look of a selected toggle, not blue), REAPER's metronome and count-in
  (2 buttons, REAPER's state; a trial of REAPER's actions first); segment 3 = transpose 0 +/- (the tab's frets and the
  list's note names, not the audio; saved in the project, 1 value, nothing at 0: a new project key; below the open
  string: the next lower string, on the lowest an octave up, yellow). All work in both tabs; narrow: 2 rows. Ask
  before each segment.
- Tab Viewer: the Guitar Pro tab is the main feature, the detection the second; no more detection work until the
  user brings it up (decided 23 November 2026).
- Tab Viewer (moved from Open now at the checkup, 24 November 2026):
  - The song inside a .gp file (its audio and sync points) as the alignment reference: not wanted (the user).
  - Time signature, "Keep their time (move bar lines)" (segment 3; put here by the user, 24 November 2026): the notes
    keep their place in the song and the bar lines move; needs new bars that the file does not have (repeats, fixes,
    line breaks, bar numbers). "Fit into the bar" is built.
  - From the developer review of 24 November 2026 (Dev 3 and Dev 6, "later", decided 24 November 2026): (Dev 3) 1
    small trial: does REAPER's undo bring back the project data (ProjExtState) written inside an undo block? If yes,
    the tab fixes and the Note Detection list use REAPER's undo (also after a close; the Undo buttons stay). (Dev 6)
    the tab logic (layout, repeats, rhythm, fixes) into its own file, as Tempo.lua: only when the tab view in Chart
    Cue starts (roadmap step 8). (Dev 4, "later", decided 24 November 2026) 1 project watcher: Tab Viewer's
    `Project.update` tells the Note Detection tab, so the order (its list first, then the tab) is in code, not in a
    comment (`stale-state`).
  - From the full simplify run of 24 November 2026 (skipped: larger, or a change of behaviour): Notes' `Project.save`
    does not update its `R.state_cc` (with Dev 4). Later, each small: "play from" 3 times (`UI.play_at`,
    `UI.play_from`, `Tempo.try`), "is it an audio take" 5 times, the start of `GP.tab` copied in `Imp.found_doc`
    (the 16th count rule twice), `Tabs.start_qn` and text sizes measured every frame, the P.M. runs scanned per line,
    the `R.doc.found` special cases (with Dev 6).
  - From the checkup of 24 November 2026 (larger changes, each a segment; ask first): note places as whole numbers
    (48 per beat); a cached copy of the file's tab, so a fix rebuilds only its bar.
- On hold (do NOT ask until the user brings it up):
  - SFX Drop: Find spots "does not work well with what I had in mind; work on it later" (13 November 2026): ask what
    they expect when they bring it up.
  - MIDI Pilot: own playback offset kept by "Use selected track" with Latency 0 ("skip until i tell you",
    7 November 2026).
  - Session Prep: full run on a real client multitrack (Scan all, Apply, 1x Ctrl+Z, speed) ("skip until i say so,
    don't bring it up", 12 November 2026).

- API name check (not built, the user's choice, 17 November 2026): a generator of the REAPER and ReaImGui 0.9.3
  function names from the test REAPER, so the check reports a wrong function name. Build it only when such a bug
  appears (the `lessons` skill). No maintained ready-made definition files exist.
- Coverage (17 November 2026, `test.ps1 -Coverage`): Chart Cue 27%, Segue 36%, Session Prep 45%, FX Link 51%,
  SFX Drop 56%, MIDI Pilot 57% of the functions (the UI functions count too; the logic tests do not reach them).
- REAPER crashes inside reaper_imgui-x64.dll 0.10.0.5 (offset 0x9fd1c, access violation) when a docked script
  window closes (middle-click on its dock tab) or its dock tab is switched; seen with Chart Cue and MIDI Pilot,
  4 times on 6-7 November 2026. Not in the scripts' code. Workaround: close with the toolbar button. A report for
  the ReaImGui author can be written again from these facts.
- The roadmap of each script: the "Later" section of its folder CLAUDE.md (moved 24 November 2026).
