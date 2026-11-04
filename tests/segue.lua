-- @noindex
-- Segue tests. Run with .\tools\test.ps1 (it starts the portable test REAPER in C:\REAPERtest).
-- Loads Segue.lua without its window, runs each test, writes tests\result_segue.txt, quits REAPER.
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

-- a saved test project with 3 regions, so REAPER can quit without a save prompt
local tmp = r.GetResourcePath() .. "\\SegueTests"
r.RecursiveCreateDirectory(tmp, 0)
local proj_file = tmp .. "\\test.rpp"
local pf = io.open(proj_file, "w")
if pf then pf:write("<REAPER_PROJECT 0.1\n>\n"); pf:close() end
r.Main_openProject("noprompt:" .. proj_file)
r.AddProjectMarker2(0, true, 0, 10, "Song A", -1, 0)
r.AddProjectMarker2(0, true, 20, 50, "Song B", -1, 0)
r.AddProjectMarker2(0, true, 60, 65, "Song C", -1, 0)

local function finish()
  log(string.format("%d passed, %d failed", passed, failed))
  local f = io.open(here .. "\\result_segue.txt", "w")
  if f then f:write(table.concat(out, "\n"), "\n"); f:close() end
  r.Main_SaveProject(0, false)
  r.defer(function() r.Main_OnCommand(40004, 0) end) -- File: Quit REAPER
end

SegueTest = {}
local loaded, err = pcall(dofile, here .. "\\..\\Segue\\Segue.lua")
local C = SegueTest
if not loaded or not C.Project then
  log("FAIL  load Segue.lua: " .. tostring(err)); failed = 1; finish(); return
end
local Project, Setlist, R, Util = C.Project, C.Setlist, C.R, C.Util
log(string.format("REAPER %s in %s, Segue %s loaded", r.GetAppVersion(), r.GetResourcePath(), C.CFG.VERSION))
Project.update()

