# MIDI Pilot

"MIDI editor for amp modelers": it prepares the MIDI for a Quad Cortex / Quad Cortex mini or a Line 6 Helix, HX
Stomp, HX Stomp XL or HX Effects (the Line 6 profiles are untested). No relation to the other scripts. Screens: tabs
Songs (with Songs > Tools), Lanes, Presets; Settings sections Devices, Editing, Appearance, General.

## Rules

- The MIDI is normal REAPER MIDI on the device tracks; the show never needs the window.
- A preparation tool: no live features (no automatic sending during playback, no stage actions, no MIDI clock;
  live chase was removed for this reason). Suggest only editing, checking, viewing and
  export features.
- Changes to the Quad Cortex controls stay Quad Cortex only, unless I say otherwise.
- Every visible text (labels, menus, buttons, headings, Help, tooltips, messages, undo names) writes "Preset",
  "Presets", "Scene", "Scenes" with a capital, also mid-sentence ("Clear all Scenes..."); not in code comments or
  internal ids (the unit's own terms).

## Files

- `MIDI Pilot.lua`. Roadmap (version 2): "Later" below.
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

## Later (ideas)

- MIDI Pilot version 2: Record (a real pedal move into Lanes, from the unit's Preset MIDI Out expression messages)
  and Learn, copy Scenes between songs, a check report, a cue sheet, import / export of the names, Looper X
  (CC#48-61) in its own section. Only if a user asks: "Scenes like..." (copy another song's Scenes). The Line 6
  profiles are untested (no units).

## Open findings (from a checkup; not decided: ask before a fix)

- Bugs: `Project.update` does not see File > Open in the same tab (only the pointer; use the file name / saved text
  check as FX Link and Segue). `Midi.take_at` extends the first item over all later items (use the nearest item
  before t). `Util.reset_settings` undocks and jumps to Songs (keep S.dock, S.tab, R.dock_req). A track mode change:
  `Dev.apply_latency` with latency 0 wipes the user's playback offset (guard `d.latency > 0` as in
  `Dev.use_selected_track`); the Channel combo in Settings > Devices does not clear `R.pcs`. Empty undo points
  (`Midi.fill_item_starts` in scene_edit, fill_starts, match_* with n == 0).
- Per-frame costs: the scene strip blocks, the scene list rows and their sort, the Preset list UI.trunc.
- Ideas: "Check new MIDI items" changes the device channel, the Help says the reverse; no empty / taken check for
  device, folder and Preset names and control CCs (rule `saved-data`); Help text errors.
