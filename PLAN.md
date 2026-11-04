# Chart Cue: plan (state on 4 November 2026)

## Context
- File: `Chart Cue/Chart Cue.lua`, public version 1.4. Chart Cue's data (settings.ini, page cache, tmp, autostart.lua, guide) is in REAPER\Data\Chart Cue since 1.2. REAPER 7 ReaScript, Lua 5.4, ReaImGui API pinned to 0.9.3 through the ReaTeam shim. Windows only.
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
- 1.1 (3 November 2026): UI review (gear tab, welcome, Settings sections, Help About / Send feedback, SWS and "This computer" labels removed); tests in the portable test REAPER; toolbar in 3 groups with drawn icons and a "Hide controls when playing" button; Autoscroll "Scroll" Smooth / Jump (P.scroll_jump, written only when on); cue list: full-width rows, click = edit cursor, Start row, "Use current view", "+ below", bar with Record / + Page turn / + Scroll point / Undo (own snapshot stack, Ctrl+Z), messages in the title line; panel grip double-click 40% <-> 60%; floating window: own resize edges and corner grip, full size kept while collapsed; right-click menus (toolbar / page, Library / Regions / Cues rows), "Replace PDF..."; page brightness minimum 25%; tools moved to `tools\`.
- 1.2 (3 November 2026): settings and page cache moved to REAPER\Data\Chart Cue (no migration: no other users yet); autoscroll mode locked during playback (text in both toolbars); repository renamed to thunderfork/reaper-scripts, ReaPack name "Thunderfork Scripts"; index workflow fixed (CMake 4, pinned runner).

## Next: several page areas (approved 4 November 2026)
Goal: (a) 2 pages of 1 PDF on screen, (b) 2 PDFs per region (e.g. "Song A lyrics" + "Song A bass"),
each with its own page, scroll and cues. Layouts: top / bottom and left / right.

Design (reviewed):
- Panes: each part of the page area is a pane with its own page, scroll, zoom, page images and render
  jobs (module Pane). Pane 1 is the global state; other panes are swapped in (Pane.swap / Pane.run).
- (a) is a linked pane: the same PDF, page + 1, same zoom. Page turn: "Rolling" (1-2, 2-3, by 1) or
  "Book" (1-2, 3-4, by 2); a cue to page 4 shows 4-5 (Rolling) or 3-4 (Book). Cues do not change.
- (b) is a free pane: its own PDF and page. Not both (a) and (b) at the same time in the first version.
- Divider between the panes: draggable, double-click = 50/50. Layout top / bottom or left / right.
- Active pane: a click makes it active (thin blue frame). Arrow keys, toolbar page / zoom, MIDI knob,
  the 3 actions, C / S and the add buttons act on it. The toolbar shows its page and zoom.
- Region: a 2nd PDF choice (new project key, written only when set). Name matching: when 2 PDFs
  match a region ("several PDFs match"), part 1 and part 2 can take them.
- Cues of part 2: a separate list of the same song (key "<region key>#2"); the cue format does not
  change. Undo, Beats / Seconds, Copy markers, Remove all and "(all songs)" must include it.
- Markers (PDFPAGE / PDFSCROLL) control part 1 only; part 2 uses cues.
- Cues tab: a "Part" dropdown next to Song: Part 1 / Part 2 / (all parts, with a Part column);
  each part has its own Start row; the bar shows the active part ("Record (R) -> Part 2").
- Rendering: the panes take turns (one batch at a time), so playback never stutters.
- To define per pane: performance mode, lock, page-turn flash, Keep last page, status "Next: page",
  the empty state when only one PDF is found.

Agreed details (4 November 2026): exactly 2 matching PDFs become part 1 + part 2 automatically (project setting
"Use 2 matching PDFs as 2 parts", on by default; part 1 = first alphabetically; right-click "Swap part 1 and part 2");
3 or more: choose in 2 dropdowns. "Show as part 2" in the Library shows 2 PDFs by hand (not saved).
With 2 PDFs each part shows 1 page. MIDI and the actions act on the active part.

Steps (each tested by the user before the next):
1. Pane module and tests, no visible change. DONE 4 November 2026 (not released).
2. (a) 2 pages of 1 PDF: DONE 4 November 2026 (not released) as one spread in the page view (no linked pane needed:
   the page images come from the same cache); Settings > Display: Pages on screen, Page turn (S.page_layout, S.page_turn).
3. (b) 2 PDFs per region:
   3a. DONE 4 November 2026 (not released): split page area (UI.draw_parts), divider (S.split_frac), active part
       (R.active_part, Pane.active), "Show as part 2" / "Close part 2", Settings "2 PDFs on screen" (S.split_layout).
   3b. DONE 4 November 2026: Regions PDF 2 row with [+] / x, automatic pair (not with an exact song name),
       "Pair 2 matching PDFs" (P.pair_off), P.assign2 / P.no2, swap, region switching (UI.sync_part2), tags.
       Split view moved into Display > Page layout (P.split_off per project, S.split_layout).
       Panel: a tab click below 30% returns to 40%; an opened Settings section / Help topic grows the panel to fit (max 80%).
   3c. DONE 4 November 2026: PDF 2 cues (key "<region>#2", Cues.key by R.cue_part_ctx / R.in_part2), Cues tab "PDF"
       dropdown, record into the active part (UI.record_cue), part 2 follows its cues. Not yet: "(both)" view, MIDI CCs for PDF 2.
   3d. DONE 4 November 2026: Help, README (ReaImGui note), full check and optimization pass, release 1.3.
- 1.3 (4 November 2026): 2 PDFs per song (split view, PDF 1 / PDF 2 in Regions, own cues, active part); pages on screen (1, side by side with Rolling / Book, continuous) and the slide-in page turn; Display > Page layout; Library: Add from folder remembers the folders, Sync, Remove unused PDFs, Sort: Unused first, Replace PDF; right-click menus; Redo; bold row labels; one standard button width; panel fit to sections; fixes (region PDF at playback start, empty dropdown text, clicks during playback, double flash, odd last page).
- 1.4 (4 November 2026, released): Setlist tab (show order, Stop / Continue, timed pauses, several setlists, lock, undo, right-click menu, play buttons, "Next song" action, Page area: PDF / Setlist / Setlist and PDF, "Next: ..." label); notes on the pages (colour and size per note); page-turn countdown (also before the next song); toolbar and tab items can be hidden; brightness button; Settings in 5 sections (Viewer, Playback, Control, Appearance, General); Shortcuts and external controls (Assign...); page cache limit (1 GB); "debug time" review skill (.claude/skills/debug-time).

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
15. Setlist: make, reorder (drag, arrows, menu), skip, remove and undo, pauses, Stop / Continue (adjacent and far songs), play buttons, Next song action, Lock setlist, Page area Setlist and Setlist and PDF, duplicate with a pause, another project.
13. Window: dock and undock (menu); resize the floating window at each edge and the corner; collapse and open.
14. Large set: a 300-page PDF and a project with 30 regions: start time, page cache size, smooth playback.

## Future consideration (not planned)
- Guitar Pro files: convert to PDF with MuseScore's command line (optional external program, like Poppler).
- REAPER forum button in Help > About (disabled until there is a forum thread).
- No way to show the mode hint again after "Not now".
- A "Sharper page available" hint after the zoom stays the same (instead of an automatic DPI match).
- Code (senior review, 1.3): the toolbar list is rebuilt every frame (cache it); the PDF 1 / PDF 2 cue list is chosen by 2 global switches (R.cue_part_ctx, R.in_part2: pass it directly); some sizes are numbers in the code (12 px gaps, 140 px DPI field: named constants).
- UI scale 100 / 125 / 150 %: high risk, fonts must be rebuilt between frames and all pixel constants in CFG must scale. Ask the user first.
