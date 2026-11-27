# Thunderfork REAPER scripts: development

Repository `thunderfork/reaper-scripts` (https://github.com/thunderfork/reaper-scripts), shown in ReaPack as
"Thunderfork Scripts". Separate scripts, each in its own folder (the folder is the ReaPack category; keep each
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
- **Tab Viewer** (`Tab Viewer/`): Guitar Pro tabs in the project, and its Detection tab (the bass notes as
  markers). Chart Cue look with tabs. Its shared files and the Detection notes: its folder CLAUDE.md.

The rules below apply to all the scripts ("the script" = the script being changed).

- Size: full. Platforms: REAPER (Lua ReaScript and ReaImGui); no global platform file
  yet: the REAPER knowledge is in "REAPER, Lua and ReaImGui" below.
- @LESSONS-RULES.md

## Users

- A musician on stage (Chart Cue, Segue): little time, low light, must see the next thing at a glance; a wrong
  click must not stop the show.
- A studio or live engineer preparing a session (MIDI Pilot, FX Link, Session Prep, SFX Drop, Mono Merge,
  Tab Viewer): speed of preparation, what REAPER really does to the tracks, undo.
- A bass player who learns a part in REAPER (Tab Viewer: the tab, and the markers of its Detection tab): easy songs, reads
  the note names on the screen.
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
- Deploy is automatic (instead of waiting for "build"): after each finished change to a script (not after each
  edit), run the code checker and the tests of that script 1 time, then `.\tools\deploy.ps1`. A test run is slow:
  write all the code of the change first, then 1 run; after a failure, fix all you can see, then 1 run again.
- Commit and back up automatically; push to the public repository and release only when I ask ("Git and
  releases").
- Ask first, in one line, before screenshots (`.\tools\shots.ps1`) or the UI test (it takes the focus).
- Prefer 1 session per topic (a feature or a release).
- A change with many parts or many tests: build it in segments and ask me before each segment. A request with more
  than 3 changes: build about 3, report them, then go on with the next ones.
- The notes for later sessions (`NOTES.md`, the folder and project `CLAUDE.md`): update them 1 time at the end of
  the topic, with the handoff, not after each change. Tooltips, labels, notices and code comments stay part of each
  change; the Help topics (the "?" tab) are updated 1 time before a release (the `release` skill).
- The limit of open manual tests (more than 3: no new feature) counts only the tests of the script being developed.
- The checks of the global rules, in this project: `debug-time` is the `debug-round` (bugs); "before a build" means
  before a deploy that I will test in REAPER; the checks before a push are in the `release` skill (they replace
  the global `checkup` before a push). `checkup` before a large change and every 30 days ("Last checkup" in PLAN.md).
- Manual tests in REAPER: remind me to close and start the script again first (it loads the new version).
- Open the repository folder (`Reaper Scripts`), not a script folder such as `Chart Cue`: else this file, the
  session-start hook and the project skills do not load.

## Look and words (all scripts with a window)

- Every optional feature (a visual aid, a warning, a note, an overlay) has an off switch in Settings; say its
  default. A section that I can fold (its closed state saved) needs no extra switch.
- Short choices (2-3) stay dropdowns or toggles, never joined (segmented) buttons. Blue is the colour of the main
  action buttons ("press me"), never the colour of a selected state.
- Help texts are friendly and casual: short leading questions ("Made a mistake?"), "you", the benefit first and the
  technical detail after it in brackets. Facts and "Settings > ..." paths stay exact.
  New labels, tooltips and notices use the existing word style of the script.
- Template: "+ Add" is a ghost button on the heading line, and its menu drops down below it; an empty list is 1 grey
  line "No ... yet. <what to do>."; yellow only for real warnings.

## Commands

- Bash for git, gh and searches; PowerShell only to run the `.ps1` tools. Always use the repository's absolute path
  (no relying on the current folder).
- The tools are quiet: `check.ps1`, `test.ps1` and `deploy.ps1` print 1 summary line, and the details only on a
  failure or a new warning. Use `-Full` only when you need the details.

## Editing

The global "Do not" rules apply (the Edit tool, no whole-file rewrites, patch scripts). This project adds:

- Keep the architecture, the naming style and the user-facing behaviour. No external dependencies without asking.
- Keep the LF line endings (core.autocrlf can turn them into CRLF); check for CRLF after a PowerShell write.
- A patch script: raw strings (r'''...''') for Lua text with backslashes or `\0`; the old text from a fresh Read.

## Saved data

- What counts as saved data: the project data (ProjExtState "ChartCue"/"cfg", "Segue"/"cfg", "MIDI Pilot"/"cfg", "FX Link"/"cfg",
  "Tab Viewer"/"cfg" and its copies in the "Tabs" folder next to the project file, "Tab Viewer"/"notes" (the Notes
  lists, 1 per song); Session Prep's track mark `P_EXT:SessionPrep`; Tab Viewer's Notes mark `P_EXT:TabViewer`),
  the settings (Chart Cue's `settings.ini`, the ExtState "Segue", "MIDI Pilot", "FX Link", "Session Prep", "SFX Drop" and "Tab Viewer" keys; SFX Drop's `library.txt` and ProjExtState "SFX Drop"/"soundcheck"), their defaults, and the
  files in Chart Cue's data folder (including the autostart block). Ask me before you change any of them.
- Current decision (the scripts are public on ReaPack, but I treat them as without other users):
  no migration code, no old keys, no fallback to old names or folders. Write clean code for a new user. Ask me
  before you change this.
- New keys get defaults. Write a project key only when it differs from its default (Chart Cue compares the saved
  text to tell "Save as" from "Open another project").

## REAPER, Lua and ReaImGui

- REAPER's embedded Lua 5.4 on Windows. Prefer `reaper.*`; use `io` / `os` only for files and processes, as the
  existing code does; never for something that REAPER has an API for. Keep REAPER-compatible path handling.
- ReaImGui is pinned to 0.9.3 (the shim). A call that returns 2 values: wrap it in parentheses when it is the
  last argument of a call (`math.max(1, (ImGui.CalcTextSize(ctx, s)))`).
- `reaper.array` and the audio accessor give silence inside a Lua coroutine: read the audio outside of it.
- Call End / EndChild / EndPopup only when its Begin returned true; keep pushes and pops paired; keep ReaImGui
  calls in their UI / deferred-loop context.
- The state tables (`CFG` constants, `COL` colours, `S` settings of this computer, `R` runtime, `P` project data;
  moving a value between `S` and `P` changes saved data): the same in the scripts with a window (Mono Merge has none of them; Tab Viewer's Notes.lua has its own `S`, `R`, `P` for the list); Session Prep has no `P`, only its track mark).

## Performance

- The UI loop runs every frame: hot code. Do not allocate tables, build strings that do not change, sort, scan
  folders or query the file system every frame. Cache stable labels, lists and lookups; invalidate the cache when
  its source changes. (Short live labels such as "Page 3 / 12" are fine.)

## Verification

- Code checker: `.\tools\check.ps1` (only the changed scripts; `-All`: all scripts) must print "Syntax and globals
  OK". A new warning, docs problem or ImGui finding: fix it, or (a false alarm) do what the tool's message says.
  It also checks that the small helpers copied into several scripts stay the same text (`tools\copy-check.ps1`).
- Tests: `.\tools\test.ps1 -Script "<the changed script>"` (all scripts only before a release) must end with
  "0 failed". They run in the portable test REAPER `C:\REAPERtest`, in the background; never use, close or save my
  normal REAPER.
- For UI code that the tests do not reach: the UI test (`ui-test` skill; Chart Cue only), after asking.

## Git and releases

- Commit messages: `git commit -m "..." -m "..."` (not from a file written by PowerShell or the Write tool: a
  byte-order mark), ending with the `Co-Authored-By` line.
- After each finished change (its checks, tests and deploy passed): 1 commit at once, without asking (the global
  "Git" rules). At each handoff: `git push backup main` (the private repository `reaper-scripts-backup`; no checks,
  the pre-push hook skips it). The public repository (`origin`) gets only releases. Never push work to `origin`
  outside a release: every branch there is public.
- Every time I ask to push or release: follow the `release` skill without asking again (a changed script gets a
  new version and a GitHub Release; only other files changed: no version). Never edit `index.xml` by hand.
- A new script starts on its own branch (`script/<name>`; its setup: the `new-feature` skill); it merges into main at
  its first release. (SFX Drop is the exception: it was on main before this rule.)

## Other files

- `PLAN.md` (the global sections); the ideas and roadmap of each script: "Later" in its folder CLAUDE.md.
- `LESSONS.md`: the escaped bugs and their cause tags (`lessons` skill). `LESSONS-RULES.md`: the rules that came
  from them (loaded above). `README.md`: for users.
- `tools\scripts.psd1`: the 1 list of the scripts (name, test file, tag, released, shared files); every tool reads
  it. Each tool in `tools\` describes its use in its first lines. A script's extra test files: its folder CLAUDE.md.
