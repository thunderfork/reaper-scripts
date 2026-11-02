# Chart Cue: plan (state on 2 November 2026)

## Context
- File: `Chart Cue.lua`, v4.7. REAPER 7 ReaScript, Lua 5.4, ReaImGui API pinned to 0.9.3 through the ReaTeam shim. Windows only.
- Modules: CFG, S (settings.ini), R (runtime), COL, P (project config in the .rpp ExtState "ChartCue"/"cfg"), Util, PDF, Project, Nav, Midi, UI, Cues, Msg, Dock, Autostart.
- Layout system: UI.form / UI.field / UI.button_pair / UI.full_button, CFG.SP + UI.sp, one control height UI.h, one text rule CFG.TEXT_LIFT. Compact layout is the default.
- Constraints:
  - Do not change the .rpp ExtState format, the settings.ini keys, the cache folder layout or the __startup.lua markers. Only add new keys, with defaults.
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

## Pass 2 (items 9–11), decisions agreed
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
