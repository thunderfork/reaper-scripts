-- @noindex
-- MIDI Pilot tests. Run with .\tools\test.ps1 (it starts the portable test REAPER in C:\REAPERtest).
-- Loads MIDI Pilot.lua without its window, runs each test, writes tests\result_midipilot.txt, quits REAPER.
local r = reaper
local here = ({ r.get_action_context() })[2]:match("^(.*)[/\\]")
local out = {}
local passed, failed = 0, 0
local function log(s) out[#out + 1] = s end
local function eq(a, b, what)
  if a ~= b then error((what or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end
local function ok(v, what) if not v then error((what or "check") .. " failed", 2) end end
local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end

-- a saved test project with 2 regions, so REAPER can quit without a save prompt
local tmp = r.GetResourcePath() .. "\\MidiPilotTests"
r.RecursiveCreateDirectory(tmp, 0)
local proj_file = tmp .. "\\test.rpp"
local pf = io.open(proj_file, "w")
if pf then pf:write("<REAPER_PROJECT 0.1\n>\n"); pf:close() end
r.Main_openProject("noprompt:" .. proj_file)
for i = r.CountTracks(0) - 1, 0, -1 do r.DeleteTrack(r.GetTrack(0, i)) end -- (no tracks of earlier runs)
r.AddProjectMarker2(0, true, 20, 50, "Song B", -1, 0)
r.AddProjectMarker2(0, true, 0, 10, "Song A", -1, 0)

local function finish()
  log(string.format("%d passed, %d failed", passed, failed))
  local f = io.open(here .. "\\result_midipilot.txt", "w")
  if f then f:write(table.concat(out, "\n"), "\n"); f:close() end
  r.Main_SaveProject(0, false)
  r.defer(function() r.Main_OnCommand(40004, 0) end) -- File: Quit REAPER
end

MidiPilotTest = {}
local loaded, err = pcall(dofile, here .. "\\..\\MIDI Pilot\\MIDI Pilot.lua")
local C = MidiPilotTest
if not loaded or not C.Project then
  log("FAIL  load MIDI Pilot.lua: " .. tostring(err)); failed = 1; finish(); return
end
local Project, Dev, R, S = C.Project, C.Dev, C.R, C.S
log(string.format("REAPER %s in %s, MIDI Pilot %s loaded", r.GetAppVersion(), r.GetResourcePath(), C.CFG.VERSION))
Project.update()

test("regions are read in timeline order", function()
  eq(#R.regions, 2, "regions"); eq(R.regions[1].name, "Song A"); eq(R.regions[2].name, "Song B")
end)

test("project data: defaults write nothing", function()
  eq(Project.serialize(), "version=1")
end)

test("project data: tracks and the shared mode are saved and read", function()
  local P = C.get_P()
  P.tracks = { dB = "{2}", dA = "{1}" }; P.track_mode = "shared"
  local p2 = Project.parse(Project.serialize())
  eq(p2.tracks.dA, "{1}"); eq(p2.tracks.dB, "{2}"); eq(p2.track_mode, "shared")
  P.tracks = {}; P.track_mode = "own"
end)

test("devices: saved and read (All channels, latency limits)", function()
  local list = { { id = "d1", name = "Guitar", model = "mini", chan = 0, port = "Quad Cortex mini", latency = 30 },
    { id = "d2", name = "Bass\tx", model = "qc", chan = 16, port = "", latency = 0 } }
  local back = Dev.parse_list(Dev.serialize_list(list))
  eq(#back, 2); eq(back[1].model, "mini"); eq(back[1].chan, 0); eq(back[1].latency, 30); eq(back[1].port, "Quad Cortex mini")
  eq(back[2].name, "Bass x", "tab removed"); eq(back[2].chan, 16)
  eq(Dev.parse_list("d3\tX\tbad\t99\tp\t9999\t")[1].chan, 16, "channel limit")
  eq(Dev.parse_list("d3\tX\tbad\t99\tp\t9999\t")[1].model, "qc", "unknown model")
  eq(Dev.parse_list("d3\tX\tbad\t99\tp\t9999\t")[1].latency, C.CFG.LATENCY_MAX)
end)

test("model from the USB port name", function()
  eq(Dev.model_from_port("Quad Cortex"), "qc"); eq(Dev.model_from_port("Quad Cortex mini MIDI 1"), "mini")
  eq(Dev.model_from_port("USB MIDI Interface"), nil)
end)

test("MIDI hardware output value", function()
  eq(Dev.hw_out(nil, 1), -1); eq(Dev.hw_out(0, 0), 0); eq(Dev.hw_out(2, 5), 69)
end)

test("models: 256 presets each", function()
  for _, m in pairs(C.MODELS) do eq(#m.letters * m.banks, 256); eq(#m.scenes, 8) end
end)

test("warnings: same output and channel, All channels, shared track", function()
  local keep = S.devices
  R.ports = { { index = 0, name = "QC" }, { index = 1, name = "Other" } }
  S.devices = { { id = "a", name = "A", model = "qc", chan = 1, port = "QC", latency = 0 },
    { id = "b", name = "B", model = "qc", chan = 1, port = "QC", latency = 0 } }
  R.conflicts = nil; eq(#Dev.conflicts(), 1, "same channel")
  S.devices[2].chan = 0; R.conflicts = nil; ok(Dev.conflicts()[1]:find("All channels", 1, true), "All channels")
  S.devices[2].chan = 2; R.conflicts = nil; eq(#Dev.conflicts(), 0, "ok")
  S.devices[2].port = "Other"; C.get_P().track_mode = "shared"; R.conflicts = nil
  ok(Dev.conflicts()[1]:find("shared", 1, true), "shared track")
  S.devices[2].port = "Gone"; C.get_P().track_mode = "own"; R.conflicts = nil
  ok(Dev.conflicts()[1]:find("not available", 1, true), "missing output")
  S.devices = keep; R.conflicts = nil
end)

test("track: created, linked by GUID, survives a rescan, removed with the device", function()
  local keep = S.devices
  S.devices = { { id = "g1", name = "Guitar", model = "qc", chan = 3, port = "", latency = 0 } }
  local d = S.devices[1]
  local n0 = r.CountTracks(0)
  Dev.create_track(d)
  eq(r.CountTracks(0), n0 + 1, "track added")
  local tr = Dev.track(d); ok(tr, "linked")
  eq(Dev.track_name(tr), "MIDI Guitar")
  eq(r.CountTrackMediaItems(tr), 1, "an empty MIDI item")
  ok(r.TakeIsMIDI(r.GetActiveTake(r.GetTrackMediaItem(tr, 0))), "MIDI take")
  eq(math.floor(r.GetMediaTrackInfo_Value(tr, "I_MIDIHWOUT")), -1, "no output: none")
  Project.scan(); ok(Dev.track(d) == tr, "after a rescan")
  Dev.remove(1); eq(C.get_P().tracks.g1, nil, "link removed")
  r.DeleteTrack(tr)
  S.devices = keep
end)

test("names: the model name, numbered when there are more; the track follows; a free unit only", function()
  local keep, keepp = S.devices, R.ports
  S.devices = {}
  R.ports = { { index = 0, name = "Quad Cortex" }, { index = 1, name = "Quad Cortex mini" } }
  local a = Dev.new(); eq(a.name, "Quad Cortex"); eq(a.port, "Quad Cortex")
  local b = Dev.new(); eq(b.name, "Quad Cortex mini"); eq(b.model, "mini")
  local c = Dev.new(); eq(c.port, "", "no unit left: no output"); eq(c.name, "Quad Cortex 2"); eq(a.name, "Quad Cortex 1")
  Dev.create_track(c)
  Dev.rename(c, "Bass"); eq(Dev.track_name(Dev.track(c)), "MIDI Bass", "track renamed")
  Dev.number_defaults("qc"); eq(a.name, "Quad Cortex", "only 1 left with a default name")
  r.SetMediaTrackInfo_Value(Dev.track(c), "I_MIDIHWOUT", 1 * 32 + 5) -- changed in REAPER's routing window
  Dev.sync_from_tracks(); eq(c.chan, 5, "channel follows"); eq(c.port, "Quad Cortex mini", "output follows")
  Dev.set_model(a, "mini"); eq(a.name, "Quad Cortex mini 1", "list order"); eq(b.name, "Quad Cortex mini 2")
  r.DeleteTrack(Dev.track(c))
  S.devices, R.ports = keep, keepp
end)

test("presets: labels and numbers (QC 8 letters, mini 4 letters)", function()
  local Preset = C.Preset
  eq(Preset.label("qc", 0), "1A"); eq(Preset.label("qc", 9), "2B"); eq(Preset.label("qc", 255), "32H")
  eq(Preset.label("mini", 0), "1A"); eq(Preset.label("mini", 5), "2B"); eq(Preset.label("mini", 255), "64D")
  eq(Preset.index("qc", 3, 2), 17); eq(Preset.index("mini", 3, 2), 9)
end)

test("library: saved and read; the .reabank file has the names", function()
  local Preset = C.Preset
  local keep, keepl = S.devices, S.lib
  S.devices = { { id = "L1", name = "Guitar", model = "qc", chan = 1, port = "", latency = 0, inport = "" } }
  S.lib = { L1 = {} }
  local d = S.devices[1]
  Preset.set_name(d, 1, 9, "  Song One  "); Preset.set_name(d, 2, 130, "Late")
  eq(Preset.name(d, 1, 9), "Song One", "trimmed")
  local back = Preset.parse_lib(Preset.serialize_lib(S.lib.L1))
  eq(back["1:9"], "Song One"); eq(back["2:130"], "Late")
  local txt = Preset.reabank_text()
  ok(txt:find("Bank 0 1 Guitar - My Presets (1-128)", 1, true), "bank of folder 1")
  ok(txt:find("\n9 2B Song One\n", 1, true), "program line")
  ok(txt:find("Bank 1 2 Guitar - User 1 (129-256)", 1, true), "group 2 of folder 2")
  Preset.set_name(d, 1, 9, ""); eq(Preset.name(d, 1, 9), nil, "removed")
  S.devices, S.lib = keep, keepl
end)

test("preset changes: written as CC0, CC32, PC; read back; before / exact / 0:00; removed; fill; match", function()
  local Midi, Preset = C.Midi, C.Preset
  local keep, keepl, kw, km = S.devices, S.lib, S.pc_when, S.pc_ms
  S.devices = { { id = "M1", name = "Guitar", model = "qc", chan = 3, port = "", latency = 0, inport = "" } }
  S.lib = { M1 = {} }
  local d = S.devices[1]
  Dev.create_track(d)
  local A, B = R.regions[1], R.regions[2] -- Song A 0-10, Song B 20-50
  S.pc_when, S.pc_ms = "before", 250
  eq(Midi.set_song(d, B, 1, 17), false, "not moved")
  local chs = Midi.changes(d)
  eq(#chs, 1); ok(math.abs(chs[1].t - 19.75) < 0.01, "250 ms before"); eq(chs[1].folder, 1); eq(chs[1].index, 17)
  -- the 3 events, in order, on channel 3
  local take = chs[1].take
  local _, _, ncc = r.MIDI_CountEvts(take)
  eq(ncc, 4, "3 events + the start scene")
  local _, _, _, _, cm4, _, a4, v4 = r.MIDI_GetCC(take, 3)
  eq(cm4, 0xB0); eq(a4, 43, "the start scene (CC43)"); eq(v4, 0, "scene A")
  local _, _, _, _, cm1, ch1, a1, v1 = r.MIDI_GetCC(take, 0)
  local _, _, _, _, _, _, a2, v2 = r.MIDI_GetCC(take, 1)
  local _, _, _, _, cm3, _, p3 = r.MIDI_GetCC(take, 2)
  eq(cm1, 0xB0); eq(ch1, 2, "channel 3"); eq(a1, 0); eq(v1, 0); eq(a2, 32); eq(v2, 1); eq(cm3, 0xC0); eq(p3, 17)
  eq(Midi.set_song(d, A, 1, 200), true, "song at 0:00: moved")
  eq(Midi.song_change(d, A).t, 0); eq(Midi.song_change(d, A).index, 200, "group 2 (CC0 = 1)")
  eq(Midi.active_at(d, 15).index, 200, "goes on")
  Midi.set_song(d, B, 1, 3) -- replaced, not added
  eq(#Midi.changes(d), 2); eq(Midi.song_change(d, B).index, 3)
  Midi.set_song(d, B, nil); eq(Midi.song_change(d, B), nil, "removed"); eq(#Midi.changes(d), 1)
  eq(Midi.fill_starts(d), 1, "Song B gets the preset that goes on"); eq(Midi.song_change(d, B).index, 200)
  Preset.set_name(d, 1, 42, "song b")
  eq(Midi.match_names(d), 1); eq(Midi.song_change(d, B).index, 42, "matched by name")
  S.pc_when = "exact"; Midi.set_song(d, B, 1, 5); eq(Midi.song_change(d, B).t, 20)
  r.DeleteTrack(Dev.track(d))
  S.devices, S.lib, S.pc_when, S.pc_ms = keep, keepl, kw, km
end)

test("a removed device added again finds its track by name; remove with or without the track", function()
  local keep, keepp = S.devices, R.ports
  S.devices, R.ports = {}, {}
  local d = Dev.new(); Dev.create_track(d) -- (in the tests Dev.new makes no track)
  local tr = Dev.track(d); ok(tr, "track")
  Dev.remove_with_track(1, false); ok(r.ValidatePtr2(0, tr, "MediaTrack*"), "track kept")
  local d2 = Dev.new(); ok(Dev.track(d2) == tr, "same name: the track is used again")
  Dev.rename(d2, "Bass"); eq(Dev.track_name(tr), "MIDI Bass")
  Dev.remove_with_track(1, true); ok(not r.ValidatePtr2(0, tr, "MediaTrack*"), "track removed")
  S.devices, R.ports = keep, keepp
end)

test("MIDI input: the unit's input is found (same name, else the same model)", function()
  local keep = S.devices
  S.devices = {}
  R.inports = { { index = 0, name = "Other" }, { index = 3, name = "MIDIIN2 (Quad Cortex mini)" } }
  eq(Dev.guess_input({ port = "x", model = "mini" }), "MIDIIN2 (Quad Cortex mini)")
  eq(Dev.guess_input({ port = "x", model = "qc" }), "", "not the other model")
  R.inports = { { index = 0, name = "Quad Cortex" } }
  eq(Dev.guess_input({ port = "Quad Cortex", model = "qc" }), "Quad Cortex")
  S.devices = keep; R.inports = {}
end)

test("preset timing in note values follows the tempo (120 bpm: 1/16 note = 125 ms)", function()
  local Midi = C.Midi
  local ku, kn, kw = S.pc_unit, S.pc_note, S.pc_when
  S.pc_when, S.pc_unit, S.pc_note = "before", "notes", 2
  local bpm = r.Master_GetTempo()
  local tt = Midi.pc_time(R.regions[2])
  ok(math.abs(tt - (20 - 0.25 * 60 / bpm)) < 0.001, "1/16 before")
  local t0, moved = Midi.pc_time(R.regions[1]); eq(t0, 0); eq(moved, true)
  S.pc_when = "after"; S.pc_note = 4
  ok(math.abs(Midi.pc_time(R.regions[2]) - (20 + 60 / bpm)) < 0.001, "1 beat after")
  S.pc_unit, S.pc_note, S.pc_when = ku, kn, kw
end)

test("folder names: your name, else the unit's; saved and read; in the bank file", function()
  local Preset = C.Preset
  local keep, kl, kf = S.devices, S.lib, S.fnames
  S.devices = { { id = "F1", name = "Gtr", model = "qc", chan = 1, port = "", latency = 0, inport = "" } }
  S.lib, S.fnames = { F1 = {} }, { F1 = {} }
  local d = S.devices[1]
  eq(Preset.folder_name(d, 2), "User 1")
  Preset.set_folder_name(d, 2, " My Band "); eq(Preset.folder_name(d, 2), "My Band")
  eq(Preset.parse_fnames(Preset.serialize_fnames(S.fnames.F1))[2], "My Band")
  ok(Preset.folder_items(d):find("My Band", 1, true), "dropdown")
  Preset.set_name(d, 2, 0, "Intro")
  ok(Preset.reabank_text():find("Gtr - My Band (1-128)", 1, true), "bank file")
  Preset.set_folder_name(d, 2, ""); eq(Preset.folder_name(d, 2), "User 1", "back to the unit's name")
  S.devices, S.lib, S.fnames = keep, kl, kf
end)

test("a kept track brings its device back (Add device: name, settings, names); undo of a removed track too", function()
  local keep, keepp, kl, kf = S.devices, R.ports, S.lib, S.fnames
  S.devices, R.ports = {}, {}
  local d = Dev.new(); Dev.create_track(d)
  Dev.rename(d, "Guitar"); d.chan = 7
  C.Preset.set_name(d, 1, 3, "Song X")
  local tr = Dev.track(d)
  Dev.remove_with_track(1, false)
  eq(#S.devices, 0)
  local d2 = Dev.new() -- no new track: the kept one, with its settings
  ok(Dev.track(d2) == tr, "the kept track"); eq(d2.name, "Guitar"); eq(d2.chan, 7)
  eq(C.Preset.name(d2, 1, 3), "Song X", "the preset names came back")
  Dev.remove_with_track(1, true)
  eq(#S.devices, 0); ok(not r.ValidatePtr2(0, tr, "MediaTrack*"), "track removed")
    r.Main_OnCommand(40029, 0) -- Edit: Undo
  Project.scan()
  local back
  for _, x in ipairs(S.devices) do if x.name == "Guitar" then back = x end end
  ok(back, "the device is back after undo"); eq(back.chan, 7)
  eq(C.Preset.name(back, 1, 3), "Song X")
  r.DeleteTrack(Dev.track(back))
  S.devices, R.ports, S.lib, S.fnames = keep, keepp, kl, kf
end)

test("scenes: CC43 written and read; the gap after a preset (the scene moves); names; markers; remove", function()
  local Midi, Preset = C.Midi, C.Preset
  local keep, kl, ks, kg, kw, km = S.devices, S.lib, S.snames, S.sc_gap, S.pc_when, S.pc_ms
  S.devices = { { id = "S1", name = "Gtr", model = "mini", chan = 2, port = "", latency = 0, inport = "" } }
  S.lib, S.snames, S.sc_gap, S.pc_when, S.pc_ms = { S1 = {} }, { S1 = {} }, 100, "exact", 0
  local d = S.devices[1]
  Dev.create_track(d)
  local B = R.regions[2] -- Song B 20-50
  Midi.set_song(d, B, 1, 4) -- preset 2A at 20.0
  eq(Midi.add_scene(d, 20, 2), 20.1, "in the gap: moved 100 ms later")
  Midi.add_scene(d, 30, 5)
  local list = Midi.song_scenes(d, B)
  eq(#list, 2); eq(list[1].v, 2); eq(list[2].v, 5)
  local _, _, ncc = r.MIDI_CountEvts(list[2].take); ok(ncc >= 5, "events")
  Midi.add_scene(d, 30, 6); eq(#Midi.song_scenes(d, B), 2, "same time: replaced"); eq(Midi.song_scenes(d, B)[2].v, 6)
  -- a new preset change at 30 pushes the scene there
  Midi.set_song(d, B, 1, 4) -- (the same, at 20: no change)
  Preset.set_scene_names(d, 1, 4, { "Verse", "", "Chorus" })
  eq(Preset.scene_name(d, 1, 4, 0), "Verse"); eq(Preset.scene_name(d, 1, 4, 1), "I-B", "the mini's name")
  eq(Preset.scene_name(d, nil, 0, 2), "I-C", "no preset there"); eq(Preset.has_scene_name(d, nil, 0, 2), false, "no preset: no error")
  eq(Preset.parse_snames(Preset.serialize_snames(S.snames.S1))["1:4"][3], "Chorus")
  r.AddProjectMarker2(0, false, 40, 0, "Chorus", -1, 0)
  r.AddProjectMarker2(0, false, 42, 0, "PDFPAGE 2", -1, 0)
  Project.scan()
  eq(Midi.match_markers(d), 1, "1 marker"); eq(Midi.song_scenes(d, B)[3].v, 2, "Chorus = scene 3")
  eq(Midi.match_markers(d), 0, "again: nothing new")
  Midi.remove_scene(d, Midi.song_scenes(d, B)[3]); eq(#Midi.song_scenes(d, B), 2, "removed")
  -- the scene before a song goes on, unless a preset change comes after it
  local A = R.regions[1]
  Midi.add_scene(d, 5, 7)
  local _, sv = Midi.song_scenes(d, B); eq(sv, nil, "a preset change at 20 starts the preset's own scene")
  Midi.set_song(d, B, nil)
  eq(#Midi.song_scenes(d, B), 2, "a song shows only its own scene changes")
  ok(Midi.start_scene(d, B), "removing the preset: the start scene is still the start scene (no new row)")
  r.DeleteTrack(Dev.track(d))
  for i = r.CountProjectMarkers(0) - 1, 0, -1 do
    local _, isr, _, _, nm, idx = r.EnumProjectMarkers(i)
    if not isr and (nm == "Chorus" or nm == "PDFPAGE 2") then r.DeleteProjectMarker(0, idx, false) end
  end
  Project.scan()
  S.devices, S.lib, S.snames, S.sc_gap, S.pc_when, S.pc_ms = keep, kl, ks, kg, kw, km
  local _ = A
end)

test("start scenes: after the song's own preset change (timing 'after'); a scene ends at its song end", function()
  local Midi, Preset = C.Midi, C.Preset
  local keep, kl, ks, kg, kw, km = S.devices, S.lib, S.snames, S.sc_gap, S.pc_when, S.pc_ms
  S.devices = { { id = "T1", name = "Gtr", model = "qc", chan = 1, port = "", latency = 0, inport = "" } }
  S.lib, S.snames, S.sc_gap, S.pc_when, S.pc_ms = { T1 = {} }, { T1 = {} }, 100, "after", 250
  local d = S.devices[1]
  Dev.create_track(d)
  local A, B = R.regions[1], R.regions[2] -- 0-10, 20-50
  Preset.set_scene_names(d, 1, 9, { "Clean", "Tight AF" })
  Midi.set_song(d, A, 1, 9) -- preset at 0.25
  Midi.set_song(d, B, 1, 9) -- preset at 20.25
  local sa = Midi.start_scene(d, A)
  ok(sa and math.abs(sa.t - 0.35) < 0.002, "start scene after the preset change + gap")
  eq(Preset.scene_name(d, Midi.preset_at(d, A, sa.t).folder, Midi.preset_at(d, A, sa.t).index, sa.v), "Clean", "its name")
  ok(math.abs(Midi.start_scene(d, B).t - 20.35) < 0.002, "song B too")
  -- a scene in song A ends at its end: song B starts on its own start scene
  Midi.insert_scene(d, 5, 1)
  local _, sv = Midi.song_scenes(d, B); eq(sv, nil, "nothing goes on into song B")
  eq(Midi.song_scenes(d, B)[1].v, 0, "song B starts on Clean")
  -- an old start scene before the preset change moves after it
  local old = Midi.start_scene(d, B); Midi.delete_scene(d, old); R.pcs = {}
  Midi.insert_scene(d, 20, 1); R.pcs = {}
  ok(Midi.ensure_start_scene(d, B), "moved"); ok(math.abs(Midi.start_scene(d, B).t - 20.35) < 0.002)
  eq(Midi.start_scene(d, B).v, 1, "the same scene")
  r.DeleteTrack(Dev.track(d))
  S.devices, S.lib, S.snames, S.sc_gap, S.pc_when, S.pc_ms = keep, kl, ks, kg, kw, km
end)

test("scenes: combine repeated scenes; move; times in m:ss and bar.beat; colours; names move with a preset", function()
  local Midi, Preset, Util = C.Midi, C.Preset, C.Util
  local keep, kl, ks, kg, kw, km, kmg = S.devices, S.lib, S.snames, S.sc_gap, S.pc_when, S.pc_ms, S.sc_merge
  S.devices = { { id = "U1", name = "Gtr", model = "qc", chan = 1, port = "", latency = 0, inport = "" } }
  S.lib, S.snames, S.sc_gap, S.pc_when, S.pc_ms, S.sc_merge = { U1 = {} }, { U1 = {} }, 100, "exact", 0, true
  local d = S.devices[1]
  Dev.create_track(d)
  local B = R.regions[2] -- 20-50
  Midi.set_song(d, B, 1, 0) -- preset at 20, start scene A at 20.1
  Midi.insert_scene(d, 30, 1); Midi.insert_scene(d, 35, 1)
  eq(Midi.merge_song(d, B), 1, "the 2nd B is removed"); eq(#Midi.song_scenes(d, B), 2)
  local s = Midi.song_scenes(d, B)[2]
  Midi.move_scene(d, B, s, 40); eq(Midi.song_scenes(d, B)[2].t, 40, "moved"); eq(Midi.song_scenes(d, B)[2].v, 1)
  eq(Util.fmt_song_time(B, 32.5), "0:12.5"); eq(Util.parse_song_time(B, "0:12.5"), 32.5); eq(Util.parse_song_time(B, "12.5"), 32.5)
  -- 120 bpm 4/4: a bar = 2 s; bars and beats from the project start
  eq(Util.fmt_beats(22), "12.1"); eq(Util.fmt_beats(22.75), "12.2.5")
  ok(math.abs(Util.parse_beats("12.2") - 22.5) < 0.001, "bar.beat read"); eq(Util.parse_beats("x"), nil)
  eq(Util.parse_song_time(B, "x"), nil)
  -- clear: 1 song, then all scenes, then all presets
  ok(Midi.clear(d, B) >= 1); eq(#Midi.song_scenes(d, B), 0)
  Midi.insert_scene(d, 25, 3); Midi.insert_scene(d, 5, 2)
  eq(Midi.clear(d), 2, "all scenes"); eq(#Midi.scenes(d), 0)
  eq(Midi.clear(d, nil, true), 1, "all presets"); eq(#Midi.changes(d), 0)
  Preset.set_scene_names(d, 1, 0, { "Verse" }, { 3 })
  eq(Preset.scene_col(d, 1, 0, 0), 3, "chosen colour"); eq(Preset.scene_col(d, 1, 0, 1), 2, "default colour")
  local back = Preset.parse_snames(Preset.serialize_snames(S.snames.U1))
  eq(back["1:0"][1], "Verse"); eq(back["1:0"].c[1], 3)
  Preset.set_name(d, 1, 0, "Song B")
  Preset.move(d, 1, 0, 1, 5)
  eq(Preset.name(d, 1, 5), "Song B"); eq(Preset.scene_name(d, 1, 5, 0), "Verse", "the scene names moved"); eq(Preset.scene_col(d, 1, 5, 0), 3)
  eq(Preset.name(d, 1, 0), nil)
  r.DeleteTrack(Dev.track(d))
  S.devices, S.lib, S.snames, S.sc_gap, S.pc_when, S.pc_ms, S.sc_merge = keep, kl, ks, kg, kw, km, kmg
end)

test("review: a new unit does not take a kept track of another unit; channel move; start scene switch; match writes start scenes", function()
  local Midi, Preset = C.Midi, C.Preset
  local keep, keepp, kl, ks, kw, km, kst = S.devices, R.ports, S.lib, S.snames, S.pc_when, S.pc_ms, S.start_scene
  S.devices, S.lib, S.snames, S.pc_when, S.pc_ms = {}, {}, {}, "exact", 0
  R.ports = { { index = 0, name = "Quad Cortex" }, { index = 1, name = "Quad Cortex mini" } }
  local a = Dev.new(); Dev.create_track(a); eq(a.port, "Quad Cortex")
  local tra = Dev.track(a)
  Dev.remove_with_track(1, false) -- kept track of the Quad Cortex
  local b = Dev.new() -- the free unit is the Quad Cortex again: its own kept track comes back
  ok(Dev.track(b) == tra, "same unit: its kept track")
  local c = Dev.new() -- the mini: no kept track of its own
  ok(Dev.track(c) ~= tra, "another unit: not the Quad Cortex's track"); eq(c.port, "Quad Cortex mini")
  -- channel move
  local B = R.regions[2]
  b.chan = 3
  Midi.set_song(b, B, 1, 4)
  ok(Midi.has_channel(b, 2), "on channel 3")
  b.chan = 5
  eq(#Midi.changes(b), 0, "not on the new channel yet")
  ok(Midi.move_channel(b, 2, 4) >= 4, "moved"); eq(#Midi.changes(b), 1); ok(not Midi.has_channel(b, 2))
  -- start scene switch off: a preset change writes no start scene
  S.start_scene = false
  Midi.clear(b); Midi.set_song(b, B, 1, 5)
  eq(Midi.start_scene(b, B), nil, "off: no start scene")
  -- Presets match Regions writes the start scene like the dropdown
  S.start_scene = true
  S.lib[b.id] = {}
  Preset.set_name(b, 1, 9, "Song B")
  Midi.set_song(b, B, nil); Midi.clear(b)
  eq(Midi.match_names(b), 1); ok(Midi.start_scene(b, B), "start scene written")
  r.DeleteTrack(Dev.track(b))
  S.devices, R.ports, S.lib, S.snames, S.pc_when, S.pc_ms, S.start_scene = keep, keepp, kl, ks, kw, km, kst
end)

test("knobs: units, nearest CC value, typed values, saved and read; CC values written, changed, removed", function()
  local Knob, Midi = C.Knob, C.Midi
  local k = { cc = 1, name = "Filter", min = 200, max = 800, unit = "Hz" }
  eq(Knob.to_cc(k, 200), 0); eq(Knob.to_cc(k, 800), 127); eq(Knob.to_cc(k, 650), 95)
  ok(math.abs(Knob.from_cc(k, 95) - 648.82) < 0.01, "nearest: 648.8 Hz")
  eq(Knob.fmt(k, 648.82), "649 Hz"); eq(Knob.to_cc(k, 9999), 127, "limited")
  local db = { cc = 3, name = "Vol", min = -48, max = 18, unit = "dB" }
  eq(Knob.to_cc(db, 0), 92); eq(Knob.fmt(db, -6.5), "-6.5 dB")
  eq(Knob.parse_value("650 Hz"), 650); eq(Knob.parse_value("1.2k"), 1200); eq(Knob.parse_value("-6 dB"), -6)
  eq(Knob.parse_value("45%"), 45); eq(Knob.parse_value("abc"), nil)
  eq(#Knob.parse(""), 2, "the 2 expression pedals by default"); eq(#Knob.parse("-"), 0, "no knobs")
  local back = Knob.parse(Knob.serialize({ k, db }))
  eq(#back, 2); eq(back[1].max, 800); eq(back[2].min, -48); eq(back[2].unit, "dB"); eq(back[1].name, "Filter")
  local keep = S.devices
  S.devices = { { id = "K1", name = "Gtr", model = "qc", chan = 1, port = "", latency = 0, inport = "" } }
  local d = S.devices[1]
  Dev.create_track(d)
  Midi.set_cc(d, 1, 25, 95)
  eq(#Midi.ccs(d, 1), 1); eq(Midi.ccs(d, 1)[1].v, 95)
  Midi.set_cc(d, 1, 25, 40, Midi.ccs(d, 1)[1]); eq(#Midi.ccs(d, 1), 1, "changed, not added"); eq(Midi.ccs(d, 1)[1].v, 40)
  Midi.set_cc(d, 1, 30, 10); eq(#Midi.ccs(d, 1), 2)
  -- the slope from the 1st value to the next: written, read back, kept when the value changes
  Midi.set_shape(d, 1, Midi.ccs(d, 1)[1], 5, 0.4)
  eq(Midi.ccs(d, 1)[1].shape, 5, "curve"); ok(math.abs(Midi.ccs(d, 1)[1].tension - 0.4) < 0.01, "tension")
  Midi.set_cc(d, 1, 25, 60, Midi.ccs(d, 1)[1]); eq(Midi.ccs(d, 1)[1].shape, 5, "the slope stays"); eq(Midi.ccs(d, 1)[1].v, 60)
  Midi.set_shape(d, 1, Midi.ccs(d, 1)[1], 1); eq(Midi.ccs(d, 1)[1].shape, 1, "straight")
  Midi.remove_cc(d, 1, Midi.ccs(d, 1)[1]); eq(#Midi.ccs(d, 1), 1); eq(Midi.ccs(d, 1)[1].t, 30)
  eq(Midi.song_at(25).name, "Song B"); eq(Midi.song_at(15), nil)
  r.DeleteTrack(Dev.track(d))
  S.devices = keep
end)

---------------------------------------------------------------------------
for _, t in ipairs(tests) do
  local good, e = pcall(t[2])
  if good then passed = passed + 1; log("ok    " .. t[1])
  else failed = failed + 1; log("FAIL  " .. t[1] .. ": " .. tostring(e)) end
end
finish()
