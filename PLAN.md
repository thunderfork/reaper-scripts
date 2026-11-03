# Chart Cue: plan (state on 3 November 2026)

## Context
- File: `Chart Cue/Chart Cue.lua`, public version 1.1. REAPER 7 ReaScript, Lua 5.4, ReaImGui API pinned to 0.9.3 through the ReaTeam shim. Windows only.
- Modules: CFG, S (settings.ini), R (runtime), COL, P (project config in the .rpp ExtState "ChartCue"/"cfg"), Util, PDF, Project, Nav, Midi, UI, Cues, Msg, Dock, Autostart.
- Layout system: UI.form / UI.field / UI.button_pair / UI.full_button, CFG.SP + UI.sp, one control height UI.h, one text rule CFG.TEXT_LIFT. Compact layout is the default.
- Constraints:
  - Do not change the .rpp ExtState format, the settings.ini keys, the cache folder layout or the __startup.lua markers. Only add new keys, with defaults. P.fixed_start, P.continue_after_end and scroll_mode=fixed are still read and written, so the saved text ("Save as" detection) stays the same.
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
- 1.2 (3 November 2026): settings and page cache moved to REAPER\Data\Chart Cue (no migration: no other users yet); autoscroll mode locked during playback (text in both toolbars); repository renamed to thunderfork/reaper-scripts, ReaPack name "Thunderfork Scripts"; index workflow fixed (CMake 4, pinned runner).
- 1.1 (3 November 2026): UI review (gear tab, welcome, Settings sections, Help About / Send feedback, SWS and "This computer" labels removed); tests in the portable test REAPER; toolbar in 3 groups with drawn icons and a "Hide controls when playing" button; Autoscroll "Scroll" Smooth / Jump (P.scroll_jump, written only when on); cue list: full-width rows, click = edit cursor, Start row, "Use current view", "+ below", bar with Record / + Page turn / + Scroll point / Undo (own snapshot stack, Ctrl+Z), messages in the title line; panel grip double-click 40% <-> 60%; floating window: own resize edges and corner grip, full size kept while collapsed; right-click menus (toolbar / page, Library / Regions / Cues rows), "Replace PDF..."; page brightness minimum 25%; tools moved to `tools\`.

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
11. Control: keys (window active); the 3 actions (window not active, also in lock mode); MIDI absolute and relative; MIDI page turns and cue buttons; every right-click menu.
12. Stage: performance mode on / off; lock; hide controls when playing; page brightness.
13. Window: dock and undock (menu); resize the floating window at each edge and the corner; collapse and open.
14. Large set: a 300-page PDF and a project with 30 regions: start time, page cache size, smooth playback.

## Future consideration (not planned)
- Half-page turn (top half shows the next page while the bottom of the current page is still read).
- Guitar Pro files: convert to PDF with MuseScore's command line (optional external program, like Poppler).
- REAPER forum button in Help > About (disabled until there is a forum thread).
- No way to show the mode hint again after "Not now".
- A "Sharper page available" hint after the zoom stays the same (instead of an automatic DPI match).
- UI scale 100 / 125 / 150 %: high risk, fonts must be rebuilt between frames and all pixel constants in CFG must scale. Ask the user first.
