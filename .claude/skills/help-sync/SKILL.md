---
name: help-sync
description: Find and fix every text in Chart Cue, Segue and MIDI Pilot that names a feature, control, section or setting after it was added, renamed, moved or removed (Help topics, tooltips, "?" texts, messages, menu items, "Settings > ..." paths, comments, CLAUDE.md, PLAN.md, README.md). Use after any rename or move, and as a step of new-feature and debug-time.
---

# Help sync

Old names were the most frequent problem in the reviews. After each change, every place that names
the changed thing must use the new name and place.

## 1. List the changed names

The old and the new name of each control, heading, section, tab, menu item, mode or setting; and its
old and new place ("Settings > Display > ..." -> "Settings > Viewer > ...").

## 2. Search everywhere (grep, case-insensitive)

- `Chart Cue/Chart Cue.lua`: Help topics (HELP_TOPICS, also "more" texts), UI.tip / tooltips,
  UI.heading "?" texts, Msg.notify messages, menu items, status bar texts, comments.
- `Segue/Segue.lua`: HELP_TEXT, the "?" texts (SETTINGS_HELP, LIST_HELP), tooltips, the notice texts.
- `MIDI Pilot/MIDI Pilot.lua`: HELP_TEXT, the "?" texts of the headings, tooltips, the notices (UI.toast),
  the questions (UI.ask) and the undo names (Undo_EndBlock).
- The action scripts' comments, CLAUDE.md, PLAN.md (history and checklist), README.md.
- Every "Settings > A > B" path: A must be a section name, B a heading in that section.
  `grep -o 'Settings > [A-Z][A-Za-z]*\( > [A-Z][A-Za-z ]*\)\?'`, then compare with SETTINGS_SECTIONS
  and the UI.heading names.
- Removed features: no text may still offer them.

## 3. Fix

Plain words (STE style for the user's texts), the same word for the same thing everywhere. Keep the
Help topic order the same as the tab order.

## 4. Report

The texts changed, in one short list. Nothing else changes for the user.
