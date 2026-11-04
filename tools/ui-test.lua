-- UI test (run it with tools\ui-test.ps1; it runs in the test REAPER C:\REAPERtest only): opens every tab,
-- Settings section, right-click menu and page area in a few states, and logs all console output (errors)
-- to %TEMP%\chartcue_menutest.txt. Add a step for each new menu, popup, tab, section or view
-- (see .claude/skills/ui-test).
local r = reaper
-- The repository folder: this file is in <repo>\tools.
local repo = debug.getinfo(1, "S").source:sub(2):match("^(.*)[\\/]tools[\\/][^\\/]*$")
local logf = os.getenv("TEMP") .. [[\chartcue_menutest.txt]]
local log = io.open(logf, "w")
local function L(s) if log then log:write(s, "\n"); log:flush() end end
local orig = r.ShowConsoleMsg
r.ShowConsoleMsg = function(s) L("CONSOLE: " .. tostring(s)) end

local tmp = r.GetResourcePath() .. "\\ChartCueTests"
r.RecursiveCreateDirectory(tmp, 0)
local pf = tmp .. "\\menutest.rpp"
local h = io.open(pf, "w"); if h then h:write("<REAPER_PROJECT 0.1\n>\n"); h:close() end
r.Main_openProject("noprompt:" .. pf)
r.AddProjectMarker2(0, true, 0, 30, "Test", -1, 0)
r.AddProjectMarker2(0, false, 2, 0, "PDFPAGE 2", -1, 0)

ChartCueTest = {}
dofile(repo .. "\\Chart Cue\\Chart Cue.lua")
local C = ChartCueTest; ChartCueTest = nil
C.UI.init()
local of = C.UI.frame
C.UI.frame = function() local ok, e = xpcall(of, debug.traceback); if not ok then L('TRACE: ' .. tostring(e)); error(e, 0) end end
local S, R = C.S, C.R
local P = function() return C.get_P() end

