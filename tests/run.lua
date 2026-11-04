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

test("page-turn countdown: seconds to the next page turn", function()
  local _, R = setup_view()
  at_play(5, function() C.Nav.timeline_tick(true, false, PAGES, {}) end)
  ok(R.turn_in and math.abs(R.turn_in - 3) < 0.01, "3 s before the turn at 8 s")
  C.Nav.timeline_tick(false, false, PAGES, {})
  eq(R.turn_in, nil, "stopped: no countdown")
end)

test("page-turn countdown: runs to the song end when the next song follows", function()
  local S, R = setup_view()
  local keep = R.regions
  local a, b = { key = "a", start = 0, stop = 30 }, { key = "b", start = 30, stop = 60 }
  R.regions, R.active_region = { a, b }, a
  at_play(28, function() C.Nav.timeline_tick(true, false, {}, {}) end)
  ok(R.turn_in and math.abs(R.turn_in - 2) < 0.01, "2 s before the next song")
  R.regions = { a }
  at_play(28, function() C.Nav.timeline_tick(true, false, {}, {}) end)
  eq(R.turn_in, nil, "no song after it: no countdown")
  R.regions, R.active_region = keep, nil
  ok(S, "S")
end)

test("notes: saved and read back; an old project has no note lines", function()
  local P = C.get_P()
  ok(not Project.serialize_cfg():find("\nnote=", 1, true), "no notes: no note lines")
  local f = "C:\\Charts\\Song N.pdf"
  P.notes[f] = { { page = 2, x = 0.25, y = 0.5, text = "repeat x2, then coda", color = "blue", size = "large" } }
  local p2 = Project.parse_cfg((Project.serialize_cfg() .. "\n"):gmatch("([^\n]*)\n"))
  P.notes[f] = nil
  local n = p2.notes[f] and p2.notes[f][1]
  ok(n, "the note is read back")
  eq(n.page, 2); eq(n.x, 0.25); eq(n.y, 0.5); eq(n.text, "repeat x2, then coda")
  eq(n.color, "blue"); eq(n.size, "large")
  -- a line without colour and size (the first format) gets the defaults of new notes
  local p3 = Project.parse_cfg(("note=" .. f .. "\t1\t0.1\t0.2\tcoda\n"):gmatch("([^\n]*)\n"))
  local n3 = p3.notes[f] and p3.notes[f][1]
  ok(n3 and n3.text == "coda" and n3.color == C.S.note_color and n3.size == C.S.note_size, "old line: defaults")
end)

