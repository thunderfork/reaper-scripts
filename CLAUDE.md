# Thunderfork REAPER scripts: development

Repository `thunderfork/reaper-scripts` (https://github.com/thunderfork/reaper-scripts), shown in ReaPack as
"Thunderfork Scripts". 7 separate scripts, each in its own folder (the folder is the ReaPack category; keep each
script's files there). Each folder has its own CLAUDE.md with its modules, data, tests and release details:

- **Chart Cue** (`Chart Cue/`): Windows-only; shows and scrolls PDF charts during playback. The UI style guide.
- **Segue** (`Segue/`): setlist only (no PDFs); shares its setlist logic and now playing view with Chart Cue.
- **MIDI Pilot** (`MIDI Pilot/`): prepares the MIDI for amp modelers (Quad Cortex, Line 6). A preparation tool.
- **FX Link** (`FX Link/`): links plugin instances across tracks (Exact / Relative). Small Chart Cue look, no tabs.
- **Session Prep** (`Session Prep/`): cleans up a multitrack import (names, colors, folders, pairs, checks).
  A preparation tool; Chart Cue look with tabs; in the project only a mark on each prepped track.
- **SFX Drop** (`SFX Drop/`): puts impacts, risers, drops and atmospheres from a library on the beat (hit points).
  A preparation tool; Chart Cue look with tabs; in the project only its Soundcheck list (its library index is in Data\SFX Drop).
- **Mono Merge** (`Mono Merge/`): joins 2 mono items into 1 stereo file. 2 actions, no window (no ReaImGui),
  no saved data.

The rules below apply to all 7 scripts ("the script" = the script being changed).

- Size: full (decided 21 November 2026). Platforms: REAPER (Lua ReaScript and ReaImGui); no global platform file
  yet: the REAPER knowledge is in "REAPER, Lua and ReaImGui" below.
- @LESSONS-RULES.md

## Users

- A musician on stage (Chart Cue, Segue): little time, low light, must see the next thing at a glance; a wrong
  click must not stop the show.
- A studio or live engineer preparing a session (MIDI Pilot, FX Link, Session Prep, SFX Drop, Mono Merge): speed of
  preparation, what REAPER really does to the tracks, undo.
- Experts (besides the senior developer and the UI/UX designer): QA tester (empty projects, playing / stopped,
  project switch), REAPER and ReaImGui specialist, a ReaPack user who installs the scripts for the first time.

## Working with me

My global rules (`%USERPROFILE%\.claude\CLAUDE.md`) apply. This project adds or changes these:

- The mockup rule also covers a new control, view, layout, interaction or visual behaviour that I asked for in a
  few words.
- Chart Cue is the UI style guide: the other scripts copy its look and behaviour (theme, title bar, docked-tab
  triangle, resize edges and grip, spacing, headings, toggles, rows, buttons). After a change to Chart Cue's UI,
  list the same change for each other script and ask me before you make it.
- Saved data: see "Saved data" below for what counts.
- Deploy is automatic (instead of waiting for "build"): after every change to a script, run the checks, then
  `.\tools\deploy.ps1`.
- Commit, push and release only when I ask (instead of 1 commit after each change).
- Ask first, in one line, before screenshots (`.\tools\shots.ps1`) or the UI test (it takes the focus).
- Prefer 1 session per topic (a feature or a release).
- Code checker: `.\tools\check.ps1` (Lua Language Server, globals, ImGui balance).
- The checks of the global rules, in this project: `debug-time` is the `debug-round` (bugs); "before a build" means
  before a deploy that I will test in REAPER; the checks before a push are in the `release` skill (they replace
  the global `checkup` before a push). `checkup` before a large change and every 30 days ("Last checkup" in PLAN.md).
- Manual tests in REAPER: remind me to close and start the script again first (it loads the new version).
- Open the repository folder (`Chart Cue`), not its parent `Reaper Scripts`: else this file, the session-start hook
  and the project skills do not load.

## Look and words (all scripts with a window)

- Every optional feature (a visual aid, a warning, a note, an overlay) has an off switch in Settings; say its
  default. A section that I can fold (its closed state saved) needs no extra switch (decided 9 November 2026).
- Short choices (2-3) stay dropdowns or toggles, never joined (segmented) buttons. Blue is the colour of the main
  action buttons ("press me"), never the colour of a selected state (decided 2 November 2026).
- Help texts are friendly and casual: short leading questions ("Made a mistake?"), "you", the benefit first and the
  technical detail after it in brackets. Facts and "Settings > ..." paths stay exact (decided 10 November 2026).
  New labels, tooltips and notices use the existing word style of the script.
- Template: "+ Add" is a ghost button on the heading line, and its menu drops down below it; an empty list is 1 grey
  line "No ... yet. <what to do>."; yellow only for real warnings.

## Commands

- Bash for git, gh and searches; PowerShell only to run the `.ps1` tools. Always use the repository's absolute path
  (no relying on the current folder).
- The tools are quiet: `check.ps1`, `test.ps1` and `deploy.ps1` print 1 summary line, and the details only on a
  failure or a new warning. Use `-Full` only when you need the details.

## Editing

- Never output or rewrite a whole script file (`Chart Cue.lua`, `Segue.lua`, `MIDI Pilot.lua`).
- Make the smallest focused change. Keep the architecture, the naming style and the user-facing behaviour.
- No external dependencies (Lua libraries, programs) without asking.
- Keep the LF line endings (core.autocrlf can turn them into CRLF); check for CRLF after a PowerShell write.
- Use the Edit tool (the global "Do not" rules). A patch script only for many identical changes: written with the
  Write tool into the scratchpad, exact old text -> new text, each must match exactly once, else stop without
  writing. Use raw strings (r'''...''') for Lua text with backslashes or `\0`. Copy the old text from a fresh Read.

## Saved data

- What counts as saved data: the project data (ProjExtState "ChartCue"/"cfg", "Segue"/"cfg", "MIDI Pilot"/"cfg", "FX Link"/"cfg";
  Session Prep's track mark `P_EXT:SessionPrep`),
  the settings (Chart Cue's `settings.ini`, the ExtState "Segue", "MIDI Pilot", "FX Link", "Session Prep" and "SFX Drop" keys; SFX Drop's `library.txt` and ProjExtState "SFX Drop"/"soundcheck"), their defaults, and the
  files in Chart Cue's data folder (including the autostart block). Ask me before you change any of them.
- Current decision (November 2026; the scripts are public on ReaPack, but I treat them as without other users):
  no migration code, no old keys, no fallback to old names or folders. Write clean code for a new user. Ask me
  before you change this.
- New keys get defaults. Write a project key only when it differs from its default (Chart Cue compares the saved
  text to tell "Save as" from "Open another project").

## REAPER, Lua and ReaImGui

- REAPER's embedded Lua 5.4 on Windows. Prefer `reaper.*`; use `io` / `os` only for files and processes, as the
  existing code does; never for something that REAPER has an API for. Keep REAPER-compatible path handling.
- ReaImGui is pinned to 0.9.3 (the shim). A call that returns 2 values: wrap it in parentheses when it is the
  last argument of a call (`math.max(1, (ImGui.CalcTextSize(ctx, s)))`).
- Call End / EndChild / EndPopup only when its Begin returned true; keep pushes and pops paired; keep ReaImGui
  calls in their UI / deferred-loop context.
- Do not move state between `CFG`, `S`, `R` and `P` without asking (`CFG` constants, `COL` colours, `S` settings
  of this computer, `R` runtime, `P` project data: the same in the 6 scripts with a window (Mono Merge has none of them); Session Prep has no `P`, only its track mark).

## Performance

- The UI loop runs every frame: hot code. Do not allocate tables, build strings that do not change, sort, scan
  folders or query the file system every frame. Cache stable labels, lists and lookups; invalidate the cache when
  its source changes. (Short live labels such as "Page 3 / 12" are fine.)

## Verification

- After editing: `.\tools\check.ps1` must print "Syntax and globals OK" (syntax with `luac -p`, undefined
  globals, then Lua Language Server warnings as information). It compares the warnings with
  `tools\known-warnings.txt` and shows only new ones: look at each new one; fix it, or (a false alarm) run
  `.\tools\check.ps1 -UpdateKnown`. It also runs `tools\docs-check.ps1`: paths, skill names and "Settings > ..."
  paths in the docs and skills that no longer match; fix each one it reports. And `tools\imgui-check.ps1`: the
  ImGui Push / Pop balance of each function; a new finding: fix it, or (a helper that pushes for its caller, a
  false alarm) run `.\tools\imgui-check.ps1 -UpdateKnown` (`tools\imgui-known.txt`).
- Test gaps: `.\tools\test.ps1 -Script "<name>" -Coverage` lists the functions that the tests never run
  (`tests\coverage_<test file>.txt`); use it to find where a test is missing (the `lessons` skill, step 5).
- For logic changes: `.\tools\test.ps1 -Script "<the changed script>"` (all scripts only before a release); it
  must end with "0 failed". An escaped bug (found by me in REAPER, or by `debug-time`): the `lessons` skill
  (a test that fails first, the fix, a search of the other scripts, an entry in `LESSONS.md`). The tests run in the portable test
  REAPER `C:\REAPERtest`, in the background; never use, close or save my normal REAPER.
- For UI code that the tests do not reach: the UI test (`ui-test` skill; Chart Cue only), after asking.
- State the manual test when a change affects rendering, scrolling, MIDI, caching or project state.
- Pre-commit hook (`tools\hooks\pre-commit`): when `.lua` files of a script are staged, it runs `check.ps1` and the
  tests of those scripts, and stops the commit on a failure.

## Git and releases

- Commit messages: `git commit -m "..." -m "..."` (not from a file written by PowerShell or the Write tool: a
  byte-order mark), ending with the `Co-Authored-By` line.
- Every time I ask to commit and push: changed `.lua` files in a script folder are a new version of that script
  (version, changelog, push, ReaPack check, GitHub Release with its zip), without asking again. Only other files
  changed (docs, the folders' CLAUDE.md, tools, tests, skills): commit and push without a version, and say so.
  Follow the `release` skill.
- After each push: the "ReaPack index" workflow must succeed (`gh run list`), then `git pull` the new
  `index.xml`. Never edit `index.xml` by hand.
- A script that is not released has `Released = $false` in `tools\scripts.psd1`: `@noindex` in its .lua files and
  its README part hidden (`<!-- -->`). The pre-push hook (`tools\hooks\pre-push`, `git config core.hooksPath
  tools/hooks`) runs `tools\publish-check.ps1` and stops a push that would publish it.
- A new script starts on its own branch (`script/<name>`), with its docs and its line in `tools\scripts.psd1`; it
  merges into main at its first release. (SFX Drop is the exception: it was on main before this rule.)

## Other files

- `PLAN.md`: Handoff (with "Last checkup"), Open now (numbered; the open manual tests too), Later (ideas and the
  roadmap of each script). No done work: git records it.
- `LESSONS.md`: the escaped bugs and their cause tags (`lessons` skill). `LESSONS-RULES.md`: the rules that came
  from them (loaded above).
- `README.md`: for users. `LICENSE`: MIT.
- `.claude/skills/`: `release`, `debug-time` (the review round), `ui-test`, `housekeeping` (read-only audit, changes
  only after my approval), `new-feature` (plan and questions before code), `help-sync` (every text that names a
  changed feature), `lessons` (the self-improvement routine for escaped bugs).
- `tools\scripts.psd1`: the 1 list of the scripts (name, test file, tag, released); every tool reads it.
- `tools\`: check.ps1 (with `.luarc.json` and `known-warnings.txt`; it also runs publish-check.ps1 and imgui-check.ps1), test.ps1 (`-Coverage`), deploy.ps1, release.ps1 (`-Script "<name>"`: the zips in
  the git-ignored `release\`), shots.ps1, ui-test.ps1 / ui-test.lua, background.ps1, session-start.ps1 (the state
  at each session start: the SessionStart hook in `.claude\settings.json`), `hooks\pre-push`, `hooks\pre-commit`.
- `tests\`: run.lua (Chart Cue), segue.lua, midipilot.lua, fxlink.lua, sessionprep.lua, sfxdrop.lua, shots.lua, test.pdf (make_pdf.lua makes it; run it with
  the normal Lua, not REAPER).
- Temporary files (test logs, helper scripts): in the scratchpad folder, never in the repository.