local steps = {
  { "open pdf", function() C.Project.add_to_library(repo .. "\\tests\\test.pdf"); C.PDF.open_pdf(repo .. "\\tests\\test.pdf", false) end, 6 },
  { "2 pages side", function() S.page_layout = "side"; S.page_turn = "book"; C.Nav.step(1) end, 3 },
  { "2 pages stack + scroll", function() S.page_layout = "stack"; C.Nav.scroll_by(200) end, 2 },
  { "settings viewer (2 pages)", function() S.panel_open = true; S.tab = 5; S.settings_open = "10000" end, 1 },
  { "side, by 1, smooth turn", function() S.page_layout = "side"; S.page_turn = "rolling"; S.cont_turn = "smooth"; S.page = 1; C.Nav.step(1) end, 1 },
  { "continuous, smooth turn + scroll across", function() C.UI.set_page_layout("stack"); C.Nav.step(1); C.Nav.scroll_by(900) end, 1.5 },
  { "1 page, smooth turn", function() C.UI.set_page_layout("single"); S.page = 1; C.Nav.step(1) end, 1 },
  { "1 page, jump turn", function() S.cont_turn = "jump"; C.Nav.step(-1) end, 1 },
  { "back to 1 page", function() S.page_layout = "single"; S.page_turn = "rolling" end, 1 },
  { "part 2: show (top and bottom)", function() C.UI.show_part2(repo .. "\\tests\\test.pdf") end, 4 },
  { "part 2: side by side + menu", function() S.split_layout = "side"; R.menu_req = { kind = "main" } end, 1.5 },
  { "part 2: active part 1 + page turn", function() R.active_part = 1; C.Nav.step(1) end, 1 },
  { "part 2: active part 2 + page turn + playing", function() R.active_part = 2; C.Pane.active(C.Nav.step, 1); r.OnPlayButton() end, 1.5 },
  { "part 2: stop, close", function() r.OnStopButton(); C.UI.close_part2(); S.split_layout = "stack" end, 1 },
  { "regions tab with PDF 2 row", function() S.panel_open = true; S.tab = 2; R.add2[C.R.regions[1].key] = true end, 1.5 },
  { "settings split view", function() S.tab = 5; S.settings_open = "10000" end, 1 },
  { "library sync row + unused sort", function() S.tab = 1; C.get_P().folders = { { path = repo .. "\\tests", sub = false } }; R.lib_sort = 3 end, 1.5 },
  { "sync folders", function() C.Project.sync_folders() end, 3 },
  { "cues tab with undo icons", function() S.tab = 3 end, 1 },
  { "appearance: dpi change mode", function() S.tab = 5; S.settings_open = "00010"; R.dpi_manual = true end, 1.5 },
  { "main menu", function() R.menu_req = { kind = "main" } end, 1.5 },
  { "main menu again", function() R.menu_req = { kind = "main" } end, 1 },
  { "pdf menu", function() R.menu_req = { kind = "pdf", path = repo .. "\\tests\\test.pdf" } end, 1 },
  { "region menu", function() R.menu_req = { kind = "region", key = C.R.regions[1] and C.R.regions[1].key } end, 1 },
  { "cue tab", function() S.tab = 3; S.panel_open = true; P().scroll_mode = "cues"; P().cues["_project"] = { { pos = 4, page = 2, scroll = 0 } } end, 1 },
  { "cue menu start", function() R.menu_req = { kind = "cue", reg = C.R.regions[1], i = 0, c = { pos = 0, page = 1, scroll = 0 } } end, 1 },
  { "perf + menu", function() R.perf = true; R.menu_req = { kind = "main" } end, 1 },
  { "perf off", function() R.perf = false end, 0.5 },
  { "hide (playing) + menu", function() S.hide_controls_playing = true; r.OnPlayButton(); R.menu_req = { kind = "main" } end, 1.5 },
  { "stop", function() r.OnStopButton() end, 0.5 },
  { "playing, controls shown + menu + hint", function() S.hide_controls_playing = false; S.tab = 3; P().scroll_mode = "marker"; r.OnPlayButton(); R.menu_req = { kind = "main" } end, 1.5 },
  { "stop 2", function() r.OnStopButton() end, 0.5 },
  { "panel closed + menu", function() S.panel_open = false; R.menu_req = { kind = "main" } end, 1 },
  { "settings tab", function() S.panel_open = true; S.tab = 5; S.settings_open = "10000" end, 1 },
  { "settings playback", function() S.tab = 5; S.settings_open = "01000" end, 1 },
  { "settings control", function() S.settings_open = "00100" end, 1.5 },
  { "settings appearance", function() S.settings_open = "00010" end, 1.5 },
  { "settings general", function() S.settings_open = "00001" end, 1 },
  { "hide tabs library + cues", function() S.tab_hide = ",library,cues,"; S.tab = 1 end, 1 },
  { "show tabs again", function() S.tab_hide = "," end, 0.5 },
  { "setlist tab (none yet)", function() S.tab = 4 end, 1 },
  { "make setlist + pause", function() P().setlists = { C.Setlist.from_timeline("UI test") }; P().setlist_cur = 1
      local l = C.Setlist.cur(); l.items[#l.items + 1] = { kind = "pause", sec = 3 }
      l.items[#l.items + 1] = { key = l.items[1].key, name = "again", ending = "continue" } end, 1.5 },
  { "setlist on + lock", function() P().setlist_on = true; P().setlist_lock = true end, 1 },
  { "setlist unlocked + row menu", function() P().setlist_lock = false; R.menu_req = { kind = "setlist", i = 1 } end, 1.5 },
  { "setlist row menu pause", function() R.menu_req = { kind = "setlist", i = 2 } end, 1 },
  { "setlist undo state", function() C.Setlist.save_undo(C.Setlist.cur()) end, 1 },
  { "page area setlist + toolbar", function() S.page_area = "setlist" end, 1.5 },
  { "page area setlist + perf", function() R.perf = true end, 1.5 },
  { "perf off 2", function() R.perf = false end, 0.5 },
  { "page area both + menu", function() S.page_area = "both"; R.menu_req = { kind = "main" } end, 1.5 },
  { "both + playing", function() r.OnPlayButton() end, 2 },
  { "both + paused", function() r.OnPauseButton() end, 1 },
  { "stop 3", function() r.OnStopButton(); S.page_area = "pdf" end, 1 },
  { "note on page + note menu", function() P().notes[S.pdf_path] = { { page = S.page, x = 0.2, y = 0.2, text = "repeat x2", color = "blue", size = "large" } }
      R.menu_req = { kind = "note", note = P().notes[S.pdf_path][1], path = S.pdf_path } end, 1.5 },
  { "brightness + countdown settings", function() S.dim_page, S.dim_level = true, 0.5; S.tab = 5; S.settings_open = "10000" end, 1 },
  { "help tab", function() S.tab = 6 end, 1 },
}
local i, t_next = 0, r.time_precise() + 1.5
local function step()
  if r.time_precise() >= t_next then
    i = i + 1
    if i > #steps then
      L("DONE; R.error = " .. tostring(R.error))
      if log then log:close() end
      R.quit = true
      r.defer(function() r.Main_SaveProject(0, false); r.Main_OnCommand(40004, 0) end)
      return
    end
    L("step: " .. steps[i][1] .. "  (error before: " .. tostring(R.error) .. ")")
    local ok, e = pcall(steps[i][2]); if not ok then L("STEP ERROR: " .. tostring(e)) end
    t_next = r.time_precise() + steps[i][3]
  end
  r.defer(step)
end
r.defer(step)
