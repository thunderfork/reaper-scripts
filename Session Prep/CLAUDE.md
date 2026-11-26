# Session Prep

Cleans up the tracks of a multitrack import in one step: Scan / Scan all (changes nothing) shows a preview table
(old name, new name, folder, notes, gain, Pan, M, S); Apply makes the ticked changes with 1 undo point
("Session Prep: apply"). A preparation tool: no project data, no live features. Chart Cue look with a tab strip:
Prep, Rules, FX Chains, Buses, Settings (gear), Help ("?"); the sections of Rules, FX Chains and Buses fold (arrows, `S.closed`;
the Rules list also folds each folder group, ids "rf_<folder>"); Settings has
collapsing sections (Appearance, Prep with Tracks / Routing / Checks, Gain staging, Window), 1 open at a time (`S.settings_open`), with a bold label column as in MIDI Pilot (`UI.form_label`,
`UI.form_toggle`).

## Files

- `Session Prep.lua` only.

## Architecture and data

- No `P`. In the project: only the mark `P_EXT:SessionPrep` (the date) on each prepped track (the ticked rows and
  the tracks that Apply made). Scan leaves marked tracks out; it is track data, so Ctrl+Z of the Apply removes it.
  After a prep, new tracks (overdubs) are scanned alone and join the folder of their rule that is there
  (`Prep.join_folders`: after its last track, `ReorderSelectedTracks(.., 2)`); no 2nd set of folders.
- `S` (ExtState "Session Prep"; a key is written only when it differs from its default): `light`, `dock`, `tab`,
  `preset` (index), `folders`, `spacer` (on), `caps` (Capital letters: all / fb / buses / none; default all),
  `color` (off), `color_win` (Colors win over SWS, off), `settings_open` (2), `pairs` (Pan L / R tracks),
  `audio` (on), `other_off` (the Other folder: no master output, on), `disarm` (record arm and input monitoring
  off at Apply, on), `pan_w_on` (Pan width: a Width column in the Prep table, `row.width`; off), `returns`
  (Make FX returns and sends, off), `closed` (the folded sections, "id,id"), `gain` (off), `gain_rms` (-18),
  `gain_peak` (-6), `gain_by_peak` (off), `gain_ptarget` (-10); the presets `presets_n` + `preset_1..N`, written
  only when they differ from the built-in ones ("Default", "Vocals first"); `preset_orig_N`: the original of an own
  preset (its text when made with Save as / Import), for "Reset to original" (a built-in preset uses its built-in
  text, `Rules.builtin_orig`, by name). Edits wait for Save: `p.saved` (the text at the last Save; `preset_saved_N`
  only while the preset has unsaved edits), `p.dirty` / `p.label` (`Rules.update_dirty`: the name with a dot; a
  rename is no edit), `Rules.save`, `Rules.revert`; "Save as" gives the new preset the edits and reverts the old one.
  The preset row: dropdown, disk icon (Save), Save as..., More... (Rename, Export, Import; red: Revert to saved,
  Reset to original, Delete preset), as Chart Cue's setlist "More...".
- A preset's text: 9 parts with "|": name | strip | rules (`match~name~folder~RRGGBB~pol`;...; pol: "" / "*" / a
  word as "Btm") | folder FX (`folder or bus~chain`;...) | track FX (`rule name~chain`;...) | order (`folder`;...) |
  returns (`name~chain~RRGGBB~src~db~out`;...; src t / f, out m / f:<folder> / b:<bus>) | sends
  (`folder~return~return`;...) | buses (`name~on~RRGGBB~f:Drums^t:Lead Vox`;...). Maps are sorted.
