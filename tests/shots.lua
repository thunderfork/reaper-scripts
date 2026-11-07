-- @noindex
-- Chart Cue screenshots. Run with .\tools\shots.ps1 (it starts the portable test REAPER in C:\REAPERtest).
-- Starts Chart Cue normally, shows one scene after the other and asks shots.ps1 for a screenshot:
-- writes tests\shots\req.txt (scene name), waits until shots.ps1 deletes it, then the next scene.
local r = reaper
local here = ({ r.get_action_context() })[2]:match("^(.*)[/\\]")
local dir = here .. "\\shots"
r.RecursiveCreateDirectory(dir, 0)
local req = dir .. "\\req.txt"

-- a test project with 3 regions: 2 match a PDF by name, 1 has no PDF
local tmp = r.GetResourcePath() .. "\\ChartCueTests"
r.RecursiveCreateDirectory(tmp, 0)
local proj_file = tmp .. "\\shots.rpp"
local pf = io.open(proj_file, "w")
if pf then pf:write("<REAPER_PROJECT 0.1\n>\n"); pf:close() end
r.Main_openProject("noprompt:" .. proj_file)
r.AddProjectMarker2(0, true, 0, 30, "Test", -1, 0)
r.AddProjectMarker2(0, true, 30, 60, "Chart", -1, 0)
r.AddProjectMarker2(0, true, 60, 90, "Song C", -1, 0)
r.Main_SaveProject(0, false)

local test_pdf = here .. "\\test.pdf"
local chart_pdf = tmp .. "\\chart.pdf" -- a real chart (optional, never in the repository)
local has_chart = r.file_exists(chart_pdf)

ChartCueTest = {}
dofile(here .. "\\..\\Chart Cue\\Chart Cue.lua")
local C = ChartCueTest
ChartCueTest = nil
C.UI.init() -- the normal start, with the window
C.S.comfortable = os.getenv("CHARTCUE_COMFORT") == "1" -- set by .\tools\shots.ps1 -Comfortable
if os.getenv("CHARTCUE_THEME") == "light" then C.S.theme = "light"; C.apply_theme("light") end -- (shots.ps1 -Light)

local S, R = C.S, C.R
local function settings(open) S.tab = 5; S.settings_open = open end -- (5 sections: Viewer, Playback, Control, Appearance, General)
local scenes = {
  { "01_first_start", function() S.tab = 1 end, 2 },
  { "02_library", function()
      C.Project.add_to_library(test_pdf)
      if has_chart then C.Project.add_to_library(chart_pdf) end
      C.PDF.open_pdf(has_chart and chart_pdf or test_pdf, false)
    end, 8 },
  { "03_regions", function() S.tab = 2 end, 2 },
  { "04_cues", function() S.tab = 3 end, 2 },
  { "04b_cues_recording", function() C.get_P().scroll_mode = "cues"; R.rec = true end, 1.5 },
  { "05_setlist", function()
      local P = C.get_P()
      if #P.setlists == 0 and #R.regions > 0 then P.setlists[1] = C.Setlist.from_timeline("Setlist 1"); P.setlist_cur = 1 end
      S.tab = 4
    end, 1.5 },
  { "06_settings_viewer", function() settings("10000") end, 1.5 },
  { "07_settings_playback", function() settings("01000") end, 1.5 },
  { "08_settings_control", function() settings("00100") end, 1.5 },
  { "09_settings_appearance", function() settings("00010") end, 1.5 },
  { "10_settings_general", function() settings("00001") end, 1.5 },
  { "11_help", function() S.tab = 6 end, 1.5 },
}

local i, t_next, waiting = 0, r.time_precise() + 1, false
local function step()
  if waiting then
    if r.file_exists(req) then r.defer(step); return end -- shots.ps1 not done yet
    waiting = false
    i = i + 1
    if i > #scenes then -- all done: close Chart Cue and REAPER
      R.quit = true
      r.Main_SaveProject(0, false)
      r.defer(function() r.Main_OnCommand(40004, 0) end)
      return
    end
    scenes[i][2](); t_next = r.time_precise() + scenes[i][3]
  elseif i == 0 then
    if r.time_precise() >= t_next then
      i = 1; scenes[1][2](); t_next = r.time_precise() + scenes[1][3]
    end
  elseif r.time_precise() >= t_next then -- the scene had its time: ask for the screenshot
    local f = io.open(req, "w"); if f then f:write(scenes[i][1]); f:close() end
    waiting = true
  end
  r.defer(step)
end
r.defer(step)
