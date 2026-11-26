---
name: help-sync
description: Find and fix every text in the scripts of this repository (tools\scripts.psd1) that names a feature, control, section or setting after it was added, renamed, moved or removed (Help topics, tooltips, "?" texts, messages, menu items, "Settings > ..." paths, comments, CLAUDE.md, PLAN.md, README.md). Use after any rename or move, and as a step of new-feature and debug-time.
---

# Help sync

Read and follow the global skill first: `%USERPROFILE%\.claude\skills\help-sync\SKILL.md`. This project adds:

## Where to search (step 2 of the global skill)

- `Chart Cue/Chart Cue.lua`: Help topics (HELP_TOPICS, also "more" texts), UI.tip / tooltips,
  UI.heading "?" texts, Msg.notify messages, menu items, status bar texts, comments.
- `Segue/Segue.lua`: HELP_TEXT, the "?" texts (SETTINGS_HELP, LIST_HELP), tooltips, the notice texts.
- `MIDI Pilot/MIDI Pilot.lua`: HELP_INTRO and HELP_TOPICS, the "?" texts of the headings, tooltips, the notices (UI.toast),
  the questions (UI.ask) and the undo names (Undo_EndBlock).
- `FX Link/FX Link.lua`: HELP_INTRO and HELP_TOPICS, the HELP_* "?" texts, tooltips, the gear menu, the notices.
- `SFX Drop/SFX Drop.lua`: HELP_INTRO and HELP_TOPICS, INSERT_HELP, PLACE_TIP, tooltips, notices
- `Session Prep/Session Prep.lua`: HELP_INTRO and HELP_TOPICS, the HELP_* and PREP_HELP_* "?" texts, tooltips
  (UI.tip / UI.tipf), the notices (UI.notice) and questions (UI.ask), the notice of Apply.
- `Mono Merge/Mono Merge.lua`: the messages and questions (`r.MB`) and the undo names (`Undo_EndBlock`).
- The action scripts' comments, the root and folder CLAUDE.md files (also the Chart Cue release checklist), the
  skills, PLAN.md, LESSONS-RULES.md, README.md.
- The "Settings > A > B" paths: `grep -o 'Settings > [A-Z][A-Za-z]*\( > [A-Z][A-Za-z ]*\)\?'`, then compare
  with SETTINGS_SECTIONS and the UI.heading names (`tools\docs-check.ps1` checks the paths in the docs).

## Fix (step 3 of the global skill)

The word style of the script (CLAUDE.md "Look and words"). Keep the Help topic order the same as the tab order.
