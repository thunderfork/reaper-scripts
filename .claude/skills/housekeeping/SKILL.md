---
name: housekeeping
description: Read-only audit of the repository (everything except the scripts) - old or duplicate files, useless tests, outdated docs, skills, the folder CLAUDE.md files - with a short report; nothing changes until the user approves. Use when the user says "housekeeping" or asks for a cleanup / tidy-up / audit of the project folder, and before a major release (x.0).
---

# Housekeeping

## Scope

- In scope (may be changed after approval): README.md, PLAN.md, the root and folder CLAUDE.md files,
  `.claude/skills/`, `tests/*.lua`, `tools/ui-test.lua`, `tools/known-warnings.txt`, `.luarc.json`, `.gitignore`.
  A change to a test, ui-test.lua or .luarc.json: run check.ps1 and the tests after it.
- Inspect only: the scripts (`Chart Cue/*.lua`, `Segue/*.lua`, `MIDI Pilot/*.lua`), `tools/*.ps1`,
  `.github/workflows/`, `index.xml` (generated: never edit it).
- Report only, never change: anything outside the repository (the deployed copies in `%APPDATA%\REAPER\Scripts\`,
  Chart Cue's data folder, the user's REAPER) and Claude's memory folder.

## What to find

1. Old, unused or duplicate files and folders. Before calling a file unused, search its name in `tools/*.ps1`
   (they copy by pattern), the `@provides` lines, `.github/workflows/`, `.gitignore`, the skills and the docs.
   Git-ignored files (`release/`, `tests/result*.txt`) are generated, not unused: list them apart.
2. Tests that test removed or renamed features, duplicates, placeholders.
3. Documents and skills that are wrong or out of date: paths, commands, versions, feature names, settings paths
   (the `help-sync` search), rules that contradict CLAUDE.md, a rule written in 2 places (CLAUDE.md, a folder
   CLAUDE.md, a skill, the memory: 1 place per rule).
4. Structure: files in the wrong folder, unclear names.

## Report (plain words, exact paths)

- A short project snapshot (2-3 lines).
- The findings, highest risk first: for each, the problem, where, the evidence (1 line), and the proposed change
  (with the replacement text when it is short).
- Deletions apart: each path, why it is unused, what was searched.
- A short plan: safe clean-ups, document updates, the user's decisions, things to leave.

Change nothing before the user approves. A tracked file is deleted only after an explicit yes for that file.

## After the approval

Only the approved changes; LF line endings; check.ps1 and the tests when a test or a tool reference changed. A commit
with no `.lua` change is not a new version.
