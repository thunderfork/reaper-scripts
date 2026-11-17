-- @noindex
-- Mono Merge tests. Run with .\tools\test.ps1 -Script "Mono Merge" (it starts the portable test REAPER in C:\REAPERtest).
-- Loads Mono Merge.lua without running it, runs each test, writes tests\result_monomerge.txt, quits REAPER.
local r = reaper
local here = ({ r.get_action_context() })[2]:match("^(.*)[/\\]")
local out = {}
local passed, failed = 0, 0
local function log(s) out[#out + 1] = s end
local function eq(a, b, what)
  if a ~= b then error((what or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end
local function near(a, b, what)
  if math.abs(a - b) > 1e-4 then error((what or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end
local function ok(v, what) if not v then error((what or "check") .. " failed", 2) end end
local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end

-- a fresh saved test project (its audio goes into the project folder)
local tmp = r.GetResourcePath() .. "\\MonoMergeTests"
r.RecursiveCreateDirectory(tmp, 0)
for _, dir in ipairs({ tmp, tmp .. "\\Media" }) do -- the old test files and results
  local names, i = {}, 0
  while true do
    local f = r.EnumerateFiles(dir, i)
    if not f then break end
    names[#names + 1] = f; i = i + 1
  end
  for _, f in ipairs(names) do
    if f:match("%.wav$") or f:match("%.reapeaks$") then os.remove(dir .. "\\" .. f) end
  end
end
local proj_file = tmp .. "\\test.rpp"
local pf = io.open(proj_file, "w")
if pf then pf:write("<REAPER_PROJECT 0.1\n>\n"); pf:close() end
r.Main_openProject("noprompt:" .. proj_file)

local function finish()
  log(string.format("%d passed, %d failed", passed, failed))
  local f = io.open(here .. "\\result_monomerge.txt", "w")
  if f then f:write(table.concat(out, "\n"), "\n"); f:close() end
  r.Main_SaveProject(0, false)
  r.defer(function() r.Main_OnCommand(40004, 0) end) -- File: Quit REAPER
end

MonoMergeTest = {}
local loaded, err = pcall(dofile, here .. "\\..\\Mono Merge\\Mono Merge.lua")
local C = MonoMergeTest
if not loaded or not C.Merge then
  log("FAIL  load Mono Merge.lua: " .. tostring(err)); failed = 1; finish(); return
end
local Util, Merge = C.Util, C.Merge
log(string.format("REAPER %s in %s, Mono Merge %s loaded", r.GetAppVersion(), r.GetResourcePath(), C.CFG.VERSION))

local SR = 48000
-- a 32-bit float test WAV file from a function of the frame (1-based) and channel; nch 1 or 2
local function make_wav(name, frames, nch, fn)
  local path = tmp .. "\\" .. name
  local f = assert(io.open(path, "wb"))
  local data = frames * nch * 4
  f:write("RIFF", string.pack("<I4", 4 + 26 + 12 + 8 + data), "WAVE")
  f:write("fmt ", string.pack("<I4I2I2I4I4I2I2I2", 18, 3, nch, SR, SR * nch * 4, nch * 4, 32, 0))
  f:write("fact", string.pack("<I4I4", 4, frames), "data", string.pack("<I4", data))
  for k = 1, frames do for c = 1, nch do f:write(string.pack("<f", fn(k, c))) end end
  f:close()
  return path
end
-- the audio of the new item (its take, as REAPER plays it): channels and frames, interleaved
local function read_item(item)
  local take = r.GetActiveTake(item)
  local nch = r.GetMediaSourceNumChannels(r.GetMediaItemTake_Source(take))
  local frames = math.floor(r.GetMediaItemInfo_Value(item, "D_LENGTH") * SR + 0.5)
  local acc = r.CreateTakeAudioAccessor(take)
  local buf = r.new_array(frames * nch)
  r.GetAudioAccessorSamples(acc, SR, nch, 0, frames, buf)
  r.DestroyAudioAccessor(acc)
  return nch, frames, buf.table()
end
local function new_track(name)
  local idx = r.CountTracks(0)
  r.InsertTrackAtIndex(idx, false)
  local tr = r.GetTrack(0, idx)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
  return tr
end
local function add_item(tr, path, pos)
  local item = r.AddMediaItemToTrack(tr)
  local take = r.AddTakeToMediaItem(item)
  local src = r.PCM_Source_CreateFromFile(path)
  r.SetMediaItemTake_Source(take, src)
  r.SetMediaItemInfo_Value(item, "D_POSITION", pos)
  r.SetMediaItemInfo_Value(item, "D_LENGTH", r.GetMediaSourceLength(src))
  for _, k in ipairs({ "D_FADEINLEN", "D_FADEOUTLEN", "D_FADEINLEN_AUTO", "D_FADEOUTLEN_AUTO" }) do
    r.SetMediaItemInfo_Value(item, k, 0)
  end
  r.UpdateItemInProject(item)
  return item
end
local function clear()
  for k = r.CountTracks(0) - 1, 0, -1 do r.DeleteTrack(r.GetTrack(0, k)) end
end

local A = make_wav("a.wav", 1000, 1, function(f) return (f % 100) / 200 end)
local B = make_wav("b.wav", 600, 1, function() return 0.25 end)
local ST = make_wav("st.wav", 100, 2, function(_, c) return c == 1 and 0.1 or 0.3 end)
local function a_val(f) return (f % 100) / 200 end

test("common name", function()
  eq(Util.common_name("Kick In", "Kick Out"), "Kick")
  eq(Util.common_name("OH L", "OH R"), "OH")
  eq(Util.common_name("Gtr_L", "Gtr_R"), "Gtr")
  eq(Util.common_name("In Kick", "Out Kick"), "Kick")
  eq(Util.common_name("Kick", "Snare"), "Kick + Snare")
  eq(Util.common_name("Bass", "Bass"), "Bass")
  eq(Util.common_name("", "Bass"), "Bass")
  eq(Util.common_name("", ""), "Stereo")
end)

test("stereo or MIDI item stops", function()
  clear()
  local tr = new_track("T")
  local st = add_item(tr, ST, 0)
  ok(Merge.check(st, "raw"):find("not mono"), "stereo refused (raw)")
  ok(Merge.check(st, "edits"):find("not mono"), "stereo refused (edits)")
  r.SetMediaItemTakeInfo_Value(r.GetActiveTake(st), "I_CHANMODE", 3) -- left only
  eq(Merge.check(st, "edits"), nil, "stereo as left only: allowed with edits")
  local bad, ask = Merge.check(st, "raw")
  eq(bad, nil, "stereo as left only, raw: no stop")
  ok(ask and ask:find("Mono %(left%)"), "stereo as left only, raw: a question")
  local midi = r.CreateNewMIDIItemInProj(tr, 5, 6)
  ok(Merge.check(midi, "edits"):find("no audio"), "MIDI refused")
end)

test("order: the top track is left; on 1 track the earlier item", function()
  clear()
  local t1, t2 = new_track("Kick In"), new_track("Kick Out")
  local x, y = add_item(t2, B, 0), add_item(t1, A, 5)
  local l, rr = Merge.order(x, y)
  ok(l == y and rr == x, "top track left")
  local z = add_item(t1, B, 1)
  l, rr = Merge.order(y, z)
  ok(l == z and rr == y, "earlier item left")
end)

test("raw files: full files, start aligned, shorter side silent", function()
  clear()
  local t1, t2 = new_track("Kick In"), new_track("Kick Out")
  local a = add_item(t1, A, 2)
  local b = add_item(t2, B, 7)
  r.SetMediaItemInfo_Value(a, "D_VOL", 0.5) -- ignored in raw mode
  local item, path = Merge.run(b, a, "raw")
  ok(item, "merged: " .. tostring(path))
  ok(path:find("Kick", 1, true), "file name: " .. path)
  local nch, frames, v = read_item(item)
  eq(nch, 2, "channels"); eq(frames, 1000, "frames")
  for f = 1, 1000 do
    near(v[f * 2 - 1], a_val(f), "left frame " .. f)
    near(v[f * 2], f <= 600 and 0.25 or 0, "right frame " .. f)
  end
  local tr = r.GetMediaItem_Track(item)
  eq(r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER"), 3, "new track below")
  eq(select(2, r.GetTrackName(tr)), "Kick", "track name")
  near(r.GetMediaItemInfo_Value(item, "D_POSITION"), 2, "position")
  eq(r.GetMediaItemInfo_Value(a, "B_MUTE"), 1, "left muted")
  eq(r.GetMediaItemInfo_Value(b, "B_MUTE"), 1, "right muted")
  eq(r.CountTracks(0), 3, "1 new track")
  eq(select(2, r.GetSetMediaItemTakeInfo_String(r.GetActiveTake(item), "P_NAME", "", false)), "Kick", "take name")
  ok(r.IsMediaItemSelected(item) and r.CountSelectedMediaItems(0) == 1, "only the new item selected")
end)

test("with edits: item volume, timeline offset, padding", function()
  clear()
  local t1, t2 = new_track("OH L"), new_track("OH R")
  local a = add_item(t1, A, 1)
  local b = add_item(t2, B, 1 + 100 / SR) -- 100 frames later
  r.SetMediaItemInfo_Value(a, "D_VOL", 0.5)
  r.SetMediaItemInfo_Value(a, "B_MUTE", 1) -- a muted item is still read
  local item, path = Merge.run(a, b, "edits")
  ok(item, "merged: " .. tostring(path))
  local nch, frames, v = read_item(item)
  eq(nch, 2, "channels"); eq(frames, 1000, "frames")
  for f = 1, 1000 do
    near(v[f * 2 - 1], a_val(f) * 0.5, "left frame " .. f)
    near(v[f * 2], (f > 100 and f <= 700) and 0.25 or 0, "right frame " .. f)
  end
  near(r.GetMediaItemInfo_Value(item, "D_POSITION"), 1, "position")
  eq(select(2, r.GetTrackName(r.GetMediaItem_Track(item))), "OH", "track name")
end)

test("raw files: a stereo file that plays as mono keeps its channel mode", function()
  clear()
  local t1, t2 = new_track("Gtr 1"), new_track("Gtr 2")
  local s = add_item(t1, ST, 0)
  r.SetMediaItemTakeInfo_Value(r.GetActiveTake(s), "I_CHANMODE", 4) -- right only
  local b = add_item(t2, B, 0)
  local item, path = Merge.run(s, b, "raw")
  ok(item, "merged: " .. tostring(path))
  local _, frames, v = read_item(item)
  eq(frames, 600, "frames")
  near(v[1], 0.3, "left = the right channel of the file")
  near(v[199], 0.3, "left frame 100")
  near(v[201], 0, "left after the file")
  near(v[2], 0.25, "right")
end)

test("with edits: a gap between the items and take FX", function()
  clear()
  local t1, t2 = new_track("Vox 1"), new_track("Vox 2")
  local a = add_item(t1, B, 0)
  local b = add_item(t2, B, (600 + 400) / SR) -- starts 400 frames after a ends
  local take = r.GetActiveTake(b)
  local fx = r.TakeFX_AddByName(take, "JS: Volume Adjustment", -1)
  ok(fx >= 0, "take FX added")
  r.TakeFX_SetParam(take, fx, 0, -6.0206) -- -6 dB: half
  local item = assert(Merge.run(a, b, "edits"))
  local _, frames, v = read_item(item)
  eq(frames, 1600, "frames: both items and the gap")
  near(v[2 * 300 - 1], 0.25, "left in a"); near(v[2 * 300], 0, "right before b")
  near(v[2 * 800 - 1], 0, "left in the gap")
  near(v[2 * 1300 - 1], 0, "left after a"); near(v[2 * 1300], 0.125, "right with its take FX")
end)

test("folder, take pan envelope, locked item, missing file", function()
  clear()
  local f, t1, t2 = new_track("Drums"), new_track("Kick In"), new_track("Kick Out")
  local after = new_track("Bass")
  r.SetMediaTrackInfo_Value(f, "I_FOLDERDEPTH", 1)
  r.SetMediaTrackInfo_Value(t2, "I_FOLDERDEPTH", -1)
  local a, b = add_item(t1, A, 0), add_item(t2, B, 0)
  r.SetMediaItemInfo_Value(a, "C_LOCK", 1)
  local env = r.GetTakeEnvelopeByName(r.GetActiveTake(b), "Pan")
  if not env then
    r.SetMediaItemSelected(b, true)
    r.Main_OnCommand(40694, 0) -- Take: Toggle take pan envelope
    env = r.GetTakeEnvelopeByName(r.GetActiveTake(b), "Pan")
  end
  ok(env, "pan envelope made")
  r.InsertEnvelopePoint(env, 0, 0, 0, 0, false, true) -- centre
  r.Envelope_SortPoints(env)
  local item = assert(Merge.run(a, b, "edits"))
  local tr = r.GetMediaItem_Track(item)
  eq(r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER"), 4, "below Kick Out")
  eq(r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH"), -1, "new track closes the folder")
  eq(r.GetMediaTrackInfo_Value(t2, "I_FOLDERDEPTH"), 0, "Kick Out no longer closes it")
  eq(r.GetMediaTrackInfo_Value(after, "I_FOLDERDEPTH"), 0, "Bass outside")
  local _, _, v = read_item(item)
  near(v[2 * 50], 0.25, "right side"); near(v[2 * 50 - 1], a_val(50), "left side: no pan envelope mix")
  eq(r.GetMediaItemInfo_Value(a, "C_LOCK"), 1, "the original stays locked")

  local gone = make_wav("gone.wav", 100, 1, function() return 0.1 end)
  local m = add_item(t1, gone, 10)
  r.GetSetMediaItemTakeInfo_String(r.GetActiveTake(m), "P_NAME", "Gone", true)
  r.SelectAllMediaItems(0, false)
  r.SetMediaItemSelected(m, true)
  r.Main_OnCommand(40440, 0) -- Item: Set selected media temporarily offline (frees the file)
  ok(os.remove(gone), "file deleted")
  local msg = Merge.check(m, "raw")
  ok(msg and msg:find("missing or offline"), "missing file: " .. tostring(msg))
end)

test("same track: item names", function()
  clear()
  local t = new_track("Gtr")
  local a, b = add_item(t, A, 0), add_item(t, B, 3)
  r.GetSetMediaItemTakeInfo_String(r.GetActiveTake(a), "P_NAME", "Gtr DI.wav", true)
  r.GetSetMediaItemTakeInfo_String(r.GetActiveTake(b), "P_NAME", "Gtr Mic.wav", true)
  eq(Merge.name(Merge.order(b, a)), "Gtr")
end)

for _, t in ipairs(tests) do
  local good, e = pcall(t[2])
  if good then passed = passed + 1; log("ok    " .. t[1])
  else failed = failed + 1; log("FAIL  " .. t[1] .. ": " .. tostring(e)) end
end
finish()
