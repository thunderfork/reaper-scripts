-- @noindex
-- Chart Cue tests. Run with .\tools\test.ps1 (it starts the portable test REAPER in C:\REAPERtest).
-- Loads Chart Cue.lua without its window, runs each test, writes tests\result.txt, quits REAPER.
local r = reaper
local here = ({ r.get_action_context() })[2]:match("^(.*)[/\\]")
local out = {}
local passed, failed = 0, 0
local function log(s) out[#out + 1] = s end

-- test helpers
local function eq(a, b, what)
  if a ~= b then error((what or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end
local function ok(v, what) if not v then error((what or "check") .. " failed", 2) end end

local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end

-- a saved, empty test project, so REAPER can quit without a save prompt
local tmp = r.GetResourcePath() .. "\\ChartCueTests"
r.RecursiveCreateDirectory(tmp, 0)
local proj_file = tmp .. "\\test.rpp"
local pf = io.open(proj_file, "w")
if pf then pf:write("<REAPER_PROJECT 0.1\n>\n"); pf:close() end
r.Main_openProject("noprompt:" .. proj_file)

local function finish()
  log(string.format("%d passed, %d failed", passed, failed))
  local f = io.open(here .. "\\result.txt", "w")
  if f then f:write(table.concat(out, "\n"), "\n"); f:close() end
  r.Main_SaveProject(0, false)
  r.defer(function() r.Main_OnCommand(40004, 0) end) -- File: Quit REAPER
end

-- load Chart Cue in test mode
ChartCueTest = {}
local loaded, err = pcall(dofile, here .. "\\..\\Chart Cue\\Chart Cue.lua")
local C = ChartCueTest
if not loaded or not C.Project then
  log("FAIL  load Chart Cue.lua: " .. tostring(err))
  failed = 1
  finish()
  return
end
local Util, Project, CFG = C.Util, C.Project, C.CFG
-- proof that the tests ran inside the test REAPER, with Chart Cue loaded
log(string.format("REAPER %s in %s, Chart Cue %s loaded", r.GetAppVersion(), r.GetResourcePath(), CFG.VERSION))

---------------------------------------------------------------------------
-- TESTS
---------------------------------------------------------------------------
test("version is set", function()
  ok(CFG.VERSION and CFG.VERSION ~= "", "CFG.VERSION")
end)

test("PDF name matching", function()
  eq(Util.match_name("songA"), "song a")
  eq(Util.match_name("01 Song A (Bb).pdf"), "song a")
  eq(Util.match_name("Song_A - Bass v2.pdf"), "song a")
  eq(Util.match_name("Bass.pdf"), "bass", "a song named Bass")
end)

test("paths", function()
  ok(Util.same_path("C:/A/b.pdf", "c:\\a\\B.PDF"), "same_path")
  eq(Util.rel_path("C:\\Proj\\PDFs\\a.pdf", "C:\\Proj"), "PDFs/a.pdf")
  eq(Util.rel_path("D:\\Other\\a.pdf", "C:\\Proj"), nil)
end)

test("region keys", function()
  eq(Project.region_key("{AB-12}", "x", 0), "gAB-12")
  eq(Project.region_key("", "Song A", 12.345), "nsong_a@12.35")
end)

-- saved project data must stay the same (Chart Cue compares the text to detect "Save as")
test("new project: no optional keys", function()
  local P = C.get_P()
  local txt = Project.serialize_cfg()
  for _, k in ipairs({ "scroll_mode", "hint_off", "turn_early", "fixed_start" }) do
    ok(not txt:find("\n" .. k .. "=", 1, true), "key " .. k .. " not written")
  end
  ok(txt:find("^version=1\n"), "starts with version=1")
  ok(P, "P")
end)

test("project data: save and read back", function()
  local P = C.get_P()
  local keep = Project.serialize_cfg()
  P.scroll_mode, P.turn_early, P.fixed_start, P.hint_off = "cues", 2, 12.5, true
  P.pdfs[#P.pdfs + 1] = "C:\\Charts\\Song A.pdf"
  P.assign["gX"] = "C:\\Charts\\Song A.pdf"
  P.names["gX"] = "Song A"
  P.cues["gX"] = { { pos = 4, page = 2, scroll = 10 } }
  local txt = Project.serialize_cfg()
  local p2 = Project.parse_cfg((txt .. "\n"):gmatch("([^\n]*)\n"))
  eq(p2.scroll_mode, "cues"); eq(p2.turn_early, 2); eq(p2.fixed_start, 12.5); eq(p2.hint_off, true)
  eq(p2.assign["gX"], "C:\\Charts\\Song A.pdf"); eq(p2.names["gX"], "Song A")
  eq(p2.cues["gX"][1].page, 2)
  -- through the real project (ExtState in the .rpp)
  C.R.proj = r.EnumProjects(-1)
  ok(Project.save_project_cfg(), "save_project_cfg")
  local p3, src = Project.load_project_cfg(C.R.proj)
  eq(src, "rpp"); eq(p3.fixed_start, 12.5)
  -- the same data gives the same text
  for k, v in pairs(p2) do P[k] = v end
  eq(Project.serialize_cfg(), txt, "text after read back")
  -- restore the defaults
  local d = Project.parse_cfg((keep .. "\n"):gmatch("([^\n]*)\n"))
  for k, v in pairs(d) do P[k] = v end
end)

-- Pretend that REAPER plays at time `pos` (seconds) while fn runs.
-- Chart Cue uses the same reaper table, so it sees these replacements.
local function at_play(pos, fn)
  local gps, gst = r.GetPlayPosition, r.GetPlayState
  r.GetPlayPosition = function() return pos end
  r.GetPlayState = function() return 1 end
  local good, e = pcall(fn)
  r.GetPlayPosition, r.GetPlayState = gps, gst
  if not good then error(e, 0) end
end

-- a 5-page PDF on screen, page 1 at the top, no region, no turn early
local function setup_view()
  local S, R, P = C.S, C.R, C.get_P()
  R.total, R.max_y, R.max_x = 5, 1000, 0
  S.page, S.scroll_y, S.scroll_x = 1, 0, 0
  R.active_region, R.empty_region, R.kept_key, R.mpage_last = nil, nil, nil, nil
  P.turn_early = 0
  return S, R, P
end

local PAGES = { { t = 8, page = 2 }, { t = 20, page = 3 } }

test("page turns at their time", function()
  local S, R = setup_view()
  at_play(5, function() C.Nav.timeline_tick(true, false, PAGES, {}) end)
  eq(S.page, 1, "before the first turn")
  at_play(10, function() C.Nav.timeline_tick(true, false, PAGES, {}) end)
  eq(S.page, 2, "after 8 s")
  at_play(25, function() C.Nav.timeline_tick(true, false, PAGES, {}) end)
  eq(S.page, 3, "after 20 s")
  ok(R.autoscroll_active, "autoscroll active")
end)

test("turn pages early (2 beats at 120 bpm = 1 s)", function()
  local S, _, P = setup_view()
  P.turn_early = 2
  at_play(7.2, function() C.Nav.timeline_tick(true, false, PAGES, {}) end)
  eq(S.page, 2, "turned 1 s early")
  P.turn_early = 0
end)

test("scroll between scroll points", function()
  local S = setup_view()
  local sp = { { t = 8, pct = 0 }, { t = 12, pct = 100 } }
  at_play(10, function() C.Nav.timeline_tick(true, false, PAGES, sp) end)
  eq(S.scroll_y, 500, "halfway")
  S.scroll_y = 123
  at_play(11, function() C.Nav.timeline_tick(true, true, PAGES, sp) end)
  eq(S.scroll_y, 123, "a manual scroll is not overwritten")
end)

test("scroll: jump at each scroll point", function()
  local S = setup_view()
  local P = C.get_P()
  local sp = { { t = 8, pct = 20 }, { t = 12, pct = 100 } }
  P.scroll_jump = true
  at_play(10, function() C.Nav.timeline_tick(true, false, PAGES, sp) end)
  P.scroll_jump = false
  eq(S.scroll_y, 200, "stays at 20 % until the next point")
end)

test("page turns stay inside the region", function()
  local S, R = setup_view()
  R.active_region = { start = 30, stop = 40, key = "r1" }
  S.page = 3
  at_play(45, function() C.Nav.timeline_tick(true, false, PAGES, {}) end)
  eq(S.page, 3, "after the region end: no change")
  at_play(31, function() C.Nav.timeline_tick(true, false, PAGES, {}) end)
  eq(S.page, 1, "region without turns: page 1")
  R.active_region = nil
end)

test("go to page: limits and blocked regions", function()
  local S, R = setup_view()
  C.Nav.go_page(99); eq(S.page, 5, "last page")
  C.Nav.go_page(-3); eq(S.page, 1, "first page")
  R.empty_region = { key = "e" }
  C.Nav.go_page(4); eq(S.page, 1, "region without PDF blocks turns")
  R.kept_key = "e"
  C.Nav.go_page(4); eq(S.page, 4, "kept last page allows turns")
  R.empty_region, R.kept_key = nil, nil
end)

test("autoscroll mode: project, default and old values", function()
  local S, P = C.S, C.get_P()
  local keep_s, keep_p = S.scroll_mode, P.scroll_mode
  P.scroll_mode, S.scroll_mode = "", "cues"; eq(C.Nav.scroll_mode(), "cues", "default for new projects")
  P.scroll_mode = "marker"; eq(C.Nav.scroll_mode(), "marker", "project value")
  P.scroll_mode = "fixed"; eq(C.Nav.scroll_mode(), "off", "old Fixed speed")
  S.scroll_mode, P.scroll_mode = keep_s, keep_p
end)

test("MIDI relative encodings", function()
  local S = C.S
  local keep_e, keep_i = S.rel_encoding, S.rel_invert
  S.rel_invert = false
  S.rel_encoding = 1; eq(C.Midi.decode_relative(3), 3); eq(C.Midi.decode_relative(125), -3)
  S.rel_encoding = 2; eq(C.Midi.decode_relative(67), 3); eq(C.Midi.decode_relative(61), -3)
  S.rel_encoding = 3; eq(C.Midi.decode_relative(3), 3); eq(C.Midi.decode_relative(67), -3)
  S.rel_encoding = 0; eq(C.Midi.decode_relative(90), 1); eq(C.Midi.decode_relative(10), -1)
  S.rel_invert = true; eq(C.Midi.decode_relative(90), -1, "inverted")
  S.rel_encoding, S.rel_invert = keep_e, keep_i
end)

test("region at a time: the inner region wins", function()
  local R = C.R
  local keep = R.regions
  R.regions = { { start = 0, stop = 100, key = "outer" }, { start = 10, stop = 20, key = "inner" } }
  eq(C.Project.region_at(15).key, "inner")
  eq(C.Project.region_at(50).key, "outer")
  eq(C.Project.region_at(100), nil, "the end is outside")
  R.regions = keep
end)

-- cue list ------------------------------------------------------------------
-- a 5-page PDF, no regions, an empty cue list in beats
local function setup_cues()
  local S, R, P = setup_view()
  S.pdf_path = "C:\\Charts\\Test.pdf"
  R.regions, R.cue_cache = {}, nil
  P.cues, P.cue_unit = {}, "beats"
  return S, R, P
end

test("cues: only page changes become page turns", function()
  local _, _, P = setup_cues()
  P.cues["_project"] = { { pos = 0, page = 1, scroll = 0 }, { pos = 4, page = 1, scroll = 50 },
    { pos = 8, page = 2, scroll = 0 } }
  local pp, sp = C.Cues.points(nil)
  eq(#pp, 2, "page points"); eq(pp[2].page, 2); eq(pp[2].t, 4, "8 beats at 120 bpm = 4 s")
  eq(#sp, 3, "scroll points"); eq(sp[2].pct, 50)
end)

test("cues: a cue at the same position is replaced", function()
  local _, _, P = setup_cues()
  C.Cues.put(nil, 4, 2, 0)
  C.Cues.put(nil, 4.0001, 3, nil)
  C.Cues.put(nil, 2, 2, 0)
  local list = P.cues["_project"]
  eq(#list, 2, "cues"); eq(list[1].pos, 2, "sorted"); eq(list[2].page, 3, "replaced")
end)

test("cues: add page turn (C) renumbers later turns", function()
  local _, _, P = setup_cues()
  P.cues["_project"] = { { pos = 8, page = 2, scroll = 0 }, { pos = 16, page = 3, scroll = 0 } }
  at_play(2, function() C.Cues.add_page_turn() end) -- 2 s = beat 4
  local list = P.cues["_project"]
  eq(#list, 3, "cues"); eq(list[1].pos, 4); eq(list[1].page, 2, "new turn")
  eq(list[2].page, 3, "renumbered"); eq(list[3].page, 4, "renumbered")
end)

test("cues: no page turn past the last page", function()
  local _, _, P = setup_cues()
  P.cues["_project"] = { { pos = 4, page = 5, scroll = 0 } }
  at_play(4, function() C.Cues.add_page_turn() end)
  eq(#P.cues["_project"], 1, "no cue added")
end)

test("cues: add scroll point (S) keeps the page", function()
  local S, _, P = setup_cues()
  P.cues["_project"] = { { pos = 0, page = 3, scroll = 0 } }
  S.scroll_y = 250
  at_play(1, function() C.Cues.add_scroll_point() end)
  local c = P.cues["_project"][2]
  eq(c.page, 3); eq(c.scroll, 25, "25 %"); eq(c.pos, 2, "beat 2")
end)

test("cues: + below adds a scroll point halfway, undo takes it back", function()
  local S, R, P = setup_cues()
  R.cue_undo = nil -- the steps of the tests before
  P.cues["_project"] = { { pos = 0, page = 3, scroll = 0 }, { pos = 8, page = 4, scroll = 0 } }
  S.page, S.scroll_y = 3, 250
  local list = P.cues["_project"]
  C.Cues.add_below(nil, list, 1)
  eq(#list, 3); eq(list[2].pos, 4, "halfway"); eq(list[2].page, 3); eq(list[2].scroll, 25, "from the view")
  C.Cues.add_below(nil, P.cues["_project"], 3)
  eq(P.cues["_project"][4].pos, 12, "1 bar after the last cue")
  C.Cues.undo(); eq(#P.cues["_project"], 3)
  C.Cues.undo(); eq(#P.cues["_project"], 2)
  eq(C.Cues.can_undo(), false)
end)

test("cues: + on the Start row", function()
  local S, _, P = setup_cues()
  P.cues["_project"] = { { pos = 8, page = 2, scroll = 0 } }
  S.page, S.scroll_y = 1, 300
  C.Cues.add_below(nil, P.cues["_project"], 0)
  local c = P.cues["_project"][1]
  eq(c.pos, 4, "halfway to the first cue"); eq(c.page, 1); eq(c.scroll, 30)
end)

test("cues: use current view", function()
  local S, _, P = setup_cues()
  P.cues["_project"] = { { pos = 0, page = 1, scroll = 0 } }
  S.page, S.scroll_y = 2, 500
  C.Cues.use_view(P.cues["_project"][1])
  eq(P.cues["_project"][1].page, 2); eq(P.cues["_project"][1].scroll, 50)
end)

test("cues: beats <-> seconds keeps the time", function()
  local _, _, P = setup_cues()
  P.cues["_project"] = { { pos = 8, page = 2 } }
  C.Cues.set_unit("seconds"); eq(P.cue_unit, "seconds"); eq(P.cues["_project"][1].pos, 4)
  C.Cues.set_unit("beats"); eq(P.cues["_project"][1].pos, 8)
end)

-- page cache --------------------------------------------------------------------
test("cache folder: one per file and sharpness", function()
  local S = C.S
  local f = tmp .. "\\cache_test.pdf"
  local h = io.open(f, "wb"); if h then h:write("%PDF-1.4 test"); h:close() end
  local keep = S.dpi
  S.dpi = 150; local a = C.PDF.compute_cache_dir(f)
  eq(C.PDF.compute_cache_dir(f), a, "the same folder again")
  S.dpi = 300; local b = C.PDF.compute_cache_dir(f)
  ok(a ~= b, "other sharpness: other folder")
  ok(a:find(C.CFG.CACHE_ROOT, 1, true) == 1, "inside the cache folder")
  S.dpi = keep
end)

-- project switch ("Save as" keeps the data, another project does not get it) -----
test("project: Save as keeps the Chart Cue data", function()
  local R = C.R
  C.S.close_with_project = false
  C.Project.check_project(true)
  local P = C.get_P()
  P.turn_early = 3; C.Project.save_project_cfg()
  r.Main_SaveProjectEx(0, tmp .. "\\saved_as.rpp", 0)
  C.Project.check_project(false)
  eq(C.get_P().turn_early, 3, "data kept")
  ok(not R.quit, "Chart Cue stays open")
  local _, fn = r.EnumProjects(-1)
  eq(R.projfn, fn, "new file name")
end)

test("project: another project does not get the data", function()
  local R = C.R
  local other = tmp .. "\\other.rpp"
  local h = io.open(other, "w"); if h then h:write("<REAPER_PROJECT 0.1\n>\n"); h:close() end
  r.Main_openProject("noprompt:" .. other)
  C.Project.check_project(false)
  eq(C.get_P().turn_early, 0, "default data")
  local n = r.GetProjExtState(0, C.CFG.PEXT, C.CFG.PEXT_KEY)
  eq(n, 0, "nothing written into the other project")
  -- with "close with project" on, Chart Cue closes instead
  C.S.close_with_project = true
  r.Main_openProject("noprompt:" .. tmp .. "\\saved_as.rpp")
  C.Project.check_project(false)
  ok(R.quit, "Chart Cue closes")
  R.quit = false
end)

---------------------------------------------------------------------------
for _, t in ipairs(tests) do
  local good, e = pcall(t[2])
  if good then passed = passed + 1; log("ok    " .. t[1])
  else failed = failed + 1; log("FAIL  " .. t[1] .. ": " .. tostring(e)) end
end
finish()
