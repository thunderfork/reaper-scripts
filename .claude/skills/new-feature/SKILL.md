---
name: new-feature
description: Turn a new idea for a script of this repository (tools\scripts.psd1) into a short plan, a text mockup and the right questions before any code. Use when the user asks for a new feature, option, button, tab, view or setting ("add ...", "is it possible to ...", "can we have ..."), or a larger change to an existing one.
---

# New feature

Read and follow the global skill first: `%USERPROFILE%\.claude\skills\new-feature\SKILL.md`. This project adds:

- More than 3 open manual tests of this script in PLAN.md: no new feature until they are tested; say so and offer
  the tests first.

## Fit it into what exists (step 1 of the global skill)

- Where it goes: the tab, the Settings section and heading, the menu. The script's folder CLAUDE.md names its
  screens and its limits (a preparation tool: no live features); grep the existing names and order in the code.
  A new tab, Settings section or menu: update that list in the folder CLAUDE.md.
- Its on/off switch in Settings and its default (CLAUDE.md "Look and words").
- What is saved: in the project (P) or on this computer (S); the "?" text says where.
- The special states: playing, paused, stopped, an empty list or project; Chart Cue: locked, performance mode,
  PDF 2, hidden panel or tabs; MIDI Pilot: 2 or more devices, Line 6 or Quad Cortex, muted items.
- A name field (a preset, bus, return, device...): when you finish typing, an empty name or a name that another
  item of the same list has goes back to the old name (LESSONS-RULES.md, saved-data).

## Mockup (step 2 of the global skill)

- The behaviour also says what Ctrl+Z does.
- Scripts with a window (all except Mono Merge): before the mockup, write every new text (labels, tooltips, "?"
  texts, notices, questions, empty states) in the existing word style of the script; the mockup shows them.

## Build (step 4 of the global skill)

- `help-sync` for every new or changed name; tests for the logic; deploy (no commit: CLAUDE.md).
- A new script: first its own branch (`script/<name>`, CLAUDE.md "Git and releases") and its line in
  `tools\scripts.psd1` (`Released = $false`, `@noindex` in its header).
