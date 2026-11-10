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
  P.test_ok = { ["Song B"] = true }
  ok(Project.parse(Project.serialize()).test_ok["Song B"], "Ignore of a Scene test hint: saved and read")
  P.test_ok = {}
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

test("models: presets = banks x letters (Quad Cortex 256, Line 6 128); scenes", function()
  for _, m in pairs(C.MODELS) do eq(#m.letters * m.banks, m.presets); eq(#m.scenes, m.n_snap or 8) end
  eq(C.MODELS.qc.presets, 256); eq(C.MODELS.helix.presets, 128); eq(#C.MODELS.hxstomp.scenes, 3)
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
  -- the Preset list: search (name, number, folder) and sort (Number, Name)
  Preset.set_name(d, 1, 3, "Zebra"); Preset.set_name(d, 1, 1, "apple")
  local ks, keepq = S.preset_sort, R.psearch
  S.preset_sort, R.psearch = 0, ""
  local keys, total = Preset.list_view(d, S.lib.L1)
  eq(total, 4); eq(table.concat(keys, ","), "1:1,1:3,1:9,2:130", "by number")
  S.preset_sort = 1
  eq(table.concat((Preset.list_view(d, S.lib.L1)), ","), "1:1,2:130,1:9,1:3", "by name, A-Z")
  R.psearch = "zeb"; eq(table.concat((Preset.list_view(d, S.lib.L1)), ","), "1:3", "search: a name")
  R.psearch = "2B"; eq(table.concat((Preset.list_view(d, S.lib.L1)), ","), "1:9", "search: a number")
  R.psearch = "user"; eq(table.concat((Preset.list_view(d, S.lib.L1)), ","), "2:130", "search: a folder")
  Preset.set_name(d, 1, 3, "Aaa"); R.psearch = ""
  eq((Preset.list_view(d, S.lib.L1))[1], "1:3", "a renamed Preset: sorted again")
  S.preset_sort, R.psearch = ks, keepq
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
  eq(ncc, 3, "3 events (no scene)")
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
  eq(Midi.fill_starts(d), 3, "Song B gets the preset that goes on, and both songs a start scene"); eq(Midi.song_change(d, B).index, 200)
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
  Preset.set_folder_name(d, 1, "Mine"); eq(Preset.folder_name(d, 1), "My Presets", "My Presets keeps its name")
  Preset.set_folder_name(d, 1, "")
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

test("scenes: written exactly where asked, nothing else changes; replace; change; move; remove; names; markers", function()
  local Midi, Preset = C.Midi, C.Preset
  local keep, kl, ks, kw, km = S.devices, S.lib, S.snames, S.pc_when, S.pc_ms
  S.devices = { { id = "S1", name = "Gtr", model = "mini", chan = 2, port = "", latency = 0, inport = "" } }
  S.lib, S.snames, S.pc_when, S.pc_ms = { S1 = {} }, { S1 = {} }, "exact", 0
  local d = S.devices[1]
  Dev.create_track(d)
  local B = R.regions[2] -- Song B 20-50
  Midi.set_song(d, B, 1, 4) -- preset 2A at 20.0
  eq(#Midi.song_scenes(d, B), 0, "a preset change writes no scene")
  Midi.add_scene(d, 20, 2) -- on the preset change itself: exactly there
  ok(math.abs(Midi.song_scenes(d, B)[1].t - 20) < 0.001, "exactly at 20 (no gap)")
  Midi.add_scene(d, 30, 5); Midi.add_scene(d, 30.123, 5)
  local list = Midi.song_scenes(d, B)
  eq(#list, 3, "nothing added or removed by itself"); ok(math.abs(list[3].t - 30.123) < 0.001, "exact time")
  Midi.add_scene(d, 30, 6); eq(#Midi.song_scenes(d, B), 3, "same time: replaced"); eq(Midi.song_scenes(d, B)[2].v, 6)
  Midi.change_scene(d, Midi.song_scenes(d, B)[2], 1); eq(Midi.song_scenes(d, B)[2].v, 1, "changed")
  ok(math.abs(Midi.song_scenes(d, B)[2].t - 30) < 0.001, "at the same time")
  Midi.move_scene(d, Midi.song_scenes(d, B)[3], 41.5)
  ok(math.abs(Midi.song_scenes(d, B)[3].t - 41.5) < 0.001, "moved exactly"); eq(Midi.song_scenes(d, B)[3].v, 5)
  Midi.remove_scene(d, Midi.song_scenes(d, B)[1]); eq(#Midi.song_scenes(d, B), 2, "removed; nothing comes back")
  -- names
  Preset.set_scene_names(d, 1, 4, { "Verse", "", "Chorus" })
  eq(Preset.scene_name(d, 1, 4, 0), "Verse"); eq(Preset.scene_name(d, 1, 4, 1), "B-I", "the mini's name")
  eq(Preset.scene_name(d, nil, 0, 2), "C-I", "no preset there"); eq(Preset.has_scene_name(d, nil, 0, 2), false, "no preset: no error")
  eq(Preset.parse_snames(Preset.serialize_snames(S.snames.S1))["1:4"][3], "Chorus")
  -- markers: exactly at the marker
  r.AddProjectMarker2(0, false, 40, 0, "Chorus", -1, 0)
  r.AddProjectMarker2(0, false, 42, 0, "PDFPAGE 2", -1, 0)
  Project.scan()
  eq(Midi.match_markers(d), 1, "1 marker"); eq(Midi.song_scenes(d, B)[2].v, 2, "Chorus = scene 3")
  ok(math.abs(Midi.song_scenes(d, B)[2].t - 40) < 0.001, "at the marker")
  eq(Midi.match_markers(d), 0, "again: nothing new")
  -- a song shows only its own scene changes; removing the preset keeps the scenes
  Midi.add_scene(d, 5, 7)
  Midi.set_song(d, B, nil)
  eq(#Midi.song_scenes(d, B), 3, "the scenes stay")
  r.DeleteTrack(Dev.track(d))
  for i = r.CountProjectMarkers(0) - 1, 0, -1 do
    local _, isr, _, _, nm, idx = r.EnumProjectMarkers(i)
    if not isr and (nm == "Chorus" or nm == "PDFPAGE 2") then r.DeleteProjectMarker(0, idx, false) end
  end
  Project.scan()
  S.devices, S.lib, S.snames, S.pc_when, S.pc_ms = keep, kl, ks, kw, km
end)

test("start scenes: only from Fill songs; after the song's own preset change (timing 'after'); tempo change; next song's change", function()
  local Midi, Preset = C.Midi, C.Preset
  local keep, kl, ks, kw, km, ku = S.devices, S.lib, S.snames, S.pc_when, S.pc_ms, S.pc_unit
  S.devices = { { id = "T1", name = "Gtr", model = "qc", chan = 1, port = "", latency = 0, inport = "" } }
  S.lib, S.snames, S.pc_when, S.pc_ms, S.pc_unit = { T1 = {} }, { T1 = {} }, "after", 250, "ms"
  local d = S.devices[1]
  Dev.create_track(d)
  local A, B = R.regions[1], R.regions[2] -- 0-10, 20-50
  Preset.set_scene_names(d, 1, 9, { "Clean", "Tight AF" })
  Midi.set_song(d, A, 1, 9) -- preset at 0.25
  eq(Midi.start_scene(d, A), nil, "a preset change writes no start scene")
  ok(Midi.fill_starts(d) >= 2, "Fill songs: B gets a preset, both get a start scene")
  local sa = Midi.start_scene(d, A)
  ok(sa and math.abs(sa.t - 0.35) < 0.002, "start scene 100 ms after the preset change")
  eq(Preset.scene_name(d, Midi.preset_at(d, A, sa.t).folder, Midi.preset_at(d, A, sa.t).index, sa.v), "Clean", "its name")
  ok(math.abs(Midi.start_scene(d, B).t - 20.35) < 0.002, "song B too")
  eq(Midi.fill_starts(d), 0, "again: nothing")
  -- a tempo change at the song start
  r.SetTempoTimeSigMarker(0, -1, 20, -1, -1, 90, 0, 0, false); r.UpdateTimeline(); R.pcs = {}
  S.pc_when, S.pc_unit = "before", "notes"
  Midi.clear(d); Midi.clear(d, nil, true)
  Midi.set_song(d, A, 1, 9); Midi.fill_starts(d)
  ok(Midi.song_change(d, B), "B has a preset"); ok(Midi.start_scene(d, B), "B has a start scene")
  r.DeleteTempoTimeSigMarker(0, r.CountTempoTimeSigMarkers(0) - 1); r.UpdateTimeline()
  -- the next song's change "before" its start (inside this song's end) belongs to the next song
  local ci = r.AddProjectMarker2(0, true, 50, 60, "Song C", -1, 0); Project.scan()
  local C3 = R.regions[3]
  S.pc_when, S.pc_unit, S.pc_ms = "before", "ms", 250
  Midi.clear(d); Midi.clear(d, nil, true)
  Midi.set_song(d, A, 1, 9); Midi.set_song(d, C3, 1, 9) -- at 49.75, inside song B
  eq(Midi.song_change(d, B), nil, "not song B's change"); ok(Midi.song_change(d, C3), "song C's change")
  Midi.fill_starts(d)
  local sb = Midi.start_scene(d, B); ok(sb and sb.t < 21, "song B: its start scene at its start")
  r.DeleteProjectMarker(0, ci, true); Project.scan()
  r.DeleteTrack(Dev.track(d))
  S.devices, S.lib, S.snames, S.pc_when, S.pc_ms, S.pc_unit = keep, kl, ks, kw, km, ku
end)

test("scene test: exactly at the cursor, 15 changes every 2 beats, 1 test; replaces its section; move; remove; no room", function()
  local Midi = C.Midi
  local keep, kl, ks = S.devices, S.lib, S.snames
  S.devices = { { id = "X1", name = "Gtr", model = "qc", chan = 1, port = "", latency = 0, inport = "" } }
  S.lib, S.snames = { X1 = {} }, { X1 = {} }
  local d = S.devices[1]
  Dev.create_track(d)
  local B = R.regions[2] -- 20-50, 120 bpm: 2 beats = 1 s
  Midi.insert_change(d, 21.5, 1, 9); R.pcs = {} -- a preset change inside the test: nothing moves
  Midi.add_scene(d, 22.5, 3); Midi.add_scene(d, 45, 4)
  local tend = Midi.add_test(d, B, 20)
  ok(tend and math.abs(tend - 35) < 0.002, "its end: 2 beats after its last change")
  local g = Midi.song_tests(d, B)
  eq(#g, 1, "1 test"); eq(#g[1].evs, 15); ok(math.abs(g[1].t0 - 20) < 0.001, "exactly at the cursor")
  eq(g[1].evs[8].v, 7, "D-II in the middle"); eq(g[1].evs[15].v, 0, "back to A-I")
  eq(#Midi.song_scenes(d, B), 17, "the scene at 22.5 replaced, the one at 45 stays, a stopping point at 35")
  local stop
  for _, s in ipairs(Midi.song_scenes(d, B)) do if math.abs(s.t - 35) < 0.002 then stop = s end end
  ok(stop and stop.v == 0 and not Midi.song_tests(d, B).of[stop], "the stopping point: a normal scene change back to A")
  eq(Midi.merge_all(d), 0, "merge keeps the test and its stopping point")
  ok(Midi.remove_test(d, B, g[1], 30), "moved"); ok(math.abs(Midi.song_tests(d, B)[1].t0 - 30) < 0.001)
  eq(Midi.add_test(d, B, 40), nil, "no room at the end: nothing written")
  eq(Midi.remove_test(d, B, Midi.song_tests(d, B)[1], 40), false, "no room to move: it stays")
  eq(#Midi.song_tests(d, B), 1)
  Midi.remove_test(d, B, Midi.song_tests(d, B)[1]); eq(#Midi.song_tests(d, B), 0, "removed")
  eq(#Midi.song_scenes(d, B), 1, "the scene at 45 (the test end) stays")
  r.DeleteTrack(Dev.track(d))
  S.devices, S.lib, S.snames = keep, kl, ks
end)

test("new MIDI items: the channel of the item; a scene at each song start inside it (the scene that plays, else A-I)", function()
  local Midi = C.Midi
  local keep, kl, ks, kci = S.devices, S.lib, S.snames, S.check_items
  S.devices = { { id = "N1", name = "Gtr", model = "qc", chan = 1, port = "", latency = 0, inport = "" } }
  S.lib, S.snames, S.check_items = { N1 = {} }, { N1 = {} }, true
  local d = S.devices[1]
  Dev.create_track(d)
  local tr = Dev.track(d)
  R.seen = nil; Midi.find_new_items() -- (the first look: only notes the items)
  -- a copied item from 0 to 60 on channel 5, with 1 scene change (B-II at 5 s, inside song A)
  local item = r.CreateNewMIDIItemInProj(tr, 0, 60, false)
  local take = r.GetActiveTake(item)
  r.MIDI_InsertCC(take, false, false, r.MIDI_GetPPQPosFromProjTime(take, 5), 0xB0, 4, 43, 5); r.MIDI_Sort(take)
  Midi.find_new_items()
  eq(d.chan, 5, "the channel of the item")
  local A, B = R.regions[1], R.regions[2]
  local sa, sb = Midi.song_scenes(d, A)[1], Midi.song_scenes(d, B)[1]
  ok(sa and math.abs(sa.t - 0) < 0.001 and sa.v == 0, "song A: A-I at its start (nothing before)")
  ok(sb and math.abs(sb.t - 20) < 0.001 and sb.v == 5, "song B: the scene that plays (B-II) at its start")
  Midi.find_new_items(); eq(#Midi.song_scenes(d, B), 1, "an item is checked only once")
  -- more than 1 channel: a question, nothing changes before the answer
  local item2 = r.CreateNewMIDIItemInProj(tr, 70, 80, false)
  local t2 = r.GetActiveTake(item2)
  r.MIDI_InsertCC(t2, false, false, 0, 0xB0, 4, 43, 1); r.MIDI_InsertCC(t2, false, false, 10, 0xB0, 6, 43, 1); r.MIDI_Sort(t2)
  Midi.find_new_items()
  ok(R.chq and #R.chq.chans == 2, "asks (the 2 channels of the item, 1 of them the current one)"); eq(d.chan, 5, "not changed yet")
  R.chq = nil
  -- the track has MIDI on channel 5: an item on channel 7 asks, it does not switch
  local item3 = r.CreateNewMIDIItemInProj(tr, 80, 85, false)
  local t3 = r.GetActiveTake(item3)
  r.MIDI_InsertCC(t3, false, false, 0, 0xB0, 6, 43, 2); r.MIDI_Sort(t3)
  Midi.find_new_items()
  ok(R.chq and R.chq.other, "asks: MIDI on the current channel"); eq(d.chan, 5, "no switch by itself")
  R.chq = nil
  -- only what plays: an event after the item end and a muted item are not read
  r.MIDI_InsertCC(t3, false, false, r.MIDI_GetPPQPosFromProjTime(t3, 88), 0xB0, 4, 43, 6); r.MIDI_Sort(t3); R.pcs = {}
  for _, s in ipairs(Midi.scenes(d)) do ok(math.abs(s.t - 88) > 0.01, "the hidden event is not read") end
  local n0 = #Midi.scenes(d)
  r.SetMediaItemInfo_Value(item, "B_MUTE", 1); R.pcs = {}
  ok(#Midi.scenes(d) < n0, "a muted item is not read")
  r.DeleteTrack(tr)
  -- a new track (Create track) is not new MIDI: its empty item adds nothing
  local d2 = { id = "N2", name = "Bass", model = "qc", chan = 1, port = "", latency = 0, inport = "" }
  S.devices[2] = d2; S.lib.N2, S.snames.N2 = {}, {}
  Dev.create_track(d2); Project.scan(); Midi.find_new_items()
  eq(#Midi.scenes(d2), 0, "no scenes from Create track")
  r.DeleteTrack(Dev.track(d2))
  S.devices, S.lib, S.snames, S.check_items = keep, kl, ks, kci
end)

test("latency: the track's playback offset; nudge: ms and note values, a row, a song, never out of the song", function()
  local Midi = C.Midi
  local keep, kl, ks, kk, ku, km, kn = S.devices, S.lib, S.snames, S.knobs, S.nudge_unit, S.nudge_ms, S.nudge_note
  S.devices = { { id = "L1", name = "Gtr", model = "qc", chan = 1, port = "", latency = 20, inport = "" } }
  S.lib, S.snames, S.knobs = { L1 = {} }, { L1 = {} }, { L1 = C.Knob.parse("") }
  local d = S.devices[1]
  Dev.create_track(d)
  local tr = Dev.track(d)
  ok(math.abs(r.GetMediaTrackInfo_Value(tr, "D_PLAY_OFFSET") + 0.02) < 0.0001, "-20 ms")
  eq(math.floor(r.GetMediaTrackInfo_Value(tr, "I_PLAY_OFFSET_FLAG")), 0, "on, in seconds")
  d.latency = 0; Dev.apply_latency(d)
  eq(math.floor(r.GetMediaTrackInfo_Value(tr, "I_PLAY_OFFSET_FLAG")), 1, "0 ms: off")
  -- nudge values
  S.nudge_unit, S.nudge_ms = "ms", 10
  ok(math.abs(Midi.nudged(30, 1) - 30.01) < 0.00001, "10 ms later")
  S.nudge_unit, S.nudge_note = "notes", 2 -- 1/16 note at 120 bpm = 125 ms
  ok(math.abs(Midi.nudged(30, -1) - 29.875) < 0.0001, "1/16 note earlier")
  -- a song: all scene changes (not the start scene) and the knob values move together
  local B = R.regions[2] -- 20-50
  Midi.add_scene(d, 20, 0); Midi.add_scene(d, 30, 1); Midi.add_scene(d, 40, 2)
  Midi.set_cc(d, 1, 35, 64)
  S.nudge_unit, S.nudge_ms = "ms", 500
  ok(Midi.nudge_song(d, B, 1), "nudged")
  local l = Midi.song_scenes(d, B)
  ok(math.abs(l[1].t - 20) < 0.001, "the start scene stays"); ok(math.abs(l[2].t - 30.5) < 0.001); ok(math.abs(l[3].t - 40.5) < 0.001)
  ok(math.abs(Midi.ccs(d, 1)[1].t - 35.5) < 0.001, "the knob value too"); eq(Midi.ccs(d, 1)[1].v, 64)
  S.nudge_ms = 1000; Midi.add_scene(d, 49.5, 3)
  eq(Midi.nudge_song(d, B, 1), false, "it would leave the song: nothing moves")
  ok(math.abs(Midi.song_scenes(d, B)[2].t - 30.5) < 0.001, "unchanged")
  -- step 7: the value of a control at a time (on a slope: on the way), the state at a time, Fill songs writes the
  -- control values at the song starts
  Midi.clear(d); Midi.clear(d, nil, true)
  for _, e in ipairs(Midi.ccs(d, 1)) do Midi.remove_cc(d, 1, e) end
  Midi.set_cc(d, 1, 5, 0); Midi.set_shape(d, 1, Midi.ccs(d, 1)[1], 1); Midi.set_cc(d, 1, 9, 100)
  eq(Midi.cc_at(d, 1, 4), nil, "nothing before")
  eq(Midi.cc_at(d, 1, 7), 50, "halfway on a straight slope"); eq(Midi.cc_at(d, 1, 30), 100, "after the last value")
  Midi.set_song(d, R.regions[1], 1, 9); Midi.add_scene(d, 6, 3)
  local st = Midi.state_at(d, 8)
  ok(st.pc and st.pc.index == 9, "the preset"); eq(st.scene, 3, "the scene"); eq(st.ccs[1].cc, 1); eq(st.ccs[1].v, 75)
  -- send_state with "from": only what differs from that place (the same preset is not loaded again)
  local _, pc1, sc1, cc1 = Midi.state_changes(d, 8)
  eq(pc1, true, "no place before: the preset"); eq(sc1, 3); eq(#cc1, 1)
  local _, pc2, sc2, cc2 = Midi.state_changes(d, 8, 7)
  eq(pc2, false, "same preset: not again"); eq(sc2, nil, "same scene: not again"); eq(#cc2, 1, "the value changed (50 -> 75)")
  local _, pc3, sc3, cc3 = Midi.state_changes(d, 30, 30)
  eq(pc3, false); eq(sc3, nil); eq(#cc3, 0, "the same place: nothing")
  local n0 = #Midi.ccs(d, 1)
  Midi.fill_starts(d)
  eq(#Midi.ccs(d, 1), n0, "Set up songs writes no control values")
  eq(Midi.fill_starts(d), 0, "again: nothing")
  r.DeleteTrack(tr)
  S.devices, S.lib, S.snames, S.knobs, S.nudge_unit, S.nudge_ms, S.nudge_note = keep, kl, ks, kk, ku, km, kn
end)

test("scenes: Merge button; times in m:ss and bar.beat; clear; colours; names move with a preset", function()
  local Midi, Preset, Util = C.Midi, C.Preset, C.Util
  local keep, kl, ks, kw, km = S.devices, S.lib, S.snames, S.pc_when, S.pc_ms
  S.devices = { { id = "U1", name = "Gtr", model = "qc", chan = 1, port = "", latency = 0, inport = "" } }
  S.lib, S.snames, S.pc_when, S.pc_ms = { U1 = {} }, { U1 = {} }, "exact", 0
  local d = S.devices[1]
  Dev.create_track(d)
  local B = R.regions[2] -- 20-50
  Midi.set_song(d, B, 1, 0)
  Midi.add_scene(d, 20, 0); Midi.add_scene(d, 30, 1); Midi.add_scene(d, 35, 1); Midi.add_scene(d, 36, 1)
  Midi.add_scene(d, 5, 3); Midi.add_scene(d, 6, 3)
  eq(#Midi.song_scenes(d, B), 4, "adding never merges")
  eq(Midi.merge_all(d), 3, "2 in song B, 1 in song A"); eq(#Midi.song_scenes(d, B), 2); eq(#Midi.song_scenes(d, R.regions[1]), 1)
  -- song B's start scene, rounded a moment before its start, the same scene as at song A's end: Merge keeps it
  Midi.add_scene(d, 19.9997, 3)
  eq(Midi.start_scene(d, B).v, 3, "song B's start scene"); eq(Midi.merge_all(d), 0, "kept")
  eq(Midi.start_scene(d, B).v, 3); Midi.remove_scene(d, Midi.start_scene(d, B))
  eq(Util.fmt_song_time(B, 32.5), "0:12.5"); eq(Util.parse_song_time(B, "0:12.5"), 32.5); eq(Util.parse_song_time(B, "12.5"), 32.5)
  -- 120 bpm 4/4: a bar = 2 s; bars and beats from the project start
  eq(Util.fmt_beats(22), "12.1.00"); eq(Util.fmt_beats(22.75), "12.2.50"); eq(Util.fmt_beats(22.9999), "12.3.00", "rounded up")
  eq(Util.fmt_beats(23.9999), "13.1.00", "before a bar line: the next bar")
  ok(math.abs(Util.parse_beats("12.2.50") - 22.75) < 0.001, "the 3-part format is read")
  ok(math.abs(Util.parse_beats("12.2") - 22.5) < 0.001, "bar.beat read"); eq(Util.parse_beats("x"), nil)
  eq(Util.parse_song_time(B, "x"), nil)
  -- clear: 1 song, then all scenes, then all presets
  eq(Midi.clear(d, B), 2); eq(#Midi.song_scenes(d, B), 0, "Clear scenes: nothing left")
  Midi.add_scene(d, 25, 3)
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
  S.devices, S.lib, S.snames, S.pc_when, S.pc_ms = keep, kl, ks, kw, km
end)

test("review: a new unit does not take a kept track of another unit; channel move; Presets match Regions", function()
  local Midi, Preset = C.Midi, C.Preset
  local keep, keepp, kl, ks, kw, km = S.devices, R.ports, S.lib, S.snames, S.pc_when, S.pc_ms
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
  ok(Midi.move_channel(b, 2, 4) >= 3, "moved"); eq(#Midi.changes(b), 1); ok(not Midi.has_channel(b, 2))
  -- Presets match Regions: the preset only
  S.lib[b.id] = {}
  Preset.set_name(b, 1, 9, "Song B")
  Midi.set_song(b, B, nil); Midi.clear(b)
  eq(Midi.match_names(b), 1); ok(Midi.song_change(b, B), "preset written"); eq(Midi.start_scene(b, B), nil, "no scene")
  r.DeleteTrack(Dev.track(b))
  S.devices, R.ports, S.lib, S.snames, S.pc_when, S.pc_ms = keep, keepp, kl, ks, kw, km
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
  -- a ramp: 2 values with a slope, the values inside replaced; lengths in beats, bars, the time selection
  Midi.set_cc(d, 1, 33, 5)
  ok(math.abs(Midi.ramp_end(32, 1) - 32.5) < 0.001, "1 beat at 120 bpm"); ok(math.abs(Midi.ramp_end(32, 5) - 40) < 0.001, "4 bars")
  r.GetSet_LoopTimeRange2(0, true, false, 31, 36, false); ok(math.abs(Midi.ramp_end(32, 9) - 36) < 0.001, "time selection end")
  r.GetSet_LoopTimeRange2(0, true, false, 0, 0, false); eq(Midi.ramp_end(32, 9), nil, "no time selection")
  ok(math.abs(Midi.ramp_end(32, 8, "2.2") - 37) < 0.001, "custom: 2 bars and 2 beats"); ok(math.abs(Midi.ramp_end(32, 8, "0.6") - 35) < 0.001, "custom: 6 beats")
  eq(Midi.ramp_end(32, 8, "x"), nil, "custom: not a length"); eq(Midi.ramp_end(32, 8, "0"), nil, "custom: 0")
  local before = #Midi.ccs(d, 1)
  Midi.add_ramp(d, 1, (Midi.ramp_points(32, 40, 0, 127, 5, 0.5)))
  local rv = {}
  for _, e in ipairs(Midi.ccs(d, 1)) do if e.t >= 32 - 0.001 and e.t <= 40 + 0.001 then rv[#rv + 1] = e end end
  eq(#rv, 2, "2 values; the one at 33 replaced"); eq(rv[1].v, 0); eq(rv[2].v, 127); eq(rv[1].shape, 5, "curve")
  ok(math.abs(rv[1].tension - 0.5) < 0.01); eq(rv[2].shape, 0, "the end: jump")
  eq(#Midi.ccs(d, 1), before + 1, "1 more in all")
  -- a swell: 0 up to 127 over 4 bars (32-40), a hold of 1 bar (40-42), back to 20 over 2 bars (42-46), Fast end
  local pts, tend = Midi.ramp_points(32, 40, 0, 127, 1, 0, { hold = 3, v2 = 20, len = 4, shape = 4, tension = 0 })
  ok(math.abs(tend - 46) < 0.001, "its end")
  Midi.add_ramp(d, 1, pts, "swell")
  local sw = {}
  for _, e in ipairs(Midi.ccs(d, 1)) do if e.t >= 32 - 0.001 and e.t <= 46 + 0.001 then sw[#sw + 1] = e end end
  eq(#sw, 4, "4 values: start, top, end of the hold, end"); eq(sw[1].v, 0); eq(sw[2].v, 127); eq(sw[3].v, 127); eq(sw[4].v, 20)
  eq(sw[1].shape, 1, "up: straight"); eq(sw[2].shape, 0, "the hold: the value stays"); eq(sw[3].shape, 4, "back: fast end")
  ok(math.abs(sw[3].t - 42) < 0.001, "the hold: 1 bar")
  -- no hold: 3 values
  local p3 = Midi.ramp_points(32, 40, 0, 127, 1, 0, { hold = 0, v2 = 0, len = 4, shape = 1, tension = 0 })
  eq(#p3, 3, "no hold: 3 values")
  -- an LFO (120 bpm: 1 quarter note = 0.5 s): a top or a bottom every half cycle, the last point at the end
  eq(Midi.lfo_cycle(32, 5), 1, "1/4 note"); eq(Midi.lfo_cycle(32, 3), 4, "1 bar in 4/4")
  local lp = Midi.lfo_points(32, 36, 20, 100, 0, 1, false) -- sine, 1/4 note, 2 bars: 16 halves + the end
  eq(#lp, 17, "sine: 16 tops and bottoms + the end"); eq(lp[1].v, 20, "starts at low"); eq(lp[2].v, 100); eq(lp[1].shape, 2, "slow start and end")
  ok(math.abs(lp[2].t - 32.25) < 0.001, "half a cycle later"); eq(lp[17].v, 20, "ends at low"); eq(lp[17].shape, 0)
  eq(Midi.lfo_points(32, 36, 20, 100, 1, 1, true)[1].v, 100, "triangle: starts at high")
  eq(Midi.lfo_points(32, 36, 20, 100, 2, 1, false)[1].shape, 0, "square: jumps")
  local sp = Midi.lfo_points(32, 34, 0, 127, 3, 2, true) -- saw up, 1/2 note, 1 bar: 2 cycles
  eq(#sp, 4, "saw: start, top before the jump, start, end"); eq(sp[1].v, 0, "saw up: starts at low"); eq(sp[2].v, 127)
  eq(sp[2].shape, 0, "the jump back"); eq(sp[3].v, 0); eq(sp[4].v, 127)
  eq(Midi.lfo_points(32, 34, 127, 0, 4, 2, false)[1].v, 127, "saw down: from the first value (high)")
  local fp = Midi.lfo_points(32, 34, 0, 127, 3, 2, true, 0) -- saw up, end at low: a jump back at the end
  eq(#fp, 5, "end at low: 1 more value"); eq(fp[4].v, 127); eq(fp[5].v, 0, "ends at low"); ok(fp[4].t < fp[5].t, "the top just before")
  eq(#Midi.lfo_points(32, 36, 20, 100, 0, 1, false, 20), 17, "already at the end value: nothing more")
  local function vals(p) local s = {} for i, x in ipairs(p) do s[i] = x.v end return table.concat(s, ",") end
  eq(vals(Midi.lfo_points(32, 33, 0, 100, 0, 1, false, nil, 1)), "0,50,0,100,0", "peaks grow")
  eq(vals(Midi.lfo_points(32, 33, 0, 100, 0, 1, false, nil, 2)), "0,100,0,50,0", "peaks shrink")
  eq(vals(Midi.lfo_points(32, 34, 0, 100, 3, 2, true, nil, 1)), "0,50,0,100", "saw: peaks grow")
  local mid = Midi.lfo_points(32, 32.625, 0, 100, 1, 1, false) -- triangle, 1.25 quarter notes: ends halfway up
  eq(mid[#mid].v, 50, "the end: the value there")
  eq(Midi.lfo_points(32, 32, 0, 100, 0, 1, false), nil, "no room")
  Midi.add_ramp(d, 1, lp, "LFO")
  local lv = {}
  for _, e in ipairs(Midi.ccs(d, 1)) do if e.t >= 32 - 0.001 and e.t <= 36 + 0.001 then lv[#lv + 1] = e end end
  eq(#lv, 17, "written: the values inside replaced")
  -- groups: found by their pattern; a name; move; copy and paste; remove
  local fg = Midi.find_groups(lv)
  eq(#fg, 1, "the LFO: 1 group"); eq(fg[1].kind, "lfo"); eq(fg[1].i0, 1); eq(fg[1].i1, 17); eq(fg[1].shape, 0, "sine")
  local lab = Midi.group_label(fg[1], k, lv)
  ok(lab:find("LFO Sine 1/4 note", 1, true) and lab:find("2 bars", 1, true), "its name: " .. lab)
  local function seg(t0, t1)
    local s = {}
    for _, e in ipairs(Midi.ccs(d, 1)) do if e.t >= t0 - 0.001 and e.t <= t1 + 0.001 then s[#s + 1] = e end end
    return s
  end
  local function fake(pts) -- points as values (for the patterns without MIDI)
    local s = {}
    for i, p in ipairs(pts) do s[i] = { t = p.t, v = p.v, shape = i < #pts and p.shape or 0, tension = 0 } end
    return s
  end
  local g2 = Midi.find_groups(fake(Midi.lfo_points(32, 34, 0, 127, 3, 2, true, 0)))
  eq(#g2, 1, "saw up with End at low: 1 group"); eq(g2[1].shape, 3); eq(g2[1].i1, 5)
  local gg = Midi.find_groups(fake(Midi.lfo_points(32, 36, 0, 100, 0, 1, false, nil, 1)))
  eq(#gg, 1, "growing peaks: 1 group"); eq(gg[1].b, 100, "the largest peak"); eq(gg[1].grow, 1)
  ok(Midi.group_label(gg[1], k, fake(Midi.lfo_points(32, 36, 0, 100, 0, 1, false, nil, 1))):find("peaks grow", 1, true), "in the name")
  local gs = Midi.find_groups(fake(Midi.lfo_points(32, 36, 0, 100, 3, 1, true, nil, 2)))
  eq(#gs, 1, "saw, shrinking peaks: 1 group"); eq(gs[1].grow, 2); eq(gs[1].b, 100)
  -- 2 LFOs, 1 right after the other (the 2nd starts on the last value of the 1st, as Add LFO writes them)
  local function joined(p1, p2)
    local s = fake(p1)
    s[#s] = nil -- (replaced by the start of the 2nd)
    for _, x in ipairs(fake(p2)) do s[#s + 1] = x end
    return s
  end
  local two = Midi.find_groups(joined(Midi.lfo_points(32, 34, 0, 100, 0, 1, false), Midi.lfo_points(34, 36, 0, 100, 0, 1, false, nil, 1)))
  eq(#two, 2, "sine, then sine with growing peaks: 2 groups"); eq(two[1].i1 + 1, two[2].i0, "next to each other")
  eq(two[2].i1 - two[2].i0 + 1, 9, "the 2nd: all its 9 values"); eq(two[2].grow, 1)
  local two2 = Midi.find_groups(joined(Midi.lfo_points(32, 34, 0, 100, 3, 1, true), Midi.lfo_points(34, 36, 0, 100, 3, 1, true, nil, 2)))
  eq(#two2, 2, "saw, then saw with shrinking peaks: 2 groups"); eq(two2[1].i1 + 1, two2[2].i0)
  eq(two2[2].i1, #joined(Midi.lfo_points(32, 34, 0, 100, 3, 1, true), Midi.lfo_points(34, 36, 0, 100, 3, 1, true, nil, 2)), "the 2nd: to the end")
  local g3 = Midi.find_groups(fake(Midi.lfo_points(32, 32.625, 0, 100, 1, 1, false)))
  eq(#g3, 1, "an LFO that stops inside a half"); eq(g3[1].i1, 4)
  local sq = Midi.find_groups(fake(Midi.lfo_points(32, 36, 20, 100, 2, 1, false, 100)))
  eq(#sq, 1, "square with End at high"); eq(sq[1].shape, 2); eq(sq[1].i1, 17, "with its end")
  local s3 = Midi.find_groups(fake((Midi.ramp_points(32, 40, 0, 127, 1, 0, { hold = 3, v2 = 20, len = 4, shape = 4, tension = 0 }))))
  eq(#s3, 1, "a swell"); eq(s3[1].kind, "swell"); eq(s3[1].c, 20)
  local r1 = Midi.find_groups(fake((Midi.ramp_points(32, 40, 0, 127, 2, 0))))
  eq(#r1, 1, "a ramp"); eq(r1[1].kind, "ramp")
  eq(#Midi.find_groups({ { t = 1, v = 5, shape = 0 }, { t = 2, v = 9, shape = 0 }, { t = 3.5, v = 5, shape = 0 } }), 0,
    "values without slopes at unequal times: no group")
  -- move the LFO 1 bar later (40 = 2 s later at 120 bpm: 32 -> 34), then copy it to 40 and remove it
  Midi.move_values(d, 1, lv, 1, 17, 34)
  eq(#seg(32, 33.99), 0, "moved away"); local mv = seg(34, 38); eq(#mv, 17, "all 17 at the new place")
  local clip = Midi.group_clip(mv, 1, 17, "x"); ok(math.abs(clip.len - 8) < 0.001, "8 quarter notes long")
  Midi.add_ramp(d, 1, Midi.clip_points(clip, 40), "paste"); eq(#seg(40, 44), 17, "pasted")
  local pv = seg(40, 44); Midi.move_values(d, 1, pv, 1, #pv, nil)
  eq(#seg(40, 44), 0, "removed"); eq(#seg(34, 38), 17, "the copy stays")
  eq(Midi.song_at(25).name, "Song B"); eq(Midi.song_at(15), nil)
  eq(Midi.song_at(19.9995).name, "Song B", "a moment before the start (a rounded start scene): the song")
  r.DeleteTrack(Dev.track(d))
  S.devices = keep
end)

test("settings of this computer: a list of several lines is saved as 1 line (REAPER keeps only line 1)", function()
  local U = C.Util
  local v = "2\t8\t1\t\tDistortion\n2\t8\t2\t3\tClean \\ wide\n2\t8\t3\t\tSolo\\n"
  U.ext_set("test_lines", v)
  local raw = r.GetExtState(C.CFG.EXT, "test_lines")
  ok(not raw:find("\n", 1, true), "saved as 1 line")
  eq(U.ext_get("test_lines"), v, "read back")
  r.DeleteExtState(C.CFG.EXT, "test_lines", true)
end)

test("track names: an old name gets the device name when a project opens; a rename in REAPER renames the device", function()
  local Dev, S = C.Dev, C.S
  local keep = S.devices
  S.devices = { { id = "n1", name = "Quad Cortex mini", model = "mini", chan = 5, port = "", latency = 0 } }
  local d = S.devices[1]
  Dev.create_track(d)
  local tr = Dev.track(d)
  ok(tr, "track")
  d.name = "QC Bass" -- (renamed while another project was open: the track kept the old name)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", "MIDI Quad Cortex mini", true)
  eq(Dev.sync_names(), 1, "renamed")
  eq(Dev.track_name(tr), "MIDI QC Bass", "track follows")
  eq(Dev.sync_names(), 0, "nothing to do")
  C.R.name_sync = nil
  Dev.sync_from_tracks() -- (the names of this scan)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", "MIDI QC asdasd", true)
  Dev.sync_from_tracks()
  eq(d.name, "QC asdasd", "a rename in REAPER renames the device")
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", "Bass", true)
  Dev.sync_from_tracks()
  eq(d.name, "Bass", "without MIDI at the start")
  eq(Dev.sync_names(), 0, "'Bass' matches the device")
  eq(Dev.track_name(tr), "Bass", "the track keeps your name")
  Dev.rename(d, "Bass 2"); eq(Dev.track_name(tr), "MIDI Bass 2", "a device rename")
  eq(r.kbd_getTextFromCmd(41175, 0), "Reset all MIDI devices", "the reset action")
  -- the start of MIDI Pilot (a track renamed while it was closed): the first scan gives the track the device name
  C.Project.save()
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", "Renamed while closed", true)
  C.R.proj, C.R.state_cc = nil, -1
  C.Project.update()
  eq(Dev.track_name(tr), "MIDI Bass 2", "at start: the device name")
  C.Project.update()
  eq(d.name, "Bass 2", "the device keeps its name")
  eq(Dev.track_name(tr), "MIDI Bass 2", "next scan")
  r.DeleteTrack(tr)
  S.devices = keep
end)

test("Line 6 profiles: labels (01A / 000), setlists, no CC#0, snapshots on CC#69, Scene test, USB names, saved format", function()
  local Dev, S, Midi, Preset = C.Dev, C.S, C.Midi, C.Preset
  eq(Preset.label("helix", 0), "01A"); eq(Preset.label("helix", 5), "02B"); eq(Preset.label("helix", 127), "32D")
  eq(Preset.label("helix", 0, "num"), "000"); eq(Preset.label("hxstomp", 127, "num"), "127")
  eq(Preset.label("qc", 9, "num"), "2B", "the Quad Cortex has no number format")
  eq(Dev.model_from_port("Line 6 Helix"), "helix"); eq(Dev.model_from_port("HX Stomp XL"), "hxstompxl")
  eq(Dev.model_from_port("HX Stomp"), "hxstomp"); eq(Dev.model_from_port("HX Effects"), "hxeffects")
  eq(Dev.model_from_port("2- Quad Cortex mini MIDI OUT"), "mini")
  local l = Dev.parse_list(Dev.serialize_list({ { id = "h1", name = "Helix", model = "helix", chan = 2, port = "",
    latency = 0, inport = "", pnum = "num" } }))
  eq(l[1].model, "helix"); eq(l[1].pnum, "num", "number format saved")
  eq(Dev.parse_list("d3\tX\tqc\t1\tp\t0\t")[1].pnum, "bank", "old line: bank + letter")
  local keep = S.devices
  S.devices = { { id = "h2", name = "Stomp test", model = "hxstomp", chan = 1, port = "", latency = 0, inport = "", pnum = "bank" } }
  local d = S.devices[1]
  eq(#Midi.test_seq(d), 5, "HX Stomp: 0 1 2 1 0")
  Dev.create_track(d)
  local tr = Dev.track(d)
  C.R.pcs = {}
  Midi.insert_change(d, 3, 2, 17)
  local take = r.GetActiveTake(r.GetTrackMediaItem(tr, 0))
  local _, _, ncc = r.MIDI_CountEvts(take)
  eq(ncc, 2, "CC#32 and the Program Change only")
  C.R.pcs = {}
  local ch = Midi.changes(d)[1]
  eq(ch.folder, 2, "setlist 3"); eq(ch.index, 17, "preset 17")
  Midi.put_scene(d, 4, 2)
  local _, _, _, _, _, _, m2 = r.MIDI_GetCC(take, 2)
  eq(m2, 69, "snapshot CC")
  Midi.put_scene(d, 5, 5) -- (beyond the 3 snapshots: not read as a scene)
  C.R.pcs = {}
  eq(#Midi.scenes(d), 1, "only valid snapshots")
  r.DeleteTrack(tr)
  S.devices = keep
end)

test("Quad Cortex expression pedals: assignments saved per preset; knob % and pedal position; move with a preset", function()
  local Preset, Knob, S = C.Preset, C.Knob, C.S
  local d = { id = "x1", name = "QC", model = "mini", chan = 1, port = "" }
  ok(Knob.pedal(d, { cc = 1 }) == 1 and Knob.pedal(d, { cc = 2 }) == 2, "CC#1 and CC#2 are pedals")
  ok(not Knob.pedal(d, { cc = 3 }), "CC#3 is not")
  ok(not Knob.pedal({ model = "helix" }, { cc = 1 }), "Line 6: no pedal mode")
  S.expr[d.id] = {}
  Preset.set_expr(d, 1, 0, { { { name = "Hi Pass", from = 0, to = 55, note = "0% = Off" }, { name = " ", from = 0, to = 1 } },
    { { name = "Low Pass", from = 100, to = 15, note = "" } } })
  local back = Preset.parse_expr(Preset.serialize_expr(S.expr[d.id]))
  local l1, l2 = back["1:0"][1], back["1:0"][2]
  eq(#l1, 1, "an empty name is dropped"); eq(l1[1].name, "Hi Pass"); eq(l1[1].to, 55); eq(l1[1].note, "0% = Off")
  eq(l2[1].from, 100); eq(l2[1].to, 15, "backwards")
  eq(Knob.assign_at(l1[1], 40), 22, "Hi Pass at pedal 40%"); eq(Knob.assign_at(l2[1], 40), 66, "Low Pass at pedal 40%")
  Preset.set_name(d, 1, 0, "Song"); Preset.move(d, 1, 0, 1, 5)
  eq(#Preset.expr(d, 1, 5, 2), 1, "moved with the preset"); eq(#Preset.expr(d, 1, 0, 1), 0)
  S.expr[d.id] = nil; S.lib[d.id] = nil
end)

test("Quad Cortex functions: the 2 pedals always, then footswitches, tap, tuner, Gig View, mode; labels; 4 taps", function()
  local Dev, S, Midi, Knob = C.Dev, C.S, C.Midi, C.Knob
  local keep = S.devices
  S.devices = { { id = "f1", name = "QC f", model = "mini", chan = 1, port = "", latency = 0, inport = "", pnum = "bank" } }
  local d = S.devices[1]
  S.knobs[d.id] = { { cc = 7, name = "Old", min = 0, max = 1, unit = "%" } }
  local l = Knob.list(d)
  eq(l[1].cc, 1); eq(l[2].cc, 2); eq(l[1].max, 100, "pedal 0-100%")
  eq(#l, 2 + 8 + 1 + 4, "pedals, 8 footswitches, page (mini), tap, tuner, Gig View, mode")
  local by = {}
  for _, k in ipairs(l) do by[k.cc] = k end
  eq(by[35].name, "Footswitch A (I)"); eq(by[42].name, "Footswitch D (II)"); eq(by[64].name, "Footswitch page")
  eq(Knob.label(by[45], 127), "Open"); eq(Knob.label(by[45], 10), "Close"); eq(Knob.label(by[45], 64), "Open")
  eq(Knob.label(by[47], 2), "Slot 3 (Stomp)"); eq(Knob.label(by[64], 0), "Page I")
  eq(#Knob.levels(d), 2, "only the pedals play on")
  ok(not Knob.pedal(d, by[35]), "a footswitch is not a pedal")
  eq(#Knob.list({ id = "f2", model = "qc" }), 2 + 8 + 4, "full size: no page swap")
  Dev.create_track(d)
  local tr = Dev.track(d)
  C.R.pcs = {}
  Midi.add_taps(d, 44, 4)
  eq(#Midi.ccs(d, 44), 4, "4 taps")
  local c = Midi.ccs(d, 44)
  ok(math.abs((c[2].t - c[1].t) - 0.5) < 0.01, "on the beat (120 bpm)")
  r.DeleteTrack(tr)
  S.knobs[d.id] = nil
  S.devices = keep
end)

test("Add device: a chosen model (no output), or a connected unit (its output and model)", function()
  local Dev, S = C.Dev, C.S
  local keep = S.devices
  S.devices = {}
  local d = Dev.new("hxstomp")
  eq(d.model, "hxstomp"); eq(d.port, "", "no output yet"); eq(d.name, "Line 6 HX Stomp")
  local d2 = Dev.new(nil, "Quad Cortex mini MIDI OUT")
  eq(d2.model, "mini", "from the output name"); eq(d2.port, "Quad Cortex mini MIDI OUT")
  eq(#S.devices, 2)
  S.devices = keep
end)

test("a preset change inside a song: add, move, change, remove; the song's own preset stays", function()
  local Dev, S, Midi = C.Dev, C.S, C.Midi
  local keep = S.devices
  S.devices = { { id = "p9", name = "PC test", model = "mini", chan = 1, port = "", latency = 0, inport = "", pnum = "bank" } }
  local d = S.devices[1]
  Dev.create_track(d)
  local tr = Dev.track(d)
  C.R.pcs = {}
  local A = C.R.regions[1] -- (0-10 s)
  Midi.set_song(d, A, 1, 4)
  eq(#Midi.song_extra_pcs(d, A), 0, "only the song's own preset")
  Midi.put_pc(d, 5, 1, 9)
  local x = Midi.song_extra_pcs(d, A)
  eq(#x, 1, "added"); eq(x[1].index, 9); ok(math.abs(x[1].t - 5) < 0.002, "at 5 s")
  eq(Midi.song_change(d, A).index, 4, "the song's own preset stays")
  eq(Midi.preset_at(d, A, 6).index, 9, "after it: the new preset"); eq(Midi.preset_at(d, A, 3).index, 4, "before it")
  Midi.put_pc(d, 7, x[1].folder, x[1].index, x[1])
  x = Midi.song_extra_pcs(d, A)
  ok(#x == 1 and math.abs(x[1].t - 7) < 0.002, "moved")
  Midi.put_pc(d, x[1].t, 2, 30, x[1])
  x = Midi.song_extra_pcs(d, A)
  ok(#x == 1 and x[1].folder == 2 and x[1].index == 30, "changed")
  Midi.put_pc(d, 0, nil, nil, x[1])
  eq(#Midi.song_extra_pcs(d, A), 0, "removed"); eq(Midi.song_change(d, A).index, 4)
  r.DeleteTrack(tr)
  S.devices = keep
end)

test("export: 1 MIDI file for the show, 1 per song (preset and start scene at 0:00; no next song's preset); ramps as steps", function()
  local Dev, S, Midi = C.Dev, C.S, C.Midi
  local keep, kw = S.devices, S.pc_when
  S.pc_when = "before"
  S.devices = { { id = "e1", name = "Export test", model = "mini", chan = 2, port = "", latency = 0, inport = "", pnum = "bank" } }
  local d = S.devices[1]
  Dev.create_track(d)
  local tr = Dev.track(d)
  C.R.pcs = {}
  local A, B = C.R.regions[1], C.R.regions[2] -- (0-10 s and 20-50 s)
  Midi.set_song(d, A, 1, 4); Midi.set_song(d, B, 1, 200)
  Midi.add_scene(d, 2, 3); Midi.add_scene(d, 25, 5)
  Midi.set_cc(d, 1, 26, 0); Midi.set_shape(d, 1, Midi.ccs(d, 1)[1], 1); Midi.set_cc(d, 1, 28, 127)
  -- the song file of B: its preset (before its start) and its scene at 0:00; no preset of a next song
  local ev = Midi.song_file_events(d, B)
  ok(ev[1].cm == 0xB0 and ev[1].m2 == 0 and ev[1].m3 == 1, "CC0 = 1 (preset 200)")
  ok(ev[2].m2 == 32 and ev[3].cm == 0xC0 and ev[3].m2 == 200 % 128, "CC32, then the Program Change")
  local steps = 0
  for _, e in ipairs(ev) do if e.cm == 0xB0 and e.m2 == 1 then steps = steps + 1 end end
  ok(steps > 5, "the ramp as steps (" .. steps .. ")")
  local evA = Midi.song_file_events(d, A)
  for _, e in ipairs(evA) do ok(not (e.cm == 0xC0 and e.m2 == 200 % 128), "no next song's preset in song A") end
  -- the files
  local n, dir = Midi.export(d, false)
  eq(n, 1, "1 file"); ok(dir, "a folder")
  local n2, sub = Midi.export(d, true)
  eq(n2, #C.R.regions, "1 file per song")
  local f = io.open(sub .. "/02 Song B.mid", "rb")
  ok(f, "Song B's file")
  local data = f:read("a"); f:close()
  eq(data:sub(1, 4), "MThd", "a MIDI file"); ok(data:find("MTrk", 1, true), "its track")
  ok(data:find(string.char(0xC1, 200 % 128), 1, true), "the Program Change on channel 2")
  for _, fn in ipairs({ sub .. "/01 Song A.mid", sub .. "/02 Song B.mid" }) do os.remove(fn) end
  -- the export folder: saved in the project only when chosen; the default folder is not saved
  local P = C.get_P()
  eq(P.export_dir, "", "default")
  Midi.set_export_dir("C:/Exports/Show/")
  eq(Midi.export_dir(), "C:/Exports/Show", "chosen (no slash at the end)")
  eq(C.Project.parse(C.Project.serialize()).export_dir, "C:/Exports/Show", "saved and read")
  Midi.set_export_dir(Midi.default_export_dir())
  eq(P.export_dir, "", "the default folder is not saved")
  ok(not C.Project.serialize():find("export_dir", 1, true), "nothing written")
  r.DeleteTrack(tr)
  S.devices, S.pc_when = keep, kw
end)

test("presets from names and markers (P 3B), markers from scenes", function()
  local Dev, S, Midi, Preset = C.Dev, C.S, C.Midi, C.Preset
  local keep, kl = S.devices, S.lib
  S.devices = { { id = "q1", name = "QoL test", model = "qc", chan = 1, port = "", latency = 0, inport = "", pnum = "bank" } }
  local d = S.devices[1]
  S.lib = { q1 = { ["1:12"] = "Lead" } }
  eq(Preset.parse_label(d, "Song One [3B]"), Preset.index("qc", 3, 2), "[3B]")
  eq(Preset.parse_label(d, "3b Song One"), Preset.index("qc", 3, 2), "3b at the start")
  eq(Preset.parse_label(d, "Song One"), nil, "no number")
  eq(Preset.parse_label(d, "Song 99Z"), nil, "not a preset")
  local hx = { model = "hxstomp", pnum = "num" }
  eq(Preset.parse_label(hx, "Song - 017"), 17, "Line 6 numbers")
  local f, i = Preset.from_text(d, "Lead", Preset.by_name(d))
  ok(f == 1 and i == 12, "a preset name")
  Dev.create_track(d)
  local tr = Dev.track(d)
  C.R.pcs = {}
  local A = C.R.regions[1] -- (0-10 s)
  -- a marker "P Lead" inside song A
  local mi = r.AddProjectMarker2(0, false, 6, 0, "P Lead", -1, 0)
  C.Project.scan()
  eq(Midi.match_marker_presets(d), 1, "1 preset change from a marker")
  local at6
  for _, ch in ipairs(Midi.changes(d)) do if math.abs(ch.t - 6) < 0.002 then at6 = ch end end
  ok(at6 and at6.index == 12 and at6.folder == 1, "at the marker, preset Lead")
  ok(A, "song A")
  eq(Midi.match_marker_presets(d), 0, "again: nothing")
  r.DeleteProjectMarker(0, mi, false)
  -- markers from scenes
  Midi.add_scene(d, 2, 1); Midi.add_scene(d, 4, 3)
  C.Project.scan()
  local m0 = #C.R.markers
  eq(Midi.markers_from_scenes(d), 2, "2 markers")
  C.Project.scan()
  eq(#C.R.markers, m0 + 2, "in the project")
  eq(Midi.markers_from_scenes(d), 0, "again: nothing")
  for _, mk in ipairs({ "B", "D" }) do
    for j = r.CountProjectMarkers(0) - 1, 0, -1 do
      local _, isrgn, _, _, nm, idx = r.EnumProjectMarkers3(0, j)
      if not isrgn and nm == mk then r.DeleteProjectMarker(0, idx, false) end
    end
  end
  C.Project.scan()
  r.DeleteTrack(tr)
  S.devices, S.lib = keep, kl
end)

test("first scene and other presets / scenes: at, before, after (ms and note values), after the region's preset", function()
  local Dev, S, Midi = C.Dev, C.S, C.Midi
  local keep = S.devices
  local ks = { S.pc_when, S.pc_unit, S.pc_ms, S.pc_note, S.pc_other, S.sc_first, S.sc_other, S.sc_unit, S.sc_ms, S.sc_note }
  S.devices = { { id = "t1", name = "Timing test", model = "mini", chan = 1, port = "", latency = 0, inport = "", pnum = "bank" } }
  local d = S.devices[1]
  Dev.create_track(d)
  local tr = Dev.track(d)
  C.R.pcs = {}
  local B = C.R.regions[2] -- (20-50 s; 120 bpm: 1 beat = 0.5 s)
  local function near(a, b, what) ok(math.abs(a - b) < 0.002, what .. ": " .. a .. " (want " .. b .. ")") end
  -- first scene
  S.sc_unit, S.sc_ms, S.sc_note = "notes", 100, 4 -- (1 beat)
  S.sc_first = "start"; near(Midi.start_time(d, B), 20, "at the region start")
  S.sc_first = "before"; near(Midi.start_time(d, B), 19.5, "1 beat before")
  S.sc_first = "after"; near(Midi.start_time(d, B), 20.5, "1 beat after")
  S.sc_first = "after_pc"; near(Midi.start_time(d, B), 20, "after the preset: no preset, the start")
  S.pc_when, S.pc_unit, S.pc_note = "after", "notes", 4
  Midi.set_song(d, B, 1, 3) -- (the preset 1 beat after the start: 20.5 s)
  near(Midi.start_time(d, B), 21, "1 beat after the preset (on the grid)")
  S.pc_when = "before"; Midi.set_song(d, B, 1, 3) -- (the preset 1 beat before: 19.5 s)
  near(Midi.start_time(d, B), 20, "a preset before the start: never before the start")
  S.sc_first = "before"
  Midi.ensure_start_scene(d, B)
  ok(Midi.start_scene(d, B), "a first scene before the start is found")
  eq(Midi.ensure_start_scene(d, B), false, "not added again")
  -- other presets and scenes
  S.pc_other, S.pc_unit, S.pc_ms = "before", "ms", 250
  near(Midi.other_time("pc", 30), 29.75, "an added preset 250 ms before")
  S.sc_other, S.sc_unit, S.sc_ms = "after", "ms", 100
  near(Midi.other_time("sc", 30), 30.1, "an added scene 100 ms after")
  S.sc_other = "exact"; near(Midi.other_time("sc", 30), 30, "exactly")
  r.DeleteTrack(tr)
  S.devices = keep
  S.pc_when, S.pc_unit, S.pc_ms, S.pc_note, S.pc_other, S.sc_first, S.sc_other, S.sc_unit, S.sc_ms, S.sc_note = table.unpack(ks)
end)

test("a muted MIDI item is never written: a scene goes into a playing item (and shows)", function()
  local Dev, S, Midi = C.Dev, C.S, C.Midi
  local keep = S.devices
  S.devices = { { id = "m1", name = "Mute test", model = "qc", chan = 1, port = "", latency = 0 } }
  local d = S.devices[1]
  Dev.create_track(d)
  local tr = Dev.track(d)
  ok(tr, "track")
  local item = r.GetTrackMediaItem(tr, 0)
  r.SetMediaItemInfo_Value(item, "B_MUTE", 1)
  C.R.pcs = {}
  Midi.put_scene(d, 5, 2)
  eq(r.CountTrackMediaItems(tr), 2, "a new item")
  local sc = Midi.scenes(d)
  eq(#sc, 1, "the scene shows")
  eq(sc[1].v, 2, "its scene")
  ok(r.GetMediaItemTake_Item(sc[1].take) ~= item, "not in the muted item")
  r.DeleteTrack(tr)
  S.devices = keep
end)

---------------------------------------------------------------------------
for _, t in ipairs(tests) do
  local good, e = pcall(t[2])
  if good then passed = passed + 1; log("ok    " .. t[1])
  else failed = failed + 1; log("FAIL  " .. t[1] .. ": " .. tostring(e)) end
end
finish()