- Engineering: per-return Source (tracks / the folder track), Level (dB) and Out (master, or a send into a folder or
  bus track with the return's master output off); Source Folder + Out into that folder is a loop: skipped (notice).
  Polarity (`row.pol`, `B_PHASE`): from the rule (all, or only with a word: Snare + "Btm"), the row's Ø button.
  File check (`Prep.file_check`): a file sample rate that is not the project's, a first item later than the others
  (`row.fnote`). Natural order in a folder: a rule named like another rule + a word ("Kick Sub" after "Kick"), then
  `QUAL_RANK` (In / Top before Out / Btm).
- A track that is already panned (`t.panned`, also dual pan) keeps its pan: the Pan button starts at "-", Notes
  "kept pan 30L" (`row.pnote`). An empty track has the fix "delete" (Apply deletes it last). The level of a one-sided
  file is its live side only (`Audio.rms`).
  Export / Import: `Data\Session Prep\<name>.txt` ("Session Prep preset" + the preset line).
- Modules: `Util` (also the settings), `Rules` (presets, compile the match words, `Rules.folders` = the folder
  order), `Prep` (clean, match, plan, folders, returns, Apply), `Audio` (the audio check of Scan), `UI`.
- Names: `Prep.base_clean` (extension, "Audio N_", track numbers), `Prep.strip_common` (shared prefix / suffix: 4+
  letters or digits, never a rule word), `Prep.match` (2 passes: a match of 2+ words first, then 1 word; in each the first rule wins; terms of 3 letters or less match only a
  whole word), `QUAL` (the extra words that stay: In, Out, L, R, numbers...). Equal new names get " 1", " 2".
  The built-in rules follow the common studio names (Kick In / Out, Kick Sub, Snare Top / Btm, Hi-Hat, Floor Tom,
  OH, Room, Bass DI / Amp, Gtr, Piano, Organ, Synth, Lead Vox, BV, Click, Guide...).
- `Prep.plan` makes no REAPER calls (the tests run it on plain names). Folders (`Prep.make_folders`): only when the
  scanned tracks are not in folders; new folder tracks at the first scanned track, sorted by the folder order (`p.order`), then
  the rule order; spacers (`I_SPACER`) set after the moves (a move takes a spacer along), not above the first.
- Colors: only when `S.color` and SWS Auto Color is off (`_SWSAUTOCOLOR_ENABLE` toggle state); with `S.color_win`
  Apply runs that toggle first (SWS off) and the notice says so.
- Buses (Buses tab, `p.buses`, `Prep.make_buses`): routed bus tracks (not folders) at the end, before the FX
  returns, for each bus that is on; a bus that Session Prep made (prep mark, same name in any case) is used again. Members: "f" = a folder
  (its folder track from `R.folder_tracks`, else its tracks), "t" = a rule name (its tracks; they stay in their
  folder and do not go through their folder's bus). A member is in 1 bus only (`UI.bus_add`). Sends at 0 dB
  post-fader (`Prep.send`, no 2nd send), `B_MAINSEND` off on each source. Defaults (off): Instrument Bus (Drums, Perc,
  Bass, Guitars, Keys, Strings, Brass), Vocal Bus (Lead Vox, BV), Lead Bus (Lead Gtr, Lead Synth).
- Capital letters (`Prep.caps(name, kind)`): the new names (not an unnamed track), the folders, buses and returns.
- Rules tab: grouped by folder (`UI.rule_group`), 1 line per rule with an x at the right, a click opens its fields
  (`R.edit_rule`, `UI.rule_editor`); drag a folder header to set `p.order` (no separate Order section). Tables use
  plain titles (`UI.plain_headers`) and no row stripes.
- Buses tab: "+ Bus" adds a bus, a click on a bus name renames it (its Folder FX key moves), its x deletes it (asks).
- Buses tab: each bus and the returns in a card (`UI.card_begin` / `UI.card_end`: draw channels, the box is drawn
  after its items); bus members as chips (`UI.chip`, x removes); "+ Add" menu (`UI.bus_menu`): folders, then the
  tracks in a submenu per folder.
- Folder depths: the last track of a folder gets -1 per folder that it closes; no spacer right below a parent.
- Audio check (`Audio.check`): a track audio accessor, at most 120 reads of 4096 frames at 44100 Hz per track (a lower
  rate cuts the highs: a hi-hat read silent); a track without items but with receives or FX is not "empty";
  `Audio.verdict` -> empty / silent / fake / only_l / only_r; also the RMS of the reads above -50 dBFS and the peak.
  The Mono fix is the take channel mode (3 left, 4 right), off until its row's "Mono" button is on (orange).
- FX chains (FX Chains tab): `Prep.add_chain` writes the .RfxChain text at the end of the track's FX chain block (found by
  its nesting; a new block when there is none). (`TrackFX_AddByName` does not load chain files.) Track FX: only on
  a track without FX. Folder FX: on the new folder track.
- Returns (`Prep.make_returns`, when `S.returns`): a track with the return's name is used again, else a new one at
  the end (in an "FX Returns" folder when Folders is on). Sends: post-fader, `send_db`; an existing send is found
  in the return's AUXRECV lines (`P_DESTTRACK` gives a number, not the track). Only a track with the prep mark is reused as a return or bus (`Prep.find_track`); Scan skips only marked tracks,
  so a client's own "Delay" is scanned and left alone.
- Scan runs in steps (`Prep.scan_begin`, `Prep.scan_step`: 30 ms of audio reading per frame, "Scanning 12 / 64");
  `Prep.scan` does it at once (the tests). New names that another project track has get a number (`scan.others`).
- Hot paths: tooltips with values use `UI.tipf` (built on hover), cut texts `UI.trunc_c` (kept per width).
- Keys (`UI.keys`): Delete removes the open rule, F2 renames the preset, Enter runs Apply (Prep tab).
- Undo per section of the current preset (`Rules.record` in `Rules.changed`, `Rules.undo(section)`; not REAPER's
  undo): "rules" (rules + folder order), "buses", "returns" (returns, sends, send level); the preset text before each
  change of that section, the last 30; changes within 0.7 s are 1 step; another preset clears it; a setting is no
  step. The button (`UI.undo_button`) sits on the Rules, Buses and FX Returns headings (not in FX Chains).
- Gain staging: `Prep.gain_for` (RMS target limited by the peak limit, or Target: Peak; 0.1 dB); the peak is exact
  (`Audio.true_peak`: REAPER's peak files, built first when missing; `CFG.PEAK_MARGIN` 0); Apply multiplies
  each item's `D_VOL`. Per row: `row.gain` (editable; 0 = no change), `row.gain_meas` (right-click resets).
- Prep table: Pan button per row (`row.pan` "L" / "C" / "R" / nil = leave; the name sets the start when `S.pairs`),
  M / S = the track's real mute / solo at once (`CSurf_On...ChangeEx`, own undo point), not at Apply.

## Later (ideas)

- Session Prep version 2: time alignment of close mics, a measured polarity check, routing / bus templates.

## Open findings (from a checkup; not decided: ask before a fix)

- Bugs: `Prep.add_chain`: `^%s*<FXCHAIN` also matches `<FXCHAIN_REC` (use `^%s*<FXCHAIN%s*$`). `Rules.undo`: no
  `Rules.update_dirty(p)`; undo of a rule rename does not restore tfx / bus members / return Out.
  `UI.draw_returns`: a rename moves `p.sends` on every key (move once at deactivation). `Prep.apply_rows`: Delete
  without `row.on`; a Delete row is still renamed, put in a folder and routed (an empty folder stays). Equal final
  names in `Prep.plan` (add each row's final name to the used set); the "send skipped" count counts rows
  (`R.loops`); the Pan L / R switch does not call `Rules.changed()`. A deleted bus leaves returns with Out
  "b:<name>" (set them to "m"); a bus named like a folder shares `p.fx`.
- Saved data (ask): the prep mark is the same on client tracks and made tracks, so `Prep.find_track` can reuse a
  client's "Delay" (a "made:" mark).
- Per-frame costs: `r.file_exists` per return per frame. Tidy: `t.guid`, `CFG.PEAK_MARGIN`.
- Ideas: Help text error (orange vs teal Mono button).