test("regions are read", function()
  eq(#R.regions, 3, "regions")
  ok(R.regions[1].key:sub(1, 1) == "g", "a GUID key")
end)

test("project data: defaults write nothing", function()
  C.set_P(Project.default())
  eq(Project.serialize(), "version=1", "default text")
end)

test("project data: round trip", function()
  local p = Project.default()
  p.setlists[1] = Setlist.from_timeline("Show")
  p.setlists[1].items[2].ending = "continue"
  p.setlists[1].items[3].skip = true
  table.insert(p.setlists[1].items, 2, { kind = "pause", sec = 7, skip = false })
  p.setlists[2] = { name = "Short", items = {} }
  p.setlist_cur, p.setlist_on, p.setlist_lock = 2, false, true
  C.set_P(p)
  local txt = Project.serialize()
  local q = Project.parse(txt)
  C.set_P(q)
  eq(Project.serialize(), txt, "same text after a round trip")
  eq(#q.setlists, 2, "setlists"); eq(q.setlists[1].name, "Show", "name")
  eq(q.setlists[1].items[2].kind, "pause", "pause"); eq(q.setlists[1].items[2].sec, 7, "seconds")
  eq(q.setlists[1].items[3].ending, "continue", "ending")
  eq(q.setlists[1].items[4].skip, true, "skip")
  eq(q.setlist_cur, 2, "current"); eq(q.setlist_on, false, "order off"); eq(q.setlist_lock, true, "lock")
end)

test("setlist: timeline order, next song, pause, length", function()
  local p = Project.default()
  local l = Setlist.from_timeline("S")
  p.setlists[1] = l
  C.set_P(p)
  eq(#l.items, 3, "3 songs"); eq(Setlist.name_of(l.items[1]), "Song A", "first")
  local j = Setlist.next_from(l, 1); eq(j, 2, "next song")
  l.items[2].skip = true
  j = Setlist.next_from(l, 1); eq(j, 3, "a skipped song is passed")
  table.insert(l.items, 2, { kind = "pause", sec = 5, skip = false })
  ok(Setlist.pause_after(l, 1), "a pause after song 1")
  R.frames = R.frames + 1
  eq(Setlist.length(l), 10 + 5 + 5, "length: A + pause + C (B skipped)")
  eq(Setlist.find(l, 61), 4, "the item at 61 s is Song C")
end)

test("setlist: undo", function()
  local p = Project.default()
  local l = Setlist.from_timeline("S")
  p.setlists[1] = l
  C.set_P(p)
  Setlist.save_undo(l)
  table.remove(l.items, 1)
  ok(Setlist.can_undo(l), "can undo")
  Setlist.undo(l)
  eq(#l.items, 3, "the row is back")
  p.setlist_lock = true
  Setlist.save_undo(l)
  ok(not Setlist.can_undo(l), "no undo while locked")
end)

test("next song action: the queue", function()
  local p = Project.default()
  p.setlists[1] = Setlist.from_timeline("S")
  p.setlist_on = false
  C.set_P(p)
  r.SetEditCurPos(0, false, false)
  R.sl_pos = nil
  r.SetExtState("Segue", "cmd_q", "nextsong,", false)
  Setlist.read_cmds()
  eq(r.GetExtState("Segue", "cmd_q"), "", "queue read")
  eq(R.sl_pos, 2, "went to song 2")
  eq(r.GetCursorPosition(), 20, "edit cursor at Song B")
end)

test("project data is saved only when it changed", function()
  local p = Project.default()
  p.setlists[1] = Setlist.from_timeline("Saved")
  C.set_P(p)
  R.proj = r.EnumProjects(-1)
  Project.save()
  local _, txt = r.GetProjExtState(0, "Segue", "cfg")
  eq(txt, Project.serialize(), "written")
  ok(not R.pdirty, "clean")
end)

test("Chart Cue also in setlist order: Segue waits; Use Segue sends the command", function()
  local p = Project.default()
  p.setlists[1] = Setlist.from_timeline("S")
  C.set_P(p)
  R.proj = r.EnumProjects(-1)
  r.SetProjExtState(0, "ChartCue", "cfg", "version=1\nsetlist_on=1")
  r.SetExtState("ChartCue", "heartbeat", tostring(r.time_precise()), false)
  R.cf_t = nil
  ok(Setlist.conflict(), "conflict found")
  r.SetExtState("ChartCue", "cmd_q", "", false)
  Setlist.take_control()
  eq(r.GetExtState("ChartCue", "cmd_q"), "setlistoff,", "command sent")
  -- Chart Cue closed (old heartbeat): no conflict
  r.SetExtState("ChartCue", "heartbeat", tostring(r.time_precise() - 10), false)
  R.cf_t = nil
  ok(not Setlist.conflict(), "no conflict without Chart Cue")
  -- Segue's own setlist order off: no conflict
  r.SetExtState("ChartCue", "heartbeat", tostring(r.time_precise()), false)
  p.setlist_on = false
  R.cf_t = nil
  ok(not Setlist.conflict(), "no conflict with Segue off")
  ok(Setlist.cc_master(), "Chart Cue is still master")
  ok(Setlist.locked(), "Segue locked while Chart Cue is master")
  eq(p.setlist_lock, false, "the saved lock does not change")
  Setlist.take_control()
  eq(p.setlist_on, true, "Use Segue turns Segue's setlist order on")
  r.SetProjExtState(0, "ChartCue", "cfg", "")
  r.SetExtState("ChartCue", "cmd_q", "", false)
end)

test("song end: REAPER stops by itself at the exact end (armed); then the next song is ready", function()
  local p = Project.default()
  local l = Setlist.from_timeline("S")
  p.setlists[1] = l
  C.set_P(p)
  R.proj = r.EnumProjects(-1)
  ok(Setlist.lead() >= 0.02 and Setlist.lead() <= 0.15, "lead in 0.02 .. 0.15 s")
  local gps, gps2, gst, stop = r.GetPlayPosition, r.GetPlayPosition2, r.GetPlayState, r.OnStopButton
  local stopped = false
  r.GetPlayState = function() return 1 end
  r.OnStopButton = function() stopped = true end
  r.GetPlayPosition = function() return 9.80 end  -- heard: 0.2 s before the end of Song A (0 .. 10)
  r.GetPlayPosition2 = function() return 9.99 end -- the engine: almost at the end
  R.sl_pos, R.sl_guard, R.sl_hold, R.cf_t, R.cf = 1, nil, nil, Util.now(), false
  local good, e = pcall(Setlist.tick)
  r.GetPlayPosition, r.GetPlayPosition2, r.GetPlayState, r.OnStopButton = gps, gps2, gst, stop
  if not good then error(e, 0) end
  ok(not stopped, "no Stop from the script")
  ok(R.arm and R.arm.stop == 10, "the stop at the end of Song A is armed")
  Setlist.tick() -- REAPER has stopped (the test REAPER does not play)
  ok(not R.arm, "disarmed")
  eq(R.sl_pos, 2, "Song B is next")
end)

test("outside the setlist songs: the last song stays current; previous / next song from it", function()
  local p = Project.default()
  p.setlists[1] = Setlist.from_timeline("S")
  C.set_P(p)
  local gps, gps2, gst = r.GetPlayPosition, r.GetPlayPosition2, r.GetPlayState
  local play = 55 -- between Song B (20 .. 50) and Song C (60 .. 65)
  r.GetPlayState = function() return 1 end
  r.GetPlayPosition = function() return play end
  r.GetPlayPosition2 = function() return play end
  local sep, seek = r.SetEditCurPos, nil
  r.SetEditCurPos = function(t) seek = t end
  R.sl_pos, R.sl_guard, R.sl_hold, R.cf_t, R.cf = 2, nil, nil, Util.now(), false
  local good, e = pcall(function()
    Setlist.tick()
    eq(R.sl_pos, 2, "Song B stays current")
    Setlist.prev_song(p.setlists[1])
    eq(seek, 20, "previous song: the start of Song B")
    seek = nil; play = 55; R.sl_pos = 2
    Setlist.next_song(p.setlists[1])
    eq(seek, 60, "next song: Song C")
  end)
  r.GetPlayPosition, r.GetPlayPosition2, r.GetPlayState, r.SetEditCurPos = gps, gps2, gst, sep
  Setlist.disarm()
  if not good then error(e, 0) end
end)

for _, t in ipairs(tests) do
  local good, e = pcall(t[2])
  if good then passed = passed + 1; log("ok    " .. t[1])
  else failed = failed + 1; log("FAIL  " .. t[1] .. ": " .. tostring(e)) end
end
finish()
