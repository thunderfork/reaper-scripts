-- @noindex
-- SFX Drop tests. Run with .\tools\test.ps1 -Script "SFX Drop" (it starts the portable test REAPER in C:\REAPERtest).
-- Loads SFX Drop.lua without its window, runs each test, writes tests\result_sfxdrop.txt, quits REAPER.
local r = reaper
local here = ({ r.get_action_context() })[2]:match("^(.*)[/\\]")
local out = {}
local passed, failed = 0, 0
local function log(s) out[#out + 1] = s end
local function eq(a, b, what)
  if a ~= b then error((what or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end
local function near(a, b, tol, what)
  if type(a) ~= "number" or math.abs(a - b) > tol then
    error((what or "value") .. ": expected " .. tostring(b) .. " +- " .. tol .. ", got " .. tostring(a), 2)
  end
end
local function ok(v, what) if not v then error((what or "check") .. " failed", 2) end end
local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end

local tmp = r.GetResourcePath() .. "/SFXDropTests"
r.RecursiveCreateDirectory(tmp, 0)
local proj_file = tmp .. "/test.rpp"
local pf = io.open(proj_file, "w")
if pf then pf:write("<REAPER_PROJECT 0.1\n>\n"); pf:close() end
r.Main_openProject("noprompt:" .. proj_file)

local function finish()
  log(string.format("%d passed, %d failed", passed, failed))
  local f = io.open(here .. "\\result_sfxdrop.txt", "w")
  if f then f:write(table.concat(out, "\n"), "\n"); f:close() end
  r.Main_SaveProject(0, false)
  r.defer(function() r.Main_OnCommand(40004, 0) end) -- File: Quit REAPER
end

SFXDropTest = {}
local loaded, err = pcall(dofile, here .. "\\..\\SFX Drop\\SFX Drop.lua")
local C = SFXDropTest
if not loaded or not C.Lib then
  log("FAIL  load SFX Drop.lua: " .. tostring(err)); failed = 1; finish(); return
end
local Lib, Drop, S, R, CFG = C.Lib, C.Drop, C.S, C.R, C.CFG
log(string.format("REAPER %s in %s, SFX Drop %s loaded", r.GetAppVersion(), r.GetResourcePath(), CFG.VERSION))

-- A mono 16-bit WAV: `pre` s of silence, then a 1 kHz tone that gets louder for `rise` s (0: at once), stays for
-- `hold` s, then silence for `post` s.
local function write_wav(path, pre, rise, hold, post)
  local sr = 44100
  local n_pre, n_rise, n_hold, n_post = math.floor(pre * sr), math.floor(rise * sr), math.floor(hold * sr), math.floor(post * sr)
  local n = n_pre + n_rise + n_hold + n_post
  local s = {}
  for i = 0, n - 1 do
    local a = 0
    if i >= n_pre and i < n_pre + n_rise then a = 0.8 * (i - n_pre) / n_rise
    elseif i >= n_pre + n_rise and i < n_pre + n_rise + n_hold then a = 0.8 end
    s[#s + 1] = string.pack("<i2", math.floor(a * 32767 * math.sin(2 * math.pi * 1000 * i / sr)))
  end
  local data = table.concat(s)
  local f = assert(io.open(path, "wb"))
  f:write("RIFF", string.pack("<I4", 36 + #data), "WAVE", "fmt ", string.pack("<I4I2I2I4I4I2I2", 16, 1, 1, sr, sr * 2, 2, 16),
    "data", string.pack("<I4", #data), data)
  f:close()
end

local lib = (tmp .. "/Library"):gsub("\\", "/") -- (the library paths always use "/")
r.RecursiveCreateDirectory(lib .. "/Impacts", 0)
r.RecursiveCreateDirectory(lib .. "/Risers", 0)
write_wav(lib .. "/Impacts/Big Hit 01.wav", 0.1, 0, 0.3, 0.2)
write_wav(lib .. "/Risers/Up 4 bars.wav", 0.0, 1.5, 0.1, 0.3)

local function defaults()
  S.library, S.place, S.trim, S.fades, S.fade_ms, S.color, S.select_item = lib, "cursor", true, true, 5, true, true
end

test("type from folder and file names", function()
  eq(Lib.type_of("Risers/Long/Up 01.wav"), "Risers", "folder word, plural")
  eq(Lib.type_of("Cinematic/Big Hit 3.wav"), "Impacts", "file name word")
  eq(Lib.type_of("Sub Drops/Deep.wav"), "Drops", "sub drop")
  eq(Lib.type_of("Risers/Hit at end.wav"), "Risers", "the folder wins over the file name")
  eq(Lib.type_of("Pads/Warm Pad.wav"), "Atmos", "pad")
  eq(Lib.type_of("Subtle/thing.wav"), "Other", "a short word matches only a whole word")
  eq(Lib.type_of("Vocals/Shout.wav"), "Other", "no word")
end)

test("measure: start, loudest point, tail", function()
  local env = {}
  for i = 1, 1000 do env[i] = 0 end
  for i = 201, 600 do env[i] = 0.5 end   -- the sound from 0.2 s
  for i = 451, 470 do env[i] = 0.9 end   -- the loudest 20 ms at 0.45 s
  local st, pk, tl, silent = Lib.measure(env, 1000, 1.0)
  ok(not silent, "not silent")
  near(st, 0.2, 0.0011, "start"); near(pk, 0.46, 0.011, "peak"); near(tl, 0.6, 0.0011, "tail")
  local z = {}
  for i = 1, 100 do z[i] = 0 end
  local _, _, _, s2 = Lib.measure(z, 1000, 0.1)
  ok(s2, "silent file")
end)

test("layout: the hit point lands on the target", function()
  local e = { type = "Impacts", len = 1.0, start = 0.1, peak = 0.12, tail = 0.5 }
  local pos, len, offs = Drop.layout(e, 4.0, true)
  near(pos + (0.1 - offs), 4.0, 1e-9, "hit on target")
  near(offs, 0.1 - CFG.PRE_ROLL, 1e-9, "trimmed start"); near(len, 0.55 - offs, 1e-9, "trimmed end")
  pos, len, offs = Drop.layout(e, 4.0, false)
  near(pos, 3.9, 1e-9, "untrimmed position"); eq(offs, 0, "no offset"); eq(len, 1.0, "the whole file")
  local riser = { type = "Risers", len = 2.0, start = 0.0, peak = 1.6, tail = 1.7 }
  pos = Drop.layout(riser, 4.0, true)
  near(pos, 2.4, 1e-9, "a riser peaks on the target")
  riser.own = 1.5
  pos = Drop.layout(riser, 4.0, true)
  near(pos, 2.5, 1e-9, "the own hit point wins")
  pos, _, offs = Drop.layout(riser, 1.0, true)
  eq(pos, 0, "not before the project start"); near(offs, 0.5, 1e-9, "the start is cut")
end)

test("scan reads the library and finds the hit points", function()
  defaults()
  R.lib = {}
  Lib.scan(false)
  eq(#R.lib, 2, "2 sounds")
  local hit = Lib.find(lib .. "/Impacts/Big Hit 01.wav")
  ok(hit, "the impact is found")
  eq(hit.type, "Impacts", "type"); near(hit.start, 0.1, 0.003, "start of the impact")
  local up = Lib.find(lib .. "/Risers/Up 4 bars.wav")
  eq(up.type, "Risers", "type"); near(up.peak, 1.55, 0.06, "the loudest point of the riser")
  near(up.tail, 1.6, 0.01, "the tail of the riser")
end)

test("the index keeps own hit points", function()
  defaults()
  local e = Lib.find(lib .. "/Impacts/Big Hit 01.wav")
  e.own = 0.123
  ok(Lib.save_index(), "saved")
  Lib.load_index()
  near(Lib.find(lib .. "/Impacts/Big Hit 01.wav").own, 0.123, 1e-6, "own after load")
  Lib.scan(true)
  near(Lib.find(lib .. "/Impacts/Big Hit 01.wav").own, 0.123, 1e-6, "own after Read all again")
  Lib.find(lib .. "/Impacts/Big Hit 01.wav").own = nil
  Lib.save_index()
end)

test("search and type filter", function()
  R.search, R.filter, R.view = "", 0, nil
  eq(#Lib.view(), 2, "all")
  R.search, R.view = "4 bars", nil
  eq(#Lib.view(), 1, "all words must match")
  R.search, R.filter, R.view = "", 1, nil
  eq(#Lib.view(), 1, "Impacts only")
  R.search, R.filter, R.view = "", 0, nil
end)

test("insert: FX folder, type track, item on the beat", function()
  defaults()
  r.SetEditCurPos(2.0, false, false)
  local e = Lib.find(lib .. "/Impacts/Big Hit 01.wav")
  local n = Drop.insert(e)
  eq(n, 1, "1 item")
  local ft = r.GetTrack(0, 0)
  eq(select(2, r.GetTrackName(ft)), "FX", "the folder")
  eq(r.GetMediaTrackInfo_Value(ft, "I_FOLDERDEPTH"), 1, "folder depth")
  local tt = r.GetTrack(0, 1)
  eq(select(2, r.GetTrackName(tt)), "Impacts", "the type track")
  eq(r.GetMediaTrackInfo_Value(tt, "I_FOLDERDEPTH"), -1, "closes the folder")
  local item = r.GetTrackMediaItem(tt, 0)
  local take = r.GetActiveTake(item)
  local pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local offs = r.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
  near(pos - offs + e.start, 2.0, 1e-6, "the start of the sound on the edit cursor")
  near(r.GetMediaItemInfo_Value(item, "D_FADEINLEN"), CFG.PRE_ROLL, 1e-6, "the fade-in ends where the sound starts")
  near(r.GetMediaItemInfo_Value(item, "D_FADEOUTLEN"), 0.005, 1e-6, "the fade-out")
  -- a 2nd type: a new child after Impacts, which no longer closes the folder
  r.SetEditCurPos(6.0, false, false)
  Drop.insert(Lib.find(lib .. "/Risers/Up 4 bars.wav"))
  eq(r.CountTracks(0), 3, "3 tracks")
  eq(r.GetMediaTrackInfo_Value(r.GetTrack(0, 1), "I_FOLDERDEPTH"), 0, "Impacts is a middle child")
  eq(select(2, r.GetTrackName(r.GetTrack(0, 2))), "Risers", "Risers")
  eq(r.GetMediaTrackInfo_Value(r.GetTrack(0, 2), "I_FOLDERDEPTH"), -1, "Risers closes the folder")
  -- the same type again: the same track
  Drop.insert(e)
  eq(r.CountTracks(0), 3, "no new track")
  eq(r.CountTrackMediaItems(tt), 2, "2 impacts")
end)

test("learn from the moved item", function()
  defaults()
  local e = Lib.find(lib .. "/Impacts/Big Hit 01.wav")
  r.SetEditCurPos(10.0, false, false)
  Drop.insert(e)
  local item = R.last.item
  r.SetMediaItemInfo_Value(item, "D_POSITION", r.GetMediaItemInfo_Value(item, "D_POSITION") + 0.02) -- 20 ms later
  local got = Drop.learn()
  ok(got, "learned")
  near(e.own, e.start - 0.02, 0.0002, "the hit point moved 20 ms earlier in the file")
  e.own = nil
  Lib.save_index()
end)

test("place at the nearest bar line and at region starts", function()
  defaults()
  r.SetCurrentBPM(0, 120, false)
  S.place = "bar"
  r.SetEditCurPos(0.5, false, false)
  near(Drop.targets()[1], 0.0, 1e-6, "closer to bar 1 (120 BPM 4/4: a bar is 2 s)")
  r.SetEditCurPos(1.5, false, false)
  near(Drop.targets()[1], 2.0, 1e-6, "closer to bar 2")
  r.SetEditCurPos(2.0, false, false)
  near(Drop.targets()[1], 2.0, 1e-6, "on a bar line: that bar line")
  S.place = "regions"
  local t, why = Drop.targets()
  ok(not t and why, "no regions")
  r.AddProjectMarker(0, true, 8, 16, "Chorus", -1)
  r.AddProjectMarker(0, true, 16, 24, "Verse", -1)
  t = Drop.targets()
  eq(#t, 2, "2 region starts"); eq(t[1], 8, "first")
  r.GetSet_LoopTimeRange(true, false, 15, 20, false)
  t = Drop.targets()
  eq(#t, 1, "only in the time selection"); eq(t[1], 16, "the 2nd region")
  r.GetSet_LoopTimeRange(true, false, 0, 0, false)
  S.place = "cursor"
end)

local Spots = C.Spots

test("riser length: the risers that fit come first", function()
  local r8 = { type = "Risers", len = 8.4, start = 2.5, peak = 3.0, tail = 8.4 }  -- 4.2 bars at 120 BPM
  local r24 = { type = "Risers", len = 24, start = 0.0, peak = 8.0, tail = 24 }   -- 12 bars, its peak at 4 bars
  ok(Lib.riser_fit(r8, 4, 2.0), "4.2 bars fits 4")
  ok(not Lib.riser_fit(r24, 4, 2.0), "12 bars does not fit 4")
  ok(Lib.riser_fit({ type = "Risers", len = 2.1, start = 0, peak = 2, tail = 2.1 }, 1, 2.0), "1.05 bars fits 1")
  ok(not Lib.riser_fit({ type = "Impacts", len = 8, start = 0, peak = 8, tail = 8 }, 4, 2.0), "risers only")
  defaults()
  r.SetCurrentBPM(0, 120, false)
  r.SetEditCurPos(0, false, false)
  near(Lib.bar_sec(), 2.0, 1e-6, "a bar at 120 BPM 4/4")
  S.riser_bars = 1 -- the test riser: 1.9 s = 1.2 bars at 150 BPM (1.6 s bars): no fit; at 120 BPM (2 s): fits
  r.SetCurrentBPM(0, 120, false)
  R.search, R.filter, R.view = "", 0, nil
  local v = Lib.view()
  eq(R.lib[v[1]].type, "Risers", "the fitting riser first")
  r.SetCurrentBPM(0, 120, false)
  S.riser_bars = 0
  R.view = nil
end)

test("copy into the project and clean up", function()
  defaults()
  S.copy = true
  local dir = Drop.copy_dir()
  ok(dir, "the project is saved: a copy folder")
  local e = Lib.find(lib .. "/Impacts/Big Hit 01.wav")
  local need = Drop.copy_need({ { e = e } })
  ok(need > 0, "a new copy is needed")
  r.SetEditCurPos(30.0, false, false)
  Drop.insert(e)
  local item = R.last.item
  local src = r.GetMediaItemTake_Source(r.GetActiveTake(item))
  local fn = C.Util.norm(r.GetMediaSourceFileName(src))
  eq(fn:lower(), (dir .. "/Big Hit 01.wav"):lower(), "the item uses the copy")
  eq(Drop.copy_need({ { e = e } }), 0, "the copy is used again")
  local list = Drop.cleanup_list()
  eq(#list, 0, "the copy is in use")
  near(r.GetMediaItemInfo_Value(item, "D_FADEINLEN"), CFG.PRE_ROLL, 0.0002, "the fade-in ends where the hit starts")
  r.DeleteTrackMediaItem(r.GetMediaItem_Track(item), item)
  -- another version of the song in the same folder still names the copy: it stays
  local other = dir:match("^(.*)/[^/]*$") .. "/Song v1.rpp"
  C.Util.write_all(other, "<REAPER_PROJECT\n  FILE \"SFX Drop/Big Hit 01.wav\"\n>\n")
  list = Drop.cleanup_list()
  eq(#list, 0, "kept: Song v1.rpp uses it")
  os.remove(other)
  list = Drop.cleanup_list()
  eq(#list, 1, "unused after the item is gone")
  os.remove(list[1])
  S.copy = false
  R.last = nil
end)

test("stop a scan: the sounds read so far stay", function()
  defaults()
  local before = #R.lib
  Lib.scan_begin(true)
  local files = {}
  for _, e in ipairs(R.lib) do files[#files + 1] = e.path end
  R.scan.phase, R.scan.files, R.scan.lib, R.scan.i = "read", files, {}, 0 -- (stopped before the 1st file)
  Lib.scan_stop()
  eq(R.scan, nil, "stopped")
  eq(#R.lib, before, "the known sounds stay")
end)

test("spots per region", function()
  R.spot_bars = { bars = {}, regions = { { t = 0, t_end = 8, name = "Intro" }, { t = 8, t_end = 16, name = "" } } }
  S.spot_off = ""
  R.spots = { { t = 4, kind = "rise", delta = 9, on = true, parts = { { type = "Risers" } } },
    { t = 8, kind = "fall", delta = -7, on = true, parts = { { type = "Drops" } } },
    { t = 20, kind = "quiet", on = false, parts = { { type = "Atmos" } } } }
  R.spot_groups = nil
  local g = Spots.groups()
  eq(#g, 3, "2 regions and the rest")
  eq(g[1].name, "Intro", "first"); eq(g[2].name, "Region 2", "a region without a name")
  eq(g[3].name, "Outside the regions", "outside"); eq(g[1].count, "1 spot", "count")
  eq(Spots.short(R.spots[1]), "+9 dB", "short text")
  R.spot_bars.regions = {}
  R.spot_groups = nil
  eq(#Spots.groups(), 1, "no regions: 1 list"); eq(Spots.groups()[1].name, nil, "no heading")
  R.spots, R.spot_bars, R.spot_groups = nil, nil, nil
end)

test("spots: the types to add and the words of the sounds", function()
  defaults()
  S.spot_off, S.spot_words = "", ""
  ok(Spots.type_on("Drops"), "all on")
  Spots.set_type("Drops", false)
  eq(S.spot_off, "Drops", "Drops off"); ok(not Spots.type_on("Drops"), "off")
  ok(not Spots.visible({ parts = { { type = "Drops" } } }), "a drop spot hides")
  ok(Spots.visible({ parts = { { type = "Risers" }, { type = "Drops" } } }), "a spot with another type shows")
  Spots.set_type("Drops", true)
  eq(S.spot_off, "", "all on again")
  eq(Spots.pick("Impacts").name, "Big Hit 01", "any impact")
  S.spot_words = "boom, explosion"
  eq(Spots.pick("Impacts"), nil, "no impact with these words")
  S.spot_words = "explosion, big"
  eq(Spots.pick("Impacts").name, "Big Hit 01", "one word matches")
  S.spot_words = ""
end)

local Sc, P = C.Sc, C.P

test("soundcheck: the settings are saved as text", function()
  Sc.parse("")
  eq(Sc.serialize(), "", "defaults: no text")
  Sc.parse("src={ABC};len=90;steps=3;imp=0;rep=2")
  eq(P.src, "{ABC}", "source"); eq(P.len, 90, "length"); eq(P.steps, 3, "steps"); eq(P.imp, false, "impacts off"); eq(P.rep, 2, "repeats")
  eq(Sc.serialize(), "src={ABC};len=90;steps=3;imp=0;rep=2", "the same text")
  Sc.parse("len=77;steps=99")
  eq(P.len, 120, "a wrong length: the default"); eq(P.steps, 5, "a wrong step count: the default")
  Sc.parse("")
end)

test("soundcheck: areas from quiet to loud, the hits and the plan", function()
  -- 2 songs of 10 bars (2 s each); levels rise in song 1, a silent bar in song 2; a hit in bar 15
  local bars, songs = {}, { { t = 0, t_end = 20, name = "A" }, { t = 20, t_end = 40, name = "B" } }
  for i = 1, 20 do
    local pw = 10 ^ ((-40 + i * 2) / 10)
    if i == 13 then pw = 0 end
    bars[i] = { t = (i - 1) * 2, t_end = i * 2, num = i, pw = pw, pk = 0, pk_t = (i - 1) * 2 }
  end
  bars[15].pk, bars[15].pk_t = 0.9, 28.5
  local areas = Sc.pick_areas(bars, songs, 4, 3)
  eq(#areas, 3, "3 areas")
  ok(areas[1].db < areas[2].db and areas[2].db < areas[3].db, "from quiet to loud")
  for x = 1, 3 do
    for y = x + 1, 3 do ok(areas[x].z <= areas[y].a or areas[y].z <= areas[x].a, "no overlap") end
    ok(not (areas[x].a < 26 and areas[x].z > 24), "never the silent bar 13")
  end
  local hits = Sc.source_hits(bars, songs, 2)
  eq(#hits, 1, "1 hit"); near(hits[1].t, 28.5, 1e-9, "at its peak")
  -- the plan: 60 s, 3 steps, 1 fx sound of 2 s x4 + the hit (1.55 s) x4 = 4 x 3 + 4 x 2.55 = 22.2 s
  local plan = Sc.make_plan(bars, songs, 60, 3, true, 4, { { item = nil, len = 2, name = "Boom" } })
  eq(#plan.zone, 2, "the fx sound and the hit"); eq(plan.dropped, 0, "all fit")
  near(plan.L, (60 - 22.2 - 1) / 3, 1e-6, "the steps share the rest")
  local short = Sc.make_plan(bars, songs, 20, 3, true, 4, { { item = nil, len = 2, name = "Boom" } })
  eq(short.dropped, 1, "20 s: the hit does not fit (at most 60 %)")
  local off = Sc.make_plan(bars, songs, 60, 3, false, 4, { { item = nil, len = 2, name = "Boom" } })
  eq(#off.zone, 0, "Impacts zone off")
end)

test("soundcheck: build and build again", function()
  defaults()
  r.SetCurrentBPM(0, 120, false)
  -- a song: a region 0-16 s and a backing track with the riser at 8 s
  r.InsertTrackAtIndex(0, true)
  local tr = r.GetTrack(0, 0)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", "Backing", true)
  local item = r.AddMediaItemToTrack(tr)
  r.SetMediaItemTake_Source(r.AddTakeToMediaItem(item), r.PCM_Source_CreateFromFile(lib .. "/Risers/Up 4 bars.wav"))
  r.SetMediaItemInfo_Value(item, "D_POSITION", 8)
  r.SetMediaItemInfo_Value(item, "D_LENGTH", 1.9)
  local rg = r.AddProjectMarker(0, true, 0, 16, "Song A", -1)
  Sc.parse("")
  P.src, P.len, P.steps = r.GetTrackGUID(tr), 60, 3
  R.sc_state = nil
  Sc.refresh()
  local n_tracks = r.CountTracks(0)
  ok(Sc.find_build(), "built")
  local old = Sc.old_region()
  ok(old, "a Soundcheck region"); ok(old.t >= 16, "after the last song")
  eq(r.CountTracks(0), n_tracks + 1, "a new Soundcheck track")
  local sct = r.GetTrack(0, r.CountTracks(0) - 1)
  eq(select(2, r.GetTrackName(sct)), "Soundcheck", "its name")
  ok(r.CountTrackMediaItems(sct) >= 1, "the areas are on it")
  eq(r.CountTrackMediaItems(tr), 1, "the source track keeps only its own item")
  ok(Sc.find_build(), "built again")
  eq(r.CountTracks(0), n_tracks + 1, "a 2nd build replaces the track")
  r.Main_OnCommand(40029, 0)
  r.Main_OnCommand(40029, 0)
  eq(Sc.old_region(), nil, "Ctrl+Z removes it")
  r.DeleteProjectMarker(0, rg, true)
  local t0 = r.GetTrack(0, 0) -- (after Ctrl+Z REAPER makes the track again: a new pointer)
  if t0 and select(2, r.GetTrackName(t0)) == "Backing" then r.DeleteTrack(t0) end
  Sc.parse("")
end)

test("vary: a different sound of the folder at each place", function()
  defaults()
  local a = { path = "L/Imp/a.wav", type = "Impacts" }
  local b = { path = "L/Imp/b.wav", type = "Impacts" }
  local c = { path = "L/Imp/c.wav", type = "Impacts" }
  local other = { path = "L/Other/x.wav", type = "Impacts" }
  local keep = R.lib
  R.lib = { a, b, c, other }
  local v = Lib.variants(b, 4)
  eq(v[1], b, "the selected sound first"); eq(v[2], c, "then the next"); eq(v[3], a, "round"); eq(v[4], b, "again")
  for k = 2, 4 do ok(v[k] ~= v[k - 1], "never twice in a row") end
  eq(Lib.variants(other, 3)[3], other, "a folder with 1 sound: the same")
  R.lib = keep
  Lib.changed()
end)

test("FX output: master or a hardware pair", function()
  defaults()
  local ft = Drop.folder()
  S.fx_out = 2
  Drop.apply_output(ft)
  eq(r.GetTrackNumSends(ft, 1), 1, "1 hardware output")
  eq(r.GetTrackSendInfo_Value(ft, 1, 0, "I_DSTCHAN"), 2, "Out 3/4")
  eq(r.GetMediaTrackInfo_Value(ft, "B_MAINSEND"), 0, "no master send")
  S.fx_out = 0
  Drop.apply_output(ft)
  eq(r.GetTrackNumSends(ft, 1), 0, "no hardware output")
  eq(r.GetMediaTrackInfo_Value(ft, "B_MAINSEND"), 1, "the master again")
end)

test("check the show: library files, tails, missing files", function()
  defaults()
  S.copy = false
  local rg1 = r.AddProjectMarker(0, true, 100, 104, "Song X", -1)
  local rg2 = r.AddProjectMarker(0, true, 104, 110, "Song Y", -1)
  r.SetEditCurPos(103.99, false, false)
  Drop.insert(Lib.find(lib .. "/Risers/Up 4 bars.wav")) -- its peak at 103.99: its tail (0.06 s) rings past 104
  local item = R.last.item
  local list = C.Chk.run()
  local kinds = {}
  for _, x in ipairs(list) do if x.item == item then kinds[x.kind] = x end end
  ok(kinds.library, "a library file"); ok(kinds.tail, "a tail into the next song")
  C.Chk.fix({ kinds.tail })
  near(r.GetMediaItemInfo_Value(item, "D_POSITION") + r.GetMediaItemInfo_Value(item, "D_LENGTH"), 104, 1e-6, "cut at the song end")
  C.Chk.fix({ kinds.library })
  local fn = C.Util.norm(r.GetMediaSourceFileName(r.GetMediaItemTake_Source(r.GetActiveTake(item))))
  ok(fn:lower():find("/sfx drop/", 1, true), "the item uses the copy in the project folder")
  -- a missing file
  local tr = r.GetMediaItem_Track(item)
  local m = r.AddMediaItemToTrack(tr)
  r.SetMediaItemTake_Source(r.AddTakeToMediaItem(m), r.PCM_Source_CreateFromFile(tmp .. "/nothing here.wav"))
  r.SetMediaItemInfo_Value(m, "D_POSITION", 106)
  r.SetMediaItemInfo_Value(m, "D_LENGTH", 1)
  local missing = false
  for _, x in ipairs(C.Chk.run()) do if x.item == m and x.kind == "missing" then missing = true end end
  ok(missing, "a missing file")
  r.DeleteTrackMediaItem(tr, m)
  r.DeleteTrackMediaItem(tr, item)
  os.remove(fn)
  r.DeleteProjectMarker(0, rg1, true)
  r.DeleteProjectMarker(0, rg2, true)
end)

test("soundcheck from a folder: a Soundcheck folder with copies of its tracks", function()
  defaults()
  r.SetCurrentBPM(0, 120, false)
  r.InsertTrackAtIndex(0, true); r.InsertTrackAtIndex(1, true); r.InsertTrackAtIndex(2, true)
  local f, a, b = r.GetTrack(0, 0), r.GetTrack(0, 1), r.GetTrack(0, 2)
  r.GetSetMediaTrackInfo_String(f, "P_NAME", "Band", true)
  r.SetMediaTrackInfo_Value(f, "I_FOLDERDEPTH", 1)
  r.SetMediaTrackInfo_Value(b, "I_FOLDERDEPTH", -1)
  for _, t in ipairs({ a, b }) do -- (the riser looped over the whole song: no silent bar)
    local it = r.AddMediaItemToTrack(t)
    r.SetMediaItemTake_Source(r.AddTakeToMediaItem(it), r.PCM_Source_CreateFromFile(lib .. "/Risers/Up 4 bars.wav"))
    r.SetMediaItemInfo_Value(it, "B_LOOPSRC", 1)
    r.SetMediaItemInfo_Value(it, "D_POSITION", 0)
    r.SetMediaItemInfo_Value(it, "D_LENGTH", 40)
  end
  local rg = r.AddProjectMarker(0, true, 0, 40, "Song A", -1)
  eq(#Sc.members(f), 3, "the folder and its 2 tracks")
  Sc.parse("")
  P.src, P.len, P.steps, P.imp = r.GetTrackGUID(f), 60, 3, false
  R.sc_state = nil
  Sc.refresh()
  local n = r.CountTracks(0)
  ok(Sc.find_build(), "built")
  eq(r.CountTracks(0), n + 3, "a Soundcheck folder and 2 copies")
  local top = r.GetTrack(0, n)
  eq(select(2, r.GetTrackName(top)), "Soundcheck", "the folder")
  eq(r.GetMediaTrackInfo_Value(top, "I_FOLDERDEPTH"), 1, "a folder")
  eq(r.GetMediaTrackInfo_Value(r.GetTrack(0, n + 2), "I_FOLDERDEPTH"), -1, "the last copy closes it")
  ok(r.CountTrackMediaItems(r.GetTrack(0, n + 1)) >= 1, "the areas are on the copies")
  Sc.remove_old()
  eq(r.CountTracks(0), n, "removed")
  r.DeleteProjectMarker(0, rg, true)
  r.DeleteTrack(b); r.DeleteTrack(a); r.DeleteTrack(f)
  Sc.parse("")
end)

test("sort the list by a column", function()
  defaults()
  R.search, R.filter, R.view = "", 0, nil
  S.sort, S.sort_desc = "len", false -- the impact is 0.6 s, the riser 1.9 s
  local v = Lib.view()
  eq(R.lib[v[1]].type, "Impacts", "short first")
  S.sort_desc = true
  v = Lib.view()
  eq(R.lib[v[1]].type, "Risers", "long first (the cache follows the sort)")
  S.sort, S.sort_desc = "name", false
  v = Lib.view()
  eq(R.lib[v[1]].name, "Big Hit 01", "by name")
  S.sort_desc = true -- "Up 4 bars" (folder Risers) before "Big Hit 01" (folder Impacts): by the name, not the folder
  v = Lib.view()
  eq(R.lib[v[1]].name, "Up 4 bars", "by name, high to low")
  S.sort_desc = false
end)

test("levels: the item gain reaches the type's level", function()
  defaults()
  S.level_on, S.levels, S.lvl_mode = true, { Impacts = -14, Atmos = -24 }, { Impacts = "lufs", Atmos = "lufs" }
  near(Drop.gain({ type = "Impacts", level = -20, top = -3 }), 10 ^ (6 / 20), 1e-9, "LUFS: +6 dB")
  near(Drop.gain({ type = "Impacts", level = -60, top = -3 }), 10 ^ (24 / 20), 1e-9, "at most +24 dB")
  S.levels.Impacts, S.lvl_mode.Impacts = -6, "peak"
  near(Drop.gain({ type = "Impacts", level = -20, top = -3 }), 10 ^ (-3 / 20), 1e-9, "Peak: -3 dB")
  S.level_on = false
  eq(Drop.gain({ type = "Impacts", level = -20 }), 1, "off: 0 dB")
  local env = {}
  for i = 1, 100 do env[i] = 0.5 end
  local _, _, _, _, lv, top = Lib.measure(env, 100, 1.0)
  near(lv, 20 * math.log(0.5, 10) - 3, 0.01, "the level of a steady sound")
  near(top, 20 * math.log(0.5, 10), 0.01, "its peak")
end)

test("favourites: the filter and the list per type", function()
  defaults()
  local e = Lib.find(lib .. "/Risers/Up 4 bars.wav")
  Lib.set_fav(e, true)
  R.search, R.filter, R.view = "", -1, nil
  eq(#Lib.view(), 1, "1 favourite")
  Lib.load_index()
  ok(Lib.find(lib .. "/Risers/Up 4 bars.wav").fav, "saved in the index")
  eq(Lib.by_type("Risers")[1].path, e.path, "a favourite first")
  Lib.set_fav(Lib.find(lib .. "/Risers/Up 4 bars.wav"), false)
  R.filter, R.view = 0, nil
end)

test("find spots: jumps, quiet parts and region starts", function()
  local bars = {}
  -- 16 bars of 2 s: bars 1-4 quiet (-30), 5-8 loud (-10), 9-12 very quiet (-45), 13-16 loud (-10)
  for i = 1, 16 do
    local db = (i <= 4 and -30) or (i <= 8 and -10) or (i <= 12 and -45) or -10
    bars[i] = { t = (i - 1) * 2, num = i, db = db }
  end
  local s = Spots.analyse(bars, { { t = 8, name = "Chorus" }, { t = 20, name = "Bridge" } }, 6)
  local by = {}
  for _, x in ipairs(s) do by[x.num .. x.kind] = x end
  ok(by["5rise"], "bar 5: quiet to loud"); ok(by["5rise"].on, "ticked")
  ok(by["9fall"], "bar 9: loud to quiet")
  ok(by["13rise"], "bar 13: quiet to loud")
  ok(not by["5region"], "the Chorus region is on a spot already")
  ok(by["11region"], "the Bridge region (bar 11)"); ok(not by["11region"].on, "not ticked")
  eq(Spots.reason(by["5rise"]), "quiet to loud +20 dB", "the text")
  local jumps = 0
  for _, x in ipairs(Spots.analyse(bars, {}, 40)) do if x.kind == "rise" or x.kind == "fall" then jumps = jumps + 1 end end
  eq(jumps, 0, "no jump of 40 dB")
  local filled = Spots.fill({ { t = 8, kind = "rise" } })
  eq(#filled[1].parts, 2, "a riser and an impact"); eq(filled[1].parts[1].type, "Risers", "riser first")
end)

test("find spots on real tracks", function()
  defaults()
  r.SetCurrentBPM(0, 120, false)
  r.SetOnlyTrackSelected(r.GetTrack(0, 0))
  r.SetTrackSelected(r.GetTrack(0, 0), false)
  -- a song track: quiet impact at 2 s, loud riser end at 12 s (the test WAVs)
  r.InsertTrackAtIndex(0, true)
  local tr = r.GetTrack(0, 0)
  local item = r.AddMediaItemToTrack(tr)
  local take = r.AddTakeToMediaItem(item)
  r.SetMediaItemTake_Source(take, r.PCM_Source_CreateFromFile(lib .. "/Risers/Up 4 bars.wav"))
  r.SetMediaItemInfo_Value(item, "D_POSITION", 8)
  r.SetMediaItemInfo_Value(item, "D_LENGTH", 1.9)
  r.GetSet_LoopTimeRange(true, false, 0, 16, false)
  ok(Spots.find_begin(), "started")
  eq(#R.spot_scan.tracks, 1, "only the song track (not the FX folder)")
  while R.spot_scan do Spots.find_step(1) end
  ok(R.spots, "spots found")
  local found = false
  for _, s in ipairs(R.spots) do if s.kind == "rise" and math.abs(s.t - 8) < 0.001 then found = true end end
  ok(found, "a rise at bar 5 (8 s)")
  r.GetSet_LoopTimeRange(true, false, 0, 0, false)
  r.DeleteTrack(tr)
end)

for _, t in ipairs(tests) do
  local good, e = pcall(t[2])
  if good then passed = passed + 1; log("ok    " .. t[1])
  else failed = failed + 1; log("FAIL  " .. t[1] .. ": " .. tostring(e)) end
end
finish()
