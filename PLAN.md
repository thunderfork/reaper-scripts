# Thunderfork scripts: plan (state on 7 November 2026)

## Context
- File: `Chart Cue/Chart Cue.lua`, public version 1.5.2. Chart Cue's data (settings.ini, page cache, tmp, autostart.lua, guide) is in REAPER\Data\Chart Cue since 1.2. REAPER 7 ReaScript, Lua 5.4, ReaImGui API pinned to 0.9.3 through the ReaTeam shim. Windows only.
- Modules: CFG, S (settings.ini), R (runtime), COL, P (project config in the .rpp ExtState "ChartCue"/"cfg"), Util, PDF, Project, Nav, Midi, UI, Cues, Notes, Setlist, Pane, Msg, Dock, Autostart.
- Layout system: UI.form / UI.field / UI.button_pair / UI.full_button, CFG.SP + UI.sp, one control height UI.h, one text rule CFG.TEXT_LIFT. Compact layout is the default.
- Constraints:
  - No users yet: no code for earlier development versions. Ask before a change to the .rpp ExtState format, the settings keys, the cache folder layout or the __startup.lua markers. New keys get defaults and are written only when they differ from them ("Save as" detection). The old keys tab_ver, sl_view, fixed_start, continue_after_end and scroll_mode=fixed were removed on 5 November 2026.
  - Keep every disk or long operation non-blocking.
  - Every Push needs a Pop. Call End only when Begin returned true.
- Working rules from the user:
  - Make small passes. The user tests each pass in REAPER and approves it before the next pass.
  - Do not remove a control without approval. List it first.
  - Write the help texts in plain, simple English, and update HELP_TOPICS with each change.
  - Keep @changelog to 1–3 user-facing lines.

