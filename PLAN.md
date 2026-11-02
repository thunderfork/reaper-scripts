# Chart Cue: plan (state on 2 November 2026)

## Context
- File: `Chart Cue.lua`, v4.7. REAPER 7 ReaScript, Lua 5.4, ReaImGui API pinned to 0.9.3 through the ReaTeam shim. Windows only.
- Modules: CFG, S (settings.ini), R (runtime), COL, P (project config in the .rpp ExtState "ChartCue"/"cfg"), Util, PDF, Project, Nav, Midi, UI, Cues, Msg, Dock, Autostart.
- Layout system: UI.form / UI.field / UI.button_pair / UI.full_button, CFG.SP + UI.sp, one control height UI.h, one text rule CFG.TEXT_LIFT. Compact layout is the default.
- Constraints:
  - Do not change the .rpp ExtState format, the settings.ini keys, the cache folder layout or the __startup.lua markers. Only add new keys, with defaults. A settings.ini key that nothing reads may be removed (done for prerender and autoscroll_start, with the user's approval).
  - Keep every disk or long operation non-blocking.
  - Every Push needs a Pop. Call End only when Begin returned true.
- Working rules from the user:
  - Make small passes. The user tests each pass in REAPER and approves it before the next pass.
  - Do not remove a control without approval. List it first.
  - Write the help texts in plain, simple English.
  - Keep @changelog to 1–3 user-facing lines.

## Done
- v4.6: refactor, async pdfinfo / cache size / cache clear (one .bat), shim pcall, font API cleanup.
- v4.7 pass 1 (items 1–4):
  1. Record cues: R.rec (not saved), toolbar red dot button, checkbox in the cue editor, R key, REC badge. C / S keys and MIDI cue CCs need Record cues on + Cue list mode + not locked (UI.can_record).
  2. Scroll mode per project: P.scroll_mode (written only when set); S.scroll_mode is the default. Status line 2 shows "This project has N cue(s)." + a "Switch to ..." button (UI.mode_hint).
  3. Keep last page: S.keep_last_page (default on, Regions tab). During playback an empty region keeps the page (R.kept_key) with a yellow banner. The empty state shows when playback stops.
  4. Touch: performance-mode exit button on click / tap (R.perf_tap_t); CFG.SPLIT_H 8 -> 12. Verified with a mouse on 2 November 2026 (the bug report was a misunderstanding).

- Pass 2, items 5–8 (tested by the user):
  5. Tab strip: Library, Regions, Cues | Settings | "?". S.tab_ver (1 -> 3) moves a saved tab number.
  6. Cues tab (UI.draw_cues_tab) with a "Use Cue list mode" button. In Cue list mode the Autoscroll section shows only a note.
  7. Scope labels (UI.scope_after, UI.heading scope arg). Mixed sections have a label on each row. "Open and close Chart Cue" has no label.
  8. "Remove all PDF markers..." renamed to "Remove PDF markers...". No controls removed.
- Cleanup pass (approved): long labels move the control to the next row (UI.form label arg); MIDI rows by mode and direct input; MIDI debug in Display > Advanced; "Pre-render all pages" removed (always on, S.prerender unused); "Dim page" + "Brightness" -> "Page brightness"; Library external-PDF count cached 0.5 s; one Settings tab with 4 collapsible sections (UI.draw_settings_tab); SWS startup method removed (only "Remove the SWS startup action..." stays); Poppler kept.

- 4.8 robustness fixes (commit 84fb3ae): __startup.lua duplicate block / backup check, stale "quit" flag, GUID diag, PowerShell block hints.
- Items 10–11: cue fields keep a wrong value with a red border and a reason (UI.mark_invalid, R.cue_err), Esc restores; scroll % no longer deleted by a wrong value. Msg.notify sticky flag with an "x" (7 messages).
- Cue undo: postponed. Open question: does REAPER undo restore SetProjExtState data? Test script in the chat of 2 November 2026. "before" -> REAPER undo blocks; "after" -> own multi-level snapshot stack.

- Item 9 (commit d9adc5c): inline confirmations (UI.ask / UI.draw_ask) for remove all cues, remove PDF markers, reset all settings. Message boxes kept on purpose: ReaImGui missing, same-name file in project folder (3 choices), Open automatically (shows the __startup.lua lines).
- Pass 3, items 13–15: bold selected filter; autoscroll "(ready)" / "(moving)"; status line 2 "Page 2 / 5  |  Next: page 3 at ..." (UI.page_status_text, cached 0.1 s); one term each: "page cache", "PDF markers".

- Second review, passes A and B: kept page can be turned (Nav.page_blocked); status bar ignores sticky; questions close on tab / song change; banner "Autoscroll paused."; "Default for new projects" row (S.scroll_mode); "Not now" on the mode hint (P.hint_off, written only when set); Record button hidden / toggle disabled outside Cue list; MIDI debug back in MIDI > Advanced; "Open and close" labelled "This computer"; Settings sections remembered (S.settings_open).

- UI cleanup round: BUG FIX Project.parse_cfg ignored keys with "_" (scroll_mode, cue_unit, active_pdf, auto_switch, continue_after_end, hint_off, fixed_start) since 4.7; PDF list and region list in columns; Regions search + "Show" menu (UI.search_row); "Region settings", "Region list (n)", "Cue settings", "Cue list (n)", "Marker settings", MIDI "Troubleshooting"; Display -> "Display and view" (View, Page quality, Layout, Troubleshooting); Fixed speed start per project (P.fixed_start); scope moved into the "?" text, labels only on 3 exception rows; red round X (UI.remove_x_button) for cues and PDFs; foldable first sections (UI.heading fold, S.folded); Settings sections in the heading style, one open at a time.

- Removed (approved): Fixed speed mode (S.autoscroll_pps, S.auto_page_turn removed; P.fixed_start and scroll_mode=fixed still read/written so the saved text and "Save as" detection stay the same; "fixed" means "off"); "Continue after region end" (always off; P.continue_after_end still read/written). Page cache in one row with "Clear..." (UI.ask); DPI shown as text with "Change". Cue list: "#" column numbered across all songs, "Position" title.

- REAPER actions: "Chart Cue - Next page / Previous page / Toggle performance mode.lua" write to ExtState "cmd_q" (next, prev, perf); Chart Cue reads it in Midi.poll_forwarded_midi, also in lock mode; cleared at start and close. deploy.ps1 copies them next to Chart Cue.lua. README.md added.

## Release checklist (do before sharing a new version)
1. Version: @version and CFG.VERSION are equal; @changelog has 1–3 user-facing lines.
2. Start: Chart Cue starts without errors; the last tab and the open Settings section come back.
3. Project data: set a mode, Seconds, "Turn pages", a PDF; close and open Chart Cue, then save, close and reopen the project: all values come back.
4. Save as: "Save as" keeps Chart Cue open with the same data; File > Open of another project in the same tab loads that project's data (or closes Chart Cue with "Close with project").
5. Project tabs: switch between 2 open projects; each shows its own library and cues.
6. PDFs: add a PDF and a folder; copy into the project; replace a PDF with a different file of the same name; relocate a missing PDF. Use a Greek folder and file name with spaces and an apostrophe.
7. Engines: open a PDF with the Windows engine and with Poppler; clear the page cache while a PDF is open.
8. Regions: rename, move, undo, save and reopen: the PDF assignment stays. "Keep last page" during playback in a region without a PDF; the page can be turned.
9. Cues: record page turns and scroll points (Record on and off, Lock on); insert a cue between 2 cues; switch Beats / Seconds; a wrong value shows a red border.
10. Markers: PDFPAGE / PDFSCROLL markers scroll the page; "Remove PDF markers..." asks first and Ctrl+Z brings them back.
11. Control: keys (window active); the 3 actions (window not active, also in lock mode); MIDI absolute and relative; MIDI page turns and cue buttons.
12. Stage: performance mode on / off; lock; hide controls when playing; page brightness.
13. Large set: a 300-page PDF and a project with 30 regions: start time, page cache size, smooth playback.

## Future consideration (not planned)
- Half-page turn (top half shows the next page while the bottom of the current page is still read).
- Cue list columns: centred layout was rejected; look again later.
- Confirmation (or undo) for the single-row cue "Remove".
- One shared confirmation pattern: done (the Library remove question uses UI.ask, 2026-11-02).
- Settings: inner headings look like the section headers.
- No way to show the mode hint again after "Not now".
- Cue undo: see the open question above.
- UI scale 100 / 125 / 150 % (item 12): high risk, fonts must be rebuilt between frames and all pixel constants in CFG must scale.

## Old plan text (done, kept for reference)
9. Inline confirmation (yellow note + red "Yes, ..." + "Cancel") instead of ShowMessageBox for: remove all cues, remove PDF markers, reset all settings. "Undo last cue change" button in the Cues tab (one-level snapshot of P.cues). Decide: own snapshot or REAPER undo (Undo_BeginBlock). Fix the "cannot be undone" texts.
10. Cue table validation: keep the typed text, red border, reason as the tooltip. No silent revert.
11. Msg.notify sticky flag with a small "x". One sticky message at a time; a new one replaces it. Use it for SWS steps, "Restart REAPER once" and copy-complete messages.
- Update HELP_TOPICS for each change.

## Pass 3 (items 13–15)
13. Not colour alone: bold text for the selected filter button; a word or icon difference between "armed" and "active" autoscroll.
14. Status line 2 with a PDF open: "Next: page 3 at <time in the project's cue unit>" in Cue list / Markers mode, else "Page 2 / 5". Keep the shortcut list when no PDF is open and in the help topic "Keyboard and mouse".
15. One term each: "page cache" (not render cache / prepared page images), "PDF markers". Text only; keys and folder names stay.

## Pass 4 (item 12, optional)
- UI scale 100 / 125 / 150 %. High risk: fonts must be rebuilt between frames, and all pixel constants in CFG must scale. Ask the user if it is still needed before you start.

## Test list for each pass
- Record cues off: press C during playback -> no cue.
- Mode set in project A, then open project B -> B has its own mode.
- Play into a region without a PDF -> last page + banner; stop -> region buttons.
- Performance mode: tap the page -> exit button shows for 3 s.
