# MIDI Pilot

"MIDI editor for amp modelers": it prepares the MIDI for a Quad Cortex / Quad Cortex mini or a Line 6 Helix, HX
Stomp, HX Stomp XL or HX Effects (the Line 6 profiles are untested). No relation to the other scripts. Screens: tabs
Songs (with Songs > Tools), Lanes, Presets; Settings sections Devices, Editing, Appearance, General.

## Rules

- The MIDI is normal REAPER MIDI on the device tracks; the show never needs the window.
- A preparation tool: no live features (no automatic sending during playback, no stage actions, no MIDI clock;
  live chase was removed for this reason, decided 8 November 2026). Suggest only editing, checking, viewing and
  export features.
- Changes to the Quad Cortex controls stay Quad Cortex only, unless I say otherwise.
- Every visible text (labels, menus, buttons, headings, Help, tooltips, messages, undo names) writes "Preset",
  "Presets", "Scene", "Scenes" with a capital, also mid-sentence ("Clear all Scenes..."); not in code comments or
  internal ids (decided 10 November 2026: the unit's own terms).

## Files

- `MIDI Pilot.lua`. Version: `@version` and `CFG.VERSION` together. Release: tag
  `midipilot-vX.Y`, title "MIDI Pilot X.Y" (the `release` skill).
- Roadmap (version 2): PLAN.md, "Later". The history: the git log and the `@changelog` lines.
- Not checked: the full-size Quad Cortex's USB port name (no unit; it contains "Cortex").

## Architecture and data

- `MODELS`: the device profiles (presets, folders, msb, scene CC and count, reserved CCs, the Quad Cortex
  functions for Lanes). `S` (this computer, ExtState "MIDI Pilot"): the devices (1 line each, with the preset
  number format), the preset / folder / scene names, the expression pedal assignments (`exp_<device>`), the controls
  (`knb_<device>`), the settings (also `lanes_open`: the open Lanes sections; `start_skip` / `start_hide`: the Getting started list; `preset_sort`: the Preset list sort; `tb_hide`, `tb_off`: the toolbar; `tab_hide`: the hidden tabs; `comfortable`: the spacing). The LFO, swell and ramp groups of
  the Values list are found by their pattern (`Midi.find_groups`, like the Scene test): nothing is saved for them. Multi-line values go through `Util.ext_set` / `Util.ext_get` (REAPER keeps only
  the first line of a value). `P` (ProjExtState "MIDI Pilot"/"cfg"): the device tracks, the track mode, the export
  folder, the ignored Scene tests.
- Modules: `Util`, `Project`, `Dev` (devices, MIDI outputs, tracks, track and device names), `Preset` (numbers,
  names, .reabank), `Knob` (Lanes controls and pedals), `Midi` (preset, scene and CC changes in the MIDI items, the
  MIDI file export), `UI` (tabs: Songs, Lanes, Presets, Settings, Help).
- Only the MIDI that REAPER plays is read (no muted items or events); a muted item is never written.

## Deployment and tests

- `.\tools\deploy.ps1` copies it to `Scripts\Thunderfork Scripts\MIDI Pilot\` (ReaPack), else `Scripts\MIDI Pilot\`.
- Tests: `tests\midipilot.lua` (`.\tools\test.ps1 -Script "MIDI Pilot"`; result in `tests\result_midipilot.txt`).

## Later (ideas, moved from PLAN.md 24 November 2026)

- MIDI Pilot version 2: Record (a real pedal move into Lanes, from the unit's Preset MIDI Out expression messages)
  and Learn, copy Scenes between songs, a check report, a cue sheet, import / export of the names, Looper X
  (CC#48-61) in its own section. Only if a user asks: "Scenes like..." (copy another song's Scenes). The Line 6
  profiles are untested (no units).