test("setlist: saved and read back in its order; no lines without a setlist", function()
  local P = C.get_P()
  ok(not Project.serialize_cfg():find("\nsetlist=", 1, true), "no setlist: no setlist lines")
  P.setlists = { { name = "Friday", items = {
    { key = "gB", name = "Song B", ending = "continue", skip = false },
    { key = "gA", name = "Song A", ending = "stop", skip = true },
    { key = "gB", name = "Song B", ending = "stop", skip = false } } } }
  P.setlist_on = true
  local p2 = Project.parse_cfg((Project.serialize_cfg() .. "\n"):gmatch("([^\n]*)\n"))
  P.setlists, P.setlist_on = {}, false
  local l = p2.setlists[1]
  ok(l and l.name == "Friday", "the name")
  eq(#l.items, 3, "3 rows (one region twice)")
  eq(l.items[1].key, "gB"); eq(l.items[1].ending, "continue")
  eq(l.items[2].skip, true, "skipped"); eq(l.items[3].key, "gB")
  eq(p2.setlist_on, true)
end)

test("setlist: stop or continue at the end of a song; a skipped song is passed", function()
  local R, P, Setlist = C.R, C.get_P(), C.Setlist
  local keep_regs, keep_sl, keep_on = R.regions, P.setlists, P.setlist_on
  local seek, stopped
  local sep, sob = r.SetEditCurPos, r.OnStopButton
  r.SetEditCurPos = function(t) seek = t end
  r.OnStopButton = function() stopped = true end
  R.regions = { { key = "a", name = "A", start = 0, stop = 10 }, { key = "b", name = "B", start = 20, stop = 30 },
    { key = "c", name = "C", start = 40, stop = 50 } }
  P.setlists = { { name = "x", items = { { key = "c", ending = "continue" }, { key = "b", skip = true, ending = "stop" },
    { key = "a", ending = "stop" } } } }
  P.setlist_cur, P.setlist_on, R.sl_pos, R.sl_guard = 1, true, nil, nil
  local good, e = pcall(function()
    at_play(45, function() Setlist.tick() end)
    eq(R.sl_pos, 1, "song C found")
    at_play(49.99, function() Setlist.tick() end)
    eq(seek, 0, "Continue: jump to A (B is skipped)")
    eq(R.sl_pos, 3)
    R.sl_guard = nil; seek = nil
    at_play(9.99, function() Setlist.tick() end)
    ok(stopped, "Stop at the end of the last song")
  end)
  r.SetEditCurPos, r.OnStopButton = sep, sob
  R.regions, P.setlists, P.setlist_on, R.sl_pos, R.sl_guard = keep_regs, keep_sl, keep_on, nil, nil
  if not good then error(e, 0) end
end)

test("setlist: a pause stops at the song end; a timed pause plays on; pauses are saved", function()
  local R, P, Setlist = C.R, C.get_P(), C.Setlist
  local keep_regs, keep_sl, keep_on = R.regions, P.setlists, P.setlist_on
  local seek, stopped, played
  local sep, sob, opb, gps = r.SetEditCurPos, r.OnStopButton, r.OnPlayButton, r.GetPlayState
  r.SetEditCurPos = function(t) seek = t end
  r.OnStopButton = function() stopped = true end
  r.OnPlayButton = function() played = true end
  R.regions = { { key = "a", name = "A", start = 0, stop = 10 }, { key = "b", name = "B", start = 20, stop = 30 } }
  P.setlists = { { name = "x", items = { { key = "a", ending = "continue" }, { kind = "pause", sec = 1 },
    { key = "b", ending = "stop" } } } }
  P.setlist_cur, P.setlist_on, R.sl_pos, R.sl_guard, R.sl_hold = 1, true, nil, nil, nil
  local good, e = pcall(function()
    at_play(5, function() Setlist.tick() end)
    at_play(9.99, function() Setlist.tick() end)
    ok(stopped, "the pause after A stops REAPER (A has Continue)")
    eq(seek, 20, "the edit cursor is at B"); eq(R.sl_pos, 3)
    ok(R.sl_hold and R.sl_hold.t_end, "a timed pause runs")
    r.GetPlayState = function() return 0 end
    R.sl_hold.t_end = C.Util.now() - 1
    Setlist.tick()
    ok(played, "after its seconds, the next song plays")
    local p2 = Project.parse_cfg((Project.serialize_cfg() .. "\n"):gmatch("([^\n]*)\n"))
    eq(p2.setlists[1].items[2].kind, "pause"); eq(p2.setlists[1].items[2].sec, 1)
    eq(p2.setlists[1].items[3].key, "b")
  end)
  r.SetEditCurPos, r.OnStopButton, r.OnPlayButton, r.GetPlayState = sep, sob, opb, gps
  R.regions, P.setlists, P.setlist_on, R.sl_pos, R.sl_guard, R.sl_hold = keep_regs, keep_sl, keep_on, nil, nil, nil
  if not good then error(e, 0) end
end)

test("setlist: next song goes from the song at the cursor, not from an old position", function()
  local R, P, Setlist = C.R, C.get_P(), C.Setlist
  local keep_regs, keep_sl, keep_on = R.regions, P.setlists, P.setlist_on
  local seek
  local sep = r.SetEditCurPos
  r.SetEditCurPos = function(t) seek = t end
  R.regions = { { key = "a", start = 0, stop = 10 }, { key = "b", start = 20, stop = 30 }, { key = "c", start = 40, stop = 50 } }
  P.setlists = { { name = "x", items = { { key = "a", ending = "stop" }, { key = "b", ending = "stop" }, { key = "c", ending = "stop" } } } }
  P.setlist_cur, P.setlist_on, R.sl_pos = 1, true, 1 -- an old position: song A
  local good, e = pcall(function()
    at_play(25, function() Setlist.next_song(P.setlists[1]) end) -- the play cursor was moved to B by hand
    eq(seek, 40, "next song after B is C")
  end)
  r.SetEditCurPos = sep
  R.regions, P.setlists, P.setlist_on, R.sl_pos, R.sl_guard = keep_regs, keep_sl, keep_on, nil, nil
  if not good then error(e, 0) end
end)

test("setlist: a copied row keeps a pause; undo takes back the last change", function()
  local R, P, Setlist = C.R, C.get_P(), C.Setlist
  local c = Setlist.copy_item({ kind = "pause", sec = 7, skip = true })
  eq(c.kind, "pause"); eq(c.sec, 7); eq(c.skip, true)
  local keep_lock = P.setlist_lock
  P.setlist_lock = false
  local l = { name = "u", items = { { key = "a", ending = "stop" }, { key = "b", ending = "stop" } } }
  Setlist.save_undo(l)
  table.remove(l.items, 1)
  eq(#l.items, 1, "removed")
  Setlist.undo(l)
  eq(#l.items, 2, "undo brings it back"); eq(l.items[1].key, "a")
  ok(not Setlist.can_undo(l), "nothing more to undo")
  P.setlist_lock, R.sl_undo, R.sl_pos = keep_lock, nil, nil
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

test("panes: a swap in and out restores the global state", function()
  local S, R = setup_view()
  S.page, S.scroll_y, R.total = 2, 123, 3
  local p = C.Pane.new()
  C.Pane.swap(p)
  eq(S.page, 1, "pane 2 starts on page 1"); eq(R.total, 0, "pane 2 has no PDF")
  C.Pane.swap(p)
  eq(S.page, 2); eq(S.scroll_y, 123); eq(R.total, 3)
end)

test("panes: a page turn in pane 2 does not change pane 1", function()
  local S, R = setup_view()
  S.page, R.total = 1, 3
  local p = C.Pane.new()
  p.r.total = 5
  C.Pane.run(p, function() C.Nav.go_page(4) end)
  eq(p.s.page, 4, "pane 2 turned"); eq(S.page, 1, "pane 1 kept its page")
  local ok = pcall(C.Pane.run, p, function() error("x") end)
  eq(ok, false); eq(S.page, 1, "restored after an error"); eq(R.total, 3)
end)

test("2 pages: pairs and page turns (rolling and book)", function()
  local S, R = setup_view()
  R.total = 5; S.page = 1
  local keep = { S.page_layout, S.page_turn }
  S.page_layout, S.page_turn = "side", "rolling"
  local a, b = C.Nav.spread(); eq(a, 1); eq(b, 2)
  C.Nav.step(1); eq(S.page, 2, "rolling: by 1"); a, b = C.Nav.spread(); eq(a, 2); eq(b, 3)
  S.page = 5; a, b = C.Nav.spread(); eq(a, 5); eq(b, nil, "no page after the last")
  S.page_turn = "book"; S.page = 4
  a, b = C.Nav.spread(); eq(a, 3, "book: the pair that contains page 4"); eq(b, 4)
  C.Nav.step(1); eq(S.page, 5, "book: by 2"); C.Nav.step(1); eq(S.page, 5, "no pair after the last")
  C.Nav.step(-1); eq(S.page, 3)
  R.flash_t = 0; C.Nav.go_page(4); eq(S.page, 4); eq(C.Nav.changes_view(5), true, "pair 5 is a new view")
  local was = R.flash_t; S.page = 3; C.Nav.go_page(4); eq(R.flash_t, was, "book: page 4 of pair 3-4 is no page turn")
  S.page = 3
  local w, h = C.Nav.content_dims(100, 140); eq(w, 202, "side: 2 pages + 2% gap"); eq(h, 140)
  S.page_layout = "stack"; w, h = C.Nav.content_dims(100, 140); eq(w, 100, "continuous: one page"); eq(h, 140)
  S.page_layout = "single"; C.Nav.step(1); eq(S.page, 4, "1 page: by 1")
  S.page_layout, S.page_turn = keep[1], keep[2]
end)

test("continuous pages: scrolling goes on across pages; smooth page turn", function()
  local S, R = setup_view()
  local keep = { S.page_layout, S.cont_turn }
  R.total, R.max_y, R.cont_step, R.view_h = 3, 40, 150, 100 -- page 140 px + gap 10, view 100 px
  S.page_layout, S.cont_turn, S.page, S.scroll_y = "stack", "smooth", 1, 0
  C.Nav.scroll_by(160); eq(S.page, 2, "down into page 2"); eq(S.scroll_y, 10)
  C.Nav.scroll_by(-20); eq(S.page, 1, "back up into page 1"); eq(S.scroll_y, 140)
  C.Nav.scroll_by(-500); eq(S.page, 1); eq(S.scroll_y, 0, "stops at the top of page 1")
  S.page = 3; C.Nav.scroll_by(500); eq(S.page, 3); eq(S.scroll_y, 40, "stops at the end of the last page")
  S.page, S.scroll_y = 1, 30; C.Nav.go_page(2)
  eq(S.page, 2); eq(S.scroll_y, 0); eq(R.cont_off, -100, "smooth: from where page 2 was, at most one view")
  S.page, S.scroll_y = 1, 120; C.Nav.update_motion(); eq(S.scroll_y, 120, "the frame clamp lets the scroll into page 2")
  S.cont_turn = "jump"; C.Nav.go_page(3); eq(R.cont_off, nil, "jump: no move")
  S.page_layout, S.cont_turn, S.page, S.scroll_y = "single", "smooth", 1, 0; C.Nav.go_page(2)
  eq(R.cont_off, -100, "1 page: the next page slides in too")
  S.page_layout, S.cont_turn, R.cont_step = keep[1], keep[2], nil
end)

test("part 2: opening a PDF there does not change the project's PDF or part 1", function()
  local S, R = setup_view()
  local P = C.get_P()
  local keep_active, keep_page = P.active_pdf, S.page
  P.active_pdf = "C:\\part1.pdf"; S.page = 2; R.total = 4
  R.part2 = C.Pane.new()
  C.Pane.part2(C.PDF.finish_open, tmp .. "\\part2.pdf", false, 7, "Page size: 595 x 842")
  eq(P.active_pdf, "C:\\part1.pdf", "the project keeps its PDF")
  eq(S.page, 2, "part 1 keeps its page"); eq(R.total, 4, "part 1 keeps its page count")
  eq(R.part2.r.total, 7, "part 2 has its own page count"); eq(R.in_part2, false)
  R.active_part = 2
  C.Pane.active(function() C.Nav.go_page(5) end)
  eq(R.part2.s.page, 5, "the active part turned"); eq(S.page, 2)
  R.part2, R.active_part = nil, 1
  P.active_pdf, S.page = keep_active, keep_page
end)

test("PDF 2: 2 matching PDFs become PDF 1 + PDF 2; choices are saved", function()
  local _, R = setup_view()
  local P = C.get_P()
  local keep = { P.pdfs, P.assign, P.assign2, P.no2, P.pair_off, R.regions }
  local lyr, bass, gtr = "C:\\x\\Song A lyrics.pdf", "C:\\x\\Song A bass.pdf", "C:\\x\\Song A guitar.pdf"
  P.pdfs, P.assign, P.assign2, P.no2, P.pair_off = { lyr, bass }, {}, {}, {}, false
  local reg = { key = "k1", name = "Song A", norm = C.Util.norm_name("Song A"), match = C.Util.match_name("Song A") }
  R.regions = { reg }
  C.Project.resolve_regions()
  eq(reg.status, "auto"); eq(reg.pdf, bass, "PDF 1: first by name"); eq(reg.pdf2, lyr)
  P.assign.k1 = lyr; C.Project.resolve_regions()
  eq(reg.pdf, lyr, "PDF 1 chosen"); eq(reg.pdf2, bass, "the other match is PDF 2")
  C.Project.set_pdf2(reg, nil); eq(reg.pdf2, nil, "x removes PDF 2"); eq(P.no2.k1, true)
  C.Project.set_pdf2(reg, bass); eq(reg.pdf2, bass, "chosen by hand"); eq(P.no2.k1, nil)
  P.pdfs[3] = gtr; P.assign, P.assign2, P.no2 = {}, {}, {}; C.Project.resolve_regions()
  eq(reg.status, "ambiguous", "3 matches: choose"); eq(reg.pdf2, nil)
  P.pdfs, P.assign, P.assign2, P.no2 = { "C:\\x\\Song A.pdf", lyr }, {}, {}, {}; C.Project.resolve_regions()
  eq(reg.status, "auto"); eq(reg.pdf, "C:\\x\\Song A.pdf", "the exact name is the main chart"); eq(reg.pdf2, nil, "no automatic pair with it")
  P.pdfs = { lyr, bass }; P.pair_off = true; C.Project.resolve_regions()
  eq(reg.status, "ambiguous", "pairs off: 2 matches are a choice again")
  -- saved and read back
  P.pair_off, P.assign, P.assign2, P.no2, P.names = true, { k1 = lyr }, { k1 = bass }, { k2 = true }, { k1 = "Song A", k2 = "B" }
  local txt = C.Project.serialize_cfg()
  local p2 = C.Project.parse_cfg((txt .. "\n"):gmatch("([^\n]*)\n"))
  eq(p2.pair_off, true); eq(p2.assign2.k1, bass); eq(p2.no2.k2, true)
  P.pdfs, P.assign, P.assign2, P.no2, P.pair_off, R.regions = keep[1], keep[2], keep[3], keep[4], keep[5], keep[6]
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
  C.Cues.redo(); eq(#P.cues["_project"], 3, "redo brings back the first change")
  C.Cues.redo(); eq(#P.cues["_project"], 4); eq(C.Cues.can_redo(), false)
  C.Cues.undo(); C.Cues.add_below(nil, P.cues["_project"], 1); eq(C.Cues.can_redo(), false, "a new change ends redo")
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

test("PDF 2 cues: their own list; used for part 2, the Cues tab and unit switches", function()
  local _, R, P = setup_cues()
  local reg = { key = "rk", name = "Song", start = 0, stop = 100 }
  local keep = R.regions
  R.regions = { reg }
  P.cues = { rk = { { pos = 0, page = 1, scroll = 0 } }, ["rk#2"] = { { pos = 8, page = 3, scroll = 0 } } }
  eq(C.Cues.key(reg), "rk", "part 1")
  R.part2 = C.Pane.new(); R.part2.r.total = 5
  eq(C.Pane.part2(C.Cues.key, reg), "rk#2", "part 2 runs: its own list")
  local pp = C.Pane.part2(function() return (C.Cues.points(reg)) end)
  eq(#pp, 1); eq(pp[1].page, 3, "part 2 page turns come from its list")
  R.cue_part_ctx = 2; eq(#C.Cues.list(reg), 1); eq(C.Cues.list(reg)[1].page, 3, "the Cues tab shows PDF 2")
  R.cue_part_ctx = 1; eq(C.Pane.part2(C.Cues.key, reg), "rk", "the Cues tab choice wins")
  R.cue_part_ctx = nil
  C.Cues.set_unit("seconds"); eq(P.cues["rk#2"][1].pos, 4, "the PDF 2 list is converted too")
  C.Cues.set_unit("beats"); eq(P.cues["rk#2"][1].pos, 8)
  R.part2, R.regions = nil, keep
end)

test("library: unused PDFs; the folders of 'Add from folder' are saved", function()
  local S, R = setup_view()
  local P = C.get_P()
  local keep = { P.pdfs, R.regions, S.pdf_path, P.folders }
  local a, b, c = "C:\\x\\Song A.pdf", "C:\\x\\Song B.pdf", "C:\\x\\Extra.pdf"
  P.pdfs = { a, b, c }; S.pdf_path = c
  R.regions = { { key = "k", pdf = a, pdf2 = nil } }
  local un = C.Project.unused_pdfs()
  eq(un[a], nil, "used by a region"); eq(un[c], nil, "on screen"); eq(un[b], true, "unused")
  R.regions[1].pdf2 = b; C.Util.bump_lib(); un = C.Project.unused_pdfs()
  eq(un[b], nil, "used as PDF 2")
  P.folders = { { path = "C:\\charts", sub = true } }
  local txt = C.Project.serialize_cfg()
  local p2 = C.Project.parse_cfg((txt .. "\n"):gmatch("([^\n]*)\n"))
  eq(#p2.folders, 1); eq(p2.folders[1].path, "C:\\charts"); eq(p2.folders[1].sub, true)
  P.pdfs, R.regions, S.pdf_path, P.folders = keep[1], keep[2], keep[3], keep[4]
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

test("cache limit: the PDFs used longest ago go first; the PDF on screen stays", function()
  local R, S, PDF = C.R, C.S, C.PDF
  local root = C.CFG.CACHE_ROOT
  local old, mid, new, cur = root .. "\\t_old", root .. "\\t_mid", root .. "\\t_new", root .. "\\t_cur"
  local times = { [old] = 100, [mid] = 200, [new] = 300, [cur] = 50 }
  local keep_rm, keep_used, keep_lim, keep_dir, keep_job = PDF.rmdir_all, PDF.last_used, S.cache_limit_mb, R.cache_dir, R.job
  local removed
  PDF.rmdir_all = function(f) removed = f end
  PDF.last_used = function(d) return times[d] end
  S.cache_limit_mb, R.cache_dir, R.job = 1, cur .. "\\dpi150_win", nil
  local MB = 1048576
  PDF.limit_cache({ [old] = 0.5 * MB, [mid] = 0.5 * MB, [new] = 0.5 * MB, [cur] = 0.5 * MB }, 2 * MB)
  PDF.rmdir_all, PDF.last_used, S.cache_limit_mb, R.cache_dir, R.job = keep_rm, keep_used, keep_lim, keep_dir, keep_job
  ok(removed ~= nil, "something removed")
  eq(#removed, 3, "3 folders: 2 MB down to 0.9 MB or less")
  eq(removed[1], old, "the oldest first")
  eq(removed[2], mid, "then the next oldest")
  eq(removed[3], new, "the PDF on screen is not removed, although it is older")
  R.cache_size = nil
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
