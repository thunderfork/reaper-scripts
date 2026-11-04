---
name: new-feature
description: Turn a new idea for Chart Cue into a short plan and the right 1-2 questions before any code. Use when the user asks for a new feature, option, button, tab, view or setting ("add ...", "is it possible to ...", "can we have ..."), or a larger change to an existing one.
---

# New feature

The user decides what Chart Cue looks like (GUI and taste) and does not read code. Get the visible
decisions right before building: a rename or a move after the build costs a whole round.

## 1. Fit it into what exists (look, do not guess)

- Where it goes: which tab, Settings section (Viewer, Playback, Control, Appearance, General) and
  heading; the toolbar; the right-click menu. Use the existing names and order; grep for them.
- Its on/off switch and the default (every optional feature can be turned off, see memory).
- What is saved: in the project (P, ExtState; new keys only when used) or on this computer
  (S, settings.ini). The "?" text of its heading says where.
- How it behaves in the special states: playing, paused, stopped, locked, performance mode, PDF 2,
  hidden panel, hidden tabs, Page area Setlist / Setlist and PDF, an empty list or project.
- Technical limits that the user will notice (timing, gaps, REAPER limits): say them plainly.
- Is it the right size? Suggest a smaller first step when it is large (step 1 / step 2).

## 2. Plan in plain words

What the user will see and do, as a short list or a small text mockup. No code, no diffs.

## 3. Ask (only what is the user's to decide)

1-2 questions with AskUserQuestion, 2-4 options each, the recommended one first with "(Recommended)":
names and wording, place, default, look. Do not ask about technical details: decide them.
When the request is already exact, skip the questions and say what you decided.

## 4. Build

CLAUDE.md editing rules and the patch rules; then `help-sync` for every new or changed name; tests for
the logic; deploy; recommend the UI test when menus, tabs or views changed (`ui-test`).

## 5. Report

What the user will see, the functions changed, the manual test in REAPER.
