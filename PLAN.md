# Thunderfork scripts: plan

## Handoff (21 November 2026)

- State: 7 scripts; REAPER 7 ReaScript, Lua 5.4, ReaImGui pinned to 0.9.3 (the shim). Chart Cue is Windows only.

  | Script | Version | State |
  |---|---|---|
  | Chart Cue | 1.7 | released 11 November 2026 |
  | Segue | 1.3.1 | released 11 November 2026 |
  | MIDI Pilot | 1.4 | released 11 November 2026 |
  | FX Link | 1.1.1 | released 11 November 2026 |
  | Session Prep | 1.0.1 | released 17 November 2026 |
  | SFX Drop | 1.0 | committed, not released (hidden with @noindex; the user wants more work first) |
  | Mono Merge | 1.0 | released 17 November 2026 |

- 21 November 2026: the project follows the newest global process (from the Athens Bus project): Size full,
  `LESSONS-RULES.md` loaded by CLAUDE.md, this PLAN.md format, the rules from Claude's memory moved into the
  CLAUDE.md files, a pre-commit hook with the checks and tests. Together with the 19 November 2026 process changes
  (Users section, release checks instead of the global checkup, security review before a push): not committed yet.
- Last checkup: none as 1 full run (17 November 2026: housekeeping and a full Session Prep review).
- More than 3 manual tests are open: no new feature until they are tested (global rule).
- Next decision: the manual tests (Open now 1-9), then the SFX Drop work or the Mono Merge drop window.

## Open now

Answer by number. Manual tests: in question windows, 1 question per test (Passed / Failed / Skip for now); a
skipped or failed test stays here; remove it when it passed.

1. Manual test (MIDI Pilot, 8 November 2026): read the rewritten Help topics and tooltips (Set up songs, Tools
   items, scene list, Lanes, Settings): are they clear? Note the unclear ones.
2. Manual test (Session Prep, 12 November 2026): Mono button on a fake stereo track (grey -> orange on click; Apply
   plays one side; Ctrl+Z undoes it). Skipped twice.
3. Manual test (Session Prep, 12 November 2026): file check: a 44.1 kHz file in a 48 kHz project (or an item that
   starts later) shows an orange "44.1k" / "late" tag in the Prep table.
4. Manual test (Session Prep, 12 November 2026): dual pan: a track in dual pan (or a project whose default pan mode
   is dual pan) with its knobs not at full L / R shows "kept" and keeps its pans after Apply.
5. Manual test (Session Prep, 17 November 2026): Gain staging on, Scan with hi-hat / OH / cymbal tracks: no
   "silent" tag, normal Gain values.
6. Manual test (Session Prep, 17 November 2026): a client's return (no items, receives a send): no "empty" tag, no
   Delete button.
7. Manual test (Session Prep, 17 November 2026): rename a return to empty, then to "Delay" (taken): the old name
   comes back each time.
8. Manual test (Session Prep, 17 November 2026): "Electric Piano" / "Acoustic Piano" become KEYS / PIANO.
9. Manual test (Session Prep, 17 November 2026): Scan speed with Gain staging on (a large session; the 1st Scan of
   new files builds peaks).
10. A first full `checkup` (no full run yet; the release skill covers the checks before a push).
11. Lessons rule (`stale-state`, accepted 17 November 2026): add an "another project" test to Chart Cue, Segue,
    MIDI Pilot and FX Link for the data they keep from a project.
12. Session Prep feedback, not decided yet (17 November 2026): deleting a return does not ask (a bus does); the Prep
    table does not show a row's bus, sends or Track FX (the Help promises "you see everything first").
13. SFX Drop, before its release: Find spots reads at 2000 Hz and Soundcheck at 500 Hz, so cymbal parts count too
    little (found 17 November 2026). Lessons rule (`audio-measure`): its measurements get tests with generated WAV
    files.
14. SFX Drop, before its release: the flaky test "find spots on real tracks" failed once ("a rise at bar 5") in a
    full `test.ps1 -Coverage` run, then passed 3 times (17 November 2026). Find the cause (the WAV peaks not ready
    yet?).
15. MIDI Pilot (19) and FX Link (10) call UI.trunc in the UI loop: check which are in lists (use UI.trunc_c there).
16. Dead code, to remove with the next real change of each script (no version only for this): Chart Cue
    `UI.button_pair`, MIDI Pilot `Dev.free_unit` and `Midi.next_song`, FX Link `CFG.FORM_MAX_W`; also the
    "4 scripts" comments in Chart Cue, FX Link and Session Prep (now 7).

## Later

Ideas, not started.

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
