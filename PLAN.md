# Thunderfork scripts: plan (state on 5 November 2026)

## Context
- File: `Chart Cue/Chart Cue.lua`, public version 1.5. Chart Cue's data (settings.ini, page cache, tmp, autostart.lua, guide) is in REAPER\Data\Chart Cue since 1.2. REAPER 7 ReaScript, Lua 5.4, ReaImGui API pinned to 0.9.3 through the ReaTeam shim. Windows only.
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

## Segue (the setlist script, since 4 November 2026)

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