## History (short)
- Pre-release (v4.6–4.8): async PDF engine and cache, Record cues, scroll mode per project, keep last page, Cues tab, one Settings tab, inline confirmations (UI.ask), cue field validation, sticky messages, Fixed speed and "Continue after region end" removed, REAPER actions via ExtState "cmd_q".
- 1.0 (2 November 2026): first public version (ReaPack and GitHub Release).
- 1.1 (3 November 2026): UI review (gear tab, welcome, Settings sections, Help About / Send feedback, SWS and "This computer" labels removed); tests in the portable test REAPER; toolbar in 3 groups with drawn icons and a "Hide controls when playing" button; Autoscroll "Scroll" Smooth / Jump (P.scroll_jump, written only when on); cue list: full-width rows, click = edit cursor, Start row, "Use current view", "+ below", bar with Record / + Page turn / + Scroll point / Undo (own snapshot stack, Ctrl+Z), messages in the title line; panel grip double-click 40% <-> 60%; floating window: own resize edges and corner grip, full size kept while collapsed; right-click menus (toolbar / page, Library / Regions / Cues rows), "Replace PDF..."; page brightness minimum 25%; tools moved to `tools\`.
- 1.2 (3 November 2026): settings and page cache moved to REAPER\Data\Chart Cue (no migration: no other users yet); autoscroll mode locked during playback (text in both toolbars); repository renamed to thunderfork/reaper-scripts, ReaPack name "Thunderfork Scripts"; index workflow fixed (CMake 4, pinned runner).
- 1.3 (4 November 2026): 2 PDFs per song (split view, PDF 1 / PDF 2 in Regions, own cues, active part; design: panes, module Pane); pages on screen (1, side by side with Rolling / Book, continuous) and the slide-in page turn; Display > Page layout (now Viewer > Page layout); Library: Add from folder remembers the folders, Sync, Remove unused PDFs, Sort: Unused first, Replace PDF; right-click menus; Redo; bold row labels; one standard button width; panel fit to sections; fixes (region PDF at playback start, empty dropdown text, clicks during playback, double flash, odd last page).
- 1.4 (4 November 2026): Setlist tab (show order, Stop / Continue, timed pauses, several setlists, lock, undo, right-click menu, play buttons, "Next song" action, Page area: PDF / Setlist / Setlist and PDF, "Next: ..." label); notes on the pages (colour and size per note); page-turn countdown (also before the next song); toolbar and tab items can be hidden; brightness button; Settings in 5 sections (Viewer, Playback, Control, Appearance, General); Shortcuts and external controls (Assign...); page cache limit (1 GB); "debug time" review skill (.claude/skills/debug-time).
- 1.4.1 (4 November 2026): code clean-up with no visible change: the toolbar is built again only when it changes (R.tb_cache); the PDF 1 / PDF 2 cue list choice is always set back (Cues.with_part); named sizes in CFG and CFG.UI_SCALE for the icons; the UI test is in tools.
- 1.5 (5 November 2026): PNG / JPG images (Add PDF only); the marker list in the cue-list layout, with Record, the add buttons, the marker colour and Copy cues into markers; the 3-band setlist view; the armed exact stop; tab icons and 2-line rows when narrow; numpad zoom; the Segue conflict command. Segue 0.1 released with it.
- 1.5.1 (5 November 2026): clean-up with no visible change: the old keys tab_ver, sl_view, fixed_start, continue_after_end and scroll_mode=fixed removed; housekeeping skill; .gitattributes keeps LF.
- 1.5.2 (7 November 2026): questions in a centred window (UI.draw_ask_popup); tooltips with a 0.5 s delay and wrapped
  lines; right-click menus on the panel, the tabs and the toolbar items ("Hide ..."); the Sync folder dropdown.
  Released with Segue 1.0 and MIDI Pilot 0.1.1. From now on Segue and MIDI Pilot get their own GitHub Releases too
  (tags segue-vX.Y, midipilot-vX.Y).

## Release checklist (do before sharing a new version)
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

## Future consideration (not planned)
- Guitar Pro files: convert to PDF with MuseScore's command line (optional external program, like Poppler).
- REAPER forum button in Help > About (disabled until there is a forum thread).
- No way to show the mode hint again after "Not now".
- A "Sharper page available" hint after the zoom stays the same (instead of an automatic DPI match).
- Setlist: "Loop" as a song ending (loops until Next song); skipped in 1.4.
- Night mode: the page inverted (white notes on black) for very dark stages.
- Undo for a deleted note.
- PDF 2: a "(both)" view of the 2 cue lists in the Cues tab, and MIDI CCs for PDF 2 (not in 1.3).
- UI scale 100 / 125 / 150 %: the drawn icons already use CFG.UI_SCALE, and the repeated sizes have names in CFG (since the code clean-up after 1.4). Still needed: the fonts rebuilt between frames, every pixel size in CFG times the scale, and a test of every screen at each scale. Ask the user first.

## MIDI Pilot (MIDI editor for Quad Cortex / Quad Cortex mini, since 6 November 2026)
- 0.1.1 (released 7 November 2026): the full version 1 (steps 1-7, below). 0.1 on ReaPack points to an early build:
  ReaPack links a version to the commit where its number first appeared (the release skill now checks this).
- Done (version 1, steps 1-4): devices (model, MIDI output / input, channel, latency, own or shared track,
  a kept track brings its device back); presets at the song starts (timing in ms or note values, Fill songs,
  Presets match Regions, names, folders, the .reabank file, Send now); scenes (strip, list with bar.beat and
  time, start scene per song, gap after a preset, merge, colours, Scenes match Markers, clear); Lanes
  (controls in real units, nearest CC value, slope between values, all songs).
- Done (6 November 2026): scene edits are exact (no gap, no automatic start scene or merge; "Fill songs" and a
  "Merge repeated scenes" button); Scene test; new MIDI items are checked (channel, a scene at each song start;
  Settings > Tracks > Check new MIDI items); only the MIDI that REAPER plays is read; the status bar.
- Step 5 done (6 November 2026): latency = the track's playback offset; nudge buttons (rows, songs; Settings > Nudge).
- Step 6 done (7 November 2026): ramps in Lanes (from / to, length in beats, bars or to the time selection end, slope).
- Layout (7 November 2026): scene list and Lanes rows with column labels, icons (send, nudge, - +), editable
  positions in bar.beat.hundredths (right-aligned), scrolling lists (Settings > Lists), Chart Cue's row look
  (hover and the current row); swell with hold and its own way back; notices only in the status bar.
- Step 7 done (7 November 2026): Fill songs writes the control values at the song starts; Live chase (window
  open; Settings > Playback); Send state (status bar). Custom ramp lengths (bars.beats).
- UI consistency (7 November 2026): Chart Cue's form rule (every control fills the control column; a row of 2 parts
  splits it; small windows 1 width; table cells fit their content), Chart Cue's buttons (standard width, dialog width,
  red outline, small buttons), Songs bar: Fill songs + Tools / Clear dropdowns, Help in formatted topics, Presets
  list icons. Forms 280 wide. Settings in 5 sections (Devices, Tracks, Playback,
  Lists, General), 1 open at a time, saved (as in Chart Cue).
- Next: the 2 open tests on the unit (below), then 0.2.
- 0.2 (after the 0.1 release, the user's decision on 7 November 2026): device profiles, so other units are a table
  entry: first Line 6 Helix (Floor, LT, Rack) and HX Stomp / Stomp XL (snapshots on CC#69: 8 / 3 / 4; their preset
  and setlist numbering; their own CCs). The user provides the MIDI tables from the manuals; no units to test, so
  the profiles are marked "untested" in the device list. Generalize: preset labels, scene CC and count, folder CC,
  the word scene / snapshot.
- Version 2: Record and Learn, copy scenes between songs, scenes from the keyboard, a check report, a cue
  sheet, import / export of the names, Tuner / Looper items.
- To test on the unit: are Hz and dB spread evenly over the pedal range? Does the pedal value survive a preset
  change? The USB port name: the mini is checked ("2- Quad Cortex mini MIDI OUT", 7 November 2026); the full-size Quad
  Cortex is not checked (no unit; expected to work when its name has "Cortex"; the output can be picked by hand). REAPER's own chase of Program Changes and CCs.

## Segue (the setlist script, since 4 November 2026)

- 1.0 (released 7 November 2026, with Chart Cue 1.5.2): a centred question, tooltips with a delay; its own GitHub
  Release (segue-v1.0).
- 0.1 (released 5 November 2026, with Chart Cue 1.5): setlists from the regions, Stop / Continue, pauses,
  skip, drag and arrows, the play buttons, the "now playing" area with its grip, more than 1 setlist (More...), Lock setlist,
  undo (Ctrl+Z), the "Segue - Next song" action, the gear menu (now playing options, docking, Help).
- Done in both scripts (5 November 2026): the 3-band now playing view (status pill, current song with
  progress bar, large list with Stop / Continue icons); the armed stop (loop points + REAPER's "stop at end
  of loop", action 41834: no part of the next song is heard); outside the setlist songs the last song stays
  current. Segue locks itself while Chart Cue plays in setlist order ("Use Segue" / "Use Chart Cue").
- Tested in REAPER (5 November 2026): an armed stop does not mark the project as changed; a Continue jump
  plays no part of the following region.
- Tests: tests\segue.lua (10). Checks, deploy and the ReaPack package ("Segue") include Segue.
- Ideas, not planned: a thin countdown bar, a right-click menu on the rows, a UI test for Segue.
- Ideas from the ReaSet changelog (not planned): repeat a song N times; region colours in the list; a note
  per song; the next marker / section in the now playing area, with a 2nd thinner progress bar; an option
  that forces an immediate jump when REAPER's smooth seek is on (Continue to a song that is not next on the
  timeline).
