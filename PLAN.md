# Thunderfork scripts: plan

## Handoff (27 November 2026)

- Session 27 November 2026, Tab Viewer, all committed and backed up, not released: the repeat fix (passes = the
  highest ending; LESSONS.md, Open now 21); < > as icons and the Time signature window tidied; the user's Detection
  feedback (decided 27 November 2026): a click on a line plays from it, the toolbar's Loop loops the line; Clear and
  Delete red next to Join...; Export in place of More...; Done: clean up merged into Write (the list stays; region
  only for a bass item song, region songs keep their names; Settings: Write removes the bass plugins / deletes the
  metronome track, both off); all windows in the middle, fixed; the Bar column from the song (Settings: Bar
  numbers). Open Tab Viewer tests: 3 (20, 21, 22): no new Tab Viewer feature until they are tested. Paused: the
  progress bars (23). Unanswered: making "never search my folders" global (24).

- New workflow (decided 26 November 2026): an automatic commit after each finished change (its checker, tests and
  deploy passed); at each handoff a push to the private `reaper-scripts-backup` (remote `backup`, no checks, GitHub
  Actions off there); the public repository only at a release (all checks and tests). The public `work` branch
  was deleted. The old commits with the personal email address (2-17 November 2026) stay in the public history
  (the user's choice, 26 November 2026: no history rewrite); so the backup gets main only, no tags (GitHub refuses
  the tag v1.7).
- Release (26 November 2026): Tab Viewer 1.2 (the toolbar as in Guitar Pro: size, Transpose | transport | speed,
  Metronome, REAPER's Count-in with the count over the tab, Loop; Ctrl+wheel size; short Help and tooltips; the
  Detection changes), and the clean-ups of Chart Cue 1.7.1, FX Link 1.1.2, MIDI Pilot 1.4.1 (the File > Open fix;
  its manual test still Open now 10) and Session Prep 1.0.2. The Ctrl+wheel "keep the line under the mouse" failed
  twice and was removed (the user's choice; LESSONS.md).
- After the release, committed, not released (tested by the user, 26 November 2026): Tab Viewer's "+" makes a note
  shorter and "-" longer (as Guitar Pro); the dots right of the stem (over the beams, right of flags); bolder rests,
  beams and flags; the Loop icon as REAPER's 2 arrows.
- Committed, not released: Tab Viewer's songs (decided 26 November 2026: a song = a region, else a bass item; 1
  Detection list and 1 tempo per song; between songs the last stays; older Detection lists are lost, no migration;
  manual test passed 27 November 2026). After a UI/UX review the user chose "A" (26 November 2026): each section's
  button at the right of its heading, "Song" section renamed "Bass", Settings > Detection > Follow the song (on);
  the bottom bar was removed. The song header band of "A" was not liked; replaced by a plain Song row (option 2,
  decided 27 November 2026: "Song" [dropdown] [<] [>], its frame flashes when it follows the cursor; Open now 20).
  Claude's choice: Write stays in the bottom row of the list. Not built (the user's choice): a mark over the active
  song in REAPER, a warning before a list is replaced; later maybe the songs overview ("B"). All of it goes into the
  next Tab Viewer release (1.3: a new feature).
- Open decisions (the user's): the detection (a measuring tool on 5-8 stems with tabs, "Use a MIDI item", or stop;
  NOTES.md); chord and guitar detection (asked 25 November 2026: chords medium, guitar notes hard; 3 questions open:
  what guitar detection means, what audio, where the chord names go). Not wanted: a real tab editor.
- Versions: Chart Cue 1.7.1, Segue 1.3.1, MIDI Pilot 1.4.1, FX Link 1.1.2, Session Prep 1.0.2, Mono Merge 1.0, Tab
  Viewer 1.2; SFX Drop 1.0 committed, not released (more work first). The findings of the checkup of 21 November 2026:
  "Open findings" in each folder CLAUDE.md (moved by the user's choice, 26 November 2026).
- Last checkup: 24 November 2026, Tab Viewer only. The other scripts: none as 1 full run yet.

## Open now

Answer by number. Manual tests: in question windows, 1 question per test (Passed / Failed / Skip for now); a
skipped or failed test stays here; remove it when it passed.

1. Manual test (Session Prep, 12 November 2026): Mono button on a fake stereo track (grey -> orange on click; Apply
   plays one side; Ctrl+Z undoes it). Skipped twice.
6. Manual test (Session Prep, 17 November 2026): rename a return to empty, then to "Delay" (taken): the old name
   comes back each time.
8. Manual test (Session Prep, 17 November 2026): Scan speed with Gain staging on (a large session; the 1st Scan of
   new files builds peaks).
10. Manual test (MIDI Pilot, 26 November 2026): with MIDI Pilot open in a project with devices, File > Open another
    project in the same tab: MIDI Pilot shows that project's own devices and tracks (none for a new one); back in
    the first project, its devices are still there. File > Save as keeps them.
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
20. Manual test (Tab Viewer, the Song row, 27 November 2026): the row at the top of the Tab and Detection tabs looks
    like the Tab and Track rows; the dropdown and < > (now drawn icons, also on Start and Bar 1) go to a song (grey
    while playing); its frame flashes blue when the edit cursor moves into another song. The Time signature window
    (right-click a bar): tidier, + / - half buttons next to the beats.
21. Manual test (Tab Viewer, repeats, 27 November 2026): Sun plays and shows the 3rd ending (bar 106); a "1. 3." /
    "2. 4." repeat plays 4 times (LESSONS.md, fixed, not confirmed).
22. Manual test (Tab Viewer, Detection, 27 November 2026): a click on a line plays from it; Loop (toolbar) on: the
    clicked line loops, Loop off: REAPER's repeat as before; Delete and Clear... red next to Join, Clear asks;
    Export... at the bottom right; Write makes the song region (a bass item song; your region names stay) and the
    list stays; Settings > Detection: the 2 Write switches and Bar numbers; the windows stay in the middle.
23. Paused (the user's choice, 27 November 2026): the Find tempo / Find notes progress bars in a bottom bar. The
    user explains what they mean by the bottom toolbar first.
24. Make this rule global? "Never search my folders for files. When you need a file of a kind, ask me to provide
    it." (asked 27 November 2026; project rule already): Yes / Project only / No.

## Later

Ideas, not started.

- Tab Viewer: its ideas (the toolbar segments 2 and 3 first) are in "Later" of `Tab Viewer/CLAUDE.md` (moved there
  26 November 2026; decided 23-25 November 2026: the toolbar, the tab first and no more detection work until the
  user brings it up, the developer review items "later").
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
- Per script, when its development starts again (decided 26 November 2026, review R1, R3, R4): its "Open findings"
  bugs (folder CLAUDE.md; 4 need the user's behaviour choice: C5 + S4 Next song after a REAPER pause, P8 a deleted
  bus, P9 a bus named like a folder, M3 on hold); SFX Drop's WAV tests and flaky test (Open now 12, 13); split
  Chart Cue and MIDI Pilot into several files at their next large change.
