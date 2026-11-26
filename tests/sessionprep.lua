-- @noindex
-- Session Prep tests. Run with .\tools\test.ps1 -Script "Session Prep" (it starts the portable test REAPER in C:\REAPERtest).
-- Loads Session Prep.lua without its window, runs each test, writes tests\result_sessionprep.txt, quits REAPER.
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

local tmp = r.GetResourcePath() .. "\\SessionPrepTests"
r.RecursiveCreateDirectory(tmp, 0)
local proj_file = tmp .. "\\test.rpp"
local pf = io.open(proj_file, "w")
if pf then pf:write("<REAPER_PROJECT 0.1\n>\n"); pf:close() end
r.Main_openProject("noprompt:" .. proj_file)

local function finish()
  log(string.format("%d passed, %d failed", passed, failed))
  local f = io.open(here .. "\\result_sessionprep.txt", "w")
  if f then f:write(table.concat(out, "\n"), "\n"); f:close() end
  r.Main_SaveProject(0, false)
  r.defer(function() r.Main_OnCommand(40004, 0) end) -- File: Quit REAPER
end

SessionPrepTest = {}
local loaded, err = pcall(dofile, here .. "\\..\\Session Prep\\Session Prep.lua")
local C = SessionPrepTest
if not loaded or not C.Prep then
  log("FAIL  load Session Prep.lua: " .. tostring(err)); failed = 1; finish(); return
end
local Prep, Rules, Audio, S, R = C.Prep, C.Rules, C.Audio, C.S, C.R
log(string.format("REAPER %s in %s, Session Prep %s loaded", r.GetAppVersion(), r.GetResourcePath(), C.CFG.VERSION))

-- a bus member of the preset (kind "f" folder / "t" track name)
function UI_has_member(p, kind, name)
  for _, b in ipairs(p.buses) do
    for _, mb in ipairs(b.members) do if mb.kind == kind and mb.name == name then return true end end
  end
  return false
end
local function defaults()
  S.presets, S.preset = Rules.default_presets(), 1
  S.folders, S.pairs, S.audio = true, true, false
  S.color, S.spacer, S.returns, S.gain, S.color_win, S.caps = true, true, false, false, false, "none"
  R.folder_list = nil
  R.comp = nil
end
-- the new names of a list of plain names (no REAPER tracks)
local function plan(names)
  defaults()
  local scan = { tracks = {}, scope = "all", folders_ok = true }
  for i, n in ipairs(names) do scan.tracks[i] = { name = n } end
  return Prep.plan(scan)
end

test("base_clean removes Audio N, numbers and .wav", function()
  eq(Prep.base_clean("Audio 1_Kik In.wav"), "Kik In")
  eq(Prep.base_clean("Audio3-OH L"), "OH L")
  eq(Prep.base_clean("03_Snare Top.WAV"), "Snare Top")
  eq(Prep.base_clean("Bass DI"), "Bass DI")
end)

test("tokens split case and digits", function()
  local t = Prep.tokens("KikIn_01")
  eq(table.concat(t, ","), "kik,in,01")
  eq(table.concat(Prep.tokens("OH1"), ","), "oh,1")
end)

test("names from the default rules keep the extra words", function()
  local rows = plan({ "Audio 1_Kik In", "Kick Out", "Snare Btm", "OH L", "OH R", "Bass DI", "Lead Vox", "BGV 1", "Click" })
  eq(rows[1].new, "Kick In"); eq(rows[1].folder, "Drums")
  eq(rows[2].new, "Kick Out")
  eq(rows[3].new, "Snare Btm")
  eq(rows[4].new, "OH L"); eq(rows[5].new, "OH R")
  eq(rows[6].new, "Bass DI"); eq(rows[6].folder, "Bass")
  eq(rows[7].new, "Lead Vox"); eq(rows[7].folder, "Vocals")
  eq(rows[8].new, "BV 1")
  eq(rows[9].new, "Click"); eq(rows[9].folder, "Other")
end)

test("short words match only whole words", function()
  local rows = plan({ "Snapshot", "Subkick" })
  eq(rows[1].rule_idx, nil, "sn must not match Snapshot")
  eq(rows[1].new, "Snapshot")
  eq(rows[2].new, "Kick Sub", "subkick: the Kick Sub rule (before Kick)")
end)

test("rule order sets the priority", function()
  local rows = plan({ "Lead Gtr", "Synth Bass" })
  eq(rows[1].new, "Lead Gtr", "Lead Gtr: its own rule, in Guitars")
  eq(rows[1].folder, "Guitars")
  eq(rows[2].folder, "Bass")
end)

test("the same name twice gets numbers", function()
  local rows = plan({ "Gtr", "Guitar", "Bass" })
  eq(rows[1].new, "Gtr 1"); eq(rows[2].new, "Gtr 2"); eq(rows[3].new, "Bass")
end)

test("L / R sides (every track with L or R is panned)", function()
  local rows = plan({ "OH L", "OH R", "Room L", "Snare", "gtr1 r", "gtr2 l" })
  eq(rows[1].side, "L"); eq(rows[2].side, "R")
  eq(rows[3].side, "L", "a single L is panned too")
  eq(rows[4].side, nil)
  eq(rows[5].new, "Gtr 1 R"); eq(rows[5].side, "R")
  eq(rows[6].new, "Gtr 2 L"); eq(rows[6].side, "L")
end)

test("Gtr L / Gtr R keep their side (the rule name Gtr has the letter r)", function()
  local rows = plan({ "gtr l", "gtr r" })
  eq(rows[1].new, "Gtr L"); eq(rows[2].new, "Gtr R")
  eq(rows[1].side, "L"); eq(rows[2].side, "R")
end)

test("unnamed tracks stay as they are", function()
  defaults()
  local scan = { tracks = { { name = "", label = "Track 1" }, { name = "", label = "Track 2" }, { name = "Kik" } },
    scope = "all", folders_ok = true }
  local rows = Prep.plan(scan)
  eq(rows[1].new, "Track 1"); eq(rows[1].old, "Track 1")
  eq(rows[2].new, "Track 2")
  eq(rows[3].new, "Kick")
end)

test("shared prefix and suffix go; rule words stay", function()
  local rows = plan({ "MySong_Kick_take2", "MySong_Snare_take2", "MySong_Bass_take2" })
  eq(rows[1].new, "Kick"); eq(rows[2].new, "Snare"); eq(rows[3].new, "Bass")
  rows = plan({ "Kick In", "Kick Out" })
  eq(rows[1].new, "Kick In", "the prefix Kick is a rule word"); eq(rows[2].new, "Kick Out")
  rows = plan({ "OH L", "OH R" })
  eq(rows[1].new, "OH L", "a short prefix stays")
end)

