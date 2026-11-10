-- @noindex
-- FX Link tests. Run with .\tools\test.ps1 -Script "FX Link" (it starts the portable test REAPER in C:\REAPERtest).
-- Loads FX Link.lua without its window, runs each test, writes tests\result_fxlink.txt, quits REAPER.
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

-- a saved test project with 4 tracks: ReaEQ on tracks 1-3, ReaComp on track 4
local tmp = r.GetResourcePath() .. "\\FxLinkTests"
r.RecursiveCreateDirectory(tmp, 0)
local proj_file = tmp .. "\\test.rpp"
local pf = io.open(proj_file, "w")
if pf then pf:write("<REAPER_PROJECT 0.1\n>\n"); pf:close() end
r.Main_openProject("noprompt:" .. proj_file)
local tr = {}
for i = 1, 4 do
  r.InsertTrackAtIndex(i - 1, false)
  tr[i] = r.GetTrack(0, i - 1)
  r.TrackFX_AddByName(tr[i], i < 4 and "ReaEQ" or "ReaComp", false, -1)
end

local function finish()
  log(string.format("%d passed, %d failed", passed, failed))
  local f = io.open(here .. "\\result_fxlink.txt", "w")
  if f then f:write(table.concat(out, "\n"), "\n"); f:close() end
  r.Main_SaveProject(0, false)
  r.defer(function() r.Main_OnCommand(40004, 0) end) -- File: Quit REAPER
end

FxLinkTest = {}
local loaded, err = pcall(dofile, here .. "\\..\\FX Link\\FX Link.lua")
local C = FxLinkTest
if not loaded or not C.Project then
  log("FAIL  load FX Link.lua: " .. tostring(err)); failed = 1; finish(); return
end
local Project, Fx, Link, R = C.Project, C.Fx, C.Link, C.R
log(string.format("REAPER %s in %s, FX Link %s loaded", r.GetAppVersion(), r.GetResourcePath(), C.CFG.VERSION))
Project.update()

local function get(i, p) return r.TrackFX_GetParamNormalized(tr[i], 0, p) end
local function set(i, p, v) r.TrackFX_SetParamNormalized(tr[i], 0, p, v) end
-- a group with ReaEQ on tracks 1 and 2 (track 3 not linked)
local function make_group(mode)
  local p = Project.default()
  C.set_P(p)
  local g = Project.new_group("Guitars")
  g.mode = mode or "exact"
  p.groups[1] = g
  ok(Fx.add(g, tr[1], 0), "add track 1")
  ok(Fx.add(g, tr[2], 0), "add track 2")
  return g
end
local function member(g, i) return g.members[i] end

test("project data: defaults write nothing", function()
  C.set_P(Project.default())
  eq(Project.serialize(), "version=1", "default text")
end)

