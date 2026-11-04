# Chart Cue development

Chart Cue is a Windows-only REAPER Lua/ReaImGui script for displaying and
scrolling PDF charts during playback.

Repository: `thunderfork/reaper-scripts` (https://github.com/thunderfork/reaper-scripts), shown in
ReaPack as "Thunderfork Scripts". It is meant for all my REAPER scripts; today it holds only Chart Cue.
When a second script arrives, split this file into general rules and per-script rules.

Main file: `Chart Cue/Chart Cue.lua` (the `Chart Cue` folder is the ReaPack category; keep the scripts there).

## Working with me

- I do not read code. I decide what Chart Cue looks like and how it behaves (GUI and taste);
  you decide the technical details.
- Before a change, explain in plain words what I will see or notice, and ask me only about
  visible behaviour, layout and wording. Do not show diffs or code unless I ask.
- Ask me before any change to what is saved in my projects or settings, or before removing
  a feature or a control.
- After editing, list only the functions changed, and the manual test I should do in REAPER.
- Deploy after every change to the scripts (after the checks pass), without waiting to be told.
- Take screenshots (`.\tools\shots.ps1`) only when I agree; ask first, in one line.
- Commit and push only when I ask.

## Editing rules

- Never output or rewrite the entire `Chart Cue.lua` file.
- Make the smallest focused change possible.
- Preserve the existing architecture, naming style, and user-facing behaviour.
- Do not change user-facing behaviour unless explicitly requested.
- Do not introduce external dependencies without asking.
- Keep the files' LF line endings (core.autocrlf can turn them into CRLF). Check for CRLF after
  writing a file with PowerShell.

## Patch rules (large edits to Chart Cue.lua)

- Write a patch script (Python: exact text -> new text, each must match exactly once, else stop without
  writing) with the Write tool into the scratchpad, then run it. Never inline it in a shell heredoc or a
  `python -c` string: the shell changes `\n`, `\t` and backslashes (this broke tests and Windows paths).
- Use raw strings (r'''...''') for Lua text with backslashes or `\0`; check the result for real tab or
  newline characters where `\t` / `\n` were meant.
- Copy the old text from a fresh Read: code inside a block that was indented later has more spaces.
- A small change: the Edit tool, not a script.

## Saved data (compatibility)

- Do not change the format of the project data (ExtState "ChartCue"/"cfg") or existing
  settings.ini keys. Add new keys only, with defaults.
- Write a new project key only when it differs from its default: Chart Cue compares the saved
  text to tell "Save as" from "Open another project".
- Keep reading and writing old project keys unchanged (e.g. `fixed_start`), for the same reason.
- A settings.ini key that nothing reads may be removed, with my approval.

## REAPER/Lua constraints

- Target REAPER's embedded Lua runtime on Windows (Lua 5.4).
- Prefer `reaper.*` functions. Use `io` / `os` only for files and processes, as the existing code
  does (settings, cache, copies, helper scripts); never for things REAPER has an API for.
- Do not assume external Lua libraries are installed.
- Preserve REAPER-compatible path handling.
- ReaImGui API is pinned to 0.9.3 (shim). Some calls return 2 values: wrap them in parentheses
  when they are the last argument of a call (e.g. `math.max(1, (ImGui.CalcTextSize(ctx, s)))`).

## Architecture

- `CFG`: constants, paths, and defaults. `COL`: the colours.
- `S`: global settings persisted in `settings.ini`.
- `R`: volatile runtime state.
- `P`: per-project configuration stored in the REAPER project.
- `Util`: small helpers (paths, files, time, settings load / save).
- `PDF`: PDF info, rendering, cache, and page images.
- `Project`: regions, markers, library, and project configuration.
- `Cues`: the cue list (per region, in the project data) and its undo.
- `Notes`: text notes on the pages (P.notes).
- `Setlist`: the show order (P.setlists), its playback (stop / continue / pauses) and its undo.
- `Nav`: page, scroll, zoom, and autoscroll logic.
- `Midi`: MIDI input and CC handling, and the commands of the action scripts.
- `Msg`: messages, errors and the diagnostic log.
- `Dock`: docking, window position and size, the resize edges.
- `Autostart`: "Open automatically" (the block in `__startup.lua` and `autostart.lua`).
- `UI`: ReaImGui interface and main deferred loop.

Do not move state between `CFG`, `S`, `R`, and `P` without asking.

## Performance rules

- The UI update loop runs every frame; treat it as hot code.
- Do not allocate tables, concatenate display strings, sort lists, scan folders, or query the filesystem every frame unless unavoidable.
  (Short labels with live values, such as "Page 3 / 12", are fine; cache what does not change between frames.)
- Cache stable labels, formatted strings, directory listings, and lookup tables outside the frame loop.
- Invalidate caches explicitly when their source data changes.
- Poll background PDF jobs at most every 100 ms.

## Verification

- After editing, run `.\tools\check.ps1` before deploying. It must end with "Syntax and globals OK":
  1. syntax (`luac -p`, Lua 5.4.6 from winget DEVCOM.Lua),
  2. undefined globals (from the `luac -l` listing; allowed: standard Lua and `reaper`),
  3. Lua Language Server warnings (information only).
- Compare Language Server warnings with the known false alarms (17 "Need check nil" /
  "unknown|nil" warnings on 2026-11-04); look at every new one.
- For logic changes (navigation, autoscroll, project data, cache), also run `.\tools\test.ps1`. It runs
  `tests\run.lua` in the portable test REAPER `C:\REAPERtest` (never the normal REAPER) and must
  end with "0 failed". Add a test for each fixed bug when practical. The test REAPER can run while
  my normal REAPER is open; never close or save my REAPER. test.ps1 starts it in the background
  (tools\background.ps1), so my window keeps the focus.
- For UI code that the tests do not reach (menus, popups, tabs, Settings sections, views), run the UI
  test (`.\tools\ui-test.ps1`, steps in `tools\ui-test.lua`; add a step for each new thing), before
  deploying when practical. It needs a visible Chart Cue window and takes the focus for about a minute:
  ask me first, in one line.
- These checks do not replace a test in REAPER.
- Ensure ReaImGui calls remain valid in their intended UI/deferred-loop context.
- Do not claim a change is tested unless I have tested it in REAPER.
- If a change affects rendering, scrolling, MIDI, caching, or project state, state the manual test I should perform.

## Deployment

- Development copy: `Chart Cue/Chart Cue.lua` in this repository, and the action scripts
  `Chart Cue - Next page.lua`, `Chart Cue - Previous page.lua`, `Chart Cue - Toggle performance mode.lua`,
  `Chart Cue - Next song.lua`
  in the same folder.
- Deploy with:

```powershell
.\tools\deploy.ps1
```

- Deployed copy (the REAPER actions run it), the first folder that exists:
  1. `%APPDATA%\REAPER\Scripts\Thunderfork Scripts\Chart Cue\` (the ReaPack install),
  2. `%APPDATA%\REAPER\Scripts\thunderfork\Chart Cue\` (the ReaPack install before the rename on 2026-11-03),
  3. `%APPDATA%\REAPER\Scripts\`.
- Chart Cue's data folder, on every user's computer: `%APPDATA%\REAPER\Data\Chart Cue\` (since 2026-11-03)
  (`settings.ini`, `cache\`, `tmp\`, `autostart.lua`, `Chart Cue Guide.html`; the script writes them).
  Reading it is OK. Never change, move or delete anything there without asking me first: it holds
  my real settings, and the `__startup.lua` block points to `autostart.lua` in it.

## Other files

- `PLAN.md`: done work, open items and the release checklist.
- `.claude/skills/`: `debug-time` (the review round: senior developer, UI/UX designer, cross-review, feedback,
  fixes, final full-code pass, then the commit / push question), `release` (version, commit, push, ReaPack
  workflow, GitHub Release), `ui-test` (run and extend the UI test), `new-feature` (plan and questions before
  code), `help-sync` (every text that names a changed feature).
- `README.md`: for other users. `tools\`: check.ps1 (with `.luarc.json`: the static checks), test.ps1,
  deploy.ps1, release.ps1, shots.ps1, ui-test.ps1 (with ui-test.lua: the UI test). `tests\`: run.lua (logic tests), shots.lua, test.pdf.
- `LICENSE` (MIT). `tools\release.ps1`: makes `release\Chart-Cue-<version>.zip` (git-ignored).
- `.github/workflows/reapack-index.yml`: GitHub builds `index.xml` (the ReaPack repository
  file) after each push to main. Do not edit `index.xml` by hand.
- Temporary files (test logs, helper scripts): in the scratchpad folder, never in the repository.

## Git

- Write commit messages with `git commit -m "..." -m "..."` (not from a file written by PowerShell
  or the Write tool: they add a byte-order mark to the title).
- End each commit message with the `Co-Authored-By` line.
- After each push, check that the "ReaPack index" workflow succeeded (`gh run list`); if it failed,
  ReaPack users do not get the update. Then `git pull` the new `index.xml`.

## Releasing a version

1. Run the release checklist in PLAN.md (in REAPER).
2. Raise `@version` and `CFG.VERSION` together; write 1-3 user-facing `@changelog` lines.
3. Commit and push (when I ask). Check the "ReaPack index" workflow; ReaPack users then get the update.
4. `.\tools\release.ps1`, then create the GitHub Release with `gh` (logged in as
   thunderfork): tag `vX.Y` on main, title "Chart Cue X.Y", the changelog lines as notes, and the zip.

Every time I ask to commit and push:
- If the scripts in `Chart Cue/` changed, the commit is a new version: do steps 2-4 above
  (raise the version, commit and push, check the workflow, then create the GitHub Release and upload
  the zip) without asking again.
- If only other files changed (CLAUDE.md, PLAN.md, README.md, tools, tests), commit and push without
  a new version or release, and say so.
