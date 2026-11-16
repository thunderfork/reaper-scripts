# Thunderfork scripts: plan (state on 17 November 2026)

## Context
- 6 scripts, each in its own folder (details in each folder's CLAUDE.md; the rules in the root CLAUDE.md):

  | Script | Version | State |
  |---|---|---|
  | Chart Cue | 1.7 | released 11 November 2026 |
  | Segue | 1.3.1 | released 11 November 2026 |
  | MIDI Pilot | 1.4 | released 11 November 2026 |
  | FX Link | 1.1.1 | released 11 November 2026 |
  | Session Prep | 1.0 | committed, not pushed or released |
  | SFX Drop | 1.0 | committed, not released (hidden with @noindex) |

- REAPER 7 ReaScript, Lua 5.4, ReaImGui pinned to 0.9.3 (the shim). Chart Cue is Windows only.

## Session handoff (16-17 November 2026)
- Done and committed (17 November 2026, commit only): housekeeping (PLAN.md tidy, docs check reads all folder CLAUDE.md files, SFX Drop hidden with
  @noindex and in README); the self-improvement routine (`lessons` skill, LESSONS.md); the process work: 1 script
  list `tools\scripts.psd1` read by all tools, the publish check + pre-push hook (core.hooksPath set on this
  computer), the session-start hook, the open manual tests moved here from the memory, a branch for each new script.
  The SFX Drop header changed, but SFX Drop stays 1.0 and unreleased.
- 17 November 2026: Session Prep full review (engineer, debug, programmer, UI/UX): 7 fixes (hi-hat read silent,
  exact peak, client return not "empty", Apply after File > Open, return names, Electric / Acoustic Piano, Rules tab
  speed) with 5 new tests (45 passed); the coverage map and the ImGui balance check. Committed (commit only).
- Not pushed: 5 earlier commits (Session Prep 1.0, SFX Drop 1.0 and docs). Note for the Session Prep release:
  Session Prep.lua changed after the commit where 1.0 first appears, so ReaPack would link 1.0 to the old file: the
  release needs a new number (1.0.1, or 1.1) (the release skill, step 0). The publish check stops a push until
  Session Prep is released (Released = $true, the release skill) or hidden. Next decision: commit, and push with the
  Session Prep 1.0 release?

## Open manual tests
Give them in question windows, 1 question per test (Passed / Failed / Skip for now); a skipped or failed test stays
here; remove a test when the user reports it passed.

- MIDI Pilot (2026-11-08): read the rewritten Help topics and tooltips (Set up songs, Tools items, scene list, Lanes,
  Settings): are they clear? Note the unclear ones.
- Session Prep (2026-11-12): Mono button on a fake stereo track (grey -> orange on click; Apply plays one side;
  Ctrl+Z undoes it). Skipped twice.
- Session Prep (2026-11-12): file check: a 44.1 kHz file in a 48 kHz project (or an item that starts later) shows
  an orange "44.1k" / "late" tag in the Prep table.
- Session Prep (2026-11-12): dual pan: a track in dual pan (or a project whose default pan mode is dual pan) with
  its knobs not at full L / R shows "kept" and keeps its pans after Apply.

- Session Prep (2026-11-17): Gain staging on, Scan with hi-hat / OH / cymbal tracks: no "silent" tag, normal Gain values.
- Session Prep (2026-11-17): a client's return (no items, receives a send): no "empty" tag, no Delete button.
- Session Prep (2026-11-17): rename a return to empty, then to "Delay" (taken): the old name comes back each time.
- Session Prep (2026-11-17): "Electric Piano" / "Acoustic Piano" become KEYS / PIANO.
- Session Prep (2026-11-17): Scan speed with Gain staging on (a large session; the 1st Scan of new files builds peaks).

On hold (do NOT ask until the user brings it up):
- SFX Drop: Find spots "does not work well with what I had in mind; work on it later" (2026-11-13): ask what they
  expect when they bring it up.
- MIDI Pilot: own playback offset kept by "Use selected track" with Latency 0 (said "skip until i tell you", 2026-11-07).
- Session Prep: full run on a real client multitrack (Scan all, Apply, 1x Ctrl+Z, speed) (said "skip until i say
  so, don't bring it up", 2026-11-12).

## Open items (all scripts)
- Lessons rule (stale-state, accepted 17 November 2026): add an "another project" test to Chart Cue, Segue, MIDI Pilot
  and FX Link for the data they keep from a project.
- Session Prep feedback, not decided yet (17 November 2026): deleting a return does not ask (a bus does); the Prep
  table does not show a row's bus, sends or Track FX (the Help promises "you see everything first").
- SFX Drop (17 November 2026, found in the Session Prep round): Find spots reads at 2000 Hz and Soundcheck at 500 Hz,
  so cymbal parts count too little. Look at it before the SFX Drop release (with Find spots). Lessons rule
  (audio-measure): its measurements get tests with generated WAV files.
- MIDI Pilot (19) and FX Link (10) call UI.trunc in the UI loop: check which are in lists (use UI.trunc_c there).
- Flaky test (17 November 2026): SFX Drop "find spots on real tracks" failed once ("a rise at bar 5") in a full
  `test.ps1 -Coverage` run, then passed 3 times. Find the cause (the WAV peaks not ready yet?) before the SFX Drop release.
- API name check (not built, the user's choice, 17 November 2026): a generator of the REAPER and ReaImGui 0.9.3
  function names from the test REAPER, so the check reports a wrong function name. Build it only when such a bug
  appears (the lessons routine, step 4). No maintained ready-made definition files exist.
- Coverage (17 November 2026, `test.ps1 -Coverage`): Chart Cue 27%, Segue 36%, Session Prep 45%, FX Link 51%,
  SFX Drop 56%, MIDI Pilot 57% of the functions (the UI functions count too; the logic tests do not reach them).
- REAPER crashes inside reaper_imgui-x64.dll 0.10.0.5 (offset 0x9fd1c, access violation) when a docked script
  window closes (middle-click on its dock tab) or its dock tab is switched; seen with Chart Cue and MIDI Pilot, 4 times
  on 6-7 November 2026. Not in the scripts' code. Workaround: close with the toolbar button. A report for the
  ReaImGui author can be written again from these facts.
- Dead code, to remove with the next real change of each script (no version only for this): Chart Cue
  `UI.button_pair`, MIDI Pilot `Dev.free_unit` and `Midi.next_song`, FX Link `CFG.FORM_MAX_W`; also the "4 scripts"
  comments in Chart Cue, FX Link and Session Prep (now 6).
- Template for all scripts: "+ Add" = ghost button on the heading line, its menu drops down below it; empty lists
  = 1 grey line "No ... yet. <what to do>."; yellow only for real warnings.

## SFX Drop 1.0 (new, 12-13 November 2026): committed, not released (the user wants more work first)
- The 6th script (`SFX Drop/`, tests `tests\sfxdrop.lua`). A preparation tool: sound effects from a
  library on the beat (hit points: start of the sound / loudest point; own hit point, Learn from the moved item).
- Decisions: name SFX Drop; tabs Sounds, Spots, Soundcheck + Settings + Help; preview with SWS, hidden without;
  1 track per type in an "FX" folder. Saved data (approved): ExtState "SFX Drop" keys (also fx_out, vary),
  `Data\SFX Drop\library.txt`, ProjExtState "SFX Drop"/"soundcheck".
- Built and tested by the user (13 November 2026, all manual tests passed): library, insert, Nearest bar line,
  preview, learn; favourites; Riser length (a filter + a Bars column); Levels (LUFS / Peak per type); column sort;
  Copy into the project (Warn above 500 MB, Clean up); scan Pause / Stop; Spots tab; Soundcheck tab (areas from quiet
  to loud, impacts zone, Find areas plan); Check the show; FX output; Soundcheck from a folder; Vary. 2 debug rounds.
- Known limit: a very long file can pause the window for a moment in the first scan (REAPER builds its peaks).
- On hold: Find spots "does not really work well with what I had in mind" (ask what the user expects, when they
  bring it up).
- Later ideas: templates, key match, tags, mono check, sub limit, a pink noise / sweep step, cue markers, Move with
  region.

## Session Prep 1.0 (new, 12 November 2026): committed (bcf85f1), not pushed or released
- The 5th script (`Session Prep/`, tests `tests\sessionprep.lua`). A preparation tool for a client's
  multitrack: Scan / Scan all (in steps) and a preview table; Apply with 1 undo point and a prep mark per track.
- Tabs: Prep (names, folders, note tags, gain, polarity, pan / width, M / S), Rules (rules grouped by folder, drag
  rules and folders; presets with Save, Save as, More: Rename, Export, Import, Revert, Reset, Delete; Undo per
  section), FX Chains (Folder FX, Track FX), Buses (routed bus tracks: Instrument / Vocal / Lead / + Bus; FX returns
  with source, level and output). Settings: Appearance, Prep (Tracks, Routing, Checks), Gain staging, Window.
- Engineering (approved in 3 review rounds): industry names and order (Kick In, Out, Sub; drums first, "Vocals
  first" preset), client pans kept, disarm, Other folder off the master, file check, one-sided level, own returns
  and buses only (prep mark), loop guard, overdubs join their folder, a later return joins FX Returns.
- Saved data (approved): ExtState "Session Prep" keys and presets (`preset_N`, `preset_orig_N`, `preset_saved_N`);
  in the project only the track mark `P_EXT:SessionPrep`.
- Tested in REAPER by the user: everything except the open manual tests (Mono, dual pan, file check; the full run
  on a real multitrack is on hold). Next: push and release 1.0 (tag `sessionprep-v1.0`).
- Version 2 ideas: time alignment of close mics, a measured polarity check, routing / bus templates.

## FX Link
- Released: 1.0 (11 November 2026, the 4th script), 1.1 / 1.1.1 (11 November 2026).
- Possible issue to watch: plugins that show meters as parameters (they would link and show "differ"); the
  workaround is All except.
- Known limit (as Chart Cue): File > New project in the same tab over a never-saved project is not seen.

## MIDI Pilot (MIDI editor for amp modelers: Quad Cortex, mini, Line 6 Helix / HX; since 6 November 2026)
- Released: 0.1.1 and 0.1.2 (7 November), 1.0 (8 November), 1.0.1, 1.1 (9 November), 1.2, 1.3 (10 November),
  1.4 (11 November 2026). The full history is in the git log and the @changelog lines.
- Not checked: the full-size Quad Cortex's USB port name (no unit; it contains "Cortex"). The Line 6 profiles are
  untested (no units).
- Version 2: Record (a real pedal move into Lanes, from the unit's Preset MIDI Out expression messages) and Learn,
  copy scenes between songs, a check report, a cue sheet, import / export of the names, Looper X (CC#48-61) in its
  own section. Later, only if a user asks: "Scenes like..." (copy another song's scenes). Not planned: live /
  show-time features (MIDI Pilot is a preparation tool).

## Segue (the setlist script, since 4 November 2026)
- Released: 0.1 (5 November), 1.0 and 1.1 (7 November), 1.2 (10 November), 1.2.1, 1.3 / 1.3.1 (11 November 2026).
- Ideas, not planned: a thin countdown bar, a UI test for Segue.
- Ideas from the ReaSet changelog (not planned): repeat a song N times; region colours in the list; a note
  per song; the next marker / section in the now playing area, with a 2nd thinner progress bar; an option
  that forces an immediate jump when REAPER's smooth seek is on (Continue to a song that is not next on the
  timeline).

## Chart Cue: history (short)
- Pre-release (v4.6–4.8): async PDF engine and cache, Record cues, scroll mode per project, keep last page, Cues tab,
  one Settings tab, inline confirmations, cue field validation, sticky messages, REAPER actions via ExtState "cmd_q".
- 1.0 (2 November 2026): first public version (ReaPack and GitHub Release).
- 1.1 (3 November): UI review, tests in the portable test REAPER, toolbar groups, cue list rework, own resize edges.
- 1.2 (3 November): data in REAPER\Data\Chart Cue; repository renamed to thunderfork/reaper-scripts.
- 1.3 (4 November): 2 PDFs per song (split view), page layouts, slide-in page turn, Library tools.
- 1.4 / 1.4.1 (4 November): Setlist tab, notes on the pages, page-turn countdown, Settings in 5 sections, Shortcuts.
- 1.5 / 1.5.1 / 1.5.2 / 1.5.3 (5-7 November): images, marker list, 3-band setlist view, armed exact stop, centred
  questions, Light / Dark theme. From 1.5.2 on Segue and MIDI Pilot get their own GitHub Releases.
- 1.6 (10 November): uniform Settings order, Window and Backup sections, friendlier Help (also Segue, MIDI Pilot).
- 1.7 (11 November): no PDF of another project; "+ Add" template; Delete / F2 / row menus; Ctrl+Z to REAPER.

## Release checklist (Chart Cue; do before sharing a new version)
1. Version: @version and CFG.VERSION are equal; @changelog has 1–3 user-facing lines.
2. Start: Chart Cue starts without errors; the last tab and the open Settings section come back.
3. Project data: set a mode, Seconds, "Turn pages", "Scroll", a PDF; close and open Chart Cue, then save, close and reopen the project: all values come back.
4. Save as: "Save as" keeps Chart Cue open with the same data; File > Open of another project in the same tab loads that project's data (or closes Chart Cue with "Close with project").
5. Project tabs: switch between 2 open projects; each shows its own library and cues.
6. PDFs: add a PDF and a folder; copy into the project; replace a PDF (same name, and "Replace PDF..."); relocate a missing PDF. Use a Greek folder and file name with spaces and an apostrophe.
7. Engines: open a PDF with the Windows engine and with Poppler; clear the page cache while a PDF is open.
8. Regions: rename, move, undo, save and reopen: the PDF assignment stays. "Keep last page" during playback in a region without a PDF; the page can be turned.
9. Cues: record page turns and scroll points (Record on and off, Lock on); "+ below" and "Use current view" (also on the Start row); Undo and Ctrl+Z; switch Beats / Seconds; a wrong value shows a red border; Scroll Smooth / Jump.
10. Markers: PDFPAGE / PDFSCROLL markers scroll the page; "Remove PDF markers..." asks first and Ctrl+Z brings them back.
11. Control: keys (window active); the 4 actions (window not active, also in lock mode), and Assign... in Settings > Control; MIDI absolute and relative; MIDI page turns and cue buttons; every right-click menu.
12. Stage: performance mode on / off (also with Page area Setlist); lock; hide panel when playing; page brightness (slider and toolbar button); page-turn countdown; notes (add, drag, edit, colour, size).
13. Setlist: make, reorder (drag, arrows, menu), skip, remove and undo, pauses, Stop / Continue (adjacent and far songs), play buttons, Next song action, Lock setlist, Page area Setlist and Setlist and PDF, duplicate with a pause, another project.
14. Window: dock and undock (menu); resize the floating window at each edge and the corner; collapse and open; hide tabs and toolbar items.
15. Large set: a 300-page PDF and a project with 30 regions: start time, page cache size and limit, smooth playback.
16. Automatic tests: `.\tools\test.ps1` ("0 failed") and `.\tools\ui-test.ps1` ("no errors").

## Chart Cue: future consideration (not planned)
- Guitar Pro files: convert to PDF with MuseScore's command line (optional external program, like Poppler).
- REAPER forum button in Help > About (disabled until there is a forum thread).
- No way to show the mode hint again after "Not now".
- A "Sharper page available" hint after the zoom stays the same (instead of an automatic DPI match).
- Setlist: "Loop" as a song ending (loops until Next song); skipped in 1.4.
- Night mode: the page inverted (white notes on black) for very dark stages.
- Undo for a deleted note.
- PDF 2: a "(both)" view of the 2 cue lists in the Cues tab, and MIDI CCs for PDF 2 (not in 1.3).
- UI scale 100 / 125 / 150 %: the drawn icons already use CFG.UI_SCALE, and the repeated sizes have names in CFG. Still needed: the fonts rebuilt between frames, every pixel size in CFG times the scale, and a test of every screen at each scale. Ask the user first.
