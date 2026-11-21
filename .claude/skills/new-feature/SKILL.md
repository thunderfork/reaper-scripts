---
name: new-feature
description: Turn a new idea for Chart Cue, Segue, MIDI Pilot, FX Link, Session Prep or SFX Drop into a short plan, a text mockup and the right questions before any code. Use when the user asks for a new feature, option, button, tab, view or setting ("add ...", "is it possible to ...", "can we have ..."), or a larger change to an existing one.
---

# New feature

The user decides the look and the behaviour and does not read code. A rename or a move after the build costs a
whole round, so the visible decisions come first (the global mockup rule). More than 3 open manual tests in
PLAN.md: no new feature until they are tested (global rule); say so and offer the tests first.

## 1. Fit it into what exists (look, do not guess)

- Where it goes: the tab, the Settings section and heading, the menu (grep the existing names and order).
  - Chart Cue: Settings sections Viewer, Playback, Control, Appearance, General; the toolbar; the right-click menus.
  - Segue: the gear menu, the setlist, the now playing view.
  - MIDI Pilot: tabs Songs, Lanes, Presets; Settings sections Devices, Editing, Appearance, General;
    Songs > Tools. A preparation tool: no live features (MIDI Pilot/CLAUDE.md).
  - FX Link: the toolbar, the gear menu (Look, Automatic open and close, Window, Backup), the foldable sections.
  - Session Prep: tabs Prep, Rules, FX Chains, Buses; Settings sections Appearance, Prep (Tracks, Routing, Checks),
    Gain staging, Window. A preparation tool (Session Prep/CLAUDE.md).
  - SFX Drop: tabs Sounds, Spots, Soundcheck; Settings sections Appearance, Library, Insert (Items, Files, Tracks,
    Levels), Window.
    A preparation tool (SFX Drop/CLAUDE.md).
- Its on/off switch and default (every optional feature can be turned off).
- What is saved: in the project (P) or on this computer (S); the "?" text says where. A new key: ask first.
- The special states: playing, paused, stopped, an empty list or project; Chart Cue: locked, performance mode,
  PDF 2, hidden panel or tabs; MIDI Pilot: 2 or more devices, Line 6 or Quad Cortex, muted items.
- Technical limits that the user will notice: say them plainly. Too large: suggest a smaller first step.

- A name field (a preset, bus, return, device...): when you finish typing, an empty name or a name that another
  item of the same list has goes back to the old name (LESSONS-RULES.md, saved-data).
- The global `new-feature` skill's checks apply too (an outside source, a small trial of what is not checked yet).

## 2. Mockup and behaviour (always, for anything visible)

A small text mockup in the question window's preview, and the exact behaviour (what a click does, what is
saved, what Ctrl+Z does). Also when the user asked for it in a few words.

Scripts with a window (all except Mono Merge): before the mockup, write every new text (labels, tooltips, "?"
texts, notices, questions, empty states) in the existing word style of the script (CLAUDE.md "Look and words");
the mockup shows these texts.

## 3. Ask

1-4 questions, 2-4 options each, the recommended one first: names, place, default, look. Decide the technical
details yourself.

## 4. Build

CLAUDE.md editing and patch rules; `help-sync` for every new or changed name; tests for the logic; deploy.
A new script: first its own branch (`script/<name>`, CLAUDE.md "Git and releases") and its line in
`tools\scripts.psd1` (`Released = $false`, `@noindex` in its header).

## 5. Report

What the user will see and the check / test result in 1 line; the manual tests in a question window. The changed
functions go into the commit message.
