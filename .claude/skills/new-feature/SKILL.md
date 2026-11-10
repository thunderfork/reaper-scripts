---
name: new-feature
description: Turn a new idea for Chart Cue, Segue, MIDI Pilot or FX Link into a short plan, a text mockup and the right questions before any code. Use when the user asks for a new feature, option, button, tab, view or setting ("add ...", "is it possible to ...", "can we have ..."), or a larger change to an existing one.
---

# New feature

The user decides the look and the behaviour and does not read code. A rename or a move after the build costs a
whole round, so the visible decisions come first (CLAUDE.md visible-change gate).

## 1. Fit it into what exists (look, do not guess)

- Where it goes: the tab, the Settings section and heading, the menu (grep the existing names and order).
  - Chart Cue: Settings sections Viewer, Playback, Control, Appearance, General; the toolbar; the right-click menus.
  - Segue: the gear menu, the setlist, the now playing view.
  - MIDI Pilot: tabs Songs, Lanes, Presets; Settings sections Devices, Tracks, Playback, Appearance, General;
    Songs > Tools. A preparation tool: no live features (MIDI Pilot/CLAUDE.md).
- Its on/off switch and default (every optional feature can be turned off).
- What is saved: in the project (P) or on this computer (S); the "?" text says where. A new key: ask first.
- The special states: playing, paused, stopped, an empty list or project; Chart Cue: locked, performance mode,
  PDF 2, hidden panel or tabs; MIDI Pilot: 2 or more devices, Line 6 or Quad Cortex, muted items.
- Technical limits that the user will notice: say them plainly. Too large: suggest a smaller first step.

## 2. Mockup and behaviour (always, for anything visible)

A small text mockup in the question window's preview, and the exact behaviour (what a click does, what is
saved, what Ctrl+Z does). Also when the user asked for it in a few words.

## 3. Ask

1-4 questions, 2-4 options each, the recommended one first: names, place, default, look. Decide the technical
details yourself.

## 4. Build

CLAUDE.md editing and patch rules; `help-sync` for every new or changed name; tests for the logic; deploy.

## 5. Report

What the user will see and the check / test result in 1 line; the manual tests in a question window. The changed
functions go into the commit message.
