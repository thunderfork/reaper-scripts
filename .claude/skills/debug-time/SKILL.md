---
name: debug-time
description: Full review of Chart Cue, Segue and MIDI Pilot before a commit - senior developer pass, senior UI/UX designer pass, a cross-review, feedback, fixes, then a final full-code pass and the commit/push question. Use when the user says "debug time" (or asks for a debug / optimize / review round).
---

# Debug time

A review round for Chart Cue (`Chart Cue/Chart Cue.lua`), Segue (`Segue/Segue.lua`) and MIDI Pilot
(`MIDI Pilot/MIDI Pilot.lua`, no shared code with the others; it copies Chart Cue's look): the action scripts,
the Help texts, CLAUDE.md, PLAN.md, README.md. Review the script(s) that changed since the last release; the
shared parts (`Setlist`, `UI.draw_now_view`) must stay the same in both, and the look must match Chart Cue. The user does not read code: report in plain words, with what they will see.

## 1. Collect (before reading)

- `git diff --stat` and `git log` since the last release tag: what changed since then. Look at it first,
  but the passes below cover the whole file.
- `.\tools\check.ps1` and `.\tools\test.ps1`: note any new Language Server warning or test failure.
- Run the `help-sync` search: every "Settings > ..." path (compare with the section and heading names),
  tab names, Help topic titles, removed features, renamed controls, old setting keys.

## 2. Pass 1: senior developer (read the FULL code, in parts)

Look for:
- bugs: state that is not reset (project switch, mode change, removed items), copies that miss fields,
  states that are not handled (paused, stopped, locked, part 2, performance mode, hidden tabs, empty lists);
- per-frame cost (CLAUDE.md performance rules): scans, allocations, repeated calculations, file access;
- saved data: new keys written only when used, old projects unchanged, parse / serialize symmetric;
- ReaImGui: pushes and pops paired, cursor not moved after the last item of a popup, modal dialogs deferred;
- comments, function names and constants that no longer match the feature.

## 3. Pass 2: senior UI/UX designer

Look for:
- texts: Help topics, tooltips, headings, messages and menu items that are wrong, old or inconsistent;
  the same word for the same thing everywhere; the "?" texts say where a setting is saved;
- layout: labels that wrap, duplicate names, controls in the wrong section, options split over 2 places;
- behaviour: every optional feature can be turned off; dangerous actions have an undo or a question;
  buttons and actions behave the same; locked or greyed controls are clear; stage use (dark, quick, safe).

## 4. Cross-review

Compare the 2 lists: merge duplicates, settle conflicts (for example "a question" against "an undo" on
stage), and sort by risk: bugs first, then texts (no risk), then visible changes (the user decides).

## 5. Feedback to the user

One list, numbered, in plain words: what is wrong, what the user would notice, the suggested fix.
Mark which items change what the user sees (they need the user's answer). Ask before fixing those.
Bugs, texts and internal clean-ups can be fixed after the user says go.

## 6. Fix

Follow CLAUDE.md and its patch rules: small changes, checks, tests (add a test for each fixed bug when
practical), deploy. Then the `ui-test` skill (ask first; it takes the focus) when menus, popups, tabs or
views changed.

## 7. Final full-code pass

Read the whole file once more, quickly, only for problems that the fixes made (new names, missed places,
broken pairs). Run check.ps1 and test.ps1 again. Update CLAUDE.md (architecture, files) and PLAN.md
(history, open items) when they are out of date.

## 8. Ask for the commit

Show a short summary of the round, then ask in one question (AskUserQuestion): UI test first, commit
and push (a release), commit only, or not yet. Then follow the `release` skill for what was chosen.