test("project data: round trip", function()
  local p = Project.default()
  C.set_P(p)
  local g = Project.new_group("Guitars")
  g.on, g.mode, g.all, g.params, g.ident, g.plug = false, "rel", false, { [3] = true, [0] = true }, "id", "Pro-Q 3"
  g.members = { { guid = "{A}" }, { guid = "{B}" } }
  p.groups[1] = g
  p.groups[2] = Project.new_group("Misc")
  p.cur = 2
  local txt = Project.serialize()
  local q = Project.parse(txt)
  eq(#q.groups, 2, "groups")
  local h = q.groups[1]
  eq(h.name, "Guitars", "name"); eq(h.on, false, "on"); eq(h.mode, "rel", "mode"); eq(h.all, false, "all")
  ok(h.params[0] and h.params[3], "picked params"); eq(h.plug, "Pro-Q 3", "plugin")
  eq(#h.members, 2, "members"); eq(h.members[2].guid, "{B}", "member guid")
  eq(q.groups[2].all, true, "2nd group: all"); eq(q.cur, 2, "current group")
  C.set_P(q)
  eq(Project.serialize(), txt, "same text again")
end)

test("short plugin names", function()
  eq(Fx.short_name("VST3: Pro-Q 3 (FabFilter)"), "Pro-Q 3", "VST3")
  eq(Fx.short_name("VST: ReaEQ (Cockos)"), "ReaEQ", "VST")
  eq(Fx.short_name("JS: My Effect"), "My Effect", "JS")
end)

test("relative target: clamps and keeps the difference", function()
  local v, virt = Link.target("rel", 0.9, 0.3, 0.8)
  near(v, 1, "clamped"); near(virt, 1.1, "unclamped")
  v, virt = Link.target("rel", 0.6, -0.3, virt)
  near(v, 0.8, "back with its old difference")
  v = Link.target("exact", 0.4, 0.1, 0.9)
  near(v, 0.4, "exact")
end)

test("add: same plugin only, 1 group only", function()
  local g = make_group()
  eq(#g.members, 2, "2 members")
  local okd = Fx.add(g, tr[1], 0)
  ok(not okd, "the same instance twice")
  local okc, e = Fx.add(g, tr[4], 0)
  ok(not okc and e:find("same plugin"), "another plugin")
  local g2 = Project.new_group("Other")
  C.get_P().groups[2] = g2
  local okg, e2 = Fx.add(g2, tr[1], 0)
  ok(not okg and e2:find("1 group only"), "a plugin in 2 groups")
end)

test("exact: a change is copied to the group only", function()
  local g = make_group("exact")
  set(1, 0, 0.2); set(2, 0, 0.7); set(3, 0, 0.5)
  Fx.resolve(true)
  set(1, 0, 0.3)
  eq(Link.sync(g, member(g, 1)), 1, "1 changed parameter")
  near(get(2, 0), 0.3, "track 2 follows")
  near(get(3, 0), 0.5, "track 3 not linked")
  eq(Link.sync(g, member(g, 1)), 0, "no change, no copy")
end)

test("relative: the same change, the range end, and back", function()
  local g = make_group("rel")
  set(1, 0, 0.5); set(2, 0, 0.8)
  Fx.resolve(true)
  set(1, 0, 0.6); Link.sync(g, member(g, 1))
  near(get(2, 0), 0.9, "+0.1")
  set(1, 0, 0.8); Link.sync(g, member(g, 1))
  near(get(2, 0), 1, "stops at the end")
  set(1, 0, 0.5); Link.sync(g, member(g, 1))
  near(get(2, 0), 0.8, "back with its old difference")
  set(2, 0, 0.7); Link.sync(g, member(g, 2))
  near(get(1, 0), 0.4, "the other instance as the source")
end)

test("picked parameters: only those are copied", function()
  local g = make_group("exact")
  g.all, g.params = false, { [1] = true }
  set(1, 0, 0.2); set(2, 0, 0.6); set(1, 1, 0.2); set(2, 1, 0.6)
  Fx.resolve(true)
  set(1, 0, 0.3); set(1, 1, 0.3)
  Link.sync(g, member(g, 1))
  near(get(2, 0), 0.6, "parameter 0 not picked")
  near(get(2, 1), 0.3, "parameter 1 picked")
end)

test("a deleted plugin shows as missing", function()
  local g = make_group("exact")
  r.InsertTrackAtIndex(4, false)
  local t5 = r.GetTrack(0, 4)
  r.TrackFX_AddByName(t5, "ReaEQ", false, -1)
  ok(Fx.add(g, t5, 0), "add track 5")
  local m = g.members[3]
  r.DeleteTrack(t5)
  Fx.resolve(false)
  ok(R.rt[m] == nil, "missing")
  ok(R.rt[g.members[1]] ~= nil, "the others are still found")
end)

test("project data is written only when it changed", function()
  make_group("exact")
  Project.save()
  local _, txt = r.GetProjExtState(0, "FX Link", "cfg")
  ok(txt:find("group=1\texact\tall\t", 1, true), "group line")
  local n = select(2, txt:gsub("\nfx=", ""))
  eq(n, 2, "2 instances")
end)

test("a group turned on again does not copy the changes made while it was off", function()
  local g = make_group("exact")
  set(1, 0, 0.2); set(2, 0, 0.6)
  Fx.resolve(true)
  g.on = false
  set(1, 0, 0.4) -- a solo change while off
  g.on = true; Link.group_changed(g)
  eq(Link.sync(g, member(g, 1)), 0, "nothing copied")
  near(get(2, 0), 0.6, "track 2 keeps its value")
end)

test("Picked to All does not copy old changes of unpicked parameters", function()
  local g = make_group("exact")
  g.all, g.params = false, { [1] = true }
  set(1, 0, 0.2); set(2, 0, 0.6)
  Fx.resolve(true)
  set(1, 0, 0.5) -- parameter 0 is not picked
  Link.sync(g, member(g, 1))
  g.all = true; Link.group_changed(g)
  Link.sync(g, member(g, 1))
  near(get(2, 0), 0.6, "not copied")
end)

test("Learn stops when its group is not shown", function()
  local g = make_group("exact")
  g.all = false
  local p = C.get_P()
  p.groups[2] = Project.new_group("Other"); p.cur = 1
  Link.learn(g)
  ok(R.learn ~= nil, "learning")
  p.cur = 2; Link.tick()
  ok(R.learn == nil, "stopped (another group)")
  p.cur = 1; Link.learn(g); g.all = true; Link.tick()
  ok(R.learn == nil, "stopped (All)")
end)

test("project data: plugin sort and Link bypass", function()
  local p = Project.default()
  C.set_P(p)
  local g = Project.new_group("G")
  p.groups[1] = g
  eq(Project.serialize():find("g_sort", 1, true), nil, "defaults write nothing")
  g.sort, g.bypass = "name", true
  local q = Project.parse(Project.serialize())
  eq(q.groups[1].sort, "name", "sort"); eq(q.groups[1].bypass, true, "bypass")
end)

test("Match: the others copy the model", function()
  local g = make_group("rel")
  set(1, 0, 0.2); set(2, 0, 0.7); set(1, 1, 0.3); set(2, 1, 0.9)
  Fx.resolve(true)
  Link.match(g, member(g, 2))
  near(get(1, 0), 0.7, "parameter 0"); near(get(1, 1), 0.9, "parameter 1")
  near(get(3, 0), get(3, 0), "track 3 untouched")
  set(2, 0, 0.8); Link.sync(g, member(g, 2))
  near(get(1, 0), 0.8, "linked from the new values (no old difference)")
end)

test("Link bypass: off on one turns the others off", function()
  local g = make_group("exact")
  for i = 1, 3 do r.TrackFX_SetEnabled(tr[i], 0, true) end
  Fx.resolve(true)
  ok(not Link.bypass_tick(), "no change yet")
  r.TrackFX_SetEnabled(tr[1], 0, false)
  ok(not Link.bypass_tick(), "Link bypass off: nothing")
  g.bypass = true; Link.group_changed(g)
  r.TrackFX_SetEnabled(tr[2], 0, false)
  ok(Link.bypass_tick(), "a change")
  eq(r.TrackFX_GetEnabled(tr[1], 0), false, "track 1 off")
  eq(r.TrackFX_GetEnabled(tr[3], 0), true, "track 3 not linked")
  for i = 1, 3 do r.TrackFX_SetEnabled(tr[i], 0, true) end
end)

test("Add all in project: every ReaEQ, not ReaComp, not twice", function()
  local p = Project.default()
  C.set_P(p)
  local g = Project.new_group("All")
  p.groups[1] = g
  ok(Fx.add(g, tr[1], 0), "first")
  local added = Fx.add_all(g)
  eq(added, 2, "2 more ReaEQ")
  eq(#g.members, 3, "3 in the group")
  eq(Fx.add_all(g), 0, "nothing twice")
end)

test("actions: toggle the selected group", function()
  local g = make_group("exact")
  r.SetExtState("FX Link", "cmd_q", "toggle,", false)
  Link.read_cmds()
  eq(g.on, false, "off")
  eq(r.GetExtState("FX Link", "cmd_q"), "", "queue empty")
  r.SetExtState("FX Link", "cmd_q", "toggle,", false)
  Link.read_cmds()
  eq(g.on, true, "on again")
end)

test("plugin row: another copy on the same track", function()
  local g = make_group("exact")
  local idx2 = r.TrackFX_AddByName(tr[1], "ReaEQ", false, -1)
  local list = Fx.copies(g, tr[1])
  eq(#list, 2, "2 copies on track 1")
  local m = member(g, 1)
  ok(Fx.replace(g, m, list[2].guid), "replace")
  eq(R.rt[m].idx, idx2, "now the 2nd copy")
  ok(R.rt[m].fx_label:find("(slot " .. (idx2 + 1) .. ")", 1, true), "the slot in the label")
  ok(not R.rt[member(g, 2)].fx_label:find("slot", 1, true), "no slot with 1 copy")
  local okr, e = Fx.replace(g, member(g, 2), list[2].guid)
  ok(not okr and e:find("already"), "a copy in the group twice")
  r.TrackFX_Delete(tr[1], idx2)
end)

test("select the tracks of a group", function()
  local g = make_group("exact")
  r.SetTrackSelected(tr[4], true)
  Fx.select_tracks(g.members)
  ok(r.IsTrackSelected(tr[1]) and r.IsTrackSelected(tr[2]), "group tracks selected")
  ok(not r.IsTrackSelected(tr[3]) and not r.IsTrackSelected(tr[4]), "only those")
  Fx.select_tracks({ member(g, 2) })
  ok(r.IsTrackSelected(tr[2]) and not r.IsTrackSelected(tr[1]), "1 plugin row: its track only")
end)

test("settings: back up, restore, reset", function()
  local S = C.S
  local Util = C.Util
  S.light, S.close_proj, S.closed = true, false, { params = true, groups = true }
  local path = Util.backup_settings()
  ok(path, "backup written")
  S.light, S.close_proj, S.closed = false, true, {}
  ok(Util.restore_settings(path), "restored")
  eq(S.light, true, "light"); eq(S.close_proj, false, "close with project")
  ok(S.closed.params and S.closed.groups, "folded sections")
  ok(Util.newest_backup() ~= nil, "the newest backup is found")
  os.remove(path)
  Util.reset_settings()
  eq(S.light, false, "reset: light"); eq(S.close_proj, true, "reset: close with project")
  eq(next(S.closed), nil, "reset: nothing folded")
  local bad = tmp .. "\\not a backup.txt"
  local f = io.open(bad, "w"); f:write("hello\n"); f:close()
  ok(not Util.restore_settings(bad), "not a backup file")
  os.remove(bad)
end)

test("close with project: Save as is no close", function()
  make_group("exact")
  Project.save()
  local proj, fn = r.EnumProjects(-1)
  R.proj_fp = Project.fingerprint(proj)
  ok(not Project.closed_or_replaced(proj, fn .. ".copy"), "same data and content: Save as")
  ok(Project.closed_or_replaced(proj, ""), "File > New / Close in the same tab")
end)

test("All except: every parameter but the listed ones; saved", function()
  local g = make_group("exact")
  g.all, g.except, g.params = true, true, { [0] = true }
  Link.group_changed(g)
  set(1, 0, 0.2); set(2, 0, 0.6); set(1, 1, 0.2); set(2, 1, 0.6)
  Fx.resolve(true)
  set(1, 0, 0.3); set(1, 1, 0.3)
  Link.sync(g, member(g, 1))
  near(get(2, 0), 0.6, "parameter 0 left out")
  near(get(2, 1), 0.3, "parameter 1 linked")
  local q = Project.parse(Project.serialize())
  eq(q.groups[1].except, true, "except saved"); eq(q.groups[1].all, true, "all")
  ok(q.groups[1].params[0], "the left-out parameter saved")
end)

test("plugin names are saved (for Find again)", function()
  local g = make_group("exact")
  r.GetSetMediaTrackInfo_String(tr[1], "P_NAME", "Gtr L", true)
  Fx.resolve(false)
  eq(member(g, 1).tname, "Gtr L", "track name")
  eq(member(g, 1).fname, "ReaEQ", "plugin name")
  local q = Project.parse(Project.serialize())
  eq(q.groups[1].members[1].tname, "Gtr L", "saved track name")
  eq(q.groups[1].members[1].guid, member(g, 1).guid, "guid still first")
end)

test("Find again: a missing plugin on a track with the same name", function()
  local g = make_group("exact")
  r.GetSetMediaTrackInfo_String(tr[3], "P_NAME", "Gtr DI", true)
  local m = member(g, 2)
  m.guid, m.tname = "{gone}", "Gtr DI"
  Fx.resolve(false)
  ok(R.rt[m] == nil, "missing first")
  ok(Fx.find_again(g, m), "found again")
  ok(R.rt[m] ~= nil and R.rt[m].track == tr[3], "on the track Gtr DI")
  m.tname = "No such track"
  m.guid = "{gone2}"; Fx.resolve(false)
  ok(not Fx.find_again(g, m), "no track with that name")
  r.GetSetMediaTrackInfo_String(tr[3], "P_NAME", "", true)
end)

test("Add from folder: the tracks inside a folder", function()
  local g = make_group("exact")
  r.SetMediaTrackInfo_Value(tr[1], "I_FOLDERDEPTH", 1)
  r.SetMediaTrackInfo_Value(tr[3], "I_FOLDERDEPTH", -1)
  local f = Fx.folders()
  eq(#f, 1, "1 folder")
  local list = Fx.folder_tracks(tr[1])
  eq(#list, 2, "2 tracks inside")
  eq(list[2], tr[3], "the last one")
  local added = Fx.add_tracks(g, list)
  eq(added, 1, "track 3 added (track 2 was already in)")
  r.SetMediaTrackInfo_Value(tr[1], "I_FOLDERDEPTH", 0)
  r.SetMediaTrackInfo_Value(tr[3], "I_FOLDERDEPTH", 0)
end)

test("Relative in real units (dB)", function()
  local g = make_group("rel")
  local P1 = 1 -- ReaEQ: band 1 gain (shown in dB)
  ok(Link.unit_value(tr[1], 0, P1, 0.5) ~= nil, "ReaEQ shows dB")
  set(1, P1, Link.find_unit(tr[1], 0, P1, -6)); set(2, P1, Link.find_unit(tr[2], 0, P1, 0))
  Fx.resolve(true)
  set(1, P1, Link.find_unit(tr[1], 0, P1, -3))
  Link.sync(g, member(g, 1))
  local db = Link.unit_value(tr[2], 0, P1, get(2, P1))
  ok(math.abs(db - 3) < 0.2, "+3 dB on track 2 too (got " .. tostring(db) .. ")")
end)

test("out of sync: the differing plugin is found", function()
  local Util = C.Util
  local g = make_group("exact")
  Fx.resolve(true)
  Link.match(g, member(g, 1)) -- (earlier tests left other knobs different)
  R.last_src[g] = member(g, 1)
  R.sync_t, R.sync_i = 0, 0
  Link.check_sync()
  eq(R.differ[g], nil, "equal: no badge")
  set(2, 0, 0.7)
  R.act[g] = nil
  R.sync_t, R.sync_i = 0, 0
  Link.check_sync()
  eq(R.differ[g], nil, "1st check: not yet (could be a short difference)")
  R.sync_t, R.sync_i = 0, 0
  Link.check_sync()
  ok(R.differ[g] and R.differ[g].n == 1, "2nd check: 1 differs")
  R.act[g] = Util.now()
  R.sync_t, R.sync_i = 0, 0
  Link.check_sync()
  ok(R.differ[g] ~= nil, "busy: the old result stays, no new check")
end)

test("snapshots: store, recall, saved", function()
  local g = make_group("exact")
  set(1, 0, 0.2); set(2, 0, 0.4)
  Fx.resolve(true)
  Link.snap_store(g, "A")
  set(1, 0, 0.9); set(2, 0, 0.9)
  Link.snap_recall(g, "A")
  near(get(1, 0), 0.2, "track 1 back"); near(get(2, 0), 0.4, "track 2 back")
  local q = Project.parse(Project.serialize())
  local sn = q.groups[1].snap.A
  ok(sn and sn.vals[member(g, 1).guid], "snapshot saved")
  near(sn.vals[member(g, 2).guid][0], 0.4, "its value")
  local old = member(g, 1).guid
  local idx2 = r.TrackFX_AddByName(tr[1], "ReaEQ", false, -1)
  ok(Fx.replace(g, member(g, 1), r.TrackFX_GetFXGUID(tr[1], idx2)), "another copy")
  ok(g.snap.A.vals[member(g, 1).guid] and not g.snap.A.vals[old], "the snapshot moved to the new copy")
  r.TrackFX_Delete(tr[1], idx2)
  eq(q.groups[1].snap.B, nil, "B empty")
end)

test("check again after a copy: a knob that the plugin reset is set again", function()
  local g = make_group("exact")
  Fx.resolve(true)
  Link.match(g, member(g, 1))
  R.verify[g] = nil
  set(1, 0, 0.25)
  Link.sync(g, member(g, 1))
  near(get(2, 0), 0.25, "copied")
  set(2, 0, 0.9) -- (as if the plugin reset it after the copy)
  R.verify[g].t = 0
  Link.verify_tick()
  near(get(2, 0), 0.25, "set again")
  ok(not (R.noset[g] and R.noset[g][0]), "not marked as a knob that does not follow")
end)

for _, t in ipairs(tests) do
  local good, e = pcall(t[2])
  if good then passed = passed + 1; log("ok    " .. t[1])
  else failed = failed + 1; log("FAIL  " .. t[1] .. ": " .. tostring(e)) end
end
finish()
