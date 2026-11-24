# Thunderfork scripts: plan

## Handoff (24 November 2026, night)

- Tab Viewer 1.1 released 24 November 2026: Note Detective is now its Note Detection tab (`Tab Viewer/Notes.lua`,
  `Tab Viewer/NOTES.md`, `tests\notes.lua`), the tab row Tab, Note Detection, Settings, Help; the UI as in Chart Cue
  (decided 24 November 2026): the Note Detection tab has a yellow "Works with bass only" line (no switch: decided 24
  November 2026), a "Song" heading (Key, Tuning, Markers in the label column) and a "Notes" heading with Find notes
  on its line; Settings: foldable sections Tab, Note Detection, Look, Window (ExtState `closed`), labels left. The
  user tested both UI segments (passed). debug-time round before 1.1: only old names fixed.
- Not done (decided by Claude, say if wrong): no saved setting for the open tab (always Tab); a tuning that is not in
  the Notes list (for example Drop A 5-string) imports with Standard's fingering names (the notes and strings are
  right); the old deployed "Note Detective" folder in REAPER's Scripts is still there (outside the repository: delete
  it yourself, or ask me). The version line under Settings is gone.
- Open: Open now 14 (6/8), 15-17 (the manual tests of the Note Detection tab).
- Not fixed (low risk): the speed of a project left with another project tab stays (REAPER has no call for a
  project that is not active); in the reader: 2 voices sharing a tie, tempo automations out of order, a repeat
  without a start mark (uncertain).
- The user's question still open: the stronger fix for the tag `imgui-input` (click rules into plain functions with
  a test; recommended "Later").
- Next: the manual tests 14-17, and the 1.1.1 fix (scroll the whole tab of a song with palm mutes through a repeat).
  Open question: the stronger fix for `edge-case` (3 entries): 1 function for the x of a bar, which gives the drawn
  pass for a bar that is not drawn. Later: chord detection, drums (on
  hold), "Keep their time (move bar lines)".
- Last checkup: 24 November 2026, Tab Viewer only (full, and a 2nd on the later changes). The other scripts: none as
  1 full run yet.

### Other scripts (the facts that still hold from the handoffs before; their history: git)

- Versions: Chart Cue 1.7, Segue 1.3.1, MIDI Pilot 1.4, FX Link 1.1.1 (released 11 November 2026); Session Prep
  1.0.1, Mono Merge 1.0 (released 17 November 2026); SFX Drop 1.0 committed, not released (the user wants more work
  first); Tab Viewer 1.1.1 released 24 November 2026 (1.1.1: the P.M. crash, LESSONS.md) (Note Detective: now its Note Detection tab, never released).
- The checkup of 21 November 2026 (all scripts) stopped before the user's answers: Open now 9.
- The Note Detection tab: the detection stays for now; no more detection work until the user brings it up (decided
  23 November 2026). The Guitar Pro tab is the main feature, the detection the second (decided 23 November 2026).
- More than 3 manual tests open: no new feature in that script.

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
   Notes (housekeeping): 9.41 `Chart Cue/CLAUDE.md` "6 scripts" -> 7.
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
15. Manual test (Tab Viewer, the Note Detection tab, 24 November 2026): the tab row Tab, Notes, gear, "?"; right-click Notes >
    Hide this tab (the Import to list button goes too), the Tabs switches in Settings > Look bring it back; a narrow window: icons.
    Settings: the Notes section. Help: the Notes topics.
16. Manual test (Tab Viewer, Import to list, 24 November 2026): a project with a Guitar Pro tab and the song's bass
    (Find tempo first): Tab tab > Import to list (next to Track): the Note Detection tab opens with the list from the tab;
    again: it asks first; Undo in the Note Detection tab brings the old list back. Write, then Ctrl+Z.
17. Manual test (Tab Viewer, Find notes and the found notes as a tab, 24 November 2026): a song without a tab: Find
    tempo (a track), Set tempo, Note Detection tab > select the bass item > Find notes: the list; the Tab tab shows the found
    notes as a tab from the bar of the first note (the song's bar numbers); click plays; fix a note (stopped): saved
    after a reopen of the project; Import to list takes the fix. Also: Export..., Finish..., Clear... as before.

## Later

Ideas, not started.

- Tab Viewer (moved from Open now at the checkup, 24 November 2026):
  - The song inside a .gp file (its audio and sync points) as the alignment reference: not wanted (the user).
  - Time signature, "Keep their time (move bar lines)" (segment 3; put here by the user, 24 November 2026): the notes
    keep their place in the song and the bar lines move; needs new bars that the file does not have (repeats, fixes,
    line breaks, bar numbers). "Fit into the bar" is built.
  - The alignment test (the tab's first note on the song's first note, empty bars and a pickup, a random item
    position) for Find tempo > From tab (decided 23 November 2026).
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
