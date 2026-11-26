---
name: new-feature
description: Turn a new idea for a script of this repository (tools\scripts.psd1) into a short plan, a text mockup and the right questions before any code. Use when the user asks for a new feature, option, button, tab, view or setting ("add ...", "is it possible to ...", "can we have ..."), or a larger change to an existing one.
---

# New feature

Read and follow the global skill first: `%USERPROFILE%\.claude\skills\new-feature\SKILL.md`. This project adds:


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
- A new or changed click or key rule (what a click, double-click, drag or key does): a plain function with a test,
  not inside the drawing code (LESSONS-RULES.md, `imgui-input`).

## A new script (before its first code)

1. Its own branch `script/<name>` (CLAUDE.md "Git and releases").
2. Its line in `tools\scripts.psd1` (`Released = $false`); `@noindex` in the header of each of its `.lua` files.
3. Its folder CLAUDE.md: what it does, Files, its data, its screens, Later (copy the headings of a similar script;
   no version, tag, deploy or test-command lines: `scripts.psd1` and the tools have them).
4. Its test file in `tests\` (the name from `scripts.psd1`) with the first test.
5. The root CLAUDE.md: its line in the list of scripts; its user in "Users" when it is a new role; its keys in
   "Saved data".
6. README.md: its part inside `<!-- -->` until its first release (the publish check).
7. Its texts in "Where to search" of the project `help-sync` skill.

The first release: the `release` skill.
