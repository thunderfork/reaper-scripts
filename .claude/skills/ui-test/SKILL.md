---
name: ui-test
description: Run Chart Cue's UI test in the test REAPER (every tab, Settings section, right-click menu, page area) and keep it up to date. Use after changes to menus, popups, tabs, Settings sections, the toolbar or the page area, before a release, or when the user says "UI test".
---

# UI test

`tools\ui-test.lua` (the steps) and `tools\ui-test.ps1` (the runner). It runs in the portable test
REAPER `C:\REAPERtest`, never the normal REAPER, and it never touches the user's REAPER or data.
It covers Chart Cue only: Segue and MIDI Pilot have no UI test yet (PLAN.md); say so in the report.

## Before running

- It needs a visible window and takes the focus for about 1 minute: ask the user first, in one line
  (CLAUDE.md). A "yes" covers that one run only.
- Update the steps first when something new can be opened:
  - a new right-click menu: `R.menu_req = { kind = "...", ... }` with real data;
  - a new tab or Settings section: the tab number (`S.tab`) and the section string (`S.settings_open`,
    one digit per section in SETTINGS_SECTIONS order);
  - a new view or mode: switch it on, then also with playback, pause, performance mode and lock;
  - a renumbered tab or section: fix the old steps too.
  Each step is `{ "name", function() ... end, seconds }`; give menus about 1-1.5 s.

## Run

- `.\tools\test.ps1` first (logic tests), then `.\tools\ui-test.ps1`.
- The runner prints the error lines (ERROR / TRACE / CONSOLE) and ends with
  "UI test: N steps, no errors" or the reason it failed.

## Report

The number of steps and what they covered, in plain words. Say that it finds crashes and error
messages, not wrong looks or behaviour: the user's manual test in REAPER is still needed.
