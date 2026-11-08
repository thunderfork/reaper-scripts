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

## Released on 8 November 2026: MIDI Pilot 1.0
- Save fix: the settings of this computer keep their line breaks (REAPER keeps only the first line of a value):
  preset, folder and scene names, the controls and the device list survive a restart.
- Track and device names in both directions: a device rename renames its track; a track rename in REAPER renames
  the device (without "MIDI "); a track with an older name gets the device name when a project opens.
- "Reset MIDI devices" (Settings > Devices; "Reset MIDI" in the status bar when a device is NOT AVAILABLE).
- Review (8 November 2026): a muted MIDI item is never written; the Scene test texts use the device's scene names;
  texts (Presets help, the channel question); clean-ups.
- Light theme: every scene block in its full colour; the block that plays has a blue outline (Dark: unchanged).
- Device profiles (8 November 2026, toward 1.0): Line 6 Helix (Floor, LT, Rack), HX Stomp, HX Stomp XL, HX Effects
  (untested, from the unofficial Helix MIDI guide): 8 setlists (CC#32) x 128 presets (Program Change, no CC#0),
  snapshots on CC#69 (8 / 3 / 4 / 4), their reserved CCs, USB names. Per device "Preset numbers": Bank + letter
  (01A) or Numbers (000), as the unit's Preset Numbering. Description: "MIDI editor for amp modelers".
- Quad Cortex expression pedals (8 November 2026): CC#1 / CC#2 write the pedal position 0-100% (no Min / Max /
  Unit); per preset (Presets tab, pedal icon; settings key exp_<device>) what each pedal moves: name, range in knob %
  (backwards allowed), optional note, no limit; Lanes rows show "-> Hi Pass 22%, Low Pass 66%". (A "Target" to type a
  knob % was built and removed: the user found it too complicated.) Other CCs keep Min / Max / Unit. Line 6 unchanged.
- Quad Cortex functions (8 November 2026, from the Neural DSP manuals' Incoming MIDI CC List): Lanes > Control lists
  Expression 1 / 2 (always there, CC fixed, names only), then Footswitch A-H (mini: A-D page I / II) and the mini's
  footswitch page (CC#64), Tap tempo (1 tap, or 4 taps on the beat), Tuner, Gig View (Open / Close), Mode (slot 1-3).
  Add by kind (press, tap, choice; no ramps). Only the pedals play on (Set up songs, Live chase). No "Add control" on
  a Quad Cortex. Later: Looper X (CC#48-61) in its own section.
- Lanes, used controls (8 November 2026): in the Control dropdown a blue dot and the count for each control with
  values in the song at the edit cursor (or all songs). (A row of buttons was tried; the user did not like it.)
- The device choice (2 or more devices) is at the right end of the tab's first heading: the name and a small arrow.
- Add device is a dropdown (8 November 2026): "Connected" (free units found on USB, with output and model), then all
  models (the Line 6 ones marked untested).
- Presets: Factory Presets and My Presets cannot be renamed (Quad Cortex); mini scenes are A-I ... D-II.
- Fixed: the send and remove buttons of a song row did nothing (the quiet row went away while the mouse was down).
- Mini tests (8 November 2026): a preset change loads the preset's own pedal positions (so Set up songs writes the
  pedal positions at the start scene time, after the song's preset change; Live chase sends them after the preset);
  REAPER's own MIDI chase depends on the items (a preset changed with Live chase off).
- Live chase removed (the user, 8 November 2026): MIDI Pilot does not send MIDI by itself during playback; REAPER
  plays the track. Send state (status bar) stays.
- Preset changes inside a song (8 November 2026): "Preset change..." in the Add scene list (Choose a preset window,
  at the edit cursor); its own row in the scene list (position, time, nudge, preset, send, X); a thin line on the
  strip. The song row keeps the song's own preset.
- Songs > Tools (8 November 2026): "Show overview" (a table: song, start, preset, its scenes in order with inside
  preset changes in brackets, its Lanes values; a click moves the edit cursor) and "Export MIDI" (standard MIDI file,
  type 0, 960 ppq, tempo map; 1 file for the show, or 1 per song from 0:00 with its preset and start scene; slopes
  as steps of a 1/32 note; MIDI Pilot's own writer, not REAPER's export). The folder: a field with Browse...
  (js_ReaScriptAPI, else the Windows folder window) and Default; saved in the project (key export_dir, only when
  chosen); default "MIDI Pilot export" next to the project file. A song event list was rejected (the
  scene list is already full). MIDI Pilot is a preparation tool: no live features (the user).
- "Set up songs" adds only presets (CC#0, CC#32, Program Change) and start scenes; no control values (the user).
- 1.0 (the user, 8 November 2026): everything above, plus the tests on the mini (Hz/dB spread, pedal value after a
  preset change, REAPER's own chase of PC/CC) and their fixes.
- Open: REAPER crashes in reaper_imgui-x64.dll 0.10.0.5 when a docked script window closes or hides (middle-click
  on its dock tab, or a dock tab switch); not in the scripts' code. A report for the ReaImGui author was written.

## Released on 7 November 2026 (2nd release): Chart Cue 1.5.3, Segue 1.1, MIDI Pilot 0.1.2
- All 3 scripts (7 November 2026): darker panels for more contrast: window #131518, tab strip #0F1114, panels /
  menus / setlist and now playing views #1A1C21 (MIDI Pilot: its scene list card #22252B). Next push: Chart Cue 1.5.3,
  Segue 1.1, MIDI Pilot 0.1.2.
- (Fixed in MIDI Pilot 1.0: the scene colours in the Light theme.)
- All 3 scripts (7 November 2026): Light / Dark theme, 1 option in each (Chart Cue: Settings > Appearance > Theme;
  Segue: gear menu > Light theme; MIDI Pilot: Settings > General > Theme); Dark is the default. The colours that were
  written in the code are named in COL; the style reads COL every frame (no restart); the window title bar follows
  the theme. tools\shots.ps1 -Light takes Chart Cue's screenshots in the light theme.

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

## MIDI Pilot (MIDI editor for amp modelers: Quad Cortex, mini, Line 6 Helix / HX; since 6 November 2026)
- 1.0 (released 8 November 2026): see "Released on 8 November 2026" above.
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
- 0.1.2 (released 7 November 2026): the scene colours (the unit's 8 colours; only the active block in full colour,
  the others semi-transparent); double-click opens REAPER's MIDI editor at that place; the Pastel option is removed.
- Next: version 2 (below).
- Device profiles (planned as 0.2, done in 1.0): Line 6 Helix, HX Stomp, HX Stomp XL, HX Effects, from the
  unofficial Helix MIDI guide; marked "untested" (no units).
- Version 2: Record (a real pedal move into Lanes, from the unit's Preset MIDI Out expression messages) and Learn,
  copy scenes between songs, a check report, a cue sheet, import / export of the names, Looper X (CC#48-61) in its
  own section. Not planned: live / show-time features (MIDI Pilot is a preparation tool).
- Unit tests done (8 November 2026): a preset change loads the preset's own pedal positions; REAPER's own chase
  depends on the items. Not checked: the full-size Quad Cortex's USB port name (no unit; it contains "Cortex").

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