test("the audio verdict", function()
  eq(Audio.verdict(0, 0, 0, true), "silent")
  eq(Audio.verdict(0.5, 0.5, 0, true), "fake")
  eq(Audio.verdict(0.5, 0, 0.5, true), "only_l")
  eq(Audio.verdict(0, 0.5, 0.5, true), "only_r")
  eq(Audio.verdict(0.5, 0.4, 0.3, true), nil)
  eq(Audio.verdict(0.5, 0.5, 0, false), nil, "a mono source is never fake stereo")
end)

test("presets save and load (text)", function()
  defaults()
  local p = S.presets[1]
  local q = Rules.parse(Rules.serialize(p))
  ok(q, "parse")
  eq(Rules.serialize(q), Rules.serialize(p))
  eq(#q.rules, #p.rules)
  eq(q.rules[1].color, p.rules[1].color)
  eq(Rules.safe("a|b;c~d"), "abcd")
  eq(Rules.parse("garbage"), nil)
end)

test("the built-in presets are not saved; a changed one is", function()
  defaults()
  C.Util.save_settings()
  eq(r.GetExtState("Session Prep", "presets_n"), "", "defaults: no key")
  S.presets[1].rules[1].name = "BD"
  C.Util.save_settings()
  eq(r.GetExtState("Session Prep", "presets_n"), "2")
  C.Util.load_settings()
  eq(S.presets[1].rules[1].name, "BD")
  defaults()
  C.Util.save_settings()
  eq(r.GetExtState("Session Prep", "presets_n"), "", "back to the defaults: the key goes")
end)

test("Apply: names, colors, folders, pans; 1 undo", function()
  defaults()
  r.Undo_BeginBlock() -- (its own undo point: Ctrl+Z below undoes only Apply)
  for i = r.CountTracks(0) - 1, 0, -1 do r.DeleteTrack(r.GetTrack(0, i)) end
  local names = { "Audio 1_Bass DI", "Audio 2_Kik In", "Audio 3_OH L", "Audio 4_OH R", "Audio 5_Click" }
  for i, n in ipairs(names) do
    r.InsertTrackAtIndex(i - 1, false)
    r.GetSetMediaTrackInfo_String(r.GetTrack(0, i - 1), "P_NAME", n, true)
  end
  r.Undo_EndBlock("test tracks", -1)
  r.Main_OnCommand(40297, 0) -- unselect all: Scan reads all tracks
  Prep.scan()
  eq(#R.rows, 5)
  Prep.apply(R.rows)
  local got = {}
  for i = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, i)
    local _, n = r.GetTrackName(tr)
    got[#got + 1] = n .. ":" .. math.floor(r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH"))
  end
  eq(table.concat(got, ","), "Drums:1,Kick In:0,OH L:0,OH R:-1,Bass:1,Bass DI:-1,Other:1,Click:-1")
  eq(r.GetMediaTrackInfo_Value(r.GetTrack(0, 0), "I_SPACER"), 0, "no spacer above the first folder")
  eq(r.GetMediaTrackInfo_Value(r.GetTrack(0, 4), "I_SPACER"), 1, "a spacer above the Bass folder")
  local ohl = r.GetTrack(0, 2)
  eq(r.GetMediaTrackInfo_Value(ohl, "D_PAN"), -1, "OH L panned left")
  eq(r.GetMediaTrackInfo_Value(ohl, "D_DUALPANL"), -1, "dual pan L knob left")
  eq(r.GetMediaTrackInfo_Value(r.GetTrack(0, 3), "D_DUALPANR"), 1, "OH R dual pan R knob right")
  ok(r.GetMediaTrackInfo_Value(r.GetTrack(0, 1), "I_CUSTOMCOLOR") ~= 0, "Kick colored")
  r.Main_OnCommand(40029, 0) -- Edit: Undo
  eq(r.CountTracks(0), 5, "undo removes the folders")
  local _, n1 = r.GetTrackName(r.GetTrack(0, 0))
  eq(n1, "Audio 1_Bass DI", "undo restores the names")
end)

test("real tracks gtr l / gtr r between others get their side", function()
  defaults()
  r.Undo_BeginBlock()
  for i = r.CountTracks(0) - 1, 0, -1 do r.DeleteTrack(r.GetTrack(0, i)) end
  for i, n in ipairs({ "Kik", "", "gtr l", "gtr r", "Snare", "" }) do
    r.InsertTrackAtIndex(i - 1, false)
    r.GetSetMediaTrackInfo_String(r.GetTrack(0, i - 1), "P_NAME", n, true)
  end
  r.Undo_EndBlock("test tracks 2", -1)
  r.Main_OnCommand(40297, 0)
  Prep.scan()
  local got = {}
  for _, row in ipairs(R.rows) do got[#got + 1] = row.new .. (row.side and "*" or "") end
  eq(table.concat(got, ","), "Kick,Track 2,Gtr L*,Gtr R*,Snare,Track 6")
end)

test("gain staging: the change to the target, limited by the peak", function()
  defaults()
  S.gain_rms, S.gain_peak = -18, -6
  local function lin(db) return 10 ^ (db / 20) end
  eq(Prep.gain_for(lin(-24), lin(-14)), 6, "RMS -24 -> +6 dB")
  eq(Prep.gain_for(lin(-24), lin(-3)), -3, "the peak limit wins (the exact peak: no extra room): peak -3 -> -3 dB")
  eq(Prep.gain_for(nil, nil), nil, "no audio")
  eq(Prep.gain_for(lin(-18), lin(-10)), 0)
end)

test("presets keep their folder FX chains", function()
  defaults()
  local p = S.presets[1]
  p.fx = { Drums = "C:\\x\\Drum bus.RfxChain" }
  local q = Rules.parse(Rules.serialize(p))
  eq(q.fx.Drums, "C:\\x\\Drum bus.RfxChain")
  eq(Rules.copy(p).fx.Drums, p.fx.Drums, "Save as copies the chains")
  R.folder_list = nil
  eq(table.concat(Rules.folders(p), ","), "Drums,Perc,Bass,Guitars,Keys,Strings,Brass,Vocals,Other")
end)

test("Scan all ignores the selection; Apply adds the folder FX chain and the gain", function()
  defaults()
  S.gain = true
  r.Undo_BeginBlock()
  for i = r.CountTracks(0) - 1, 0, -1 do r.DeleteTrack(r.GetTrack(0, i)) end
  for i, n in ipairs({ "Kik", "Snare", "Bass" }) do
    r.InsertTrackAtIndex(i - 1, false)
    r.GetSetMediaTrackInfo_String(r.GetTrack(0, i - 1), "P_NAME", n, true)
  end
  r.Undo_EndBlock("test tracks 3", -1)
  r.SetOnlyTrackSelected(r.GetTrack(0, 0))
  Prep.scan(true)
  eq(#R.rows, 3, "all 3 tracks, with 1 selected")
  -- an FX chain file with ReaEQ, as REAPER saves it (the FX part of a track with ReaEQ)
  local chain = tmp .. "\\Drum bus.RfxChain"
  r.InsertTrackAtIndex(r.CountTracks(0), false)
  local scratch = r.GetTrack(0, r.CountTracks(0) - 1)
  r.TrackFX_AddByName(scratch, "ReaEQ", false, -1)
  local _, ch = r.GetTrackStateChunk(scratch, "", false)
  local body = ch:match("<FXCHAIN\n.-\nDOCKED %d+\n(.*)\n>\n>%s*$")
  ok(body, "the FX part of the chunk")
  r.DeleteTrack(scratch)
  local f = io.open(chain, "w")
  ok(f, "write the chain file")
  if f then f:write(body .. "\n"); f:close() end
  S.presets[1].fx = { Drums = chain }
  -- a fake gain on the Kick (no audio in the test: the gain is set by hand)
  r.AddMediaItemToTrack(R.rows[1].t.tr)
  R.rows[1].gain = 6
  Prep.apply(R.rows)
  local drums = r.GetTrack(0, 0)
  local _, n = r.GetTrackName(drums)
  eq(n, "Drums")
  eq(r.TrackFX_GetCount(drums), 1, "the FX chain is on the Drums folder")
  local kick = r.GetTrack(0, 1)
  local it = r.GetTrackMediaItem(kick, 0)
  ok(it, "the Kick item")
  ok(math.abs(r.GetMediaItemInfo_Value(it, "D_VOL") - 10 ^ (6 / 20)) < 1e-6, "the item gain is +6 dB")
  r.Main_OnCommand(40029, 0)
  S.gain = false
end)

test("an FX chain goes after the FX that a track already has", function()
  local chain = tmp .. "\\Drum bus.RfxChain" -- (written by the test before)
  r.InsertTrackAtIndex(0, true)
  local t0 = r.GetTrack(0, 0)
  r.TrackFX_AddByName(t0, "ReaComp", false, -1)
  ok(Prep.add_chain(t0, chain), "added")
  eq(r.TrackFX_GetCount(t0), 2, "ReaComp + ReaEQ")
  local _, n = r.TrackFX_GetFXName(t0, 1, "")
  ok(n:find("ReaEQ"), "the chain is after the old FX")
  r.DeleteTrack(t0)
end)

test("gain staging: Target Peak", function()
  defaults()
  S.gain_by_peak, S.gain_ptarget = true, -10
  local function lin(db) return 10 ^ (db / 20) end
  eq(Prep.gain_for(lin(-24), lin(-1)), -9, "peak -1 -> -9 dB")
  eq(Prep.gain_for(lin(-30), lin(-16)), 6, "peak -16 -> +6 dB")
  S.gain_by_peak = false
end)

test("industry names: Kick Sub, Hi-Hat, Floor Tom, Lead Vox", function()
  local rows = plan({ "Sub Kick", "HH", "Floor Tom", "Tom 2", "Vox Dbl", "Pno", "Shaker", "Gtr DI" })
  eq(rows[1].new, "Kick Sub"); eq(rows[2].new, "Hi-Hat"); eq(rows[3].new, "Floor Tom"); eq(rows[4].new, "Tom 2")
  eq(rows[5].new, "Lead Vox Dbl"); eq(rows[6].new, "Piano"); eq(rows[7].new, "Perc"); eq(rows[8].new, "Gtr DI")
end)

test("the full preset text: order, track FX, returns, sends", function()
  defaults()
  local p = S.presets[2]
  eq(p.name, "Vocals first"); eq(p.order[1], "Vocals")
  p.tfx = { Kick = "C:\\k.RfxChain" }
  local q = Rules.parse(Rules.serialize(p))
  eq(Rules.serialize(q), Rules.serialize(p), "the same text")
  eq(q.tfx.Kick, "C:\\k.RfxChain"); eq(#q.returns, 4); eq(q.returns[1].name, "Room Verb")
  ok(q.sends.Drums["Drum Crush"], "Drums -> Drum Crush"); eq(q.returns[1].db, -12); eq(q.returns[4].db, 0); eq(q.returns[4].out, "f:Drums"); eq(q.returns[4].src, "t")
  R.folder_list = nil
  eq(Rules.folders(q)[1], "Vocals", "Vocals first")
  R.folder_list = nil
end)

test("Apply: Vocals first order, returns, sends, Track FX; colors off", function()
  defaults()
  S.preset, S.color, S.returns = 2, false, true
  R.comp, R.folder_list = nil, nil
  r.Undo_BeginBlock()
  for i = r.CountTracks(0) - 1, 0, -1 do r.DeleteTrack(r.GetTrack(0, i)) end
  for i, n in ipairs({ "Kik", "Lead Vox", "Gtr" }) do
    r.InsertTrackAtIndex(i - 1, false)
    r.GetSetMediaTrackInfo_String(r.GetTrack(0, i - 1), "P_NAME", n, true)
  end
  r.Undo_EndBlock("test tracks 4", -1)
  S.presets[2].tfx = { Kick = tmp .. "\\Drum bus.RfxChain" } -- (written by a test before)
  r.Main_OnCommand(40297, 0)
  Prep.scan()
  Prep.apply(R.rows)
  local got = {}
  for i = 0, r.CountTracks(0) - 1 do
    local _, n = r.GetTrackName(r.GetTrack(0, i))
    got[#got + 1] = n
  end
  eq(table.concat(got, ","), "Vocals,Lead Vox,Drums,Kick,Guitars,Gtr,FX Returns,Room Verb,Hall Verb,Delay,Drum Crush")
  local kick, vox = r.GetTrack(0, 3), r.GetTrack(0, 1)
  eq(r.TrackFX_GetCount(kick), 1, "Track FX on the Kick")
  eq(math.floor(r.GetMediaTrackInfo_Value(kick, "I_CUSTOMCOLOR")) & 0x1000000, 0, "colors off: no custom color")
  eq(r.GetTrackNumSends(kick, 0), 2, "Kick -> Room Verb, Drum Crush")
  eq(r.GetTrackNumSends(vox, 0), 2, "Lead Vox -> Hall Verb, Delay")
  ok(math.abs(r.GetTrackSendInfo_Value(kick, 0, 0, "D_VOL") - 10 ^ (-12 / 20)) < 1e-6, "send at -12 dB")
  -- a 2nd Scan: every track is prepped (left out)
  local rows1 = R.rows
  Prep.scan(true)
  eq(#R.rows, 0, "all prepped")
  eq(R.scan.skipped, 11, "11 prepped tracks")
  -- the same rows again: no new returns, no 2nd send
  Prep.apply(rows1)
  eq(r.GetTrackNumSends(r.GetTrack(0, 3), 0), 2, "no 2nd send")
  local n = 0
  for i = 0, r.CountTracks(0) - 1 do
    local _, nm = r.GetTrackName(r.GetTrack(0, i))
    if nm == "Room Verb" then n = n + 1 end
  end
  eq(n, 1, "one Room Verb")
  r.Main_OnCommand(40029, 0); r.Main_OnCommand(40029, 0)
  for i = 0, r.CountTracks(0) - 1 do
    local _, mark = r.GetSetMediaTrackInfo_String(r.GetTrack(0, i), "P_EXT:SessionPrep", "", false)
    eq(mark, "", "Ctrl+Z removes the prep marks")
  end
  S.preset, S.returns = 1, false
  S.presets[2].tfx = {}
  R.comp, R.folder_list = nil, nil
end)

test("buses: Inst, Vocal, Lead bus tracks with sends, output off", function()
  defaults()
  for _, b in ipairs(S.presets[1].buses) do b.on = true end
  r.Undo_BeginBlock()
  for i = r.CountTracks(0) - 1, 0, -1 do r.DeleteTrack(r.GetTrack(0, i)) end
  for i, n in ipairs({ "Lead Vox", "Kik", "Gtr", "Lead Gtr", "Click" }) do
    r.InsertTrackAtIndex(i - 1, false)
    r.GetSetMediaTrackInfo_String(r.GetTrack(0, i - 1), "P_NAME", n, true)
  end
  r.Undo_EndBlock("test tracks 5", -1)
  Prep.scan(true)
  Prep.apply(R.rows)
  local got = {}
  for i = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, i)
    local _, n = r.GetTrackName(tr)
    got[#got + 1] = n .. ":" .. math.floor(r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH"))
      .. (r.GetMediaTrackInfo_Value(tr, "I_SPACER") == 1 and "s" or "")
  end
  eq(table.concat(got, ","),
    "Drums:1,Kick:-1,Guitars:1s,Lead Gtr:0,Gtr:-1,Vocals:1s,Lead Vox:-1,Other:1s,Click:-1,Instrument Bus:0s,Vocal Bus:0,Lead Bus:0")
  local function track(name)
    for i = 0, r.CountTracks(0) - 1 do
      local tr = r.GetTrack(0, i)
      local _, n = r.GetTrackName(tr)
      if n == name then return tr end
    end
  end
  eq(r.GetTrackNumSends(track("Instrument Bus"), -1), 2, "Drums + Guitars -> Instrument Bus")
  eq(r.GetTrackNumSends(track("Vocal Bus"), -1), 1, "Lead Vox -> Vocal Bus")
  eq(r.GetTrackNumSends(track("Lead Bus"), -1), 1, "Lead Gtr -> Lead Bus")
  eq(r.GetMediaTrackInfo_Value(track("Drums"), "B_MAINSEND"), 0, "Drums only through the Instrument Bus")
  eq(r.GetMediaTrackInfo_Value(track("Lead Vox"), "B_MAINSEND"), 0, "Lead Vox only through the Vocal Bus")
  eq(r.GetMediaTrackInfo_Value(track("Lead Gtr"), "B_MAINSEND"), 0, "Lead Gtr only through the Lead Bus")
  eq(r.GetMediaTrackInfo_Value(track("Vocals"), "B_MAINSEND"), 1, "Vocals folder: not in a bus")
  eq(r.GetMediaTrackInfo_Value(track("Gtr"), "B_MAINSEND"), 1, "Gtr stays in its folder")
  eq(r.GetMediaTrackInfo_Value(track("Click"), "B_MAINSEND"), 1, "Click stays apart")
  r.Main_OnCommand(40029, 0)
end)

test("presets keep the buses and the return colors; Lead Gtr / Lead Synth names", function()
  defaults()
  local q = Rules.parse(Rules.serialize(S.presets[1]))
  eq(#q.buses, 3)
  eq(q.buses[1].name, "Instrument Bus"); eq(q.buses[1].on, false); eq(q.buses[1].members[1].name, "Drums")
  eq(q.buses[2].members[1].kind, "t"); eq(q.buses[2].members[1].name, "Lead Vox")
  eq(q.returns[1].color, 0x5E9C96)
  local rows = plan({ "gtr solo", "lead synth", "Synth Pad" })
  eq(rows[1].new, "Lead Gtr"); eq(rows[2].new, "Lead Synth"); eq(rows[3].new, "Synth")
end)

test("capital letters: All, Folders and buses, Buses only, None", function()
  defaults()
  S.caps = "all"
  eq(Prep.caps("Kick In", "track"), "KICK IN"); eq(Prep.caps("Drums", "folder"), "DRUMS")
  S.caps = "fb"
  eq(Prep.caps("Kick In", "track"), "Kick In"); eq(Prep.caps("Drums", "folder"), "DRUMS"); eq(Prep.caps("Instrument Bus", "bus"), "INSTRUMENT BUS")
  S.caps = "buses"
  eq(Prep.caps("Drums", "folder"), "Drums"); eq(Prep.caps("Instrument Bus", "bus"), "INSTRUMENT BUS")
  S.caps = "none"
  eq(Prep.caps("Instrument Bus", "bus"), "Instrument Bus")
  S.caps = "all"
  local rows = plan({ "kik in", "" })
  S.caps = "all"
  rows = Prep.plan({ tracks = { { name = "kik in" }, { name = "", label = "Track 2" } }, scope = "all", folders_ok = true })
  eq(rows[1].new, "KICK IN"); eq(rows[2].new, "Track 2", "an unnamed track stays as it is")
  S.caps = "none"
end)

test("more match words: gtr lead, gtr rtm, guide vox, bass gtr", function()
  local rows = plan({ "GTR Lead", "gtr rtm", "Gtr Rhythm L", "Guide Vox", "Bass Gtr", "Kick Drum", "Ohs", "Tambo" })
  eq(rows[1].new, "Lead Gtr"); eq(rows[2].new, "Gtr"); eq(rows[3].new, "Gtr L")
  eq(rows[4].new, "Guide", "guide vox is the guide, not the lead vocal"); eq(rows[5].new, "Bass")
  eq(rows[6].new, "Kick"); eq(rows[7].new, "OH"); eq(rows[8].new, "Perc")
end)

test("a renamed folder or rule name takes its settings along", function()
  defaults()
  local p = S.presets[1]
  p.fx.Guitars, p.tfx.Kick = "C:\\g.RfxChain", "C:\\k.RfxChain"
  for _, ru in ipairs(p.rules) do if ru.folder == "Guitars" then ru.folder = "Gtrs" end end
  Rules.rename(p, "folder", "Guitars", "Gtrs")
  eq(p.fx.Gtrs, "C:\\g.RfxChain"); eq(p.fx.Guitars, nil)
  ok(p.sends.Gtrs and p.sends.Gtrs["Hall Verb"], "the sends")
  local order = table.concat(p.order, ",")
  ok(order:find("Gtrs", 1, true) and not order:find("Guitars", 1, true), "the order")
  ok(UI_has_member(p, "f", "Gtrs"), "the bus member")
  -- a folder that another rule still uses keeps its settings
  p.fx.Drums = "C:\\d.RfxChain"
  p.rules[2].folder = "Kicks" -- (only 1 of the drum rules)
  Rules.rename(p, "folder", "Drums", "Kicks")
  eq(p.fx.Drums, "C:\\d.RfxChain", "Drums is still used")
  -- a rule name
  for _, ru in ipairs(p.rules) do if ru.name == "Kick" then ru.name = "Kick In" end end
  Rules.rename(p, "name", "Kick", "Kick In")
  eq(p.tfx["Kick In"], "C:\\k.RfxChain"); eq(p.tfx.Kick, nil)
  for _, ru in ipairs(p.rules) do if ru.name == "Lead Gtr" then ru.name = "Solo Gtr" end end
  Rules.rename(p, "name", "Lead Gtr", "Solo Gtr")
  ok(UI_has_member(p, "t", "Solo Gtr"), "the bus member of a rule name")
end)

test("a client track named like a return is scanned and never used as the return", function()
  defaults()
  S.returns = true
  r.Undo_BeginBlock()
  for i = r.CountTracks(0) - 1, 0, -1 do r.DeleteTrack(r.GetTrack(0, i)) end
  for i, n in ipairs({ "Kik", "Delay" }) do
    r.InsertTrackAtIndex(i - 1, false)
    r.GetSetMediaTrackInfo_String(r.GetTrack(0, i - 1), "P_NAME", n, true)
  end
  r.Undo_EndBlock("test tracks 6", -1)
  local client = r.GetTrack(0, 1)
  Prep.scan(true)
  eq(#R.rows, 2, "the client's Delay is in the table")
  Prep.apply(R.rows)
  eq(r.GetTrackNumSends(client, -1), 0, "the client's Delay gets no sends")
  local n = 0
  for i = 0, r.CountTracks(0) - 1 do
    local _, nm = r.GetTrackName(r.GetTrack(0, i))
    if nm == "Delay" then n = n + 1 end
  end
  eq(n, 2, "a new Delay return next to the client's track")
  r.Main_OnCommand(40029, 0)
  S.returns = false
end)

test("a new name that another track has gets a number", function()
  defaults()
  local scan = { tracks = { { name = "gtr" }, { name = "kik" } }, scope = "selected", folders_ok = true,
    others = { ["GTR"] = true, ["GTR 1"] = true } }
  local rows = Prep.plan(scan)
  eq(rows[1].new, "Gtr 2", "Gtr and Gtr 1 are taken"); eq(rows[2].new, "Kick")
end)

test("a bus or return rename: an empty or taken name goes back", function()
  local a, b = { name = "Delay" }, { name = "Verb" }
  local list = { a, b }
  eq(Rules.name_ok(list, a, ""), false, "empty")
  eq(Rules.name_ok(list, a, "Verb"), false, "the other return's name")
  eq(Rules.name_ok(list, a, "VERB"), false, "the other name in another case")
  eq(Rules.name_ok(list, a, "Delay"), true, "its own name")
  eq(Rules.name_ok(list, a, "Slap"), true, "a free name")
  eq(Rules.name_ok({ a }, a, "Verb"), true, "1 item: any name but empty")
end)

test("Undo per section: steps, quick changes as 1 step, other sections apart", function()
  defaults()
  R.snap, R.hist, R.hist_t = Rules.snapshot(), {}, {}
  local p = S.presets[1]
  local n0 = #p.rules
  table.remove(p.rules, 1); Rules.changed()                      -- rules: step 1 (delete a rule)
  R.hist_t = {}
  p.rules[1].color = 0x112233; Rules.changed()                   -- rules: step 2 (a color...)
  p.rules[1].color = 0x445566; Rules.changed()                   -- ...dragged on (merged into step 2)
  p.buses[1].on = true; Rules.changed()                          -- buses: step 1
  eq(Rules.undo_count("rules"), 2, "2 rule steps"); eq(Rules.undo_count("buses"), 1, "1 bus step")
  eq(Rules.undo_count("returns"), 0)
  Rules.undo("rules")
  ok(p.rules[1].color ~= 0x445566, "the color is back")
  eq(p.buses[1].on, true, "the bus change stays (another section)")
  Rules.undo("rules")
  eq(#p.rules, n0, "the deleted rule is back")
  Rules.undo("buses")
  eq(p.buses[1].on, false, "the bus change undone")
  S.caps = "all"; Rules.changed() -- (a setting is no step)
  eq(Rules.undo_count("rules") + Rules.undo_count("buses"), 0, "a setting is no step")
  S.caps = "none"
end)

test("Reset to original: built-in and own presets; the originals are saved", function()
  defaults()
  local p = S.presets[1]
  local text0 = Rules.serialize(p)
  table.remove(p.rules, 1); p.buses[1].on = true; p.name = "My Default"
  ok(Rules.reset(p), "reset")
  eq(p.name, "My Default", "the name stays")
  p.name = "Default"
  eq(Rules.serialize(p), text0, "the built-in settings again")
  -- an own preset (Save as): its original is the text at that moment
  local c = Rules.copy(p); c.name = "Rock"; c.orig = Rules.serialize(c); c.rules[1].name = "BD"
  S.presets[3] = c
  C.Util.save_settings()
  C.Util.load_settings()
  local q = S.presets[3]
  eq(q.rules[1].name, "BD"); ok(q.orig, "the original is saved")
  ok(Rules.reset(q)); ok(q.rules[1].name ~= "BD", "back to its original")
  defaults()
  C.Util.save_settings()
  eq(r.GetExtState("Session Prep", "preset_orig_3"), "", "no orig key left")
end)

test("Save: changes wait for Save; revert; the saved version is kept over a restart", function()
  defaults()
  local p = S.presets[1]
  eq(p.dirty, false, "a built-in preset starts saved")
  table.remove(p.rules, 1); Rules.changed()
  eq(p.dirty, true, "unsaved after an edit"); ok(p.label:find("\u{2022}", 1, true), "the dot after the name")
  local edited = Rules.serialize(p)
  C.Util.save_settings()
  C.Util.load_settings()
  p = S.presets[1]
  eq(Rules.serialize(p), edited, "the edit is kept"); eq(p.dirty, true, "still unsaved after a restart")
  ok(Rules.revert(p), "revert")
  eq(p.dirty, false, "back to the saved version")
  table.remove(p.rules, 1); Rules.changed()
  Rules.save(p)
  eq(p.dirty, false, "saved"); eq(p.label, p.name)
  p.name = "Renamed"; Rules.update_dirty(p)
  eq(p.dirty, false, "a rename is no unsaved change")
  defaults()
  C.Util.save_settings()
  eq(r.GetExtState("Session Prep", "preset_saved_1"), "", "no saved key left")
end)

test("polarity per rule; the natural order in a folder; Other off the master; file notes", function()
  defaults()
  local rows = plan({ "snr top", "snr btm", "kik" })
  ok(not rows[1].pol, "Snare Top keeps its polarity"); ok(rows[2].pol, "Snare Btm flips")
  -- real tracks: Kick Sub, Kick Out, Kick In (in that order) + a click; a file that starts later
  r.Undo_BeginBlock()
  for i = r.CountTracks(0) - 1, 0, -1 do r.DeleteTrack(r.GetTrack(0, i)) end
  for i, n in ipairs({ "sub kick", "kick out", "kick in", "snr btm", "click" }) do
    r.InsertTrackAtIndex(i - 1, false)
    local tr = r.GetTrack(0, i - 1)
    r.GetSetMediaTrackInfo_String(tr, "P_NAME", n, true)
    local it = r.AddMediaItemToTrack(tr)
    r.SetMediaItemInfo_Value(it, "D_POSITION", n == "kick in" and 12 or 0)
    r.SetMediaItemInfo_Value(it, "D_LENGTH", 1)
  end
  r.Undo_EndBlock("test tracks 7", -1)
  Prep.scan(true)
  eq(R.rows[3].fnote, "starts at 0:12", "the file note of a later start")
  Prep.apply(R.rows)
  local got = {}
  for i = 0, r.CountTracks(0) - 1 do
    local _, n = r.GetTrackName(r.GetTrack(0, i))
    got[#got + 1] = n
  end
  eq(table.concat(got, ","), "Drums,Kick In,Kick Out,Kick Sub,Snare Btm,Other,Click", "In, Out, then Sub")
  eq(r.GetMediaTrackInfo_Value(r.GetTrack(0, 4), "B_PHASE"), 1, "Snare Btm flipped")
  eq(r.GetMediaTrackInfo_Value(r.GetTrack(0, 5), "B_MAINSEND"), 0, "the Other folder: no master output")
  -- an overdub after the prep joins its folder
  r.Undo_BeginBlock()
  r.InsertTrackAtIndex(r.CountTracks(0), false)
  local od = r.GetTrack(0, r.CountTracks(0) - 1)
  r.GetSetMediaTrackInfo_String(od, "P_NAME", "tom 1", true)
  r.Undo_EndBlock("test overdub", -1)
  Prep.scan(true)
  eq(#R.rows, 1, "only the overdub")
  Prep.apply(R.rows)
  local parent = r.GetParentTrack(od)
  ok(parent, "the overdub is in a folder")
  local _, pn = r.GetTrackName(parent)
  eq(pn, "Drums", "it joined the Drums folder")
  eq(r.GetMediaTrackInfo_Value(od, "I_SPACER"), 0, "the overdub has no spacer")
  local oth
  for i = 0, r.CountTracks(0) - 1 do
    local _, nm = r.GetTrackName(r.GetTrack(0, i))
    if nm == "Other" then oth = r.GetTrack(0, i) end
  end
  eq(r.GetMediaTrackInfo_Value(oth, "I_SPACER"), 1, "the next folder keeps its spacer")
  r.Main_OnCommand(40029, 0); r.Main_OnCommand(40029, 0)
end)

test("returns: per-return level, source folder, output into a folder; no loop", function()
  defaults()
  S.returns = true
  local p = S.presets[1]
  r.Undo_BeginBlock()
  for i = r.CountTracks(0) - 1, 0, -1 do r.DeleteTrack(r.GetTrack(0, i)) end
  for i, n in ipairs({ "kik", "snr" }) do
    r.InsertTrackAtIndex(i - 1, false)
    r.GetSetMediaTrackInfo_String(r.GetTrack(0, i - 1), "P_NAME", n, true)
  end
  r.Undo_EndBlock("test tracks 8", -1)
  Prep.scan(true)
  Prep.apply(R.rows)
  local function track(name)
    for i = 0, r.CountTracks(0) - 1 do
      local tr = r.GetTrack(0, i)
      local _, n = r.GetTrackName(tr)
      if n == name then return tr end
    end
  end
  local crush, kick, drums = track("Drum Crush"), track("Kick"), track("Drums")
  ok(crush and kick and drums, "tracks made")
  eq(r.GetMediaTrackInfo_Value(crush, "B_MAINSEND"), 0, "Drum Crush: no master output")
  eq(r.GetTrackNumSends(crush, 0), 1, "Drum Crush -> Drums")
  local found
  for i = 0, r.GetTrackNumSends(kick, 0) - 1 do
    if math.abs(r.GetTrackSendInfo_Value(kick, 0, i, "D_VOL") - 1) < 1e-6 then found = true end
  end
  ok(found, "the Kick sends to Drum Crush at 0 dB")
  r.Main_OnCommand(40029, 0)
  -- Source Folder + Out into that folder: the send is skipped (a loop)
  p.returns[4].src = "f"
  Prep.scan(true)
  local msg = Prep.apply(R.rows)
  ok(msg:find("would loop", 1, true), "the notice says the send was skipped")
  r.Main_OnCommand(40029, 0)
  S.returns = false
end)

test("one-sided level, kept pans, pan width, disarm, delete empty", function()
  defaults()
  -- the level of a one-sided file: only the live side (not 3 dB low)
  local both = Audio.rms(0.01, 0.01, 1, nil)
  ok(math.abs(Audio.rms(0.01, 0, 1, "only_l") - both) < 1e-9, "only_l: the left side alone")
  ok(math.abs(Audio.rms(0, 0.01, 1, "only_r") - both) < 1e-9, "only_r: the right side alone")
  -- a pan that is already set is kept
  local rows = Prep.plan({ tracks = { { name = "gtr 2 l", panned = true, pan = -0.3 }, { name = "oh l" } },
    scope = "all", folders_ok = true })
  eq(rows[1].pan, nil, "kept: the Pan button at -"); eq(rows[1].pnote, "kept pan 30L"); eq(rows[2].pan, "L")
  -- real tracks: pan width, disarm, delete empty
  S.audio, S.pan_w_on, S.disarm = true, true, true
  r.Undo_BeginBlock()
  for i = r.CountTracks(0) - 1, 0, -1 do r.DeleteTrack(r.GetTrack(0, i)) end
  for i, n in ipairs({ "oh l", "kik" }) do
    r.InsertTrackAtIndex(i - 1, false)
    local tr = r.GetTrack(0, i - 1)
    r.GetSetMediaTrackInfo_String(tr, "P_NAME", n, true)
    r.SetMediaTrackInfo_Value(tr, "I_RECARM", 1)
  end
  r.Undo_EndBlock("test tracks 9", -1)
  Prep.scan(true)
  eq(R.rows[2].fix, "delete", "an empty track: the Delete fix")
  R.rows[2].fix_on = true
  R.rows[1].width = 80 -- (the Width column of the row)
  local oh = R.rows[1].t.tr
  Prep.apply(R.rows)
  ok(math.abs(r.GetMediaTrackInfo_Value(oh, "D_PAN") + 0.8) < 1e-6, "OH L at 80L")
  eq(r.GetMediaTrackInfo_Value(oh, "I_RECARM"), 0, "disarmed")
  local names = {}
  for i = 0, r.CountTracks(0) - 1 do names[#names + 1] = select(2, r.GetTrackName(r.GetTrack(0, i))) end
  ok(not table.concat(names, ","):find("Kick", 1, true), "the empty Kick track is deleted")
  r.Main_OnCommand(40029, 0)
  S.audio, S.pan_w_on = false, false
end)

test("a new track (project default pan mode) is not 'kept'; the notes as short tags", function()
  defaults()
  r.Undo_BeginBlock()
  for i = r.CountTracks(0) - 1, 0, -1 do r.DeleteTrack(r.GetTrack(0, i)) end
  r.InsertTrackAtIndex(0, false)
  r.GetSetMediaTrackInfo_String(r.GetTrack(0, 0), "P_NAME", "oh l", true)
  r.InsertTrackAtIndex(1, false)
  local panned = r.GetTrack(0, 1)
  r.GetSetMediaTrackInfo_String(panned, "P_NAME", "gtr 2 l", true)
  r.SetMediaTrackInfo_Value(panned, "D_PAN", -0.3)
  r.Undo_EndBlock("test tracks 10", -1)
  Prep.scan(true)
  eq(R.rows[1].pan, "L", "a new track is not 'kept'")
  eq(R.rows[2].pnote, "kept pan 30L")
  eq(R.rows[2].tags[1].text, "kept 30L", "the short tag")
  local rows = Prep.plan({ tracks = { { name = "kik", audio = "empty" } }, scope = "all", folders_ok = true })
  eq(rows[1].tags[1].text, "empty"); eq(rows[1].fix, "delete")
end)

test("a return added later joins the FX Returns folder (no 2nd folder)", function()
  defaults()
  S.returns = true
  local p = S.presets[1]
  r.Undo_BeginBlock()
  for i = r.CountTracks(0) - 1, 0, -1 do r.DeleteTrack(r.GetTrack(0, i)) end
  r.InsertTrackAtIndex(0, false)
  r.GetSetMediaTrackInfo_String(r.GetTrack(0, 0), "P_NAME", "kik", true)
  r.Undo_EndBlock("test tracks 11", -1)
  Prep.scan(true)
  Prep.apply(R.rows)
  p.returns[#p.returns + 1] = { name = "Slap", chain = "", color = 0x5E9C96, src = "t", db = -12, out = "m" }
  r.Undo_BeginBlock()
  r.InsertTrackAtIndex(r.CountTracks(0), false)
  r.GetSetMediaTrackInfo_String(r.GetTrack(0, r.CountTracks(0) - 1), "P_NAME", "snr", true)
  r.Undo_EndBlock("test overdub 2", -1)
  Prep.scan(true)
  Prep.apply(R.rows)
  local folders, slap = 0, nil
  for i = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, i)
    local _, n = r.GetTrackName(tr)
    if n == "FX Returns" then folders = folders + 1 end
    if n == "Slap" then slap = tr end
  end
  eq(folders, 1, "1 FX Returns folder")
  ok(slap, "the new return")
  local _, pn = r.GetTrackName(r.GetParentTrack(slap))
  eq(pn, "FX Returns", "Slap is in the FX Returns folder")
  r.Main_OnCommand(40029, 0); r.Main_OnCommand(40029, 0); r.Main_OnCommand(40029, 0)
  S.returns = false
end)

test("a new plan keeps the edits of the Prep table", function()
  defaults()
  local scan = { tracks = { { name = "kik" }, { name = "oh l" } }, scope = "all", folders_ok = true }
  local old = Prep.plan(scan)
  old[1].on = false
  old[1].new, old[1].edited = "BD", true
  old[2].pan, old[2].pan_edited = "C", true
  S.caps = "all" -- (a setting changes: the new plan has other names)
  local rows = Prep.keep_edits(old, Prep.plan(scan))
  eq(rows[1].on, false, "the tick stays"); eq(rows[1].new, "BD", "the typed name stays")
  eq(rows[2].pan, "C", "the pan stays"); eq(rows[2].new, "OH L", "an untouched name follows the setting")
  S.caps = "none"
end)

test("Apply leaves existing folders alone", function()
  defaults()
  r.Main_OnCommand(40297, 0)
  local first = r.GetTrack(0, 0)
  ok(first, "a track from the test before")
  r.Undo_BeginBlock()
  r.SetMediaTrackInfo_Value(first, "I_FOLDERDEPTH", 1)
  r.Undo_EndBlock("test folder", -1)
  Prep.scan()
  ok(not R.scan.folders_ok, "folders found")
  local n = r.CountTracks(0)
  Prep.apply(R.rows)
  eq(r.CountTracks(0), n, "no new folder tracks")
  r.Main_OnCommand(40029, 0)
end)

-- a 16-bit stereo WAV of a sine (hz, peak amplitude), 2 s at 44.1 kHz; returns its path
local function sine_wav(name, hz, amp)
  local sr, n = 44100, 88200
  local path = tmp .. "\\" .. name
  local f = io.open(path, "wb")
  local data = {}
  for i = 0, n - 1 do
    local v = math.floor(amp * 32767 * math.sin(2 * math.pi * hz * i / sr) + 0.5)
    data[#data + 1] = string.pack("<i2<i2", v, v)
  end
  local body = table.concat(data)
  f:write("RIFF", string.pack("<I4", 36 + #body), "WAVEfmt ", string.pack("<I4I2I2I4I4I2I2", 16, 1, 2, sr, sr * 4, 4, 16),
    "data", string.pack("<I4", #body), body)
  f:close()
  return path
end
local function track_with(path)
  r.InsertTrackAtIndex(r.CountTracks(0), false)
  local tr = r.GetTrack(0, r.CountTracks(0) - 1)
  local it = r.AddMediaItemToTrack(tr)
  local tk = r.AddTakeToMediaItem(it)
  r.SetMediaItemTake_Source(tk, r.PCM_Source_CreateFromFile(path))
  r.SetMediaItemInfo_Value(it, "D_LENGTH", 2)
  return tr
end

test("gain staging: a bright track (8 kHz, a hi-hat) is measured at its real level", function()
  defaults()
  local tr = track_with(sine_wav("hat8k.wav", 8000, 0.1)) -- (a sine of peak 0.1: RMS -23 dBFS)
  local verdict, rms = Audio.check(tr)
  ok(verdict ~= "silent", "not silent (got " .. tostring(verdict) .. ")")
  ok(rms, "a level")
  local db = 20 * math.log(rms, 10)
  ok(math.abs(db - (-23)) < 1, string.format("RMS about -23 dBFS (got %.1f)", db))
  r.DeleteTrack(tr)
end)

test("an empty track with a receive or FX (a client's return) is not 'empty'", function()
  defaults()
  local src = track_with(sine_wav("low100.wav", 100, 0.1))
  r.InsertTrackAtIndex(r.CountTracks(0), false)
  local ret = r.GetTrack(0, r.CountTracks(0) - 1)
  r.CreateTrackSend(src, ret)
  eq(Audio.check(ret), nil, "a track with a receive")
  r.InsertTrackAtIndex(r.CountTracks(0), false)
  local fx = r.GetTrack(0, r.CountTracks(0) - 1)
  r.TrackFX_AddByName(fx, "ReaEQ", false, -1)
  eq(Audio.check(fx), nil, "a track with FX")
  r.InsertTrackAtIndex(r.CountTracks(0), false)
  local empty = r.GetTrack(0, r.CountTracks(0) - 1)
  eq(Audio.check(empty), "empty", "a really empty track")
  for _, t in ipairs({ src, ret, fx, empty }) do r.DeleteTrack(t) end
end)

test("Apply does nothing when the scanned tracks are gone (another project in the same tab)", function()
  defaults()
  S.returns = true
  for i = r.CountTracks(0) - 1, 0, -1 do r.DeleteTrack(r.GetTrack(0, i)) end
  for i, n in ipairs({ "Kik", "Vox" }) do
    r.InsertTrackAtIndex(i - 1, false)
    r.GetSetMediaTrackInfo_String(r.GetTrack(0, i - 1), "P_NAME", n, true)
  end
  Prep.scan(true)
  for i = r.CountTracks(0) - 1, 0, -1 do r.DeleteTrack(r.GetTrack(0, i)) end
  local msg = Prep.apply(R.rows)
  eq(r.CountTracks(0), 0, "no returns or folders made")
  ok(msg:find("Scan again", 1, true), "the notice says Scan again (got: " .. msg .. ")")
  S.returns = false
end)

test("a 2-word match wins: Electric Piano is Keys, Acoustic Piano is Piano (not Gtr / Ac Gtr)", function()
  local rows = plan({ "Electric Piano", "Acoustic Piano", "Acoustic Gtr", "Electric Gtr", "Guide Vox" })
  eq(rows[1].new, "Keys", "Electric Piano")
  eq(rows[2].new, "Piano", "Acoustic Piano")
  eq(rows[3].new, "Ac Gtr", "Acoustic Gtr")
  eq(rows[4].new, "Gtr", "Electric Gtr")
  eq(rows[5].new, "Guide", "Guide Vox")
  eq(plan({ "Ac Piano" })[1].new, "Piano", "Ac Piano")
end)

test("gain staging: the peak is exact (a short hit between 2 reads is found)", function()
  defaults()
  S.gain = true
  -- 20 s quiet (peak 0.01) with a 10 ms hit of 0.9 at 10.12 s: between the reads of the fast audio check
  local sr, n = 44100, 20 * 44100
  local path = tmp .. "\\hit.wav"
  local f = io.open(path, "wb")
  local data = {}
  local h0, h1 = math.floor(10.12 * sr), math.floor(10.13 * sr)
  for i = 0, n - 1 do
    local amp = (i >= h0 and i < h1) and 0.9 or 0.01
    local v = math.floor(amp * 32767 * math.sin(2 * math.pi * 440 * i / sr) + 0.5)
    data[#data + 1] = string.pack("<i2<i2", v, v)
  end
  local body = table.concat(data)
  f:write("RIFF", string.pack("<I4", 36 + #body), "WAVEfmt ", string.pack("<I4I2I2I4I4I2I2", 16, 1, 2, sr, sr * 4, 4, 16),
    "data", string.pack("<I4", #body), body)
  f:close()
  for i = r.CountTracks(0) - 1, 0, -1 do r.DeleteTrack(r.GetTrack(0, i)) end
  local tr = track_with(path)
  r.SetMediaItemInfo_Value(r.GetTrackMediaItem(tr, 0), "D_LENGTH", 20)
  Prep.scan(true)
  local pk = R.scan.tracks[1].peak or 0
  ok(math.abs(pk - 0.9) < 0.02, string.format("peak 0.9 (got %.3f)", pk))
  r.DeleteTrack(tr)
  S.gain = false
end)

for _, t in ipairs(tests) do
  local good, e = pcall(t[2])
  if good then passed = passed + 1; log("ok    " .. t[1])
  else failed = failed + 1; log("FAIL  " .. t[1] .. ": " .. tostring(e)) end
end
finish()
