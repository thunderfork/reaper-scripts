-- @description Chart Cue: Open PDF Viewer
-- @version 4.8
-- @author Nick Gkogkomitros
-- @license MIT
-- @about
--   Chart Cue - PDF Viewer for REAPER. Shows PDF charts and scrolls them with markers,
--   cue lists, MIDI CC, mouse wheel or dragging. Windows only.
-- @changelog
--   Fixed: the autoscroll mode, the cue time unit and the open PDF are now restored when a project opens.
--   New Cues tab, one Settings tab, list search, Record cues (R) and an option to turn pages early.
--   Removed: Fixed speed mode and "Continue after region end".

-- MIT License
--
-- Copyright (c) 2026 Nick Gkogkomitros
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software
-- and associated documentation files (the "Software"), to deal in the Software without
-- restriction, including without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all copies or
-- substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
-- BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
-- DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

--[[
  Chart Cue: shows PDF charts in a ReaImGui window and scrolls them during playback
  (PDFSCROLL / PDFPAGE markers, cue lists or MIDI CC). One PDF per region.
  Requirements: REAPER 7 or newer on Windows 10 / 11, and ReaImGui 0.9.3 or newer (ReaPack).
  Optional: Poppler (pdftoppm.exe, pdfinfo.exe) as an alternative PDF engine, and the SWS
  extension for the per-project startup action.
  Install: Actions > Show action list > New action... > Load ReaScript... > pick this file.
  Settings are saved in the .rpp (project) and in settings.ini (global).
  See the in-app Help ("?" at the end of the tab strip) for all features.
]]

local r = reaper

---------------------------------------------------------------------------
-- CONFIG (constants; most are also exposed in the UI)
---------------------------------------------------------------------------
local CFG = {}   -- all constants; grouped below (the paths and the rest follow after SEP)
-- Identity
CFG.EXT = "ChartCue"
-- PDF rendering
CFG.BATCH_SIZE = 4              -- pages rendered per pdftoppm call
CFG.MAX_IMAGE_DIM = 4096        -- longest side (px) allowed for a page texture; bigger pages are scaled down
CFG.DEFAULT_DPI = 200
CFG.JOB_TIMEOUT_SEC = 240       -- give up on a render batch after this long
CFG.MAX_CACHED_TEXTURES = 3
CFG.EXEC_NOWAIT = -2            -- ExecProcess timeout value meaning "don't wait"
CFG.PAGE_BG = 0x2B2B2BFF
-- Scrolling, zoom and MIDI
CFG.MIDI_OVERRIDE_SEC = 1.5     -- MIDI/manual scroll overrides playback autoscroll this long
CFG.ABS_SMOOTHING = 0.35        -- 0..1, higher = snappier absolute-mode following
CFG.ZOOM_STEP = 1.15
CFG.MIN_ZOOM = 0.2
CFG.MAX_ZOOM = 8.0
CFG.WHEEL_STEP = 90             -- screen px per mouse-wheel notch
-- Timing
CFG.HEARTBEAT_TIMEOUT = 1.0     -- seconds; single-instance detection
CFG.MARKER_RESCAN_DELAY = 0.25  -- seconds after a project change before markers are rescanned
CFG.DOCK_SETTLE_FRAMES = 30     -- frames to wait before tracking dock changes after startup
CFG.IMPORT_FRAME_BUDGET = 0.004 -- seconds of folder scanning per frame
CFG.MSG_SECONDS = 8             -- how long a message stays in the status bar / its section
CFG.PICKER_TIMEOUT_SEC = 900    -- give up waiting for the folder dialog after this long
-- Window and panel layout
CFG.SCROLLBAR_W = 14
CFG.MIN_VIEW_H = 160            -- the PDF view never gets smaller than this
CFG.PANEL_DEFAULT_FRAC = 0.40   -- default panel height as a fraction of the free height
CFG.PANEL_MIN_H = 70
CFG.SPLIT_H = 12                -- height of the panel resize grip (its hit area; touch friendly)
CFG.TAB_H = 32                  -- tab strip button height
CFG.TAB_GAP = 4                 -- gap between tabs
CFG.TAB_GROUP_GAP = 12          -- gap between the main tabs and the settings tabs
CFG.LABEL_W = 190               -- label column width in panels
CFG.SORT_W = 170                -- width of the dropdown next to a list search field (Library sort, Regions show)
CFG.DEFAULT_WIN = { 100, 100, 760, 900 }

local SEP = package.config:sub(1, 1)
CFG.TITLE = "Chart Cue"   -- keep stable: REAPER uses it to restore docking (ASCII only)
CFG.VERSION = "4.8"       -- keep equal to @version in the header
CFG.AUTHOR = "Nick Gkogkomitros"
CFG.RES = r.GetResourcePath()
CFG.BASE_DIR = CFG.RES .. SEP .. "Scripts" .. SEP .. "Chart Cue"
CFG.CACHE_ROOT = CFG.BASE_DIR .. SEP .. "cache"
CFG.TMP_DIR = CFG.BASE_DIR .. SEP .. "tmp"
CFG.SETTINGS_FILE = CFG.BASE_DIR .. SEP .. "settings.ini"
-- Files and folders
CFG.PS_ENGINE_FILE = CFG.TMP_DIR .. SEP .. "chartcue_pdf.ps1"
CFG.STARTUP_FILE = CFG.RES .. SEP .. "Scripts" .. SEP .. "__startup.lua"
CFG.AUTOSTART_FILE = CFG.BASE_DIR .. SEP .. "autostart.lua"
CFG.GUIDE_FILE = CFG.BASE_DIR .. SEP .. "Chart Cue Guide.html"
CFG.PDF_SUBDIR = "PDFs"
-- Project data (stored in the .rpp)
CFG.PEXT = "ChartCue"   -- project ExtState section (stored in the .rpp)
CFG.PEXT_KEY = "cfg"
-- PDF engine, cache and copying
CFG.KEY_SAMPLE = 65536
CFG.KEY_MEMO_SEC = 2
CFG.INFO_TIMEOUT_SEC = 60
CFG.COPY_CHUNK = 262144          -- bytes per read/write
CFG.COPY_FRAME_BUDGET = 0.004    -- seconds of copying per frame
-- Zoom
CFG.SCREEN_DPI = 96
-- Cue list
CFG.CUE_SAME_POS = 0.02   -- a new cue this close to an existing one replaces it (beats or seconds)
-- Autostart block in __startup.lua
CFG.AS_BEGIN = "-- >>> Chart Cue autostart (added by Chart Cue; remove with the Chart Cue option) >>>"
CFG.AS_END = "-- <<< Chart Cue autostart <<<"
CFG.AS_BLOCK = CFG.AS_BEGIN .. "\n"
  .. 'pcall(dofile, reaper.GetResourcePath() .. "/Scripts/Chart Cue/autostart.lua")\n'
  .. CFG.AS_END .. "\n"
-- Fonts (Segoe UI)
CFG.FONT_SIZE = 14
CFG.FONT_SIZE_BOLD = 15
CFG.TEXT_LIFT = 1            -- px Segoe UI text is raised above true centre, the same in every control (0 = exact centre)
-- Spacing (pixels): { comfortable, compact }. Compact is the default; "Comfortable layout" in the
-- Display tab uses the first value. Only empty space changes; controls keep their size.
CFG.SP = {
  ROW = { 7, 4 },             -- between rows (ImGui item spacing)
  EDGE = { 8, 4 },            -- window edge, top and bottom (= gap below the toolbar)
  TITLE_BEFORE = { 12, 6 },   -- before a section title
  TITLE_AFTER = { 6, 3 },     -- below a section title's underline
  SECTION = { 4, 0 },         -- extra space between sections
  PANEL = { 4, 2 },           -- inside the settings panel, top and bottom
  LIST = { 4, 2 },            -- above a list / between list blocks
  SEARCH = { 12, 8 },         -- below a list's search row (Library, Regions), before the first row
  CLOSED_TABS = { 6, 3 },     -- below the tab strip when the panel is closed
}
-- Layout sizes (pixels)
CFG.ROW_H = 26   -- height of every control (fields, dropdowns, buttons, list rows); see UI.h
CFG.TB_BTN_W = 34          -- width of the < > - + toolbar buttons
CFG.TB_GAP = 8             -- gap between toolbar items
CFG.EXPLORER_BTN_W = 120    -- "Show in Explorer"
CFG.MIN_PATH_W = 80         -- Library: below this width the path is hidden
CFG.REGION_COMBO_W = 220    -- Regions: PDF menu
CFG.DOT_W = 16              -- Regions: status symbol column
CFG.FIT_COMBO_W = 110       -- toolbar: fit menu
CFG.SCROLL_COMBO_W = 160    -- toolbar: autoscroll menu
CFG.HELP_ICON = 20          -- round "?" icon
CFG.SMALL_BTN_W = 80        -- Browse..., Cancel
CFG.MEDIUM_BTN_W = 100      -- Relocate..., Yes, remove
CFG.FLASH_SEC = 0.7         -- page-turn flash duration
CFG.FLASH_W = 6             -- page-turn flash border width
CFG.FORM_MAX_W = 360        -- maximum width of the control column in the settings panels
CFG.FORM_MIN_WIDE = 220     -- below label column + this width, labels go above their control
-- Settings reset
CFG.KEEP_ON_RESET = { pdf_path = true, page = true, scroll_y = true, scroll_x = true, tab = true, panel_open = true }

-- Colours (0xRRGGBBAA), by purpose
local COL = {
  -- state
  RED = 0xF26D6DFF,            -- errors, missing files, removals
  YELLOW = 0xF2C75CFF,         -- warnings, needs attention
  GREEN = 0x6FCF8AFF,          -- OK, has a PDF
  GREY = 0x9AA1B0FF,           -- secondary text, ignored
  -- accent
  ACCENT = 0x3B82F6FF,         -- primary buttons, selected tab bar, toggles, underline, "?" icons
  ACCENT_HOVER = 0x5B9BFFFF,
  ACCENT_ACTIVE = 0x2F6FE0FF,
  ACTIVE_BG = 0x3B82F633,      -- active row background (accent, transparent)
  HEADING = 0x8DB8FFFF,        -- section titles
  -- surfaces (flat dark theme)
  WIN_BG = 0x1A1C21FF,         -- window background
  TAB_BG = 0x15171BFF,         -- tab strip background
  PANEL_BG = 0x23262DFF,       -- settings panel (and the selected tab, so they look connected)
  TAB_HOVER = 0x343944FF,
  FIELD = 0x2B2F38FF, FIELD_HOVER = 0x333844FF, FIELD_ACTIVE = 0x2C3A55FF,   -- inputs, dropdowns
  BTN = 0x30343EFF, BTN_HOVER = 0x3B404CFF, BTN_ACTIVE = 0x464C5AFF,          -- secondary buttons
  LINE = 0x31353FFF,           -- borders, separators
  TOGGLE_OFF = 0x4A5060FF,
  SCROLL_TRACK = 0x1A1A1AFF, SCROLL_THUMB = 0x808080FF, SCROLL_THUMB_ACTIVE = 0xC0C0C0FF,
  GRIP = 0x555A66FF,           -- panel resize grip
  -- text
  TEXT = 0xDDDDDDFF, TEXT_BRIGHT = 0xEEEEEEFF, WHITE = 0xFFFFFFFF,
  TEXT_MAIN = 0xE6E8EEFF, TEXT_DIM = 0x8C93A3FF,
  TRANSPARENT = 0x00000000,
  ROW_HOVER = 0xFFFFFF12,      -- clickable list row under the mouse
  DANGER_HOVER = 0xF26D6D2E, DANGER_ACTIVE = 0xF26D6D50,  -- red outline buttons (remove all, reset, clear)
}

-- Module tables (declared up front so every function can reference them)
local Util = {}    -- general helper functions
local PDF = {}     -- Poppler, PDF info, rendering, cache
local Project = {} -- project, markers, regions, project config
local Dock = {}    -- docking state and dock-related helpers
local UI = {}       -- ImGui drawing, tabs, toolbar, status, view, main frame
local Nav = {}       -- pages, scrolling, zoom, autoscroll motion
local Midi = {}      -- MIDI input (direct + action-bound)
local Autostart = {} -- open Chart Cue with projects (__startup.lua watcher, SWS helpers)
local Msg = {}       -- user messages, errors and the diagnostic log
local Cues = {}      -- cue list: page / scroll changes per region, stored in the project (no markers)

---------------------------------------------------------------------------
-- SINGLE-INSTANCE / MIDI FORWARDING
-- A MIDI-triggered launch while Chart Cue runs just forwards its value and exits;
-- a normal second launch closes the running instance.
---------------------------------------------------------------------------
-- get_action_context() returns: is_new, file name, section ID, command ID, mode, resolution, value.
-- resolution is -1 when the action was not started by MIDI.
local is_new, _, sect_id, cmd_id, _, act_res, act_val = r.get_action_context()
local launched_by_midi = (is_new == true) and act_val ~= nil and act_res ~= nil and act_res > 0
if launched_by_midi and act_res > 127 then act_val = act_val * 127 / act_res end -- 14-bit -> 0..127

local function main_alive()
  local hb = tonumber(r.GetExtState(CFG.EXT, "heartbeat"))
  return hb ~= nil and math.abs(r.time_precise() - hb) < CFG.HEARTBEAT_TIMEOUT
end

if main_alive() then
  if launched_by_midi then
    local q = r.GetExtState(CFG.EXT, "midi_q")
    if #q > 4000 then q = "" end
    r.SetExtState(CFG.EXT, "midi_q", q .. tostring(math.floor(act_val)) .. ",", false)
  else
    r.SetExtState(CFG.EXT, "quit", "1", false)
  end
  return
end

-- ReaImGui API pinned to 0.9.3 with the official compatibility shim, so newer ReaImGui versions
-- behave the same and no version checks are needed in the code.
local IMGUI_SHIM = r.GetResourcePath() .. "/Scripts/ReaTeam Extensions/API/imgui.lua"
local IMGUI_MISSING = "ReaImGui 0.9.3 or newer is needed.\n\nInstall or update it with ReaPack:\nExtensions > ReaPack > Browse packages > search 'ReaImGui' > Install, then restart REAPER."
if not r.ImGui_CreateContext or not r.file_exists(IMGUI_SHIM) then
  r.ShowMessageBox(IMGUI_MISSING, CFG.TITLE, 0)
  return
end
-- the shim raises an error when the installed ReaImGui is older than 0.9.3
if not pcall(function() dofile(IMGUI_SHIM)("0.9.3") end) then
  r.ShowMessageBox(IMGUI_MISSING, CFG.TITLE, 0)
  return
end

---------------------------------------------------------------------------
-- GLOBAL SETTINGS (persisted to settings.ini; NOT project specific)
---------------------------------------------------------------------------
local S = {
  pdf_path = "", pdftoppm_path = "", dpi = CFG.DEFAULT_DPI,
  engine = "windows",          -- PDF engine: "windows" (built in, no install) or "poppler"
  page = 1, zoom = 1.0, fit_mode = "width", scroll_y = 0, scroll_x = 0,
  cc_abs = 1, cc_rel = 2, mode = "absolute", rel_encoding = 1, rel_invert = false,
  sensitivity = 24.0, direct_midi = false,
  midi_page_turn = false, cc_page_next = 3, cc_page_prev = 4, show_midi_debug = false,
  midi_add_cue = false, cc_add_cue = 5, cc_add_scroll = 6,   -- "Add cues with MIDI"
  scroll_mode = "off",         -- "off" | "marker" | "cues"; default for projects without P.scroll_mode
  keep_last_page = true,       -- during playback, keep the last page when a region has no PDF
  include_subfolders = false,
  hide_controls_playing = true,
  comfortable = false,         -- "Comfortable layout": more empty space (compact is the default)
  dim_page = false, dim_level = 0.65,   -- dim mode: page brightness 0.3..1 (no re-render)
  turn_flash = true,           -- accent border for a moment when the page turns during playback
  close_with_project = true,   -- close Chart Cue when its project closes or is replaced in the same tab
  import_copy = true,          -- copy imported PDFs into <project folder>\PDFs (else link the original)
  tab = 1, panel_open = true,
  tab_ver = 1,                 -- 2 = tab numbers include the Cues tab; 3 = one Settings tab (v4.8)
  settings_open = "1000",      -- Settings tab sections open (1) or closed (0): Autoscroll, MIDI, Display, Project
  folded = ",",                -- closed foldable headings (first section of Library, Regions, Cues): ",id,id,"
  panel_h = 0,                 -- 0 = automatic (~40% of free height); otherwise the user's dragged height
  win_x = CFG.DEFAULT_WIN[1], win_y = CFG.DEFAULT_WIN[2], win_w = CFG.DEFAULT_WIN[3], win_h = CFG.DEFAULT_WIN[4],
  dock_id = 0,
  log_diag = false,            -- "Write diagnostic log" (Display tab > Advanced)
}
CFG.S_DEFAULTS = {}   -- copy of the defaults (before settings.ini is read), for "Reset all settings"
for k, v in pairs(S) do CFG.S_DEFAULTS[k] = v end

function Util.ensure_dir(p) r.RecursiveCreateDirectory(p, 0) end

function Util.load_settings()
  local f = io.open(CFG.SETTINGS_FILE, "r")
  if not f then return end
  for line in f:lines() do
    local k, v = line:match("^([%w_]+)=(.*)$")
    if k and S[k] ~= nil then
      local t = type(S[k])
      if t == "number" then
        local n = tonumber(v); if n then S[k] = n end
      elseif t == "boolean" then
        S[k] = (v == "1" or v == "true")
      else
        S[k] = v
      end
    end
  end
  f:close()
  Util.validate_settings()
end

-- After settings.ini is read: numbers back into their range, unknown values back to the default
-- (protects against a damaged or hand-edited file). Only values that are out of range change.
function Util.validate_settings()
  local D = CFG.S_DEFAULTS
  local function int(k, lo, hi) S[k] = Util.clamp(math.floor(S[k] + 0.5), lo, hi) end
  local function num(k, lo, hi) if S[k] ~= S[k] then S[k] = D[k] end; S[k] = Util.clamp(S[k], lo, hi) end -- NaN -> default
  local function one_of(k, ...)
    for _, v in ipairs({ ... }) do if S[k] == v then return end end
    S[k] = D[k]
  end
  int("dpi", 50, 600); int("page", 1, 100000); int("tab", 1, 99); int("tab_ver", 1, 99)
  for _, k in ipairs({ "cc_abs", "cc_rel", "cc_page_next", "cc_page_prev", "cc_add_cue", "cc_add_scroll" }) do int(k, 0, 127) end
  int("rel_encoding", 1, 4)
  num("sensitivity", 1, 200); num("dim_level", 0.3, 1); num("zoom", CFG.MIN_ZOOM, CFG.MAX_ZOOM)
  num("scroll_y", 0, math.huge); num("scroll_x", 0, math.huge); num("panel_h", 0, 10000)
  num("win_w", 200, 20000); num("win_h", 150, 20000)
  one_of("engine", "windows", "poppler")
  one_of("mode", "absolute", "relative")
  one_of("scroll_mode", "off", "marker", "cues", "fixed") -- "fixed" (older settings) means off
  one_of("fit_mode", "width", "height", "page", "100", "manual")
  if not S.settings_open:match("^[01]+$") then S.settings_open = D.settings_open end
  if S.folded:sub(1, 1) ~= "," then S.folded = "," .. S.folded end
end

function Util.save_settings()
  Util.ensure_dir(CFG.BASE_DIR)
  local f = io.open(CFG.SETTINGS_FILE, "w")
  if not f then return end
  local keys = {}
  for k in pairs(S) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local v = S[k]
    if type(v) == "boolean" then v = v and "1" or "0" end
    f:write(k, "=", (tostring(v):gsub("[\r\n]", " ")), "\n")
  end
  f:close()
end

---------------------------------------------------------------------------
-- RUNTIME STATE
---------------------------------------------------------------------------
local R = {
  ctx = nil, quit = false, dirty = false, last_save = 0, frames = 0,
  error = nil, warn = nil,
  exe = nil, pdfinfo_ok = true,
  total = 0, cache_dir = nil, prefix = nil, scale_to = nil, force_scale = false,
  bstate = {}, job = nil, batches_done = 0, page_paths = {}, images = {}, image_order = {},
  max_x = 0, max_y = 0, view_w = 0, view_h = 0, last_ratio = nil,
  last_cc = nil, abs_target = nil, override_until = 0,
  autoscroll_active = false, last_midi_seq = 0, page_cc_state = {},
  pdf_name = "", dpi_edit = nil,
  dbg = {},
  -- project / markers / regions
  proj = nil, projfn = "", psaveable = false, pdirty = false, plast = 0,
  state_cc = nil, scan_due = nil,
  regions = {}, scroll_pts = {}, page_pts = {}, marker_warns = {},
  cur_region_key = nil, active_region = nil,
  mpage_last = nil, was_playing = false, marker_pct = nil,
  libpages = {}, libexists = {}, libexists_t = 0, lib_scan_t = 0,
  cache_size = nil,
  dock_applied = false, reset_layout = false,
  -- region empty state (current region has no PDF)
  empty_region = nil,          -- the region (table) whose empty state is shown, or nil
  stash_pdf = nil,             -- PDF that was on screen before it was cleared (restored when region switching is turned off)
  cleared_key = nil,           -- key of the region we cleared the display for
  empty_sel = 0, empty_sel_key = nil, choose_existing = false,
  -- UI state
  lib_filter = "", lib_sort = 0, confirm_remove = nil, region_filter = 0,
  picker = nil, import = nil, msg = nil,
  tab_font = nil, tab_font_big = nil, big_font = nil,
  -- window / docking state
  in_window = false,           -- between Begin() and End() (for error recovery)
  was_visible = nil,           -- last visibility (diagnostic log)
  last_docked = nil, dock_settle = 0,
  hb_t = 0,                    -- last heartbeat write (single-instance detection)
  -- per-frame caches (rebuilt when R.lib_ver / the project / the frame changes)
  lib_ver = 0,                 -- changes on every library / assignment change
  items_cache = nil, order_cache = nil, counts_cache = nil, cue_cache = nil,
  -- PDF engine
  info_job = nil, info_seq = 0, -- background page-count job for opening a PDF
  lib_job = nil,               -- background page-count job for the Library list (Poppler)
  size_job = nil,              -- cache size calculation, spread over frames
  cache_clear_t = nil,         -- time of the last cache clear (its cmd.exe deletes in the background)
  clear_seq = 0,               -- number for the cache clear .bat file names
  page_w_pt = nil,             -- page 1 width in points (for "100%")
  -- copying PDFs into the project
  copyq = {}, copy = nil,      -- pending copy jobs / the running one
  -- project data
  plast_txt = nil,             -- last config text written to the project (skip unchanged writes)
  proj_fp = "",                -- content fingerprint of R.proj (tells "Save as" from "Open project")
  as_installed = nil,          -- cached: autostart block present in __startup.lua
  -- cue list editor
  cue_edit_key = "_all",       -- "_all" (default), nil = current song (play cursor, or edit cursor when stopped), "_project" or a region key
  cue_text = {},               -- text being typed in cue fields (kept while the value is invalid)
  cue_err = {},                -- cue field -> reason the typed value is not accepted (red border)
  help_open = nil,             -- help topic to open once
  -- live-use features
  perf = false, perf_t = 0,    -- performance mode (F): only the page is shown
  perf_btn_over = false,       -- mouse over the performance-mode exit button (no page drag)
  marks_cache = nil,           -- scrollbar marks of the page on screen
  lock = false,                -- lock mode (L): no mouse / keys on the page during playback
  rec = false,                 -- "Record cues" armed (R): C / S keys and MIDI cue CCs add cues; not saved
  kept_key = nil,              -- region key whose empty state is replaced by the last page (playback)
  perf_tap_t = -100,           -- performance mode: time of the last click on the page (shows the exit button)
  flash_t = 0,                 -- time of the last page turn during playback (page-turn flash)
  goto_edit = false, goto_text = "", goto_focus = false, -- "go to page" field in the toolbar
  -- modern UI
  ui_font = nil,               -- UI font (see UI.init_fonts)
  theme = nil,                 -- { c = colours pushed, v = style vars pushed } (the font is always pushed)
  anim = {},                   -- id -> 0..1 (hover fades, toggle knobs)
}

-- Project-specific configuration (saved inside the project .rpp, never to settings.ini)
function Project.default_project()
  return {
    pdfs = {},            -- library: ordered list of PDF paths (insertion order = "recently added")
    rel = {},             -- pdf path -> path relative to the project folder ("PDFs/Song A.pdf")
    assign = {},          -- region key -> pdf path (manual assignment)
    ignore = {},          -- region key -> true (ignored permanently)
    names = {},           -- region key -> last known region name (for display)
    auto_switch = true,
    continue_after_end = false, -- not used since 4.8 (markers stop at the region end); still read and written, so the saved text stays the same
    active_pdf = "",
    cues = {},            -- region key (or "_project") -> list of { pos, page, scroll }
    cue_unit = "beats",   -- "beats" (quarter notes from the region start) or "seconds"
    scroll_mode = "",     -- autoscroll mode of this project; "" = use the default (S.scroll_mode)
    hint_off = false,     -- "Not now" clicked on the mode hint (status line 2); written only when true
    turn_early = 0,       -- turn pages this many beats before their marker / cue (0 = on time); written only when not 0
    fixed_start = 0,      -- not used since 4.8 (Fixed speed removed); still read and written, so the saved text stays the same
    view = {},            -- pdf path -> { fit = fit mode, zoom = manual zoom } (per-PDF zoom)
  }
end
local P = Project.default_project()

function Util.now() return r.time_precise() end
function Util.touch_override() R.override_until = Util.now() + CFG.MIDI_OVERRIDE_SEC end
function Util.mark_dirty() R.dirty = true end
-- R.lib_ver changes whenever the project config (library, assignments) may have changed.
-- Per-frame caches (dropdown list, library order) compare it to know when to rebuild.
function Util.mark_pdirty() R.pdirty = true; R.lib_ver = R.lib_ver + 1 end
function Util.bump_lib() R.lib_ver = R.lib_ver + 1 end
-- Stability diagnostics: printed only when the Display tab option is on.
function Msg.diag(msg)
  if S.log_diag then r.ShowConsoleMsg("[" .. CFG.TITLE .. " diag] " .. msg .. "\n") end
end

function Msg.set_error(msg)
  R.error = msg
  if msg then r.ShowConsoleMsg("[" .. CFG.TITLE .. "] " .. msg .. "\n") end
end

function Util.file_exists(p)
  if not p or p == "" then return false end
  local f = io.open(p, "rb")
  if f then f:close(); return true end
  return false
end

function Util.read_all(p, maxbytes)
  local f = io.open(p, "rb"); if not f then return nil end
  local d = f:read(maxbytes or "a"); f:close(); return d
end

-- Copies a small file byte for byte (used for the __startup.lua backup). Never touches the source.
function Util.copy_file(src, dst)
  local d = Util.read_all(src)
  if not d then return false end
  local f = io.open(dst, "wb")
  if not f then return false end
  f:write(d); f:close()
  return true
end

function Util.file_size(p)
  local f = io.open(p, "rb"); if not f then return 0 end
  local n = f:seek("end"); f:close(); return n or 0
end

function Util.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
function Util.dir_of(p) return (p:match("^(.*)[/\\][^/\\]*$")) end
function Util.name_of(p) return (p:match("([^/\\]*)$")) end
function Util.same_path(a, b)
  if not a or not b then return false end
  return a:lower():gsub("/", "\\") == b:lower():gsub("/", "\\")
end
-- Path of `path` relative to folder `base`, with "/" separators, or nil if it is not inside it.
function Util.rel_path(path, base)
  if not path or not base or base == "" then return nil end
  local np = path:gsub("/", "\\")
  local nb = base:gsub("/", "\\"):gsub("\\+$", "") .. "\\"
  if #np <= #nb or np:sub(1, #nb):lower() ~= nb:lower() then return nil end
  return (np:sub(#nb + 1):gsub("\\", "/"))
end

function Util.join_path(d, n)
  if d:sub(-1) == "\\" or d:sub(-1) == "/" then return d .. n end
  return d .. SEP .. n
end

function Util.trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- Normalise a region name or PDF filename for matching
function Util.norm_name(s)
  s = Util.trim((s or ""):lower())
  s = s:gsub("%.pdf$", "")
  s = s:gsub("[_%-%s]+", " ")
  return Util.trim(s)
end

function Util.fmt_time(t) return string.format("%.1fs", t) end

---------------------------------------------------------------------------
-- POPPLER LOCATION
---------------------------------------------------------------------------
function PDF.find_pdftoppm()
  if S.pdftoppm_path ~= "" and Util.file_exists(S.pdftoppm_path) then return S.pdftoppm_path end
  -- on PATH? (checked by file name, so no process has to run)
  for dir in (os.getenv("PATH") or ""):gmatch("[^;]+") do
    local exe = Util.join_path(Util.trim((dir:gsub('"', ""))), "pdftoppm.exe")
    if Util.file_exists(exe) then return exe end
  end
  local roots = { "C:\\", "C:\\Program Files", "C:\\Program Files (x86)", "C:\\tools", "C:\\Tools" }
  local up = os.getenv("USERPROFILE")
  if up then roots[#roots + 1] = up; roots[#roots + 1] = up .. "\\Downloads"; roots[#roots + 1] = up .. "\\Documents" end
  local suffixes = { "\\Library\\bin\\pdftoppm.exe", "\\bin\\pdftoppm.exe", "\\pdftoppm.exe" }
  for _, root in ipairs(roots) do
    local i = 0
    while true do
      local sub = r.EnumerateSubdirectories(root, i)
      if not sub then break end
      if sub:lower():find("^poppler") then
        local base = root:gsub("[/\\]$", "") .. "\\" .. sub
        local bases = { base }
        local j = 0
        while true do
          local s2 = r.EnumerateSubdirectories(base, j)
          if not s2 then break end
          if s2:lower():find("^poppler") then bases[#bases + 1] = base .. "\\" .. s2 end
          j = j + 1
        end
        for _, b in ipairs(bases) do
          for _, suf in ipairs(suffixes) do
            if Util.file_exists(b .. suf) then return b .. suf end
          end
        end
      end
      i = i + 1
    end
  end
  return nil
end

function PDF.poppler_help()
  return "pdftoppm.exe not found. Install Poppler for Windows (e.g. https://github.com/oschwartz10612/poppler-windows/releases), "
      .. "unzip it, then use Settings > Display and view > PDF engine = Poppler > 'Browse...' to select  <poppler>\\Library\\bin\\pdftoppm.exe."
end

local POPPLER_PDFINFO_WARN = "pdftoppm.exe was found, but pdfinfo.exe was not found in the same folder. "
    .. "PDF page count and page-size detection may be unreliable. "
    .. "Install the complete Poppler package or select the folder containing both executables."

function PDF.pdfinfo_exe() return Util.dir_of(R.exe) .. SEP .. "pdfinfo.exe" end

function PDF.check_pdfinfo()
  R.pdfinfo_ok = (not R.exe) or Util.file_exists(PDF.pdfinfo_exe())
end

---------------------------------------------------------------------------
-- HASH / CACHE PATHS
---------------------------------------------------------------------------
function Util.hash_str(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) & 0xFFFFFFFF end
  return string.format("%08x", h)
end

-- Second, independent 32-bit hash (sdbm). Used with hash_str for a 64-bit content key.
function Util.hash_str2(s)
  local h = 0
  for i = 1, #s do h = (s:byte(i) + (h << 6) + (h << 16) - h) & 0xFFFFFFFF end
  return string.format("%08x", h)
end

-- Content key of a PDF: file size + hash of the first and last 64 KB. It does not depend on the
-- path or the file name, so a moved, copied or renamed PDF uses the same render cache.
-- (PDF edits are normally appended at the end of the file, so the last 64 KB changes when the
-- PDF changes.) Results are remembered per path and size, so the file is read only once.
PDF.key_memo = {}
-- Modification time via js_ReaScriptAPI when it is installed (REAPER itself has no such API).
function Util.file_mtime(p)
  if not r.JS_File_Stat then return nil end
  local rv, _, _, mtime = r.JS_File_Stat(p)
  if rv == 0 then return mtime end
  return nil
end

-- The memo is reused only while the file is unchanged: same size and same modification time,
-- or (without js_ReaScriptAPI) for CFG.KEY_MEMO_SEC, so a file edited in place gets a new key.
function PDF.content_key(pdf)
  local size, mtime = Util.file_size(pdf), Util.file_mtime(pdf)
  local memo = PDF.key_memo[pdf]
  if memo and memo.size == size then
    if mtime and memo.mtime == mtime then return memo.key end
    if not mtime and Util.now() - memo.t < CFG.KEY_MEMO_SEC then return memo.key end
  end
  local f = io.open(pdf, "rb")
  if not f then return nil end
  local head = f:read(CFG.KEY_SAMPLE) or ""
  local tail = ""
  if size > CFG.KEY_SAMPLE then
    f:seek("set", math.max(CFG.KEY_SAMPLE, size - CFG.KEY_SAMPLE))
    tail = f:read(CFG.KEY_SAMPLE) or ""
  end
  f:close()
  local sample = head .. "|" .. tail
  local key = string.format("pdf_%d_%s%s", size, Util.hash_str(sample), Util.hash_str2(sample))
  PDF.key_memo[pdf] = { size = size, mtime = mtime, t = Util.now(), key = key }
  return key
end

---------------------------------------------------------------------------
-- PDF ENGINES
--   windows: Windows 10/11 built-in PDF renderer (Windows.Data.Pdf) through PowerShell. No install.
--   poppler: pdftoppm.exe + pdfinfo.exe (optional, selectable in the Display tab).
-- Both write the same files: <cache>\p-<page>.png, job.done (exit code), job.err (message).
-- Page count + page size are cached in <cache root>\<content key>\info.txt, so a PDF that was
-- opened once opens at once (PowerShell needs about 1 s to start).
---------------------------------------------------------------------------
function PDF.engine() return (S.engine == "poppler") and "poppler" or "windows" end


local PS_ENGINE_SCRIPT = [=[
param([string]$JobFile)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$inv = [Globalization.CultureInfo]::InvariantCulture
$cfg = @{}
foreach ($l in [IO.File]::ReadAllLines($JobFile, $utf8)) {
  $i = $l.IndexOf('=')
  if ($i -gt 0) { $cfg[$l.Substring(0, $i)] = $l.Substring($i + 1) }
}
try {
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
  $null = [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
  $null = [Windows.Data.Pdf.PdfDocument,Windows.Data.Pdf,ContentType=WindowsRuntime]
  $null = [Windows.Data.Pdf.PdfPageRenderOptions,Windows.Data.Pdf,ContentType=WindowsRuntime]
  $null = [Windows.Storage.Streams.InMemoryRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime]
  $m = [System.WindowsRuntimeSystemExtensions].GetMethods()
  $asTaskOp = ($m | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
  $asTaskAct = ($m | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' })[0]
  function AwaitOp($op, [Type]$t) {
    $task = $asTaskOp.MakeGenericMethod($t).Invoke($null, @($op))
    try { $task.Wait() } catch { throw $_.Exception.InnerException.InnerException }
    $task.Result
  }
  function AwaitAct($a) {
    $task = $asTaskAct.Invoke($null, @($a))
    try { $task.Wait() } catch { throw $_.Exception.InnerException.InnerException }
  }
  $file = AwaitOp ([Windows.Storage.StorageFile]::GetFileFromPathAsync($cfg['pdf'])) ([Windows.Storage.StorageFile])
  $doc = AwaitOp ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($file)) ([Windows.Data.Pdf.PdfDocument])
  if ($cfg['mode'] -eq 'info') {
    # same text format as pdfinfo.exe (sizes in points = 1/72 inch; the API uses 1/96 inch)
    $pg = $doc.GetPage(0)
    $w = ($pg.Size.Width * 0.75).ToString($inv); $h = ($pg.Size.Height * 0.75).ToString($inv)
    $pg.Dispose()
    [IO.File]::WriteAllText($cfg['out'], "Pages: " + $doc.PageCount + "`nPage size: " + $w + " x " + $h + " pts`n", $utf8)
  } else {
    $first = [int]$cfg['first']; $last = [int]$cfg['last']; $digits = [int]$cfg['digits']
    $dpi = [double]::Parse($cfg['dpi'], $inv); $maxdim = [int]$cfg['maxdim']
    for ($n = $first; $n -le $last; $n++) {
      $page = $doc.GetPage($n - 1)
      $w = $page.Size.Width; $h = $page.Size.Height
      if ($maxdim -gt 0) { $s = $maxdim / [Math]::Max($w, $h) } else { $s = $dpi / 96.0 }
      $opt = New-Object Windows.Data.Pdf.PdfPageRenderOptions
      $opt.DestinationWidth = [uint32][Math]::Max(1, [Math]::Round($w * $s))
      $opt.DestinationHeight = [uint32][Math]::Max(1, [Math]::Round($h * $s))
      $mem = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
      AwaitAct ($page.RenderToStreamAsync($mem, $opt))   # PNG is the default encoder
      $out = $cfg['prefix'] + '-' + $n.ToString('D' + $digits) + '.png'
      $src = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($mem.GetInputStreamAt(0))
      $fs = [IO.File]::Create($out + '.part')
      $src.CopyTo($fs); $fs.Close(); $src.Dispose(); $mem.Dispose(); $page.Dispose()
      if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Force }
      Move-Item -LiteralPath ($out + '.part') -Destination $out
    }
  }
  [IO.File]::WriteAllText($cfg['done'], '0', $utf8)
} catch {
  [IO.File]::WriteAllText($cfg['err'], $_.Exception.Message, $utf8)
  [IO.File]::WriteAllText($cfg['done'], '1', $utf8)
}
# End the process at once. A normal exit lets .NET finalize the Windows Runtime (PDF) objects
# while the runtime shuts down, which can crash powershell.exe ("has stopped working").
# All result files are already written and closed here, so nothing is lost.
[System.Diagnostics.Process]::GetCurrentProcess().Kill()
]=]

function PDF.write_engine_script()
  Util.ensure_dir(CFG.TMP_DIR)
  local f = io.open(CFG.PS_ENGINE_FILE, "wb")
  if not f then return false end
  f:write((PS_ENGINE_SCRIPT:gsub("\n", "\r\n"))); f:close()
  return true
end

-- Job parameters go through a UTF-8 file (never the command line): spaces, Unicode and
-- apostrophes in paths are safe.
function PDF.run_engine_job(args_file, t)
  local f = io.open(args_file, "wb")
  if not f then return false end
  for k, v in pairs(t) do f:write(k, "=", tostring(v), "\n") end
  f:close()
  local res = r.ExecProcess('powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "'
    .. CFG.PS_ENGINE_FILE .. '" -JobFile "' .. args_file .. '"', CFG.EXEC_NOWAIT)
  return res ~= nil
end

-- info cache (page count + page size text), stored per PDF content
function PDF.info_cache_file(path)
  local key = PDF.content_key(path)
  return key and (CFG.CACHE_ROOT .. SEP .. key .. SEP .. "info.txt") or nil
end

function PDF.read_info_cache(path)
  local f = PDF.info_cache_file(path)
  local d = f and Util.read_all(f)
  local n = d and tonumber(d:match("Pages:%s*(%d+)"))
  if n and n > 0 then return n, d end
  return nil
end

function PDF.write_info_cache(path, info)
  local f = PDF.info_cache_file(path)
  if not f or not info or not info:match("Pages:%s*%d+") then return end
  Util.ensure_dir(Util.dir_of(f))
  local h = io.open(f, "wb")
  if h then h:write(info); h:close() end
end

-- Reads page count + page size in the background. Windows engine: the PowerShell script.
-- Poppler: pdfinfo.exe from a .bat (the Windows engine is used when pdfinfo.exe is missing).
-- The caller stores the job in R.info_job (opening a PDF) or R.lib_job (Library page count).
function PDF.start_info(path, keep_position)
  R.info_seq = R.info_seq + 1
  local base = CFG.TMP_DIR .. SEP .. "info_" .. R.info_seq
  local job = { path = path, keep = keep_position, started = Util.now(), kind = "ps",
    out_f = base .. ".out", done_f = base .. ".done", err_f = base .. ".err", run_f = base .. ".args" }
  local ok = false
  if PDF.engine() == "poppler" and R.exe and R.pdfinfo_ok then
    job.kind, job.run_f = "pdfinfo", base .. ".bat"
    local f = io.open(job.run_f, "wb")
    if f then
      f:write("@echo off\r\nchcp 65001 >nul\r\n",
        string.format('"%s" "%s" > "%s" 2> "%s"\r\n', PDF.bat_escape(PDF.pdfinfo_exe()), PDF.bat_escape(path),
          PDF.bat_escape(job.out_f), PDF.bat_escape(job.err_f)),
        string.format('echo %%errorlevel%% > "%s"\r\n', PDF.bat_escape(job.done_f)))
      f:close()
      ok = r.ExecProcess('cmd.exe /C "' .. job.run_f .. '"', CFG.EXEC_NOWAIT) ~= nil
    end
  else
    ok = PDF.write_engine_script() and PDF.run_engine_job(job.run_f,
      { mode = "info", pdf = path, out = job.out_f, done = job.done_f, err = job.err_f })
  end
  return ok and job or nil
end

-- nil while running; otherwise ok, output text, error text ("timeout" when it did not answer).
function PDF.poll_info(job)
  local d = Util.read_all(job.done_f, 32)
  if d and not d:match("%d") then d = nil end -- .done exists but is not written yet: still running
  local timeout = not d and Util.now() - job.started > CFG.INFO_TIMEOUT_SEC
  if not d and not timeout then return nil end
  local out, err = Util.read_all(job.out_f) or "", Util.read_all(job.err_f, 600) or ""
  for _, f in ipairs({ job.out_f, job.done_f, job.err_f, job.run_f }) do os.remove(f) end
  if timeout then return false, "", "timeout" end
  return (tonumber(d:match("%-?%d+")) or 1) == 0, out, (err:gsub("[\r\n]+", " "))
end

-- Page count from the info text, or nil + a message.
function PDF.parse_info(out, err)
  if (out .. " " .. err):lower():find("password", 1, true) then
    return nil, "This PDF is encrypted / password protected and cannot be rendered."
  end
  local n = tonumber(out:match("Pages:%s*(%d+)"))
  if n and n > 0 then return n end
  if err ~= "" then return nil, "Could not read the PDF: " .. err:sub(1, 200) end
  return nil, "Could not determine the page count (invalid PDF)."
end

function PDF.info_tick()
  local job = R.info_job
  if job then
    local ok, out, err = PDF.poll_info(job)
    if ok ~= nil then
      R.info_job = nil
      local engine = (job.kind == "ps") and "Windows PDF engine" or "pdfinfo"
      if err == "timeout" then
        Msg.set_error(engine .. " did not answer. Try again, or select the other PDF engine in Settings > Display and view."
          .. (job.kind == "ps" and " Antivirus or a company policy can block PowerShell." or ""))
      else
        local n, msg = PDF.parse_info(out, err)
        if n then
          PDF.write_info_cache(job.path, out)
          if Util.same_path(job.path, S.pdf_path) then PDF.finish_open(job.path, job.keep, n, out) end
        else
          Msg.set_error(engine .. ": " .. msg .. " (You can select the other PDF engine in Settings > Display and view.)")
        end
      end
    end
  end
  local lj = R.lib_job
  if lj then
    local ok, out, err = PDF.poll_info(lj)
    if ok ~= nil then
      R.lib_job = nil
      local n = (err ~= "timeout") and PDF.parse_info(out, err) or nil
      if n then PDF.write_info_cache(lj.path, out) end
      R.libpages[lj.path] = n or false; Util.bump_lib()
    end
  end
end

function PDF.compute_cache_dir(pdf)
  -- content key; a file that cannot be read gets a path key (it cannot be rendered anyway)
  local key = PDF.content_key(pdf) or ("unreadable_" .. Util.hash_str(pdf:lower()))
  local suffix = "dpi" .. S.dpi .. (R.scale_to and ("_max" .. R.scale_to) or "")
    .. (PDF.engine() == "windows" and "_win" or "") -- each engine has its own page images
  return CFG.CACHE_ROOT .. SEP .. key .. SEP .. suffix
end

---------------------------------------------------------------------------
-- PAGE FILE LOOKUP + BATCH RENDERING (non-blocking)
---------------------------------------------------------------------------
function PDF.total_batches() return math.ceil(R.total / CFG.BATCH_SIZE) end
function PDF.batch_of(p) return math.ceil(p / CFG.BATCH_SIZE) end

-- pdftoppm (and the Windows engine) zero-pad the page number to the digit count of the page total
function PDF.find_page_file(p)
  if R.page_paths[p] then return R.page_paths[p] end
  for _, fmt in ipairs({ "%s-%0" .. #tostring(R.total) .. "d.png", "%s-%d.png" }) do
    local path = string.format(fmt, R.prefix, p)
    if Util.file_exists(path) then R.page_paths[p] = path; return path end
  end
  return nil
end

function PDF.batch_range(b)
  local first = (b - 1) * CFG.BATCH_SIZE + 1
  return first, math.min(first + CFG.BATCH_SIZE - 1, R.total)
end

function PDF.batch_status(b)
  local st = R.bstate[b]
  if st then return st end
  if R.job and R.job.batch == b then return "running" end
  local first, last = PDF.batch_range(b)
  for p = first, last do
    if not PDF.find_page_file(p) then R.bstate[b] = "todo"; return "todo" end
  end
  R.bstate[b] = "done"; R.batches_done = R.batches_done + 1
  return "done"
end

function PDF.page_ready(p) return PDF.batch_status(PDF.batch_of(p)) == "done" end
function PDF.bat_escape(s) return (s:gsub("%%", "%%%%")) end

function PDF.start_batch(b)
  local first, last = PDF.batch_range(b)
  local done_f = R.cache_dir .. SEP .. "job.done"
  local err_f = R.cache_dir .. SEP .. "job.err"
  local bat_f = R.cache_dir .. SEP .. "job.bat"
  os.remove(done_f); os.remove(err_f)
  if PDF.engine() == "windows" then
    local ok = PDF.write_engine_script() and PDF.run_engine_job(R.cache_dir .. SEP .. "job.args", {
      mode = "render", pdf = S.pdf_path, first = first, last = last, digits = #tostring(R.total),
      prefix = R.prefix, dpi = S.dpi, maxdim = R.scale_to or 0, done = done_f, err = err_f })
    if not ok then
      Msg.set_error("Could not start the Windows PDF engine (PowerShell). Antivirus or a company policy can block it. "
        .. "Select Poppler in Settings > Display and view.")
      R.bstate[b] = "failed"; return
    end
    R.job = { batch = b, started = Util.now(), done_f = done_f, err_f = err_f }
    return
  end
  local lines = {
    "@echo off", "chcp 65001 >nul",
    string.format('"%s" -png %s -f %d -l %d "%s" "%s" 2> "%s"',
      PDF.bat_escape(R.exe),
      R.scale_to and ("-scale-to " .. R.scale_to) or ("-r " .. S.dpi),
      first, last, PDF.bat_escape(S.pdf_path), PDF.bat_escape(R.prefix), PDF.bat_escape(err_f)),
    string.format('echo %%errorlevel%% > "%s"', PDF.bat_escape(done_f)),
  }
  local f = io.open(bat_f, "wb")
  if not f then Msg.set_error("Cannot write to cache folder: " .. R.cache_dir); R.bstate[b] = "failed"; return end
  f:write(table.concat(lines, "\r\n"), "\r\n"); f:close()
  local ok = r.ExecProcess('cmd.exe /C "' .. bat_f .. '"', CFG.EXEC_NOWAIT)
  if ok == nil then
    Msg.set_error("Failed to launch pdftoppm (cmd.exe could not start the render job).")
    R.bstate[b] = "failed"; return
  end
  R.job = { batch = b, started = Util.now(), done_f = done_f, err_f = err_f }
end

function PDF.finish_job(code)
  local job = R.job
  local b = job.batch
  R.job = nil
  local first, last = PDF.batch_range(b)
  if code == 0 then
    R.bstate[b] = nil
    for p = first, last do R.page_paths[p] = nil end
    local all = true
    for p = first, last do if not PDF.find_page_file(p) then all = false end end
    if all then R.bstate[b] = "done"; R.batches_done = R.batches_done + 1
    else R.bstate[b] = "failed"; Msg.set_error(string.format("Render finished but pages %d-%d are missing.", first, last)) end
  else
    R.bstate[b] = "failed"
    local err = (Util.read_all(job.err_f, 600) or ""):gsub("[\r\n]+", " ")
    if err:lower():find("password") then err = "PDF is encrypted/password protected. " .. err end
    Msg.set_error(string.format("%s failed (exit %d) on pages %d-%d. %s",
      PDF.engine() == "windows" and "Windows PDF engine" or "pdftoppm", code, first, last, err))
  end
end

function PDF.pick_next_batch()
  local nb = PDF.total_batches()
  if nb == 0 then return nil end
  local cur = PDF.batch_of(S.page)
  local order = { cur, cur + 1 }
  -- all pages are always prepared in the background, the pages near the current page first
  order[#order + 1] = cur - 1
  for b = cur + 2, nb do order[#order + 1] = b end
  for b = cur - 2, 1, -1 do order[#order + 1] = b end
  for _, b in ipairs(order) do
    if b >= 1 and b <= nb and PDF.batch_status(b) == "todo" then return b end
  end
  return nil
end

function PDF.render_tick()
  if R.total == 0 or not R.cache_dir then return end
  if R.job then
    local d = Util.read_all(R.job.done_f, 32)
    if d and d:match("%d") then PDF.finish_job(tonumber(d:match("%-?%d+")) or 1)
    elseif Util.now() - R.job.started > CFG.JOB_TIMEOUT_SEC then
      R.bstate[R.job.batch] = "failed"; R.job = nil
      Msg.set_error("Render timed out. Check that pdftoppm.exe runs, then press 'Retry rendering'.")
    end
    return
  end
  local b = PDF.pick_next_batch()
  if b then PDF.start_batch(b) end
end

function PDF.retry_failed()
  for b, st in pairs(R.bstate) do if st == "failed" then R.bstate[b] = nil end end
  Msg.set_error(nil)
end

---------------------------------------------------------------------------
-- PROJECT IDENTITY + PER-PROJECT CONFIG
---------------------------------------------------------------------------

-- Text format (one "key=value" per line) shared by the .rpp ExtState.
function Project.parse_cfg(lines_iter)
  local p = Project.default_project()
  for line in lines_iter do
    line = line:gsub("\r$", "")
    -- [%w_]: keys such as scroll_mode and cue_unit contain "_" (%w alone does not match it)
    local k, v = line:match("^([%w_]+)=(.*)$")
    if k == "pdf" then
      p.pdfs[#p.pdfs + 1] = v
    elseif k == "assign" then
      local key, path = v:match("^(.-)\t(.*)$")
      if key then p.assign[key] = path end
    elseif k == "ignore" then
      p.ignore[v] = true
    elseif k == "rname" then
      local key, nm = v:match("^(.-)\t(.*)$")
      if key then p.names[key] = nm end
    elseif k == "auto_switch" then p.auto_switch = (v == "1")
    elseif k == "continue_after_end" then p.continue_after_end = (v == "1")
    elseif k == "active_pdf" then p.active_pdf = v
    elseif k == "cue_unit" then p.cue_unit = (v == "seconds") and "seconds" or "beats"
    elseif k == "scroll_mode" then
      p.scroll_mode = (v == "off" or v == "fixed" or v == "marker" or v == "cues") and v or ""
    elseif k == "hint_off" then p.hint_off = (v == "1")
    elseif k == "turn_early" then p.turn_early = Util.clamp(tonumber(v) or 0, 0, 4)
    elseif k == "fixed_start" then p.fixed_start = tonumber(v) or 0
    elseif k == "view" then
      local path, fit, zoom = v:match("^(.-)\t(.-)\t(.*)$")
      if path and fit ~= "" then p.view[path] = { fit = fit, zoom = tonumber(zoom) or 1.0 } end
    elseif k == "cue" then
      local key, pos, pg, sc = v:match("^(.-)\t(.-)\t(.-)\t(.*)$")
      pos = tonumber(pos)
      if key and pos then
        p.cues[key] = p.cues[key] or {}
        table.insert(p.cues[key], { pos = pos, page = tonumber(pg), scroll = tonumber(sc) })
      end
    elseif k == "prel" then
      local path, rel = v:match("^(.-)\t(.*)$")
      if path and rel ~= "" then p.rel[path] = rel end
    end
  end
  return p
end

function Project.serialize_cfg()
  local t = {}
  local function w(k, v) t[#t + 1] = k .. "=" .. (tostring(v):gsub("[\r\n]", " ")) end
  w("version", 1)
  w("auto_switch", P.auto_switch and 1 or 0)
  w("continue_after_end", P.continue_after_end and 1 or 0)
  w("active_pdf", P.active_pdf)
  for _, path in ipairs(P.pdfs) do w("pdf", path) end
  for _, path in ipairs(P.pdfs) do
    if P.rel[path] then w("prel", path .. "\t" .. P.rel[path]) end
  end
  -- sorted keys: an unchanged config always gives the same text (check_project compares the
  -- texts to tell "Save as" from "Open project", and save_project_cfg skips unchanged writes)
  local function sorted(t)
    local k = {}
    for x in pairs(t) do k[#k + 1] = x end
    table.sort(k)
    return k
  end
  for _, key in ipairs(sorted(P.assign)) do w("assign", key .. "\t" .. P.assign[key]) end
  for _, key in ipairs(sorted(P.ignore)) do w("ignore", key) end
  for _, key in ipairs(sorted(P.names)) do
    -- names are only needed for regions that have a manual choice (keeps the data small)
    if P.assign[key] or P.ignore[key] then w("rname", key .. "\t" .. P.names[key]) end
  end
  w("cue_unit", P.cue_unit)
  -- only written when set, so projects that never changed the mode keep the same text
  if P.scroll_mode ~= "" then w("scroll_mode", P.scroll_mode) end
  if P.hint_off then w("hint_off", 1) end -- only when set, so older projects keep the same text
  if P.turn_early ~= 0 then w("turn_early", string.format("%g", P.turn_early)) end -- the same
  if P.fixed_start ~= 0 then w("fixed_start", string.format("%.6f", P.fixed_start)) end
  for _, path in ipairs(sorted(P.view)) do
    w("view", string.format("%s\t%s\t%.3f", path, P.view[path].fit, P.view[path].zoom))
  end
  for _, key in ipairs(sorted(P.cues)) do
    for _, c in ipairs(P.cues[key]) do
      w("cue", string.format("%s\t%.4f\t%s\t%s", key, c.pos, c.page and tostring(c.page) or "",
        c.scroll and string.format("%.1f", c.scroll) or ""))
    end
  end
  return table.concat(t, "\n")
end

function Project.valid_proj(proj)
  if not proj then return false end
  local ok, valid = pcall(r.ValidatePtr2, 0, proj, "ReaProject*")
  return ok and valid
end

-- Reads the config from the project's own ExtState (.rpp). Returns config, source ("rpp" | "new").
function Project.load_project_cfg(proj)
  if Project.valid_proj(proj) then
    local n, txt = r.GetProjExtState(proj, CFG.PEXT, CFG.PEXT_KEY)
    if n and n > 0 and txt and txt ~= "" then
      return Project.parse_cfg((txt .. "\n"):gmatch("([^\n]*)\n")), "rpp"
    end
  end
  return Project.default_project(), "new"
end

-- Writes the config into R.proj (the project it belongs to, not necessarily the active tab).
-- Works for unsaved projects too: REAPER writes the ExtState to disk when the project is saved.
function Project.save_project_cfg()
  if not Project.valid_proj(R.proj) then return false end
  local txt = Project.serialize_cfg()
  if txt == R.plast_txt then return true end -- unchanged: do not mark the project modified
  r.SetProjExtState(R.proj, CFG.PEXT, CFG.PEXT_KEY, txt)
  R.plast_txt = txt
  return true
end

---------------------------------------------------------------------------
-- MARKER + REGION SCAN
---------------------------------------------------------------------------
function Project.region_key(guid, name, pos)
  if guid and guid ~= "" then return "g" .. guid:gsub("[^%w%-]", "") end
  return (("n" .. Util.norm_name(name) .. "@" .. string.format("%.2f", pos)):gsub("[^%w%-_@%.]", "_"))
end

function Project.resolve_regions()
  local norms = {}
  for i, path in ipairs(P.pdfs) do norms[i] = Util.norm_name(Util.name_of(path)) end
  for _, reg in ipairs(R.regions) do
    reg.cands, reg.pdf = {}, nil
    if P.ignore[reg.key] then
      reg.status = "ignored"
    elseif P.assign[reg.key] then
      reg.status = "assigned"; reg.pdf = P.assign[reg.key]
    else
      for i, n in ipairs(norms) do
        if n ~= "" and n == reg.norm then reg.cands[#reg.cands + 1] = P.pdfs[i] end
      end
      if #reg.cands == 1 then reg.status = "auto"; reg.pdf = reg.cands[1]
      elseif #reg.cands == 0 then reg.status = "unassigned"
      else reg.status = "ambiguous" end
    end
  end
end

function Project.region_by_key(key)
  for _, reg in ipairs(R.regions) do if reg.key == key then return reg end end
  return nil
end

-- Read every region and PDFSCROLL / PDFPAGE marker in the active project.
-- Chart Cue markers: name starts with PDFPAGE or PDFSCROLL (any case). Regions are never included.
function Project.is_script_marker(name)
  local l = Util.trim((name or ""):lower())
  return l:find("^pdfscroll") ~= nil or l:find("^pdfpage") ~= nil
end

-- Indexes of the Chart Cue markers in [lo, hi), highest index first (safe order for deleting).
function Project.script_markers(lo, hi)
  local idx = {}
  local total = r.CountProjectMarkers(0) or 0
  for i = total - 1, 0, -1 do
    local ok, isrgn, pos, _, name = r.EnumProjectMarkers3(0, i)
    if ok and ok > 0 and not isrgn and pos >= lo and pos < hi and Project.is_script_marker(name) then
      idx[#idx + 1] = i
    end
  end
  return idx
end

-- Removes the Chart Cue markers between lo and hi (asked first by UI.ask_remove_markers).
function Project.remove_script_markers(lo, hi, where)
  local idx = Project.script_markers(lo, hi)
  if #idx == 0 then return end
  r.Undo_BeginBlock()
  for _, i in ipairs(idx) do r.DeleteProjectMarkerByIndex(0, i) end
  r.Undo_EndBlock("Chart Cue: remove PDF markers", -1)
  r.UpdateTimeline()
  Project.scan_project()
  Msg.notify(string.format("%d marker(s) removed from %s.", #idx, where), false, "cues")
end

-- "Rescan project" button: scans and reports the result in the section (source = message area).
function Project.rescan(source)
  Project.scan_project()
  Msg.notify(string.format("Rescanned: %d region(s), %d PDFPAGE and %d PDFSCROLL marker(s)%s.",
    #R.regions, #R.page_pts, #R.scroll_pts,
    #R.marker_warns > 0 and string.format(", %d invalid", #R.marker_warns) or ""), false, source)
end

function Project.scan_project()
  R.regions, R.scroll_pts, R.page_pts, R.marker_warns = {}, {}, {}, {}
  local total = r.CountProjectMarkers(0) or 0
  local no_guid = 0
  for i = 0, total - 1 do
    local retval, isrgn, pos, rend, name = r.EnumProjectMarkers3(0, i)
    if retval and retval > 0 then
      name = name or ""
      if isrgn then
        local okg, guid = r.GetSetProjectInfo_String(0, "MARKER_GUID:" .. i, "", false)
        if not okg or guid == "" then guid = nil; no_guid = no_guid + 1 end
        R.regions[#R.regions + 1] = {
          key = Project.region_key(guid, name, pos), name = name, norm = Util.norm_name(name),
          start = pos, stop = rend,
        }
      else
        local lname = Util.trim(name:lower())
        if lname:find("^pdfscroll") then
          local num = tonumber(lname:sub(10):match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
          if num and num >= 0 and num <= 100 then
            R.scroll_pts[#R.scroll_pts + 1] = { t = pos, pct = num, ord = i }
          else
            R.marker_warns[#R.marker_warns + 1] = string.format('Invalid marker "%s" at %s', name, Util.fmt_time(pos))
          end
        elseif lname:find("^pdfpage") then
          local num = tonumber(lname:sub(8):match("^%s*(%d+)%s*$"))
          if num and num >= 1 then
            R.page_pts[#R.page_pts + 1] = { t = pos, page = num, ord = i }
          else
            R.marker_warns[#R.marker_warns + 1] = string.format('Invalid marker "%s" at %s', name, Util.fmt_time(pos))
          end
        end
      end
    end
  end
  -- one log line per change (the scan runs after every project change)
  if no_guid ~= (R.no_guid_logged or 0) then
    if no_guid > 0 then Msg.diag(string.format("%d region(s) have no GUID; they use name and position as their key.", no_guid)) end
    R.no_guid_logged = no_guid
  end
  local function by_time(a, b) if a.t ~= b.t then return a.t < b.t end return a.ord < b.ord end
  table.sort(R.scroll_pts, by_time)
  table.sort(R.page_pts, by_time)
  table.sort(R.regions, function(a, b) return a.start < b.start end)
  Project.resolve_regions()
  if R.active_region then R.active_region = Project.region_by_key(R.active_region.key) end
end

---------------------------------------------------------------------------
-- OPENING A PDF / LIBRARY
---------------------------------------------------------------------------
-- Page images are attached to the ImGui context, so ReaImGui does not delete them while the
-- window is hidden (for example in an inactive dock tab). Detach them when the cache drops them.
function PDF.release_image(e)
  -- protected: the image may already be invalid
  if e and e.img and R.ctx then pcall(r.ImGui_Detach, R.ctx, e.img) end
end

function PDF.reset_images()
  for _, e in pairs(R.images) do PDF.release_image(e) end
  R.images = {}; R.image_order = {}; R.page_paths = {}
end

-- Forget the open PDF: page count, render jobs, textures, active region.
function PDF.reset_state()
  R.total = 0; R.job = nil; R.bstate = {}; R.batches_done = 0; PDF.reset_images()
  R.active_region = nil; R.mpage_last = nil
  R.info_job = nil -- a running page-count job is ignored when it finishes
end

function PDF.open_pdf(path, keep_position)
  if not Util.same_path(path, S.pdf_path) then R.force_scale = false end -- the cap belongs to one PDF
  Msg.set_error(nil)
  PDF.reset_state()
  if not path or path == "" then return end
  if not Util.file_exists(path) then Msg.set_error("PDF not found: " .. path); return end
  S.pdf_path = path
  R.pdf_name = Util.name_of(path)
  if PDF.engine() == "poppler" then
    if not R.exe then R.exe = PDF.find_pdftoppm(); PDF.check_pdfinfo() end
    if not R.exe then Msg.set_error(PDF.poppler_help()); return end
    S.pdftoppm_path = R.exe
  end

  -- page count + size: cache first (instant), otherwise in the background (PDF.info_tick)
  local n, info = PDF.read_info_cache(path)
  if n then return PDF.finish_open(path, keep_position, n, info) end
  R.info_job = PDF.start_info(path, keep_position)
  if not R.info_job then
    Msg.set_error("Could not start the PDF engine. Select the other PDF engine in Settings > Display and view.")
  end
end

-- Second half of opening a PDF, once the page count and page size are known.
function PDF.finish_open(path, keep_position, n, info)
  if not n or n < 1 then Msg.set_error("Could not determine the page count (invalid PDF)."); return end
  R.total = n
  R.libpages[path] = n; Util.bump_lib()

  -- Cap texture size: if page 1 at the chosen DPI exceeds MAX_IMAGE_DIM, render with -scale-to instead.
  R.scale_to = nil
  local wpt, hpt = (info or ""):match("Page size:%s*([%d%.]+)%s*x%s*([%d%.]+)")
  R.page_w_pt = tonumber(wpt) -- page width in points (1/72 inch), used for "100%" = real size
  if wpt and math.max(tonumber(wpt), tonumber(hpt)) / 72 * S.dpi > CFG.MAX_IMAGE_DIM then
    R.scale_to = CFG.MAX_IMAGE_DIM
  end
  if R.force_scale then R.scale_to = CFG.MAX_IMAGE_DIM end

  R.cache_dir = PDF.compute_cache_dir(path)
  Util.ensure_dir(R.cache_dir)
  R.prefix = R.cache_dir .. SEP .. "p"
  if not keep_position then S.page = 1; S.scroll_y = 0; S.scroll_x = 0 end
  S.page = Util.clamp(S.page, 1, R.total)
  local view = P.view[path] -- per-PDF zoom
  if view then S.fit_mode, S.zoom = view.fit, Util.clamp(view.zoom, CFG.MIN_ZOOM, CFG.MAX_ZOOM)
  else S.fit_mode, S.zoom = "width", 1.0 end -- no saved zoom: start with "Fit width"
  R.cache_size = nil
  if P.active_pdf ~= path then P.active_pdf = path; Util.mark_pdirty() end
  local reg = R.cur_region_key and Project.region_by_key(R.cur_region_key)
  if reg and reg.pdf and Util.same_path(reg.pdf, path) then R.active_region = reg end
  R.scan_due = Util.now() -- rescan markers whenever a PDF is opened
  Util.mark_dirty()
end

---------------------------------------------------------------------------
-- PORTABLE PATHS (relative to the project folder) + MISSING-PDF RECOVERY
---------------------------------------------------------------------------
-- Folder of the saved project file, or nil for an unsaved project.
function Project.dir()
  if not R.projfn or R.projfn == "" then return nil end
  return Util.dir_of(R.projfn)
end

-- Replaces library entry `old` with `new` everywhere: library, region assignments, active PDF,
-- relative path and the open PDF. If `new` is already in the library, the two entries merge.
function Project.remap_pdf(old, new)
  if Util.same_path(old, new) then return end
  local has_new = false
  for _, p in ipairs(P.pdfs) do if Util.same_path(p, new) then has_new = true end end
  for i = #P.pdfs, 1, -1 do
    if Util.same_path(P.pdfs[i], old) then
      if has_new then table.remove(P.pdfs, i) else P.pdfs[i] = new; has_new = true end
    end
  end
  for key, p in pairs(P.assign) do if Util.same_path(p, old) then P.assign[key] = new end end
  if Util.same_path(P.active_pdf, old) then P.active_pdf = new end
  P.rel[old] = nil
  P.rel[new] = Util.rel_path(new, Project.dir()) or P.rel[new]
  R.libpages[new] = R.libpages[new] or R.libpages[old]
  R.libexists[new] = Util.file_exists(new)
  if Util.same_path(S.pdf_path, old) then S.pdf_path = new end
  if P.view[old] then P.view[new] = P.view[new] or P.view[old]; P.view[old] = nil end
  Util.mark_pdirty()
end

-- Finds every library PDF: 1) relative path from the current project folder, 2) stored absolute
-- path. Adds a relative path for PDFs inside the project folder (also for old projects).
-- Returns the number of PDFs that were found at their relative path.
function Project.resolve_paths()
  local dir = Project.dir()
  local moved = 0
  local list = {}
  for i, p in ipairs(P.pdfs) do list[i] = p end
  for _, abs in ipairs(list) do
    local rel = P.rel[abs]
    local cand = (dir and rel) and Util.join_path(dir, (rel:gsub("/", "\\"))) or nil
    if cand and Util.file_exists(cand) then
      if not Util.same_path(cand, abs) then Project.remap_pdf(abs, cand); moved = moved + 1 end
    elseif Util.file_exists(abs) then
      local r2 = Util.rel_path(abs, dir)
      if r2 and r2 ~= rel then P.rel[abs] = r2; Util.mark_pdirty() end
    end
  end
  if moved > 0 then Project.resolve_regions() end
  R.libexists_t = 0
  return moved
end

-- Number of regions that currently use `path` (manual or automatic assignment).
function Project.region_use_count(path)
  local n = 0
  for _, reg in ipairs(R.regions) do
    if reg.pdf and Util.same_path(reg.pdf, path) then n = n + 1 end
  end
  return n
end

-- Relocate a missing PDF to `new`, then look in the same folder for the other missing PDFs
-- (by file name). Returns the number of other PDFs found.
function Project.relocate_pdf(old, new)
  Project.remap_pdf(old, new)
  local folder = Util.dir_of(new)
  local found = 0
  local list = {}
  for i, p in ipairs(P.pdfs) do list[i] = p end
  for _, p in ipairs(list) do
    if not Util.file_exists(p) then
      local cand = Util.join_path(folder, Util.name_of(p))
      if Util.file_exists(cand) then Project.remap_pdf(p, cand); found = found + 1 end
    end
  end
  Project.resolve_regions()
  R.libexists_t = 0
  -- reload the region under the play cursor if its PDF just came back
  R.cur_region_key = nil
  return found
end

-- Returns true if added, false if it was already in the library.
function Project.add_to_library(path, defer_resolve)
  for _, p in ipairs(P.pdfs) do if Util.same_path(p, path) then return false end end
  P.pdfs[#P.pdfs + 1] = path
  P.rel[path] = Util.rel_path(path, Project.dir())
  if not defer_resolve then Project.resolve_regions() end
  Util.mark_pdirty()
  return true
end

function PDF.browse_add_pdf(open_after)
  local ok, f = r.GetUserFileNameForRead("", "Select a PDF", "pdf")
  if ok and f and f ~= "" then
    Project.import_pdf(f, { open = open_after })
  end
end

---------------------------------------------------------------------------
-- COPY PDFs INTO THE PROJECT (<project folder>\PDFs), non-blocking
--
-- Each import is a job in R.copyq. One job runs at a time and copies a few hundred KB per frame,
-- so REAPER and playback never freeze. The file is written to "<name>.pdf.part" and renamed when
-- complete. The source PDF is only read, never changed or moved.
---------------------------------------------------------------------------

function Project.pdf_dir()
  local d = Project.dir()
  return d and (d .. SEP .. CFG.PDF_SUBDIR) or nil
end

-- true if `path` should be copied: copy mode on, project saved, PDF not already in the project folder
function Project.should_copy(path)
  local d = Project.dir()
  return S.import_copy and d ~= nil and Util.rel_path(path, d) == nil
end

-- Adds a PDF to the library. Copies it into the project first when copy mode is on.
-- opts: open (open when done), region_key (assign to that region when done),
--       remap_from (replace that library entry when done). Returns "queued", true or false.
function Project.import_pdf(src, opts)
  opts = opts or {}
  if not Project.should_copy(src) then
    local added
    if opts.remap_from then Project.remap_pdf(opts.remap_from, src); added = true
    else added = Project.add_to_library(src) end
    if opts.region_key then
      local reg = Project.region_by_key(opts.region_key)
      if reg then Project.assign_region_pdf(reg, src) end
    elseif opts.open then PDF.open_pdf(src, false) end
    return added
  end
  local dst = Project.pdf_dir() .. SEP .. Util.name_of(src)
  for _, j in ipairs(R.copyq) do if Util.same_path(j.dst, dst) then return false end end
  if R.copy and Util.same_path(R.copy.dst, dst) then return false end
  R.copyq[#R.copyq + 1] = { src = src, dst = dst, opts = opts }
  return "queued"
end

function Project.import_for_region(reg, src)
  if Project.should_copy(src) then
    Project.import_pdf(src, { region_key = reg.key })
    R.warn = string.format('Copying "%s" into the project for region "%s"...', Util.name_of(src), reg.name)
  else
    Project.assign_region_pdf(reg, src)
  end
end

-- Library PDFs that are outside the project folder and exist on disk.
-- use_cache: use the existence flags of the Library tab (refreshed every 2 s) instead of
-- opening every file. The Library tab calls this every frame, so it must not touch the disk.
function Project.external_pdfs(use_cache)
  local t, d = {}, Project.dir()
  if not d then return t end
  for _, p in ipairs(P.pdfs) do
    if Util.rel_path(p, d) == nil then
      local exists
      if use_cache then exists = (R.libexists[p] ~= false) else exists = Util.file_exists(p) end
      if exists then t[#t + 1] = p end
    end
  end
  return t
end

function Project.copy_all_into_project()
  local n = 0
  for _, p in ipairs(Project.external_pdfs()) do
    if Project.import_pdf(p, { remap_from = p }) == "queued" then n = n + 1 end
  end
  Msg.notify(string.format("Copying %d PDF(s) into the project folder...", n), false, "library")
end

function Project.copy_pending() return (R.copy and 1 or 0) + #R.copyq end

-- Called when a job is complete; `final` is the path to use (the copy, or the original on failure).
function Project.finish_copy(job, final)
  local o = job.opts
  if o.remap_from then Project.remap_pdf(o.remap_from, final)
  else Project.add_to_library(final, true) end
  Project.resolve_regions(); Util.mark_pdirty(); R.libexists_t = 0
  if o.region_key then
    local reg = Project.region_by_key(o.region_key)
    if reg then Project.assign_region_pdf(reg, final) end
  elseif o.open then
    PDF.open_pdf(final, false)
  end
  -- the region under the play cursor may now be assigned to this PDF: re-evaluate it
  local reg = R.cur_region_key and Project.region_by_key(R.cur_region_key)
  if reg and reg.pdf and Util.same_path(reg.pdf, final) and not Util.same_path(final, S.pdf_path) then
    R.cur_region_key = nil
  end
  if Project.copy_pending() == 0 and not o.region_key then
    Msg.notify("PDF copy into the project folder is complete.", false, "library")
  end
end

function Project.close_copy(job, remove_part)
  if job.fin then job.fin:close(); job.fin = nil end
  if job.fout then job.fout:close(); job.fout = nil end
  if remove_part and job.part then os.remove(job.part) end
end

-- Cancels every pending and running copy (project change, script exit). Partial files are removed.
function Project.cancel_copies()
  if R.copy then Project.close_copy(R.copy, true) end
  R.copy = nil; R.copyq = {}
end

function Project.files_identical(a, b)
  if Util.file_size(a) ~= Util.file_size(b) then return false end
  return PDF.content_key(a) == PDF.content_key(b)
end

-- Starts the next job. Returns false if the job finished at once (identical / skipped / error).
function Project.start_copy(job)
  if Util.same_path(job.src, job.dst) then Project.finish_copy(job, job.dst); return false end
  if not Util.file_exists(job.src) then
    Msg.notify("Source PDF not found: " .. job.src, true, "library"); return false
  end
  Util.ensure_dir(Util.dir_of(job.dst))
  if Util.file_exists(job.dst) then
    if Project.files_identical(job.src, job.dst) then
      Project.finish_copy(job, job.dst); return false -- same file already in the project
    end
    local ans = r.ShowMessageBox(string.format(
      "A different file with the same name is already in the project folder:\n%s\n\n"
      .. "Yes = replace it with:\n%s\n\nNo = keep the existing copy and use it\n\nCancel = skip this PDF",
      job.dst, job.src), CFG.TITLE, 3)
    if ans == 7 then Project.finish_copy(job, job.dst); return false end -- keep existing
    if ans ~= 6 then return false end                                    -- skip
    job.replace = true
  end
  job.part = job.dst .. ".part"
  job.fin = io.open(job.src, "rb")
  job.fout = job.fin and io.open(job.part, "wb")
  if not (job.fin and job.fout) then
    Project.close_copy(job, true)
    Msg.notify("Cannot copy into the project folder; the original PDF is used: " .. job.src, true, "library", true)
    Project.finish_copy(job, job.src)
    return false
  end
  R.copy = job
  return true
end

function Project.copy_tick()
  if not R.copy then
    while #R.copyq > 0 do
      local job = table.remove(R.copyq, 1)
      if Project.start_copy(job) then break end
    end
    if not R.copy then return end
  end
  local job = R.copy
  local deadline = Util.now() + CFG.COPY_FRAME_BUDGET
  while Util.now() < deadline do
    local d = job.fin:read(CFG.COPY_CHUNK)
    if not d then
      Project.close_copy(job, false)
      R.copy = nil
      -- replace safely: the old file becomes a backup first, and is deleted only after the new file
      -- is in place; if that fails, the backup is put back (the old file is never lost)
      local bak = job.replace and (job.dst .. ".chartcue-old") or nil
      if bak then
        os.remove(bak) -- a backup left by an earlier, interrupted replacement
        if not os.rename(job.dst, bak) then
          os.remove(job.part)
          Msg.notify("Could not replace the PDF in the project folder (is it open in another program?); "
            .. "the original PDF is used: " .. job.src, true, "library")
          Project.finish_copy(job, job.src)
          return
        end
      end
      local ok = os.rename(job.part, job.dst)
      if ok then
        if bak then os.remove(bak) end
        Project.finish_copy(job, job.dst)
      else
        if bak then os.rename(bak, job.dst) end -- put the old file back
        os.remove(job.part)
        Msg.notify("Could not finish the copy (is the file in use?); the original PDF is used: "
          .. job.src, true, "library")
        Project.finish_copy(job, job.src)
      end
      return
    end
    if not job.fout:write(d) then
      Project.close_copy(job, true); R.copy = nil
      Msg.notify("Copy failed (disk full?); the original PDF is used: " .. job.src, true, "library")
      Project.finish_copy(job, job.src)
      return
    end
  end
end

function PDF.browse_exe()
  local ok, f = r.GetUserFileNameForRead("", "Select pdftoppm.exe", "exe")
  if ok and f and f ~= "" then
    S.pdftoppm_path = f; Util.mark_dirty()
    R.exe = PDF.find_pdftoppm(); PDF.check_pdfinfo()
    if S.pdf_path ~= "" then PDF.open_pdf(S.pdf_path, true) end
  end
end

---------------------------------------------------------------------------
-- REGION EMPTY STATE HELPERS (clear the display / assign a PDF to a region)
---------------------------------------------------------------------------
-- Clears the page on screen and stops rendering for the previous PDF. The previous PDF is
-- remembered so it can be restored if the user turns region switching off.
function Project.clear_pdf_display()
  if R.total > 0 and S.pdf_path ~= "" then R.stash_pdf = S.pdf_path end
  PDF.reset_state()
  R.cache_dir, R.prefix, R.pdf_name = nil, nil, ""
  R.abs_target = nil
  R.max_x, R.max_y = 0, 0; R.autoscroll_active = false
  S.scroll_y, S.scroll_x = 0, 0
end

function Project.restore_stash()
  local p = R.stash_pdf
  R.stash_pdf = nil; R.cleared_key = nil
  if p and p ~= "" and R.total == 0 and Util.file_exists(p) then PDF.open_pdf(p, true) end
end

-- The one place that changes a region's PDF choice.
-- choice: "auto" (match by name), "ignore", or a PDF path (manual assignment).
function Project.set_region_choice(reg, choice)
  P.names[reg.key] = reg.name
  if choice == "auto" then P.assign[reg.key] = nil; P.ignore[reg.key] = nil
  elseif choice == "ignore" then P.assign[reg.key] = nil; P.ignore[reg.key] = true
  else P.assign[reg.key] = choice; P.ignore[reg.key] = nil end
  Project.resolve_regions(); Util.mark_pdirty()
end

-- Assign `path` to region `reg` (adding it to the library), re-run matching and open it now.
function Project.assign_region_pdf(reg, path)
  Project.add_to_library(path, true)
  Project.set_region_choice(reg, path)
  R.stash_pdf = nil; R.cleared_key = nil; R.choose_existing = false
  R.warn = nil
  if Util.file_exists(path) then
    PDF.open_pdf(path, false)
  else
    R.warn = string.format('PDF for region "%s" is missing: %s', reg.name, path)
  end
  Util.mark_dirty()
end

-- Ignoring a region means "no PDF here": the previous PDF is NOT kept on screen. The region shows
-- its empty state (with options to add a PDF or stop ignoring).
function Project.ignore_region(reg)
  Project.set_region_choice(reg, "ignore")
  R.choose_existing = false
  if R.total > 0 then Project.clear_pdf_display() end
  R.cleared_key = reg.key
end

function Project.unignore_region(reg)
  Project.set_region_choice(reg, "auto")
  R.choose_existing = false
  R.cur_region_key = nil -- re-trigger region entry: opens its PDF if matched, else shows the empty state
end

---------------------------------------------------------------------------
-- IMAGES (textures)
---------------------------------------------------------------------------
function PDF.png_size(path)
  local f = io.open(path, "rb"); if not f then return nil end
  local h = f:read(24); f:close()
  if not h or #h < 24 or h:sub(2, 4) ~= "PNG" then return nil end
  local w, hh = string.unpack(">I4I4", h, 17)
  return w, hh
end

function PDF.get_page_image(p)
  if R.total == 0 then return nil end
  -- A texture already in memory stays usable even if its file was removed from the cache.
  local e = R.images[p]
  if e then
    if r.ImGui_ValidatePtr(e.img, "ImGui_Image*") then return e.img, e.w, e.h end
    -- stale handle: drop it and load the page again from the cache file
    Msg.diag("Image for page " .. p .. " failed validation; reloading.")
    R.images[p] = nil
    for i, q in ipairs(R.image_order) do if q == p then table.remove(R.image_order, i); break end end
  end
  if not PDF.page_ready(p) then return nil end
  local path = PDF.find_page_file(p)
  if not path then
    Msg.set_error("Missing cached image for page " .. p .. "; re-rendering.")
    R.bstate[PDF.batch_of(p)] = nil; R.page_paths[p] = nil
    return nil
  end
  local w, h = PDF.png_size(path)
  local too_big = w and (w > CFG.MAX_IMAGE_DIM or h > CFG.MAX_IMAGE_DIM)
  local ok, img
  if not too_big then ok, img = pcall(r.ImGui_CreateImage, path) end
  if too_big or not ok or not img or not w then
    local msg = tostring(img)
    if not R.scale_to and (too_big or msg:lower():find("big", 1, true)) and S.pdf_path ~= "" then
      R.force_scale = true
      PDF.open_pdf(S.pdf_path, true)
      return nil
    end
    Msg.set_error("Failed to load image for page " .. p .. ": " .. msg
      .. (R.scale_to and " (already scaled to max size; try a lower DPI)" or ""))
    return nil
  end
  r.ImGui_Attach(R.ctx, img)
  R.images[p] = { img = img, w = w, h = h }
  table.insert(R.image_order, p)
  while #R.image_order > CFG.MAX_CACHED_TEXTURES do
    local old = table.remove(R.image_order, 1)
    PDF.release_image(R.images[old])
    R.images[old] = nil
  end
  return img, w, h
end

---------------------------------------------------------------------------
-- NAVIGATION / SCROLL LOGIC
---------------------------------------------------------------------------
function Util.playing()
  local st = r.GetPlayState()
  return ((st & 1) ~= 0 or (st & 4) ~= 0) and (st & 2) == 0
end

-- The ONE autoscroll mode state: "off" | "marker" | "cues"
-- Saved per project (P.scroll_mode). A project without one uses the default in settings.ini.
-- "fixed" (Fixed speed, removed in 4.8) can still be saved in older projects: it means "off".
function Nav.scroll_mode()
  local m = (P.scroll_mode ~= "") and P.scroll_mode or S.scroll_mode
  if m == "marker" or m == "cues" then return m end
  return "off"
end

-- Writes only to the project; the settings.ini default does not change.
function Nav.set_scroll_mode(m)
  P.scroll_mode = m
  R.mpage_last = nil
  if m ~= "cues" then R.rec = false end -- recording needs the Cue list mode
  Util.mark_pdirty()
end

-- A region without a PDF blocks page turns, unless its last page is kept on screen (R.kept_key).
function Nav.page_blocked()
  return R.empty_region ~= nil and R.kept_key ~= R.empty_region.key
end

function Nav.go_page(p)
  if R.total == 0 or Nav.page_blocked() then return end
  p = Util.clamp(p, 1, R.total)
  if p == S.page then return end
  S.page = p; S.scroll_y = 0; S.scroll_x = 0; R.abs_target = nil
  if Util.playing() then R.flash_t = Util.now() end -- page-turn flash
  Util.mark_dirty()
end

function Nav.scroll_by(dy)
  S.scroll_y = Util.clamp(S.scroll_y + dy, 0, R.max_y)
  R.abs_target = nil; Util.touch_override(); Util.mark_dirty()
end

function Midi.decode_relative(v)
  local d
  local e = S.rel_encoding
  if e == 1 then d = (v < 64) and v or (v - 128)          -- two's complement
  elseif e == 2 then d = v - 64                            -- binary offset
  elseif e == 3 then d = (v < 64) and v or -(v - 64)       -- sign magnitude
  else d = (v > 64 and 1) or (v < 64 and -1) or 0 end      -- direction only
  if S.rel_invert then d = -d end
  return d
end

-- source: "direct MIDI input" or "action-bound MIDI CC"; cc is nil when unknown
function Midi.handle_scroll_value(v, source, cc)
  v = Util.clamp(math.floor(v), 0, 127)
  R.last_cc = v
  Util.touch_override()
  R.dbg.cc, R.dbg.val, R.dbg.src = cc, v, source
  if S.mode == "absolute" then
    R.abs_target = (v / 127) * R.max_y
    R.dbg.decoded = string.format("absolute target %.0f px (%.0f%%)", R.abs_target, v / 127 * 100)
  else
    local d = Midi.decode_relative(v)
    S.scroll_y = Util.clamp(S.scroll_y + d * S.sensitivity, 0, R.max_y)
    R.abs_target = nil
    R.dbg.decoded = string.format("relative %+d tick(s): %s", d, d > 0 and "down" or (d < 0 and "up" or "no movement"))
  end
  Util.mark_dirty()
end

function Midi.handle_page_cc(cc, v)
  if not S.midi_page_turn then return end
  if Nav.page_blocked() or R.total == 0 then return end -- no PDF for this region (and no kept page)
  local prev = R.page_cc_state[cc] or 0
  R.page_cc_state[cc] = v
  if v >= 64 and prev < 64 then
    if cc == S.cc_page_next then Nav.go_page(S.page + 1)
    elseif cc == S.cc_page_prev then Nav.go_page(S.page - 1) end
  end
end

function Midi.poll_forwarded_midi()
  local q = r.GetExtState(CFG.EXT, "midi_q")
  if q ~= "" then
    r.SetExtState(CFG.EXT, "midi_q", "", false)
    for n in q:gmatch("(%-?%d+),") do Midi.handle_scroll_value(tonumber(n), "action-bound MIDI CC", nil) end
  end
  if r.GetExtState(CFG.EXT, "quit") == "1" then
    r.SetExtState(CFG.EXT, "quit", "", false); R.quit = true
  end
end

function Midi.poll_direct_midi()
  if not S.direct_midi or not r.MIDI_GetRecentInputEvent then return end
  local events, idx, newest = {}, 0, nil
  while idx < 256 do
    local seq, buf = r.MIDI_GetRecentInputEvent(idx)
    if not seq or seq == 0 then break end
    if seq <= R.last_midi_seq then break end
    newest = newest or seq
    events[#events + 1] = buf
    idx = idx + 1
  end
  if newest then R.last_midi_seq = newest end
  local cc = (S.mode == "absolute") and S.cc_abs or S.cc_rel
  for i = #events, 1, -1 do
    local b = events[i]
    if #b >= 3 then
      local st, d1, d2 = b:byte(1), b:byte(2), b:byte(3)
      if (st & 0xF0) == 0xB0 then
        if d1 == cc then Midi.handle_scroll_value(d2, "direct MIDI input", d1) end
        if d1 == S.cc_page_next or d1 == S.cc_page_prev then Midi.handle_page_cc(d1, d2) end
        if S.midi_add_cue and (d1 == S.cc_add_cue or d1 == S.cc_add_scroll) then
          local st_key = (d1 == S.cc_add_cue) and "cue_turn" or "cue_scroll"
          local prev = R.page_cc_state[st_key] or 0
          R.page_cc_state[st_key] = d2
          if d2 >= 64 and prev < 64 and UI.can_record() then
            if st_key == "cue_turn" then Cues.add_page_turn() else Cues.add_scroll_point() end
          end
        end
      end
    end
  end
end

-- Page / scroll from time points. Used by the Markers mode (PDFPAGE / PDFSCROLL markers) and by
-- the Cue list mode (page_pts / scroll_pts built from the cue list).
function Nav.timeline_tick(is_play, overriding, page_pts, scroll_pts)
  page_pts, scroll_pts = page_pts or R.page_pts, scroll_pts or R.scroll_pts
  R.autoscroll_active = false
  if not is_play then return end
  local pos = r.GetPlayPosition()
  local reg = R.active_region
  local lo, hi = -math.huge, math.huge
  -- inside a region, its markers / cues work from the region start to the region end
  if reg then
    lo, hi = reg.start, reg.stop
    if pos >= hi or pos < lo then return end
  end

  -- find the page segment containing pos
  local seg_lo, seg_hi, page = lo, hi, nil
  -- "Turn pages early" (P.turn_early beats): a page turn counts as reached that many beats before
  -- its time, so you can read ahead. The new page starts at the top until its scroll points come.
  local pos_page = pos
  if P.turn_early > 0 then pos_page = r.TimeMap2_QNToTime(0, r.TimeMap2_timeToQN(0, pos) + P.turn_early) end
  for _, pp in ipairs(page_pts) do
    if pp.t >= lo and pp.t < hi then
      if pp.t <= pos_page then page = pp.page; seg_lo = pp.t
      else seg_hi = math.min(seg_hi, pp.t); break end
    end
  end
  if page == nil and reg then page = 1 end
  if page ~= R.mpage_last then
    R.mpage_last = page
    if page and page <= R.total and page ~= S.page then Nav.go_page(page) end
  end

  -- interpolate scroll percentage between PDFSCROLL markers inside the segment
  local prev, nxt
  local lower = math.max(seg_lo, lo)
  for _, sp in ipairs(scroll_pts) do
    if sp.t >= lower and sp.t < seg_hi then
      if sp.t <= pos then prev = sp else nxt = sp; break end
    end
  end
  local pct = 0
  if prev then
    if nxt then pct = prev.pct + (nxt.pct - prev.pct) * (pos - prev.t) / (nxt.t - prev.t)
    else pct = prev.pct end
  end
  R.marker_pct = pct
  if not overriding then
    R.autoscroll_active = true
    S.scroll_y = Util.clamp(pct / 100 * R.max_y, 0, R.max_y)
  end
end

function Nav.update_motion()
  local overriding = Util.now() < R.override_until
  if R.abs_target then
    local diff = R.abs_target - S.scroll_y
    if math.abs(diff) < 0.5 then S.scroll_y = R.abs_target; R.abs_target = nil
    else S.scroll_y = S.scroll_y + diff * CFG.ABS_SMOOTHING end
  end
  local is_play = Util.playing()
  if is_play and not R.was_playing then R.mpage_last = nil end
  R.was_playing = is_play
  R.autoscroll_active = false
  local mode = Nav.scroll_mode()
  -- no PDF for the current region: every autoscroll mode is disabled
  if R.empty_region or R.total == 0 then mode = "off" end
  if mode == "marker" then
    Nav.timeline_tick(is_play, overriding)
  elseif mode == "cues" then
    if is_play then
      local pp, sp = Cues.points(Cues.playing_region())
      Nav.timeline_tick(is_play, overriding, pp, sp)
    else
      R.autoscroll_active = false
    end
  end
  S.scroll_y = Util.clamp(S.scroll_y, 0, R.max_y)
  S.scroll_x = Util.clamp(S.scroll_x, 0, R.max_x)
end

---------------------------------------------------------------------------
-- REGION TRACKING / PROJECT SWITCHING
---------------------------------------------------------------------------
function Project.time_pos()
  if Util.playing() then return r.GetPlayPosition() end
  return r.GetCursorPosition()
end

function Project.region_at(pos)
  local best
  for _, reg in ipairs(R.regions) do
    if pos >= reg.start and pos < reg.stop then
      if not best or reg.start >= best.start then best = reg end
    end
  end
  return best
end

function Project.on_enter_region(reg)
  R.warn = nil
  R.cleared_key = nil
  R.choose_existing = false
  if not P.auto_switch then return end
  if reg.status == "auto" or reg.status == "assigned" then
    if not Util.file_exists(reg.pdf) then
      R.warn = string.format('PDF for region "%s" is missing: %s', reg.name, reg.pdf)
      return
    end
    R.stash_pdf = nil
    if R.total == 0 or not Util.same_path(reg.pdf, S.pdf_path) then
      PDF.open_pdf(reg.pdf, false)
    end
    S.page = 1; S.scroll_y = 0; S.scroll_x = 0; R.abs_target = nil
    R.active_region = reg
    R.mpage_last = nil
    Util.mark_dirty()
  elseif S.keep_last_page and Util.playing() and R.total > 0 then
    -- no PDF here, but the show goes on: keep the last page on screen (a banner says why)
    R.kept_key = reg.key
    R.cleared_key = reg.key
  else
    -- unassigned, ambiguous or ignored: no PDF here, so do not keep showing the previous PDF
    Project.clear_pdf_display()
    R.cleared_key = reg.key
  end
end

function Project.region_tick()
  local reg = Project.region_at(Project.time_pos())
  local key = reg and reg.key or nil
  if key ~= R.cur_region_key then
    R.cur_region_key = key
    R.kept_key = nil
    if reg then Project.on_enter_region(reg) end
  end
  -- kept page: when playback stops (or the option is turned off), show the region's empty state
  if R.kept_key and (not Util.playing() or not S.keep_last_page) then
    R.kept_key = nil
    if reg and R.cleared_key == reg.key then Project.clear_pdf_display() end
  end
  -- the region we showed an empty state for just got a PDF (e.g. added to the library): load it
  if reg and R.cleared_key == reg.key and (reg.status == "auto" or reg.status == "assigned") then
    Project.on_enter_region(reg)
  end
  -- empty state flag for this frame
  if reg and P.auto_switch
      and (reg.status == "unassigned" or reg.status == "ambiguous" or reg.status == "ignored") then
    R.empty_region = reg
  else
    R.empty_region = nil
  end
end

-- Content fingerprint of a project: tracks (count, first / last GUID), markers, regions, length.
-- "Save as" keeps it; opening another project in the same tab changes it.
function Project.fingerprint(proj)
  if not Project.valid_proj(proj) then return "" end
  local nt = r.CountTracks(proj)
  local g1 = nt > 0 and r.GetTrackGUID(r.GetTrack(proj, 0)) or ""
  local g2 = nt > 0 and r.GetTrackGUID(r.GetTrack(proj, nt - 1)) or ""
  local _, nm, nr = r.CountProjectMarkers(proj)
  return string.format("%d|%s|%s|%d|%d|%.3f", nt, g1, g2, nm or 0, nr or 0, r.GetProjectLength(proj))
end

function Project.check_project(force)
  local proj, fn = r.EnumProjects(-1)
  fn = fn or ""
  if not force and proj == R.proj and fn == R.projfn then return end

  -- Did the project we were showing close, or was it replaced in the same tab?
  --   closed:   its project tab was closed (the pointer is no longer valid)
  --   replaced: same tab, but File > Close / New project ("" file name) or File > Open project.
  --             "Save as" (or a first save) keeps both the content fingerprint and the Chart Cue
  --             data; anything else is another project, and the in-memory config never moves to it.
  local closed, replaced = false, false
  if R.proj ~= nil and not force then
    if not Project.valid_proj(R.proj) then
      closed = true
    elseif proj == R.proj and fn ~= R.projfn then
      if fn == "" then
        replaced = true
      else
        local n, txt = r.GetProjExtState(proj, CFG.PEXT, CFG.PEXT_KEY)
        if not (n and n > 0) then txt = "" end
        replaced = (txt ~= (R.plast_txt or "")) or (Project.fingerprint(proj) ~= R.proj_fp)
      end
    end
  end
  if (closed or replaced) and S.close_with_project then
    Msg.diag(closed and "Project tab closed; closing Chart Cue." or "Project replaced; closing Chart Cue.")
    R.proj = nil   -- never write the old config into the next project
    R.quit = true
    return
  end
  if replaced then R.proj = nil end -- option off: load the new project's config, do not save the old one
  if not force and proj == R.proj then
    -- same project, new file name (first save or "Save as"): the config is already in the
    -- project, so keep it in memory; only the file name changes.
    R.projfn = fn
    R.psaveable = (fn ~= "")
    R.proj_fp = Project.fingerprint(proj)
    Project.resolve_paths()
    Project.save_project_cfg()
    R.pdirty = false
    return
  end
  if R.proj ~= nil then Project.save_project_cfg() end -- flush into the project we are leaving
  R.proj, R.projfn = proj, fn
  R.psaveable = (fn ~= "")
  R.proj_fp = Project.fingerprint(proj)
  local src
  P, src = Project.load_project_cfg(proj)
  R.plast_txt = (src == "rpp") and Project.serialize_cfg() or nil
  Project.resolve_paths() -- find PDFs relative to the (possibly moved) project folder
  R.cur_region_key = nil; R.active_region = nil
  R.mpage_last = nil; R.warn = nil; R.import = nil; R.confirm_remove = nil
  R.empty_region = nil; R.stash_pdf = nil; R.cleared_key = nil; R.choose_existing = false
  Project.cancel_copies() -- pending copies belong to the project we left
  Project.scan_project()
  R.state_cc = r.GetProjectStateChangeCount(0)
  if P.active_pdf ~= "" and Util.file_exists(P.active_pdf) then
    if not Util.same_path(P.active_pdf, S.pdf_path) or R.total == 0 then PDF.open_pdf(P.active_pdf, true) end
  elseif R.total == 0 and S.pdf_path ~= "" and Util.file_exists(S.pdf_path) then
    PDF.open_pdf(S.pdf_path, true)
  end
end

function Project.project_tick()
  Project.check_project(false)
  local cc = r.GetProjectStateChangeCount(0)
  if cc ~= R.state_cc then
    R.state_cc = cc; R.scan_due = R.scan_due or (Util.now() + CFG.MARKER_RESCAN_DELAY)
    R.proj_fp = Project.fingerprint(R.proj) -- kept current, so a later file-name change can be judged
  end
  if R.scan_due and Util.now() >= R.scan_due then R.scan_due = nil; Project.scan_project() end
  if R.pdirty and Util.now() - R.plast > 1.5 then
    if Project.save_project_cfg() then R.pdirty = false end
    R.plast = Util.now()
  end
end

---------------------------------------------------------------------------
-- DIRECTORY HELPERS / CACHE MANAGEMENT
---------------------------------------------------------------------------
function Util.refresh_dir(d) r.EnumerateFiles(d, -1); r.EnumerateSubdirectories(d, -1) end

function Util.list_files(d)
  Util.refresh_dir(d)
  local t, i = {}, 0
  while true do local f = r.EnumerateFiles(d, i); if not f then break end; t[#t + 1] = f; i = i + 1 end
  return t
end

function Util.list_subdirs(d)
  Util.refresh_dir(d)
  local t, i = {}, 0
  while true do local f = r.EnumerateSubdirectories(d, i); if not f then break end; t[#t + 1] = f; i = i + 1 end
  return t
end

-- Cache size, calculated over several frames (CFG.IMPORT_FRAME_BUDGET per frame): R.size_job.
function Util.start_dir_size(root, depth)
  R.size_job = { dirs = { { d = root, depth = depth } }, files = nil, fi = 0, cur = nil, total = 0 }
end

function Util.dir_size_tick()
  local j = R.size_job
  if not j then return end
  local deadline = Util.now() + CFG.IMPORT_FRAME_BUDGET
  while Util.now() < deadline do
    if not j.files then
      local e = table.remove(j.dirs)
      if not e then R.cache_size, R.size_job = j.total, nil; return end
      j.cur, j.files, j.fi = e.d, Util.list_files(e.d), 0
      if e.depth > 0 then
        for _, sd in ipairs(Util.list_subdirs(e.d)) do j.dirs[#j.dirs + 1] = { d = e.d .. SEP .. sd, depth = e.depth - 1 } end
      end
    else
      j.fi = j.fi + 1
      local f = j.files[j.fi]
      if f then j.total = j.total + Util.file_size(j.cur .. SEP .. f) else j.files = nil end
    end
  end
end

-- Deletes all `folders` with ONE cmd.exe (one .bat, started without waiting; the .bat deletes itself).
-- Only folders inside CFG.CACHE_ROOT are deleted.
function PDF.rmdir_all(folders)
  local lines = { "@echo off", "chcp 65001 >nul" }
  for _, path in ipairs(folders) do
    if path:sub(1, #CFG.CACHE_ROOT) == CFG.CACHE_ROOT and #path > #CFG.CACHE_ROOT + 1 then
      lines[#lines + 1] = string.format('rmdir /S /Q "%s"', PDF.bat_escape(path))
    end
  end
  if #lines == 2 then return end
  R.cache_clear_t = Util.now()
  R.clear_seq = R.clear_seq + 1
  local bat = CFG.TMP_DIR .. SEP .. "clear_" .. R.clear_seq .. ".bat"
  lines[#lines + 1] = string.format('del /F /Q "%s"', PDF.bat_escape(bat))
  local f = io.open(bat, "wb")
  if not f then return end
  f:write(table.concat(lines, "\r\n") .. "\r\n"); f:close()
  r.ExecProcess('cmd.exe /C "' .. bat .. '"', CFG.EXEC_NOWAIT)
end

function Util.fmt_bytes(n)
  if n >= 1048576 then return string.format("%.1f MB", n / 1048576) end
  return string.format("%.0f KB", n / 1024)
end

-- Clears the cache of the current PDF but never deletes the page currently on screen.
function PDF.clear_current_cache()
  if not R.cache_dir then return end
  if R.job then Msg.set_error("Wait for the current render to finish before clearing the cache."); return end
  local keep = (R.total > 0) and PDF.find_page_file(S.page) or nil
  local parent = Util.dir_of(R.cache_dir)
  local folders = {}
  for _, sd in ipairs(Util.list_subdirs(parent)) do
    local full = parent .. SEP .. sd
    if full ~= R.cache_dir then folders[#folders + 1] = full end
  end
  PDF.rmdir_all(folders)
  for _, f in ipairs(Util.list_files(R.cache_dir)) do
    local full = R.cache_dir .. SEP .. f
    if full ~= keep then os.remove(full) end
  end
  R.bstate = {}; R.batches_done = 0; R.page_paths = {}
  R.cache_size = nil
end

function PDF.clear_all_cache()
  if R.job then Msg.set_error("Wait for the current render to finish before clearing the cache."); return end
  local current_parent = R.cache_dir and Util.dir_of(R.cache_dir) or nil
  local folders = {}
  for _, sd in ipairs(Util.list_subdirs(CFG.CACHE_ROOT)) do
    local full = CFG.CACHE_ROOT .. SEP .. sd
    if full ~= current_parent then folders[#folders + 1] = full end
  end
  PDF.rmdir_all(folders)
  if current_parent then PDF.clear_current_cache() end
  R.cache_size = nil
end

---------------------------------------------------------------------------
-- FOLDER PICKER (PowerShell FolderBrowserDialog, separate process) + INCREMENTAL IMPORT
--
-- The dialog runs in its own powershell.exe process, launched with "don't wait", so REAPER keeps
-- running (and playing) while it is open. PowerShell writes the chosen folder to a temporary UTF-8
-- file (never through the command line, so spaces / Unicode / apostrophes are safe) and then a
-- ".done" marker ("ok", "cancel" or "error: ..."). Each frame we poll for the marker.
---------------------------------------------------------------------------
local PS_PICKER_SCRIPT = [=[
$ErrorActionPreference = 'Stop'
$out  = Join-Path $PSScriptRoot 'folder_pick.txt'
$done = Join-Path $PSScriptRoot 'folder_pick.done'
$utf8 = New-Object System.Text.UTF8Encoding($false)
try {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  [System.Windows.Forms.Application]::EnableVisualStyles()
  $owner = New-Object System.Windows.Forms.Form
  $owner.TopMost = $true
  $owner.ShowInTaskbar = $false
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  $dlg.Description = 'Select a folder containing PDFs to add to the library'
  $dlg.ShowNewFolderButton = $false
  $result = $dlg.ShowDialog($owner)
  if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    [System.IO.File]::WriteAllText($out, $dlg.SelectedPath, $utf8)
    [System.IO.File]::WriteAllText($done, 'ok', $utf8)
  } else {
    [System.IO.File]::WriteAllText($done, 'cancel', $utf8)
  }
} catch {
  [System.IO.File]::WriteAllText($done, ('error: ' + $_.Exception.Message), $utf8)
}
]=]

-- One message system: a message shows for CFG.MSG_SECONDS in the status bar and, when it has a
-- source ("library", "project", "help"), also in that place of the UI.
-- sticky: the message stays until its "x" is clicked or another message replaces it
-- (use it for messages that ask the user to do something).
function Msg.notify(msg, is_err, source, sticky)
  R.msg = { text = msg, err = is_err and true or false, t = Util.now(), src = source, sticky = sticky or nil }
end

-- timed_only: ignore the sticky flag (the status bar has no "x", so it uses the time rule only)
function Msg.recent(source, timed_only)
  local m = R.msg
  local live = (m and m.sticky and not timed_only) or (m and Util.now() - m.t < CFG.MSG_SECONDS)
  if m and live and (source == nil or m.src == source) then return m end
  return nil
end

function Project.start_folder_pick()
  if R.picker or R.import then return end
  Util.ensure_dir(CFG.TMP_DIR)
  local ps1 = CFG.TMP_DIR .. SEP .. "pick_folder.ps1"
  local out_f = CFG.TMP_DIR .. SEP .. "folder_pick.txt"
  local done_f = CFG.TMP_DIR .. SEP .. "folder_pick.done"
  os.remove(out_f); os.remove(done_f)
  local f = io.open(ps1, "wb")
  if not f then Msg.notify("Cannot write the folder-picker script to " .. CFG.TMP_DIR, true, "library"); return end
  f:write((PS_PICKER_SCRIPT:gsub("\n", "\r\n"))); f:close()
  local res = r.ExecProcess('powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "' .. ps1 .. '"',
    CFG.EXEC_NOWAIT)
  if res == nil then
    Msg.notify("Could not start PowerShell. Antivirus or a company policy can block it.", true, "library")
    return
  end
  R.picker = { started = Util.now(), out_f = out_f, done_f = done_f }
  R.msg = nil
end

function Project.begin_import(folder)
  R.import = {
    dirs = { folder }, cur = nil, phase = "files", fi = 0, si = 0,
    added = 0, skipped = 0, scanned = 0, recursive = S.include_subfolders, folder = folder,
  }
  R.msg = nil
end

function Project.pick_tick()
  local pk = R.picker
  if not pk then return end
  local d = Util.read_all(pk.done_f, 1024)
  if not d then
    if Util.now() - pk.started > CFG.PICKER_TIMEOUT_SEC then
      os.remove(pk.out_f); R.picker = nil
      Msg.notify("Folder selection timed out.", true, "library")
    end
    return
  end
  local out = Util.read_all(pk.out_f, 4096)
  os.remove(pk.done_f); os.remove(pk.out_f)
  R.picker = nil
  d = Util.trim(d)
  if d == "ok" and out then
    if out:sub(1, 3) == "\239\187\191" then out = out:sub(4) end -- strip UTF-8 BOM if present
    out = Util.trim((out:gsub("[\r\n]+", "")))
    if out ~= "" then
      if out:sub(-1) == ":" then out = out .. SEP end
      Project.begin_import(out)
      return
    end
  end
  if d:sub(1, 5) == "error" then Msg.notify("Folder dialog failed: " .. d, true, "library")
  else Msg.notify("Folder selection cancelled.", false, "library") end
end

function Project.finish_import()
  local im = R.import
  R.import = nil
  Project.resolve_regions() -- re-run region matching for the whole new library
  Util.mark_pdirty()
  R.libexists_t = 0
  Msg.notify(string.format("Added %d PDF(s), skipped %d duplicate(s).", im.added, im.skipped), false, "library")
  -- If the play cursor sits in a region that just became assigned to a different PDF, trigger the switch.
  local reg = R.cur_region_key and Project.region_by_key(R.cur_region_key)
  if reg and (reg.status == "auto" or reg.status == "assigned") and not Util.same_path(reg.pdf, S.pdf_path) then
    R.cur_region_key = nil
  end
end

function Project.import_tick()
  local im = R.import
  if not im then return end
  local deadline = Util.now() + CFG.IMPORT_FRAME_BUDGET
  while Util.now() < deadline do
    if not im.cur then
      im.cur = table.remove(im.dirs, 1)
      if not im.cur then Project.finish_import(); return end
      Util.refresh_dir(im.cur); im.fi = 0; im.si = 0; im.phase = "files"
    end
    if im.phase == "files" then
      local f = r.EnumerateFiles(im.cur, im.fi)
      if not f then
        im.phase = im.recursive and "subs" or "done"
      else
        im.fi = im.fi + 1; im.scanned = im.scanned + 1
        if f:lower():match("%.pdf$") then
          if Project.import_pdf(Util.join_path(im.cur, f), {}) then im.added = im.added + 1
          else im.skipped = im.skipped + 1 end
        end
      end
    elseif im.phase == "subs" then
      local sd = r.EnumerateSubdirectories(im.cur, im.si)
      if not sd then im.phase = "done"
      else im.si = im.si + 1; im.dirs[#im.dirs + 1] = Util.join_path(im.cur, sd) end
    else
      im.cur = nil
    end
  end
end

---------------------------------------------------------------------------
-- CUE LIST: page / scroll changes per region, stored in the project data (not as markers).
-- A cue = { pos, page, scroll }. pos is measured from the region start (from the project start
-- for "_project"), in quarter-note beats or in seconds (P.cue_unit, chosen per project).
-- During playback the cues become time points for Nav.timeline_tick, exactly like the markers.
---------------------------------------------------------------------------

function Cues.key(reg) return reg and reg.key or "_project" end
function Cues.origin(reg) return reg and reg.start or 0 end

-- region used for playback: the region of the open PDF, else the region under the play cursor
function Cues.playing_region()
  return R.active_region or Project.region_at(Project.time_pos())
end

function Cues.list(reg) return P.cues[Cues.key(reg)] or {} end

function Cues.to_time(reg, pos, unit)
  local o = Cues.origin(reg)
  if (unit or P.cue_unit) == "seconds" then return o + pos end
  return r.TimeMap2_QNToTime(0, r.TimeMap2_timeToQN(0, o) + pos)
end

function Cues.from_time(reg, t, unit)
  local o = Cues.origin(reg)
  if (unit or P.cue_unit) == "seconds" then return t - o end
  return r.TimeMap2_timeToQN(0, t) - r.TimeMap2_timeToQN(0, o)
end

function Cues.sort(list) table.sort(list, function(a, b) return a.pos < b.pos end) end

-- Text for the position column: "bar.beat.hundredths" (beats) or "m:ss.hh" from the region start.
function Cues.label(reg, pos)
  if P.cue_unit == "seconds" then
    local sgn = pos < 0 and "-" or ""
    pos = math.abs(pos)
    return string.format("%s%d:%05.2f", sgn, math.floor(pos / 60), pos % 60)
  end
  return r.format_timestr_pos(Cues.to_time(reg, pos), "", 2)
end

function Cues.parse_label(reg, text)
  text = Util.trim(text or "")
  if text == "" then return nil end
  if P.cue_unit == "seconds" then
    local m, sec = text:match("^(%d+):(%d+%.?%d*)$")
    if m then return tonumber(m) * 60 + tonumber(sec) end
    return tonumber(text)
  end
  if not text:match("^[%d%.]+$") then return nil end
  return Cues.from_time(reg, r.parse_timestr_pos(text, 2))
end

-- Time points for playback (cached until the cues, the project or the tempo change).
-- A page point is added only when the page changes, so the scroll moves smoothly between cues.
function Cues.points(reg)
  local key = Cues.key(reg)
  local c = R.cue_cache
  if c and c.P == P and c.key == key and c.ver == R.lib_ver and c.cc == R.state_cc and c.start == Cues.origin(reg) then
    return c.pp, c.sp
  end
  local pp, sp, last_page = {}, {}, nil
  for _, cue in ipairs(Cues.list(reg)) do
    local t = Cues.to_time(reg, cue.pos)
    if cue.page and cue.page ~= last_page then pp[#pp + 1] = { t = t, page = cue.page }; last_page = cue.page end
    if cue.scroll then sp[#sp + 1] = { t = t, pct = cue.scroll } end
  end
  R.cue_cache = { P = P, key = key, ver = R.lib_ver, cc = R.state_cc, start = Cues.origin(reg), pp = pp, sp = sp }
  return pp, sp
end

-- Adds (or replaces) a cue at a position. Returns the cue.
function Cues.put(reg, pos, page, scroll)
  local key = Cues.key(reg)
  P.cues[key] = P.cues[key] or {}
  local list = P.cues[key]
  for _, c in ipairs(list) do
    if math.abs(c.pos - pos) < CFG.CUE_SAME_POS then
      c.page, c.scroll = page or c.page, scroll or c.scroll
      Util.mark_pdirty(); return c
    end
  end
  local c = { pos = pos, page = page, scroll = scroll }
  list[#list + 1] = c
  Cues.sort(list); Util.mark_pdirty()
  return c
end

-- Highest page of the PDF that a region uses (nil if unknown: then no check).
function Cues.max_page(reg)
  local pdf = (reg and reg.pdf) or S.pdf_path
  if not pdf or pdf == "" then return nil end
  if Util.same_path(pdf, S.pdf_path) and R.total > 0 then return R.total end
  local n = R.libpages[pdf]
  if type(n) == "number" then return n end
  n = PDF.read_info_cache(pdf)
  if n then R.libpages[pdf] = n; Util.bump_lib() end -- read the cache file only once
  return n
end

-- Page of the last cue before `pos` that has a page (nil if none).
function Cues.page_before(list, pos)
  local pg
  for _, c in ipairs(list) do
    if c.pos < pos - CFG.CUE_SAME_POS then
      if c.page then pg = c.page end
    else break end
  end
  return pg
end

-- Common start for both recording actions. Returns ok, reg, list, pos.
-- The keys and MIDI buttons call the recording actions only in Cue list mode.
function Cues.record_start()
  if R.total == 0 then Msg.notify("Open a PDF first, then add cues.", true, "cues"); return false end
  local t = Project.time_pos()
  local reg = Project.region_at(t)
  local key = Cues.key(reg)
  P.cues[key] = P.cues[key] or {}
  local pos = math.floor(Cues.from_time(reg, t) * 1000 + 0.5) / 1000
  if R.cue_edit_key ~= "_all" then R.cue_edit_key = nil end -- the editor shows this song
  return true, reg, P.cues[key], pos
end

-- "Add page turn" (C key, MIDI): the page after the cue before it (first page turn = page 2),
-- at the top of the page. Following cues are renumbered when the new page would repeat.
function Cues.add_page_turn()
  local ok, reg, list, pos = Cues.record_start()
  if not ok then return end
  local page = (Cues.page_before(list, pos) or 1) + 1
  local maxp = Cues.max_page(reg)
  if maxp and page > maxp then
    Msg.notify(string.format("No page turn added: this PDF has only %d page(s).", maxp), true, "cues"); return
  end
  local replacing = false
  for _, c in ipairs(list) do if math.abs(c.pos - pos) < CFG.CUE_SAME_POS then replacing = true end end
  if not replacing then
    local clash = false
    for _, c in ipairs(list) do if c.pos > pos and c.page == page then clash = true end end
    if clash then -- renumber the following page cues (5 -> 6, 6 -> 7 ...)
      for _, c in ipairs(list) do
        if c.pos > pos and c.page then c.page = maxp and math.min(c.page + 1, maxp) or (c.page + 1) end
      end
    end
  end
  Cues.put(reg, pos, page, 0)
  if not Util.playing() then Nav.go_page(page) end
  Msg.notify(string.format("Page turn added at %s: page %d%s.", Cues.label(reg, pos), page,
    reg and (' in "' .. reg.name .. '"') or ""), false, "cues")
end

-- "Add scroll point" (S key, MIDI): the page of the cue before it, with the current scroll position.
function Cues.add_scroll_point()
  local ok, reg, list, pos = Cues.record_start()
  if not ok then return end
  local page = Cues.page_before(list, pos) or S.page
  local scroll = (R.max_y > 0) and (math.floor(S.scroll_y / R.max_y * 1000 + 0.5) / 10) or 0
  Cues.put(reg, pos, page, scroll)
  Msg.notify(string.format("Scroll point added at %s: page %d, scroll %d%%%s.", Cues.label(reg, pos), page,
    math.floor(scroll + 0.5), reg and (' in "' .. reg.name .. '"') or ""), false, "cues")
end
-- Removes all cues of one song (key), or of all songs (key == "_all").
function Cues.remove_all(key)
  if key == "_all" then P.cues = {} else P.cues[key] = nil end
  Util.mark_pdirty()
end

function Cues.remove(reg, index)
  local list = P.cues[Cues.key(reg)]
  if list and list[index] then table.remove(list, index); Util.mark_pdirty() end
  if list and #list == 0 then P.cues[Cues.key(reg)] = nil end
end

-- Switch beats <-> seconds for this project; every cue keeps its time in the project.
function Cues.set_unit(unit)
  if unit == P.cue_unit then return end
  local old = P.cue_unit
  for key, list in pairs(P.cues) do
    local reg = (key ~= "_project") and Project.region_by_key(key) or nil
    if key == "_project" or reg then
      for _, c in ipairs(list) do
        c.pos = Cues.from_time(reg, Cues.to_time(reg, c.pos, old), unit)
      end
    end
  end
  P.cue_unit = unit
  Util.mark_pdirty()
end

-- Copies the PDFPAGE / PDFSCROLL markers inside a region (or the whole project) into its cue list.
-- The markers are not changed. Returns the number of cues created or updated.
function Cues.convert_markers(reg)
  local lo, hi = -math.huge, math.huge
  if reg then lo, hi = reg.start, reg.stop end
  local at = {}
  local function slot(t)
    for _, a in ipairs(at) do if math.abs(a.t - t) < 0.001 then return a end end
    local a = { t = t }; at[#at + 1] = a; return a
  end
  for _, pp in ipairs(R.page_pts) do if pp.t >= lo and pp.t < hi then slot(pp.t).page = pp.page end end
  for _, sp in ipairs(R.scroll_pts) do if sp.t >= lo and sp.t < hi then slot(sp.t).scroll = sp.pct end end
  for _, a in ipairs(at) do
    local pos = math.floor(Cues.from_time(reg, a.t) * 1000 + 0.5) / 1000
    -- a page marker alone starts the page at the top (same rule as the Markers mode)
    Cues.put(reg, pos, a.page, a.scroll or (a.page and 0) or nil)
  end
  return #at
end

---------------------------------------------------------------------------
-- UI HELPERS
---------------------------------------------------------------------------
local ImGui = {}
setmetatable(ImGui, { __index = function(_, k) return r["ImGui_" .. k] end }) -- plain passthrough

-- Buttons: zero vertical padding + a per-button text alignment, so the label sits exactly
-- CFG.TEXT_LIFT px above centre on a whole pixel, whatever the button height.
function UI.button(ctx, label, w, h)
  if not h or h <= 0 then h = r.ImGui_GetFrameHeight(ctx) end
  local fs = r.ImGui_GetFontSize(ctx)
  local free = h - fs
  local ay = 0.5
  if free > 0 then ay = Util.clamp((math.floor(free / 2) - CFG.TEXT_LIFT) / free, 0, 1) end
  local px = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
  r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FramePadding(), px, 0)
  r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ButtonTextAlign(), 0.5, ay)
  local hit = r.ImGui_Button(ctx, label, w or 0, h)
  r.ImGui_PopStyleVar(ctx, 2) -- always paired with the 2 pushes above
  return hit
end

local MODE_ITEMS = "Absolute\0Relative\0"
local REL_ITEMS = "Relative 1 - two's complement (1=+1, 127=-1)\0Relative 2 - binary offset (65=+1, 63=-1)\0Relative 3 - sign-magnitude (1=+1, 65=-1)\0Direction only (>64 down, <64 up)\0"
local SCROLL_ITEMS = "Off\0Markers\0Cue list\0"
local SCROLL_TOOLBAR_ITEMS = "Scroll: Off\0Scroll: Markers\0Scroll: Cue list\0"
local FIT_ITEMS = { { "width", "Fit width" }, { "height", "Fit height" }, { "page", "Fit page" }, { "100", "100%" } }
local SCROLL_MODES = { "off", "marker", "cues" }
local SORT_ITEMS = "Sort: Name\0Sort: Page count\0Sort: Recently added\0"
local TAB_NAMES = { "Library", "Regions", "Cues", "Settings" }
local TAB_REGIONS = 2
local TAB_CUES = 3
local TAB_FIRST_SETTING = 4      -- the Settings tab (Autoscroll, MIDI, Display, Project sections)
local TAB_HELP = #TAB_NAMES + 1   -- the "?" button at the end of the tab strip

function Nav.effective_scale(iw, ih, view_w, view_h)
  local fit_w = view_w / iw
  if S.fit_mode == "height" then return view_h / ih end
  if S.fit_mode == "page" then return math.min(fit_w, view_h / ih) end
  return fit_w * S.zoom
end

function Nav.set_zoom_from_scale(scale, iw, view_w)
  S.fit_mode = "manual"
  S.zoom = Util.clamp(scale / (view_w / iw), CFG.MIN_ZOOM, CFG.MAX_ZOOM)
  Util.mark_dirty(); Nav.remember_view()
end

-- Per-PDF zoom: stores the fit mode and zoom of the open PDF in the project.
function Nav.remember_view()
  if S.pdf_path == "" or R.total == 0 then return end
  local v = P.view[S.pdf_path]
  if v and v.fit == S.fit_mode and v.zoom == S.zoom then return end
  P.view[S.pdf_path] = { fit = S.fit_mode, zoom = S.zoom }
  Util.mark_pdirty()
end

function Nav.zoom_by(factor)
  local e = R.images[S.page]
  if not e then return end
  Nav.set_zoom_from_scale(Nav.effective_scale(e.w, e.h, R.view_w, R.view_h) * factor, e.w, R.view_w)
end
-- Screen scale for "100%" = the real page size (96 screen units per inch, as Windows uses).
-- If the page size is unknown (no pdfinfo.exe), 100% = one image pixel per screen pixel.
function Nav.actual_scale(iw)
  if not R.page_w_pt or R.page_w_pt <= 0 or not iw or iw <= 0 then return 1.0 end
  local render_dpi = iw / (R.page_w_pt / 72)  -- also correct when pages are capped (-scale-to)
  return CFG.SCREEN_DPI / render_dpi
end

-- Current zoom in percent of the real page size (all fit modes), or nil if no page is shown.
function Nav.zoom_pct()
  local e = R.images[S.page]
  if not e or R.view_w <= 0 then return nil end
  return Nav.effective_scale(e.w, e.h, R.view_w, R.view_h) / Nav.actual_scale(e.w) * 100
end

function Nav.zoom_100()
  local e = R.images[S.page]
  if e then Nav.set_zoom_from_scale(Nav.actual_scale(e.w), e.w, R.view_w) end
end
function Nav.fit_width() S.zoom = 1.0; S.fit_mode = "width"; S.scroll_x = 0; Util.mark_dirty(); Nav.remember_view() end
function Nav.fit_height() S.fit_mode = "height"; S.scroll_x = 0; S.scroll_y = 0; Util.mark_dirty(); Nav.remember_view() end
function Nav.fit_page() S.fit_mode = "page"; S.scroll_x = 0; S.scroll_y = 0; Util.mark_dirty(); Nav.remember_view() end

function Autostart.command_string()
  if cmd_id and cmd_id ~= 0 then
    local named = r.ReverseNamedCommandLookup(cmd_id)
    if named and named ~= "" then
      if named:sub(1, 1) ~= "_" then named = "_" .. named end
      return named
    end
    return tostring(cmd_id)
  end
  return nil
end

---------------------------------------------------------------------------
-- AUTOSTART: open Chart Cue for every project that contains Chart Cue data.
-- A small watcher (Scripts\Chart Cue\autostart.lua) is started from REAPER's __startup.lua.
-- Chart Cue adds ONE marked block at the END of __startup.lua (after a backup) and removes only
-- that block when the option is turned off. The user's own code is never changed.
---------------------------------------------------------------------------

local AUTOSTART_SCRIPT = [=[
-- Chart Cue autostart watcher (written by Chart Cue - do not edit, it is overwritten).
-- Opens Chart Cue when a project that contains Chart Cue data opens or becomes the active tab.
--   * waits 0.5 s after a project change, so a closing Chart Cue (or an SWS startup action) acts first
--   * then tries for up to 3 s until Chart Cue runs
--   * after a start it waits 3 s before it starts Chart Cue again (prevents a double start)
local r = reaper
local last_proj, last_fn = nil, nil
local next_t, wait_until, pending_until, cooldown_until = 0, 0, 0, 0
local function chart_cue_running()
  local hb = tonumber(r.GetExtState("ChartCue", "heartbeat"))
  return hb ~= nil and math.abs(r.time_precise() - hb) < 1.0
end
local function tick()
  local t = r.time_precise()
  if t >= next_t then
    next_t = t + 0.1
    local proj, fn = r.EnumProjects(-1)
    fn = fn or ""
    if proj ~= last_proj or fn ~= last_fn then
      last_proj, last_fn = proj, fn
      local n = r.GetProjExtState(proj, "ChartCue", "cfg")
      if n and n > 0 then
        wait_until, pending_until = t + 0.5, t + 3.5
      else
        pending_until = 0
      end
    end
    if t < pending_until and t >= wait_until and t >= cooldown_until then
      if chart_cue_running() then
        pending_until = 0                       -- already open: nothing to do
      else
        local name = r.GetExtState("ChartCue", "cmd")
        local id = (name ~= "") and r.NamedCommandLookup(name) or 0
        if id ~= 0 then r.Main_OnCommand(id, 0) end
        cooldown_until, pending_until = t + 3, 0
      end
    end
  end
  r.defer(tick)
end
tick()
]=]

-- Reads __startup.lua only when asked to refresh (start-up, install, uninstall); cached otherwise.
function Autostart.installed(refresh)
  if refresh or R.as_installed == nil then
    local d = Util.read_all(CFG.STARTUP_FILE)
    R.as_installed = (d ~= nil and d:find(CFG.AS_BEGIN, 1, true) ~= nil)
  end
  return R.as_installed
end

function Autostart.write_script()
  Util.ensure_dir(CFG.BASE_DIR)
  local f = io.open(CFG.AUTOSTART_FILE, "wb")
  if not f then return false end
  f:write(AUTOSTART_SCRIPT); f:close()
  return true
end

function Autostart.install()
  -- the block is already in __startup.lua: never add a second one
  if Autostart.installed(true) then
    Msg.notify("Automatic open is already ON.", false, "project"); return
  end
  local ans = r.ShowMessageBox(
    "Chart Cue will add these 3 lines at the END of your REAPER startup script:\n\n"
    .. CFG.STARTUP_FILE .. "\n\n" .. CFG.AS_BLOCK .. "\n"
    .. "Your own code in that file is not changed. A backup is saved as __startup.lua.chartcue-backup.\n"
    .. "Restart REAPER once after this change.\n\n"
    .. "If some projects have an SWS startup action for Chart Cue, remove it there with the button "
    .. "'Remove the SWS startup action' (Settings > Project) and save the project.\n\nContinue?", CFG.TITLE, 1)
  if ans ~= 1 then return end
  if not Autostart.write_script() then
    Msg.notify("Cannot write " .. CFG.AUTOSTART_FILE, true, "project"); return
  end
  local old = Util.read_all(CFG.STARTUP_FILE)
  local backup = CFG.STARTUP_FILE .. ".chartcue-backup"
  if old and not (Util.copy_file(CFG.STARTUP_FILE, backup) and Util.read_all(backup) == old) then
    Msg.notify("Cannot write the backup " .. backup .. ". __startup.lua was not changed.", true, "project"); return
  end
  local f = io.open(CFG.STARTUP_FILE, "ab")
  if not f then Msg.notify("Cannot write " .. CFG.STARTUP_FILE, true, "project"); return end
  if old and old ~= "" and old:sub(-1) ~= "\n" then f:write("\n") end
  f:write("\n", CFG.AS_BLOCK); f:close()
  Autostart.installed(true)
  Msg.notify("Automatic open is ON. Restart REAPER once to start it.", false, "project", true)
end

function Autostart.uninstall()
  local d = Util.read_all(CFG.STARTUP_FILE)
  if not d then return end
  local a = d:find(CFG.AS_BEGIN, 1, true)
  local b = a and d:find(CFG.AS_END, a, true)
  if not (a and b) then return end
  local stop = b + #CFG.AS_END
  if d:sub(stop, stop) == "\n" then stop = stop + 1 end
  local start = a
  if start > 1 and d:sub(start - 1, start - 1) == "\n" then start = start - 1 end -- blank line we added
  local f = io.open(CFG.STARTUP_FILE, "wb")
  if not f then Msg.notify("Cannot write " .. CFG.STARTUP_FILE, true, "project"); return end
  f:write(d:sub(1, start - 1), d:sub(stop)); f:close()
  Autostart.installed(true)
  Msg.notify("Automatic open is OFF. It stops after the next REAPER restart.", false, "project", true)
end

-- SWS: find the action that clears the project startup action (only in some SWS versions)
function Autostart.sws_clear_action_id()
  for _, name in ipairs({ "_S&M_CLR_PRJ_ACTION", "_S&M_CLEAR_PRJ_ACTION", "_S&M_CLEAR_PROJECT_STARTUP_ACTION" }) do
    local id = r.NamedCommandLookup(name)
    if id and id ~= 0 then return id end
  end
  return nil
end

-- SWS: find the action that sets a project startup action (the name differs between versions)
function Autostart.sws_startup_action_id()
  for _, name in ipairs({ "_S&M_SET_PRJ_ACTION", "_S&M_SET_PROJECT_STARTUP_ACTION", "_S&M_PRJ_STARTUP_ACTION" }) do
    local id = r.NamedCommandLookup(name)
    if id and id ~= 0 then return id end
  end
  return nil
end

function UI.open_url(url)
  r.ExecProcess('cmd.exe /C start "" "' .. url .. '"', CFG.EXEC_NOWAIT)
end

function Autostart.sws_installed()
  return r.APIExists("CF_GetSWSVersion") or r.APIExists("BR_GetMediaItemByGUID")
end

function UI.pdf_items_string()
  local c = R.items_cache
  if c and c.ver == R.lib_ver and c.P == P then return c.str end
  local t = {}
  for _, p in ipairs(P.pdfs) do t[#t + 1] = Util.name_of(p) .. "\0" end
  R.items_cache = { ver = R.lib_ver, P = P, str = table.concat(t) }
  return R.items_cache.str
end

function UI.autoscroll_state_text()
  local mode = Nav.scroll_mode()
  if mode == "off" then return "Off" end
  local names = { marker = "Markers", cues = "Cue list" }
  -- words, not colour only: "moving" while the page is moved, "ready" while REAPER does not play
  return names[mode] .. (R.autoscroll_active and " (moving)" or " (ready)")
end

function UI.midi_in_use() return S.direct_midi or R.last_cc ~= nil end

function UI.region_counts()
  if R.counts_cache and R.counts_cache.frame == R.frames then return R.counts_cache end -- once per frame
  local c = { all = #R.regions, need = 0, assigned = 0, ignored = 0, frame = R.frames }
  for _, reg in ipairs(R.regions) do
    local s = reg.status
    if s == "unassigned" or s == "ambiguous" then c.need = c.need + 1
    elseif s == "auto" or s == "assigned" then c.assigned = c.assigned + 1
    elseif s == "ignored" then c.ignored = c.ignored + 1 end
  end
  R.counts_cache = c
  return c
end

function UI.attention_count() return UI.region_counts().need end

-- Truncate text with "..." so it fits in max_w pixels
function UI.trunc_text(ctx, s, max_w)
  if max_w < 20 then return "" end
  local w = ImGui.CalcTextSize(ctx, s)
  if w <= max_w then return s end
  local n = utf8.len(s) or #s
  n = math.max(1, math.floor(n * (max_w / w)))
  while n > 1 do
    local cut = (utf8.offset(s, n + 1) or (n + 1)) - 1
    local cand = s:sub(1, cut) .. "..."
    if (ImGui.CalcTextSize(ctx, cand)) <= max_w then return cand end
    n = n - 1
  end
  return "..."
end

-- Truncate from the START with "..." so the end of a path (the file name) stays visible.
function UI.trunc_left(ctx, s, max_w)
  if max_w < 20 then return "" end
  if (ImGui.CalcTextSize(ctx, s)) <= max_w then return s end
  local n = utf8.len(s) or #s
  for k = 2, n do
    local start = utf8.offset(s, k) or k
    local cand = "..." .. s:sub(start)
    if (ImGui.CalcTextSize(ctx, cand)) <= max_w then return cand end
  end
  return "..."
end

-- Fonts: normal, bold (tabs), larger bold (selected tab), big (empty states).
function UI.init_fonts(ctx)
  -- "sans-serif" is Segoe UI on Windows
  local function make(size, flags)
    local f = r.ImGui_CreateFont("sans-serif", size, flags)
    r.ImGui_Attach(ctx, f)
    return f
  end
  local bold = r.ImGui_FontFlags_Bold()
  R.ui_font = make(CFG.FONT_SIZE, 0)
  R.tab_font = make(CFG.FONT_SIZE_BOLD, bold)
  R.tab_font_big = make(CFG.FONT_SIZE_BOLD + 1, bold) -- the selected tab
  R.big_font = make(30, bold)
end
function UI.push_font(ctx, font) ImGui.PushFont(ctx, font) end
function UI.push_bold_font(ctx, larger) UI.push_font(ctx, larger and R.tab_font_big or R.tab_font) end
function UI.push_big_font(ctx) UI.push_font(ctx, R.big_font) end
function UI.pop_font(ctx) r.ImGui_PopFont(ctx) end

-- Panel layout helpers: one primary control per row, consistent label column, uniform buttons.
-- Round "?" icon. Hovering shows `text` in a wrapped tooltip.
function UI.help_icon(ctx, id, text)
  local d = CFG.HELP_ICON
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, "##help_" .. id, d, d)
  local hov = ImGui.IsItemHovered(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local cx, cy = x + d / 2, y + d / 2
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, d / 2, hov and COL.ACCENT_HOVER or COL.ACCENT)
  local tw, th = ImGui.CalcTextSize(ctx, "?")
  ImGui.DrawList_AddText(dl, cx - tw / 2, cy - th / 2, COL.WHITE, "?")
  if hov then
    if ImGui.BeginTooltip(ctx) then
      ImGui.PushTextWrapPos(ctx, ImGui.GetFontSize(ctx) * 32)
      ImGui.Text(ctx, text)
      ImGui.PopTextWrapPos(ctx)
      ImGui.EndTooltip(ctx)
    end
  end
end

-- Section title: bold, accent colour, full-width accent underline, optional "?" help on the right.
local SCOPE_TEXT = { project = "This project", computer = "This computer" }

-- Dim scope label ("This project" / "This computer") to the right of the last item.
-- Drawn only when it fits before `right` (screen x), so a narrow panel hides it.
function UI.scope_after(ctx, scope, right)
  local txt = SCOPE_TEXT[scope]
  if not txt then return end
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = ImGui.GetItemRectMax(ctx)
  local tw = ImGui.CalcTextSize(ctx, txt)
  right = right or (ImGui.GetWindowPos(ctx) + ImGui.GetWindowWidth(ctx) - 12)
  if x1 + 10 + tw > right then return end
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x1 + 10, UI.text_y(ctx, y0, y1 - y0), COL.TEXT_DIM, txt)
end

-- The scope of a heading goes into its "?" text (not on screen, so the panel stays clean).
-- Built once per help text, not every frame.
local SCOPE_HELP = {
  project = { line = "Saved in this project.", memo = {} },
  computer = { line = "Saved on this computer (the same for all your projects).", memo = {} },
}

-- Section heading. With `fold` (an id): an arrow before the title, and a click on the arrow or
-- the title opens / closes the section. Returns open (always true without `fold`) and clicked.
-- The closed sections are saved in S.folded (",id,id,"). `fold` can also be a boolean: then the
-- caller keeps the state (open = fold) and saves it itself (Settings tab: one section at a time).
-- big: the larger bold font, for the Settings tab sections (one level above the normal headings).
function UI.heading(ctx, text, help, scope, fold, big)
  local sc = scope and SCOPE_HELP[scope]
  if sc then
    local k = help or ""
    if not sc.memo[k] then sc.memo[k] = help and (help .. "\n\n" .. sc.line) or sc.line end
    help = sc.memo[k]
  end
  UI.vgap(ctx, UI.sp("TITLE_BEFORE"))
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local full = math.max(60, UI.panel_w(ctx) - 12)
  local open, clicked = true, false
  local ext = (type(fold) == "boolean") -- state kept by the caller
  if fold ~= nil then
    if ext then open = fold else open = not S.folded:find("," .. fold .. ",", 1, true) end
    local fh = ImGui.GetFrameHeight(ctx)
    clicked = ImGui.InvisibleButton(ctx, "##fold_" .. (ext and text or fold), 14, fh)
    local hov = ImGui.IsItemHovered(ctx)
    -- the arrow: pointing right when closed, down when open
    local dl, cx, cy = ImGui.GetWindowDrawList(ctx), sx + 6, sy + fh / 2
    local col = hov and COL.TEXT_MAIN or COL.HEADING
    if open then ImGui.DrawList_AddTriangleFilled(dl, cx - 4, cy - 2, cx + 4, cy - 2, cx, cy + 3, col)
    else ImGui.DrawList_AddTriangleFilled(dl, cx - 2, cy - 4, cx - 2, cy + 4, cx + 3, cy, col) end
    ImGui.SameLine(ctx, 0, 2)
    UI.push_bold_font(ctx, big)
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.TextColored(ctx, COL.HEADING, text)
    UI.pop_font(ctx)
    clicked = clicked or ImGui.IsItemClicked(ctx)
    if hov or ImGui.IsItemHovered(ctx) then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
    if clicked then
      open = not open
      if not ext then
        S.folded = open and S.folded:gsub("," .. fold .. ",", ",") or (S.folded .. fold .. ",")
        if S.folded:sub(1, 1) ~= "," then S.folded = "," .. S.folded end
        Util.mark_dirty()
      end
    end
  else
    UI.push_bold_font(ctx, big)
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.TextColored(ctx, COL.HEADING, text)
    UI.pop_font(ctx)
  end
  local _, ty = ImGui.GetItemRectMax(ctx)
  if help then
    ImGui.SameLine(ctx)
    ImGui.SetCursorScreenPos(ctx, sx + full - CFG.HELP_ICON, sy)
    UI.help_icon(ctx, text, help)
    local _, hy = ImGui.GetItemRectMax(ctx)
    ty = math.max(ty, hy)
  end
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddLine(dl, sx, ty + 3, sx + full, ty + 3, COL.ACCENT, 1.5)
  ImGui.Dummy(ctx, 0, 3)                -- room for the underline
  UI.vgap(ctx, UI.sp("TITLE_AFTER"))
  return open, clicked
end

-- Space between sections (the heading underline replaces the old separator line).
function UI.group_sep(ctx)
  local g = UI.sp("SECTION")
  if g > 0 then ImGui.Dummy(ctx, 0, g) end
end

-- Text that wraps to the AVAILABLE content width (never a fixed pixel width), optionally coloured.
function UI.wrapped(ctx, text, col)
  local aw = ImGui.GetContentRegionAvail(ctx)
  ImGui.PushTextWrapPos(ctx, ImGui.GetCursorPosX(ctx) + math.max(60, aw - 14))
  if col then ImGui.TextColored(ctx, col, text) else ImGui.Text(ctx, text) end
  ImGui.PopTextWrapPos(ctx)
end


-- List rows: every frame item (button, combo) is ROW_H tall; text uses UI.row_text.
-- Height of every control in the current row: the frame height (font + 2 x frame padding).
-- Buttons use it too, so buttons, fields, dropdowns and row text always have the same height.
function UI.h(ctx) return ImGui.GetFrameHeight(ctx) end

-- Frame padding that gives a frame height of CFG.ROW_H for the current font.
function UI.pad_y(ctx) return math.max(1, math.floor((CFG.ROW_H - ImGui.GetFontSize(ctx)) / 2)) end

function UI.push_row_style(ctx)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding(), 8, UI.pad_y(ctx))
end
function UI.pop_row_style(ctx) ImGui.PopStyleVar(ctx, 1) end

-- Highlight for the "current" row (active PDF, current region): accent background + left bar.
function UI.row_highlight(ctx, aw)
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local h = ImGui.GetFrameHeight(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(dl, sx - 6, sy - 2, sx + aw - 10, sy + h + 2, COL.ACTIVE_BG, 4)
  ImGui.DrawList_AddRectFilled(dl, sx - 6, sy - 2, sx - 3, sy + h + 2, COL.ACCENT, 2)
end

-- Opens Explorer in the foreground with the file selected (or its folder if the file is missing).
--   SWS installed: CF_LocateInExplorer(file) selects the file; CF_ShellExecute(folder) opens a folder.
--   (Both take ONE argument.) Without SWS, or if an SWS call fails: the Windows "start" command.
-- Every SWS call is protected with pcall, so a different SWS version can never stop Chart Cue.
function Util.show_in_explorer(path)
  if not path or path == "" then return end
  local exists = Util.file_exists(path)
  local dir = Util.dir_of(path)
  if exists and r.CF_LocateInExplorer and pcall(r.CF_LocateInExplorer, path) then return end
  if not exists and dir and r.CF_ShellExecute and pcall(r.CF_ShellExecute, dir) then return end
  local args
  if exists then args = '/select,"' .. path .. '"'
  elseif dir then args = '"' .. dir .. '"'
  else return end
  r.ExecProcess('cmd.exe /C start "" explorer.exe ' .. args, CFG.EXEC_NOWAIT)
end

function Util.fmt_mmss(t)
  t = math.max(0, t or 0)
  return string.format("%d:%02d", math.floor(t / 60), math.floor(t % 60))
end

function UI.tip(ctx, text)
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, text) end
end


function UI.fit_label()
  if S.fit_mode == "manual" then
    local pct = Nav.zoom_pct()
    return pct and string.format("%d%%", math.floor(pct + 0.5)) or "Zoom"
  end
  for _, f in ipairs(FIT_ITEMS) do if f[1] == S.fit_mode then return f[2] end end
  return "Fit"
end


-- One rule for all text in a row of controls (buttons, dropdowns, plain text, tabs):
-- text top = row top + floor((height - font) / 2) - CFG.TEXT_LIFT
function UI.text_y(ctx, top, h)
  h = h or ImGui.GetFrameHeight(ctx)
  return top + math.floor((h - ImGui.GetFontSize(ctx)) / 2) - CFG.TEXT_LIFT
end

-- Plain text in a row of buttons / fields: drawn at the shared text position, laid out as a
-- full-height item, so SameLine neighbours and the next row line up without cursor tricks.
function UI.row_text(ctx, text, col)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.Dummy(ctx, (ImGui.CalcTextSize(ctx, text)), ImGui.GetFrameHeight(ctx))
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, UI.text_y(ctx, y), col or COL.TEXT_MAIN, text)
end

-- Dropdown whose preview text uses the shared text position (UI.text_y). Returns true while open
-- (then call ImGui.EndCombo, exactly like BeginCombo).
function UI.combo(ctx, id, preview, w)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local h = ImGui.GetFrameHeight(ctx)
  local px = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
  local txt = UI.trunc_text(ctx, preview, w - h - 2 * px)
  local ty = UI.text_y(ctx, y)
  ImGui.SetNextItemWidth(ctx, w)
  local open = ImGui.BeginCombo(ctx, id, "") -- preview drawn below, on the window's draw list
  ImGui.DrawList_AddText(dl, x + px, ty, COL.TEXT_MAIN, txt)
  return open
end

-- Toolbar items: { w = width, draw = function(ctx, w) }. Items are packed into rows that fit the
-- window width, and every row is centred. The order of the items never changes.
function UI.toolbar_items(ctx, perf)
  local items = {}
  local function add(w, draw) items[#items + 1] = { w = w, draw = draw } end
  local bw = CFG.TB_BTN_W
  add(bw, function() if UI.button(ctx, "<", bw, 0) then Nav.go_page(S.page - 1) end
    UI.tip(ctx, "Previous page (Left, PgUp)") end)
  local ptxt = (R.total > 0) and string.format("Page %d / %d", S.page, R.total) or "No PDF open"
  if R.total > 0 then
    -- "go to page": click the page number to type a page
    local pw = UI.btn_w(ctx, ptxt, 0)
    add(pw, function()
      if R.goto_edit then
        ImGui.SetNextItemWidth(ctx, pw)
        if not R.goto_focus then ImGui.SetKeyboardFocusHere(ctx); R.goto_focus = true end
        local enter
        enter, R.goto_text = ImGui.InputText(ctx, "##goto", R.goto_text,
          ImGui.InputTextFlags_EnterReturnsTrue() | ImGui.InputTextFlags_AutoSelectAll() | ImGui.InputTextFlags_CharsDecimal())
        if enter then
          local n = tonumber(R.goto_text)
          if n then Nav.go_page(math.floor(n)) end
          R.goto_edit = false
        elseif ImGui.IsItemDeactivated(ctx) then
          R.goto_edit = false -- Esc or click elsewhere
        end
      else
        if UI.row_button(ctx, ptxt .. "##gotobtn", pw, "ghost") then
          R.goto_edit, R.goto_text, R.goto_focus = true, tostring(S.page), false
        end
        UI.tip(ctx, "Click to go to a page")
      end
    end)
  else
    add((ImGui.CalcTextSize(ctx, ptxt)), function() UI.row_text(ctx, ptxt) end)
  end
  add(bw, function() if UI.button(ctx, ">", bw, 0) then Nav.go_page(S.page + 1) end
    UI.tip(ctx, "Next page (Right, PgDn)") end)
  if R.pdf_name ~= "" then
    local avail = (ImGui.GetContentRegionAvail(ctx)) - 12
    local nw = math.min((ImGui.CalcTextSize(ctx, R.pdf_name)), 220, math.max(40, avail))
    add(nw, function(_, w) UI.row_text(ctx, UI.trunc_text(ctx, R.pdf_name, w), COL.GREY); UI.tip(ctx, S.pdf_path) end)
  end
  add(bw, function() if UI.button(ctx, "-", bw, 0) then Nav.zoom_by(1 / CFG.ZOOM_STEP) end
    UI.tip(ctx, "Zoom out (Ctrl -, Ctrl+wheel)") end)
  add(bw, function() if UI.button(ctx, "+", bw, 0) then Nav.zoom_by(CFG.ZOOM_STEP) end
    UI.tip(ctx, "Zoom in (Ctrl +, Ctrl+wheel)") end)
  add(CFG.FIT_COMBO_W, function()
    if UI.combo(ctx, "##fit", UI.fit_label(), CFG.FIT_COMBO_W) then
      for _, f in ipairs(FIT_ITEMS) do
        local sel = (f[1] == S.fit_mode)
        if f[1] == "100" then
          local pct = Nav.zoom_pct()
          sel = (S.fit_mode == "manual" and pct ~= nil and math.abs(pct - 100) < 0.5)
        end
        if ImGui.Selectable(ctx, f[2], sel) then
          if f[1] == "width" then Nav.fit_width()
          elseif f[1] == "height" then Nav.fit_height()
          elseif f[1] == "page" then Nav.fit_page()
          else Nav.zoom_100() end
        end
      end
      ImGui.EndCombo(ctx)
    end
    UI.tip(ctx, "Fit mode (Ctrl 0 = fit width). 100% = the real page size.")
  end)
  -- lock: a square icon button, the same size as < > - +
  add(bw, function()
    local nc, nv = UI.push_kind(ctx, R.lock and "primary" or nil)
    local hit = UI.button(ctx, "##lock", bw, 0)
    UI.pop_kind(ctx, nc, nv)
    local x0, y0 = ImGui.GetItemRectMin(ctx)
    local x1, y1 = ImGui.GetItemRectMax(ctx)
    UI.draw_lock_icon(ImGui.GetWindowDrawList(ctx), (x0 + x1) / 2, (y0 + y1) / 2, R.lock,
      R.lock and COL.WHITE or COL.TEXT_MAIN)
    if hit then UI.toggle_lock() end
    UI.tip(ctx, "Lock (L): during playback the page ignores the mouse wheel, dragging and the keys.\n"
      .. "MIDI and autoscroll still work. Click again or press L to unlock.")
  end)
  -- record cues: a square icon button, the same size as the lock button (only in the Cue list mode)
  if Nav.scroll_mode() == "cues" then add(bw, function()
    local nc, nv = UI.push_kind(ctx, R.rec and "danger" or nil)
    local hit = UI.button(ctx, "##rec", bw, 0)
    UI.pop_kind(ctx, nc, nv)
    local x0, y0 = ImGui.GetItemRectMin(ctx)
    local x1, y1 = ImGui.GetItemRectMax(ctx)
    UI.draw_rec_icon(ImGui.GetWindowDrawList(ctx), (x0 + x1) / 2, (y0 + y1) / 2, R.rec)
    if hit then UI.toggle_rec() end
    UI.tip(ctx, "Record cues (R): while on, the C and S keys and the MIDI cue buttons add cues.\n"
      .. "Only in the Cue list autoscroll mode. Lock mode blocks it during playback.")
  end) end
  if perf then
    local st = "Autoscroll: " .. UI.autoscroll_state_text()
    add((ImGui.CalcTextSize(ctx, st)), function() UI.row_text(ctx, st) end)
  else
    add(CFG.SCROLL_COMBO_W, function()
      local labels = {}
      for l in SCROLL_TOOLBAR_ITEMS:gmatch("([^\0]+)") do labels[#labels + 1] = l end
      local cur = 1
      for i, m in ipairs(SCROLL_MODES) do if m == Nav.scroll_mode() then cur = i end end
      if UI.combo(ctx, "##scrollmode", labels[cur] or "", CFG.SCROLL_COMBO_W) then
        for i, m in ipairs(SCROLL_MODES) do
          if ImGui.Selectable(ctx, labels[i], i == cur) then Nav.set_scroll_mode(m) end
        end
        ImGui.EndCombo(ctx)
      end
      UI.tip(ctx, "Autoscroll mode")
    end)
  end
  return items
end

function UI.draw_centered_toolbar(ctx, perf)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding(), 8, UI.pad_y(ctx)) -- the same height as all controls
  local items = UI.toolbar_items(ctx, perf)
  local avail = math.max(1, (ImGui.GetContentRegionAvail(ctx)))
  local x0 = ImGui.GetCursorPosX(ctx)
  local gap = CFG.TB_GAP
  local rows, row, row_w = {}, {}, 0
  for _, it in ipairs(items) do
    local need = (#row == 0) and it.w or (row_w + gap + it.w)
    if #row > 0 and need > avail then rows[#rows + 1] = { items = row, w = row_w }; row = {}; need = it.w end
    row[#row + 1] = it; row_w = need
  end
  if #row > 0 then rows[#rows + 1] = { items = row, w = row_w } end
  for _, rw in ipairs(rows) do -- every item is one frame high, so SameLine keeps one top edge
    for j, it in ipairs(rw.items) do
      if j == 1 then ImGui.SetCursorPosX(ctx, x0 + math.max(0, math.floor((avail - rw.w) / 2)))
      else ImGui.SameLine(ctx, 0, gap) end
      it.draw(ctx, it.w)
    end
  end
  ImGui.PopStyleVar(ctx, 1)
end

---------------------------------------------------------------------------
-- LAYOUT SYSTEM for the settings panels (every tab uses these, so all sections look the same)
--   * two columns: label column (CFG.LABEL_W) + control column (max CFG.FORM_MAX_W)
--   * every dropdown, input, slider and button fills the control column
--   * 3 button types: single (full column), pair (2 equal halves), row action (fixed, in lists)
--   * checkboxes, notes and messages start in the control column
--   * dangerous actions: red outline, last in their section
--   * narrow panel: labels go above their control, button pairs stack
---------------------------------------------------------------------------
-- Available width in the settings panel, always measured as if its scrollbar were shown.
-- Without this, a list that becomes short enough to lose the scrollbar (for example the
-- "needs PDF" view) makes the panel wider and every button in it resizes.
function UI.panel_w(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  if ImGui.GetScrollMaxY(ctx) <= 0 then
    aw = aw - r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ScrollbarSize())
  end
  return aw
end

-- Spacing value for the current layout (CFG.SP entry: comfortable / compact).
function UI.sp(key) return CFG.SP[key][S.comfortable and 1 or 2] end

-- Exact vertical gap of `px` pixels after the previous item. ImGui adds its row spacing on its
-- own, so it is subtracted here; every gap in the UI is set with this, so top and bottom match.
function UI.vgap(ctx, px)
  local _, sy = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing())
  ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) - (sy or 0) + px)
end

-- Returns row start x, control column x, control column width, wide (labels left of controls).
-- With `label`: a label wider than the label column puts its control on the next row (no overlap).
function UI.form(ctx, label)
  local x0 = ImGui.GetCursorPosX(ctx)
  local aw = UI.panel_w(ctx)
  local wide = aw >= CFG.LABEL_W + CFG.FORM_MIN_WIDE
  if wide and label and (ImGui.CalcTextSize(ctx, label)) > CFG.LABEL_W - 8 then wide = false end
  local cx = wide and (x0 + CFG.LABEL_W) or x0
  local cw = math.max(100, math.min(CFG.FORM_MAX_W, aw - (cx - x0) - 12))
  return x0, cx, cw, wide
end

-- Label + the next widget in the control column (call the widget right after this).
function UI.field(ctx, label)
  local _, cx, cw, wide = UI.form(ctx, label)
  UI.row_text(ctx, label)
  if wide then ImGui.SameLine(ctx) end
  ImGui.SetCursorPosX(ctx, cx)
  ImGui.SetNextItemWidth(ctx, cw)
end

-- Checkbox row: the label in the label column (clickable), the box in the control column.
function UI.checkbox(ctx, label, v)
  local _, cx, _, wide = UI.form(ctx, label)
  UI.row_text(ctx, label)
  local label_clicked = ImGui.IsItemClicked(ctx)
  if ImGui.IsItemHovered(ctx) then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
  if wide then ImGui.SameLine(ctx) end
  ImGui.SetCursorPosX(ctx, cx)
  local ch, nv = UI.toggle(ctx, "##cb_" .. label, v)
  if label_clicked then ch, nv = true, not v end
  return ch, nv
end

-- Starts a row: optional label in the label column, cursor in the control column.
-- Returns the control column x and width.
function UI.row_start(ctx, row_label)
  local _, cx, cw, wide = UI.form(ctx, row_label)
  if row_label then
    UI.row_text(ctx, row_label)
    if wide then ImGui.SameLine(ctx) end
  end
  ImGui.SetCursorPosX(ctx, cx)
  return cx, cw
end

-- Read-only "label: value" row (value wraps inside the control column).
function UI.value(ctx, label, text, col)
  local cx, cw = UI.row_start(ctx, label)
  ImGui.PushTextWrapPos(ctx, cx + cw)
  ImGui.TextColored(ctx, col or COL.GREY, text)
  ImGui.PopTextWrapPos(ctx)
end
-- Wrapped text in the control column (notes, status lines, messages).
function UI.note(ctx, text, col)
  local _, cx, cw = UI.form(ctx)
  ImGui.SetCursorPosX(ctx, cx)
  ImGui.PushTextWrapPos(ctx, cx + cw)
  if col then ImGui.TextColored(ctx, col, text) else ImGui.Text(ctx, text) end
  ImGui.PopTextWrapPos(ctx)
end

-- The message area of a section: the latest message of `source`, always under its buttons.
-- Inline confirmation (in place of a message box): UI.ask() arms it, UI.draw_ask() shows the
-- question with a red "Yes, ..." and a "Cancel" button at the place where it was asked.
-- `key` (optional): what the question is about, e.g. the song; draw_ask closes the question when
-- its key changes, so an old question never stays open for a different song.
function UI.ask(id, text, yes_label, run, key)
  R.ask = { id = id, text = text, yes = yes_label, run = run, key = key }
end

function UI.draw_ask(ctx, id, key)
  local a = R.ask
  if not a or a.id ~= id then return end
  if a.key ~= key then R.ask = nil; return end
  UI.note(ctx, a.text, COL.YELLOW)
  ImGui.PushID(ctx, "ask_" .. id)
  local _, cw = UI.row_start(ctx)
  local hw = math.floor((cw - 8) / 2)
  local yes = UI.row_button(ctx, a.yes, hw, true)
  ImGui.SameLine(ctx, 0, 8)
  local no = UI.button(ctx, "Cancel", cw - hw - 8, UI.h(ctx))
  ImGui.PopID(ctx) -- always paired with PushID above
  if yes then R.ask = nil; a.run() elseif no then R.ask = nil end
end

-- "Remove PDF markers...": asks first, with the number of markers and where they are.
function UI.ask_remove_markers(id, lo, hi, where, key)
  local n = #Project.script_markers(lo, hi)
  if n == 0 then
    Msg.notify("There are no PDF markers in " .. where .. ".", false, "cues"); return
  end
  UI.ask(id, string.format("Remove %d PDF marker(s) in %s? Only PDF markers (PDFPAGE / PDFSCROLL) are removed. "
    .. "Regions and other markers are not changed. Edit > Undo (Ctrl+Z) brings them back.", n, where),
    "Yes, remove", function() Project.remove_script_markers(lo, hi, where) end, key)
end

function UI.section_msg(ctx, source)
  local m = Msg.recent(source)
  if not m then return end
  UI.note(ctx, m.text, m.err and COL.RED or COL.GREEN)
  if m.sticky then
    -- small "x" to close it, at the end of the note
    ImGui.SameLine(ctx, 0, 6)
    if UI.button(ctx, "x##closemsg", UI.h(ctx), UI.h(ctx)) then R.msg = nil end
    UI.tip(ctx, "Close this message")
  end
end

---------------------------------------------------------------------------
-- MODERN THEME: flat dark colours, rounded corners, roomier padding, Segoe UI.
-- Pushed ONCE per frame before Begin() and popped after End(); the counts are stored in R.theme,
-- so the pops always match the pushes (also after an error, see UI.loop).
---------------------------------------------------------------------------
function UI.push_theme(ctx)
  local nc, nv = 0, 0
  local function col(fn, c) ImGui.PushStyleColor(ctx, fn(), c); nc = nc + 1 end
  local function var(fn, a, b)
    if b then ImGui.PushStyleVar(ctx, fn(), a, b) else ImGui.PushStyleVar(ctx, fn(), a) end
    nv = nv + 1
  end
  col(ImGui.Col_WindowBg, COL.WIN_BG)
  col(ImGui.Col_ChildBg, COL.TRANSPARENT)
  col(ImGui.Col_PopupBg, COL.PANEL_BG)
  col(ImGui.Col_Border, COL.LINE)
  col(ImGui.Col_FrameBg, COL.FIELD)
  col(ImGui.Col_FrameBgHovered, COL.FIELD_HOVER)
  col(ImGui.Col_FrameBgActive, COL.FIELD_ACTIVE)
  col(ImGui.Col_Button, COL.BTN)
  col(ImGui.Col_ButtonHovered, COL.BTN_HOVER)
  col(ImGui.Col_ButtonActive, COL.BTN_ACTIVE)
  col(ImGui.Col_Header, COL.ACTIVE_BG)
  col(ImGui.Col_HeaderHovered, 0x3B82F655)
  col(ImGui.Col_HeaderActive, 0x3B82F677)
  col(ImGui.Col_CheckMark, COL.ACCENT)
  col(ImGui.Col_SliderGrab, COL.ACCENT)
  col(ImGui.Col_SliderGrabActive, COL.ACCENT_HOVER)
  col(ImGui.Col_Text, COL.TEXT_MAIN)
  col(ImGui.Col_TextDisabled, COL.TEXT_DIM)
  col(ImGui.Col_Separator, COL.LINE)
  col(ImGui.Col_ScrollbarBg, COL.TRANSPARENT)
  col(ImGui.Col_ScrollbarGrab, COL.BTN_HOVER)
  col(ImGui.Col_ScrollbarGrabHovered, COL.BTN_ACTIVE)
  col(ImGui.Col_ScrollbarGrabActive, COL.TOGGLE_OFF)
  col(ImGui.Col_TextSelectedBg, 0x3B82F666)
  var(ImGui.StyleVar_FrameRounding, 6)
  var(ImGui.StyleVar_GrabRounding, 6)
  var(ImGui.StyleVar_PopupRounding, 6)
  var(ImGui.StyleVar_ScrollbarRounding, 6)
  var(ImGui.StyleVar_ChildRounding, 8)
  -- all fields, dropdowns and buttons are CFG.ROW_H high (text centred in the same box)
  var(ImGui.StyleVar_FramePadding, 10, math.max(2, math.floor((CFG.ROW_H - CFG.FONT_SIZE) / 2)))
  var(ImGui.StyleVar_ItemSpacing, 8, UI.sp("ROW"))
  var(ImGui.StyleVar_WindowPadding, 8, UI.sp("EDGE"))
  var(ImGui.StyleVar_ScrollbarSize, 12)
  var(ImGui.StyleVar_FrameBorderSize, 0)
  UI.push_font(ctx, R.ui_font)
  R.theme = { c = nc, v = nv }
end

-- The pops are protected because pop_theme also runs after an error inside a frame (UI.loop).
function UI.pop_theme(ctx)
  local t = R.theme
  if not t then return end
  R.theme = nil
  pcall(r.ImGui_PopFont, ctx)
  if t.v > 0 then pcall(ImGui.PopStyleVar, ctx, t.v) end
  if t.c > 0 then pcall(ImGui.PopStyleColor, ctx, t.c) end
end

-- Smoothly moves an animation value (0..1) towards `target` (hover fades, toggle knobs).
function UI.anim(id, target, speed)
  local v = R.anim[id] or target
  local dt = 1 / 60
  if R.ctx then dt = ImGui.GetDeltaTime(R.ctx) end
  v = v + (target - v) * math.min(1, dt * (speed or 14))
  if math.abs(v - target) < 0.002 then v = target end
  R.anim[id] = v
  return v
end

function Util.lerp_col(a, b, t)
  local function ch(c, sh) return (c >> sh) & 0xFF end
  local out = 0
  for _, sh in ipairs({ 24, 16, 8, 0 }) do
    out = out | (math.floor(ch(a, sh) + (ch(b, sh) - ch(a, sh)) * t + 0.5) << sh)
  end
  return out
end

-- Toggle switch (replaces the checkbox). Returns changed, new value.
function UI.toggle(ctx, id, v)
  local h = math.floor(ImGui.GetFrameHeight(ctx))
  local th = math.min(20, h - 4)
  local tw = math.floor(th * 1.8)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, id, tw, h)
  local hov, clk = ImGui.IsItemHovered(ctx), ImGui.IsItemClicked(ctx)
  if clk then v = not v end
  local t = UI.anim("tg" .. id, v and 1 or 0, 16)
  local ty = y + math.floor((h - th) / 2)
  local dl = ImGui.GetWindowDrawList(ctx)
  local track = Util.lerp_col(COL.TOGGLE_OFF, COL.ACCENT, t)
  if hov then track = Util.lerp_col(track, COL.WHITE, 0.12) end
  ImGui.DrawList_AddRectFilled(dl, x, ty, x + tw, ty + th, track, th / 2)
  local rad = th / 2 - 3
  ImGui.DrawList_AddCircleFilled(dl, x + th / 2 + t * (tw - th), ty + th / 2, rad, COL.WHITE)
  if hov then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
  return clk, v
end

-- Button kinds: "primary" (filled accent), "danger" or true (red outline), "ghost" (text only).
-- Returns the counts to pop with UI.pop_kind.
function UI.push_kind(ctx, kind)
  if kind == true or kind == "danger" then -- red outline
    ImGui.PushStyleColor(ctx, ImGui.Col_Button(), COL.TRANSPARENT)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered(), COL.DANGER_HOVER)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive(), COL.DANGER_ACTIVE)
    ImGui.PushStyleColor(ctx, ImGui.Col_Border(), COL.RED)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.RED)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize(), 1)
    return 5, 1
  end
  if kind == "primary" then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button(), COL.ACCENT)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered(), COL.ACCENT_HOVER)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive(), COL.ACCENT_ACTIVE)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.WHITE)
    return 4, 0
  end
  if kind == "ghost" then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button(), COL.TRANSPARENT)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered(), COL.ROW_HOVER)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive(), COL.ACTIVE_BG)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.ACCENT_HOVER)
    return 4, 0
  end
  return 0, 0
end
function UI.pop_kind(ctx, nc, nv)
  if nv > 0 then ImGui.PopStyleVar(ctx, nv) end
  if nc > 0 then ImGui.PopStyleColor(ctx, nc) end
end

-- Single action: the full control column. kind: nil, "primary", "danger"/true, "ghost".
-- row_label = the name of the row in the label column (only when the button needs it).
function UI.full_button(ctx, label, kind, row_label)
  local _, cw = UI.row_start(ctx, row_label)
  local nc, nv = UI.push_kind(ctx, kind)
  local hit = UI.button(ctx, label, cw, UI.h(ctx))
  UI.pop_kind(ctx, nc, nv)
  return hit
end
function UI.danger_button(ctx, label, row_label) return UI.full_button(ctx, label, true, row_label) end

-- Width a button needs for its text: text + horizontal padding on both sides (+2 px for the
-- red outline), but never less than `min_w`. Used so a fixed-width button never clips its text.
function UI.btn_w(ctx, label, min_w)
  local px = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
  local tw = ImGui.CalcTextSize(ctx, (label:gsub("##.*$", "")))
  return math.max(min_w or 0, math.ceil(tw + 2 * px + 2))
end

-- Row action button in a list. kind: nil, "primary", "danger"/true, "ghost".
-- The width grows when the text needs more space, so the label never clips.
function UI.row_button(ctx, label, w, kind)
  w = UI.btn_w(ctx, label, w)
  local nc, nv = UI.push_kind(ctx, kind)
  local hit = UI.button(ctx, label, w, UI.h(ctx))
  UI.pop_kind(ctx, nc, nv)
  return hit
end

-- Clickable area for a list row (call at the row start, then draw the row content on top).
-- Returns clicked, hovered. Shows a light highlight and a hand cursor on hover.
function UI.row_click_area(ctx, id, w)
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local h = ImGui.GetFrameHeight(ctx)
  ImGui.InvisibleButton(ctx, id, math.max(1, w), h)
  local hov, clk = ImGui.IsItemHovered(ctx), ImGui.IsItemClicked(ctx)
  if hov then
    ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx), sx - 6, sy - 2, sx + w, sy + h + 2, COL.ROW_HOVER, 4)
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
  end
  ImGui.SetCursorScreenPos(ctx, sx, sy)
  return clk, hov
end

-- Title row for a song's cue list: name (bold) + time range (normal text), centred on one line.
function UI.song_title(ctx, name, rg)
  UI.vgap(ctx, UI.sp("TITLE_BEFORE"))
  local _, y = ImGui.GetCursorScreenPos(ctx)
  UI.push_bold_font(ctx)
  ImGui.TextColored(ctx, COL.HEADING, name)
  local _, y1 = ImGui.GetItemRectMax(ctx)
  UI.pop_font(ctx)
  if rg then
    ImGui.SameLine(ctx, 0, 12)
    local x = ImGui.GetCursorScreenPos(ctx)
    local th = ImGui.GetTextLineHeight(ctx)
    ImGui.SetCursorScreenPos(ctx, x, y + math.floor(((y1 - y) - th) / 2))
    ImGui.TextColored(ctx, COL.TEXT, Util.fmt_mmss(rg.start) .. " - " .. Util.fmt_mmss(rg.stop))
  end
end

-- Pair of actions: 2 equal halves of the control column. The pair stacks when the column is
-- narrow or when a label does not fit in its half (so a button text never clips).
function UI.button_pair(ctx, la, lb, kind, row_label)
  local cx, cw = UI.row_start(ctx, row_label)
  local hw = math.floor((cw - 8) / 2)
  local need = math.max((ImGui.CalcTextSize(ctx, la)), (ImGui.CalcTextSize(ctx, lb))) + 20
  local stack = (cw < 240) or (need > hw)
  local nc, nv = UI.push_kind(ctx, kind)
  local a, b
  if stack then
    a = UI.button(ctx, la, cw, UI.h(ctx))
    ImGui.SetCursorPosX(ctx, cx)
    b = UI.button(ctx, lb, cw, UI.h(ctx))
  else
    a = UI.button(ctx, la, hw, UI.h(ctx))
    ImGui.SameLine(ctx, 0, 8)
    b = UI.button(ctx, lb, cw - hw - 8, UI.h(ctx))
  end
  UI.pop_kind(ctx, nc, nv)
  return a, b
end

-- Like UI.button_pair, but each button has its own kind (e.g. blue "primary" next to red "danger")
-- and its own optional tooltip (ta, tb).
function UI.button_pair2(ctx, la, ka, lb, kb, ta, tb)
  local cx, cw = UI.row_start(ctx)
  local hw = math.floor((cw - 8) / 2)
  local need = math.max((ImGui.CalcTextSize(ctx, (la:gsub("##.*$", "")))), (ImGui.CalcTextSize(ctx, (lb:gsub("##.*$", ""))))) + 20
  local stack = (cw < 240) or (need > hw)
  local nc, nv = UI.push_kind(ctx, ka)
  local a = UI.button(ctx, la, stack and cw or hw, UI.h(ctx))
  UI.pop_kind(ctx, nc, nv)
  if ta then UI.tip(ctx, ta) end
  if stack then ImGui.SetCursorPosX(ctx, cx) else ImGui.SameLine(ctx, 0, 8) end
  nc, nv = UI.push_kind(ctx, kb)
  local b = UI.button(ctx, lb, stack and cw or (cw - hw - 8), UI.h(ctx))
  UI.pop_kind(ctx, nc, nv)
  if tb then UI.tip(ctx, tb) end
  return a, b
end

-- Search field + dropdown above a list (Library: sort, Regions: show), the same in every list.
-- In a very narrow panel the dropdown wraps below the field. Returns the new text and index.
function UI.search_row(ctx, id, text, hint, sel, items)
  local aw = UI.panel_w(ctx)
  local narrow = aw < CFG.SORT_W + 150
  ImGui.SetNextItemWidth(ctx, narrow and -12 or (aw - CFG.SORT_W - 8 - 12))
  local _, nt = ImGui.InputTextWithHint(ctx, "##" .. id .. "search", hint, text)
  if not narrow then ImGui.SameLine(ctx) end
  ImGui.SetNextItemWidth(ctx, narrow and -12 or CFG.SORT_W)
  local _, ns = ImGui.Combo(ctx, "##" .. id .. "menu", sel, items)
  UI.vgap(ctx, UI.sp("SEARCH")) -- more room before the list, so the search row stands apart
  return nt, ns
end

-- Column titles above a list (Library, Regions, Cue list): same style everywhere.
function UI.list_header(ctx, cols)
  for i, c in ipairs(cols) do
    if i > 1 then ImGui.SameLine(ctx, c[2]) end
    ImGui.TextDisabled(ctx, c[1])
  end
end

---------------------------------------------------------------------------
-- UI: TAB CONTENTS
---------------------------------------------------------------------------
function UI.library_order()
  local oc = R.order_cache
  if oc and oc.ver == R.lib_ver and oc.P == P and oc.n == #P.pdfs and oc.filter == R.lib_filter
      and oc.sort == R.lib_sort then
    return oc.idx
  end
  local idx, f = {}, R.lib_filter:lower()
  for i, path in ipairs(P.pdfs) do
    if f == "" or Util.name_of(path):lower():find(f, 1, true) or path:lower():find(f, 1, true) then idx[#idx + 1] = i end
  end
  if R.lib_sort == 0 then
    table.sort(idx, function(a, b)
      local na, nb = Util.name_of(P.pdfs[a]):lower(), Util.name_of(P.pdfs[b]):lower()
      if na ~= nb then return na < nb end
      return a < b
    end)
  elseif R.lib_sort == 1 then
    table.sort(idx, function(a, b)
      local pa, pb = R.libpages[P.pdfs[a]] or math.huge, R.libpages[P.pdfs[b]] or math.huge
      if pa ~= pb then return pa < pb end
      return a < b
    end)
  else
    table.sort(idx, function(a, b) return a > b end) -- newest first
  end
  R.order_cache = { ver = R.lib_ver, P = P, n = #P.pdfs, filter = R.lib_filter, sort = R.lib_sort, idx = idx }
  return idx
end

function UI.draw_library_tab(ctx)
  local ch
  if not R.psaveable then
    UI.note(ctx, "Project not saved yet: the library and region assignments are stored in the project and are written to disk when you save it.", COL.YELLOW)
  end

  if UI.heading(ctx, "Add PDFs", "Copy into project ON: imported PDFs are copied into <project folder>\\PDFs\\. "
    .. "The original files are only read. The project is portable.\n\n"
    .. "Copy into project OFF (link mode): the library points to the original PDFs. The project is not portable.\n\n"
    .. "The PDFs you add are saved in this project; the two options below are for this computer.", nil, "lib_add") then
    local a, b = UI.button_pair(ctx, "Add PDF...", "Add PDFs from folder...", "primary")
    if a then PDF.browse_add_pdf(false) end
    if b then Project.start_folder_pick() end
    ch, S.import_copy = UI.checkbox(ctx, "Copy into project", S.import_copy)
    if ch then Util.mark_dirty() end
    UI.tip(ctx, "On: imported PDFs are copied into <project folder>\\PDFs\\ (portable project).\nOff: the library links to the original files.")
    ch, S.include_subfolders = UI.checkbox(ctx, "Include subfolders", S.include_subfolders)
    if ch then Util.mark_dirty() end
    UI.tip(ctx, "Used by 'Add PDFs from folder...'")
    if S.import_copy and not Project.dir() then
      UI.note(ctx, "Project not saved: imported PDFs are linked to their original location for now. "
        .. "Save the project, then use 'Copy all PDFs into the project'.", COL.YELLOW)
    end
    -- count of PDFs outside the project folder: rebuilt at most every 0.5 s, not every frame
    if not R.ext_count_t or Util.now() - R.ext_count_t > 0.5 then
      R.ext_count = Project.dir() and #Project.external_pdfs(true) or 0
      R.ext_count_t = Util.now()
    end
    local ext = R.ext_count
    if ext > 0 and not R.copy and #R.copyq == 0 then
      if UI.full_button(ctx, string.format("Copy all PDFs into the project (%d)", ext)) then
        Project.copy_all_into_project()
      end
      UI.tip(ctx, string.format("%d PDF(s) of the library are outside the project folder. "
        .. "This copies them into <project folder>\\PDFs\\.", ext))
    end
    if R.copy or #R.copyq > 0 then
      UI.note(ctx, string.format("Copying into the project... %d PDF(s) left%s", Project.copy_pending(),
        R.copy and (": " .. Util.name_of(R.copy.src)) or ""), COL.YELLOW)
    end
    if R.picker then
      UI.note(ctx, "Waiting for the folder dialog (it may be behind REAPER)...", COL.YELLOW)
    elseif R.import then
      UI.note(ctx, string.format("Scanning... %d files checked, %d added, %d duplicates skipped",
        R.import.scanned, R.import.added, R.import.skipped), COL.YELLOW)
    else
      UI.section_msg(ctx, "library")
    end
  end -- "Add PDFs" open

  UI.group_sep(ctx)
  UI.heading(ctx, string.format("PDF list (%d)", #P.pdfs), "Click a PDF to open it. The first column shows the name "
    .. "and the number of pages; the second column shows where the file is (starting with the project folder "
    .. "for PDFs inside it).\nMove the mouse over a PDF to see its full path.", "project")

  -- search + sort, above the list
  R.lib_filter, R.lib_sort = UI.search_row(ctx, "lib", R.lib_filter, "Search PDFs...", R.lib_sort, SORT_ITEMS)

  -- refresh existence flags every 2 s; fetch one missing page count per 0.3 s
  if Util.now() - R.libexists_t > 2 then
    for _, path in ipairs(P.pdfs) do R.libexists[path] = Util.file_exists(path) end
    R.libexists_t = Util.now()
  end
  if not R.lib_job and Util.now() - R.lib_scan_t > 0.3 then
    for _, path in ipairs(P.pdfs) do
      if R.libpages[path] == nil and R.libexists[path] ~= false then
        R.lib_scan_t = Util.now()
        local n = PDF.read_info_cache(path)
        if n then
          R.libpages[path] = n
        elseif PDF.engine() == "poppler" and R.exe and R.pdfinfo_ok then
          R.lib_job = PDF.start_info(path) -- result arrives in PDF.info_tick
          if not R.lib_job then R.libpages[path] = false end
        else
          R.libpages[path] = false -- Windows engine: known once the PDF is opened
        end
        Util.bump_lib()
        break
      end
    end
  end

  if #P.pdfs == 0 then ImGui.TextDisabled(ctx, "No PDFs in this project's library yet.") end
  -- name column width: the widest "name (pages)", measured only when the library changes
  if not R.lib_name_w or R.lib_name_w.ver ~= R.lib_ver then
    local w = 0
    for _, p in ipairs(P.pdfs) do
      local pg = R.libpages[p]
      w = math.max(w, (ImGui.CalcTextSize(ctx, Util.name_of(p) .. (pg and string.format("  (%d pp)", pg) or ""))))
    end
    R.lib_name_w = { ver = R.lib_ver, w = w }
  end
  local remove_path, relocate_path
  local shown = 0
  -- measured once, so the buttons are wide enough for their text and the right edge stays aligned
  local BTN_W = UI.h(ctx) -- the round red X (the same as in the cue list)
  local EXP_W = UI.btn_w(ctx, "Show in Explorer", CFG.EXPLORER_BTN_W)
  local MIN_PATH_W = CFG.MIN_PATH_W   -- below this the path is hidden (the tooltip still shows it)
  UI.push_row_style(ctx)
  for _, i in ipairs(UI.library_order()) do
    shown = shown + 1
    local path = P.pdfs[i]
    ImGui.PushID(ctx, "lib" .. i)
    local active = Util.same_path(path, S.pdf_path) and R.total > 0
    local missing = (R.libexists[path] == false)
    local x = ImGui.GetCursorPosX(ctx)
    local aw = UI.panel_w(ctx)
    local btns_x = x + aw - (EXP_W + BTN_W + 8) - 14
    if active then UI.row_highlight(ctx, aw) end
    -- one line: filename (pages) | path | Show in Explorer / red X (all on the same frame height)
    -- a click anywhere on the name / path area opens the PDF
    local pg = R.libpages[path]
    local label = Util.name_of(path) .. (pg and string.format("  (%d pp)", pg) or "")
    local space = btns_x - x - 8
    local clicked, hovered = UI.row_click_area(ctx, "##open", space)
    if clicked and not missing then PDF.open_pdf(path, false) end
    if hovered then
      ImGui.SetTooltip(ctx, missing and ("MISSING: " .. path) or ("Click to open\n" .. path))
    end
    -- two columns: the names share one width (at most half the space), so every path starts at the same x
    local col_w = math.min(R.lib_name_w.w, math.floor(space * 0.5))
    local txt = UI.trunc_text(ctx, label, math.max(20, col_w))
    UI.row_text(ctx, txt, missing and COL.RED or nil)
    local rel = P.rel[path]
    local pdir = Project.dir()
    local inside = rel and pdir and Util.rel_path(path, pdir)
    local path_w = space - col_w - 16
    if path_w >= MIN_PATH_W then
      -- inside the project folder: "<project folder name>/PDFs/file.pdf"; else the full path
      local shown = inside and ((Util.name_of((pdir:gsub("[/\\]+$", ""))) or "") .. "/" .. rel) or path
      ImGui.SameLine(ctx, x + col_w + 16)
      UI.row_text(ctx, UI.trunc_left(ctx, shown, path_w), COL.TEXT_DIM)
    end
    ImGui.SameLine(ctx, btns_x)
    if UI.row_button(ctx, "Show in Explorer", EXP_W, "ghost") then Util.show_in_explorer(path) end
    UI.tip(ctx, "Opens the folder of this PDF in Windows Explorer.")
    ImGui.SameLine(ctx)
    if UI.remove_x_button(ctx, "##remove", BTN_W) then R.confirm_remove = path end
    UI.tip(ctx, "Remove this PDF from the library (asks first). The file is not deleted.")
    if missing then
      local dir, rel = Project.dir(), P.rel[path]
      if dir and rel then
        UI.wrapped(ctx, "Expected: " .. Util.join_path(dir, (rel:gsub("/", "\\"))), COL.GREY)
      end
      UI.wrapped(ctx, "Old location: " .. path, COL.GREY)
      UI.wrapped(ctx, string.format("Used by %d region(s).", Project.region_use_count(path)), COL.YELLOW)
      if UI.button(ctx, "Relocate...", CFG.MEDIUM_BTN_W, 0) then relocate_path = path end
    end
    if R.confirm_remove == path then
      local n = 0
      for _, p in pairs(P.assign) do if Util.same_path(p, path) then n = n + 1 end end
      UI.wrapped(ctx, string.format("Remove this PDF? %d region assignment(s) will be cleared.", n), COL.YELLOW)
      if UI.row_button(ctx, "Yes, remove", CFG.MEDIUM_BTN_W, true) then remove_path = path; R.confirm_remove = nil end
      ImGui.SameLine(ctx)
      if UI.button(ctx, "Cancel", CFG.SMALL_BTN_W, 0) then R.confirm_remove = nil end
    end
    ImGui.PopID(ctx)
  end
  UI.pop_row_style(ctx)
  if #P.pdfs > 0 and shown == 0 then ImGui.TextDisabled(ctx, "No PDFs match the filter.") end
  if relocate_path then
    local ok, f = r.GetUserFileNameForRead("", "Locate " .. Util.name_of(relocate_path), "pdf")
    if ok and f and f ~= "" then
      local found = Project.relocate_pdf(relocate_path, f)
      Msg.notify(string.format("Relocated %s.%s", Util.name_of(relocate_path),
        found > 0 and string.format(" Also found %d other missing PDF(s) in the same folder.", found) or ""), false, "library")
    end
  end
  if remove_path then
    for i, p in ipairs(P.pdfs) do
      if Util.same_path(p, remove_path) then table.remove(P.pdfs, i); break end
    end
    for key, p in pairs(P.assign) do if Util.same_path(p, remove_path) then P.assign[key] = nil end end
    if Util.same_path(P.active_pdf, remove_path) then P.active_pdf = "" end
    P.rel[remove_path] = nil; P.view[remove_path] = nil
    R.libpages[remove_path] = nil; R.libexists[remove_path] = nil
    Project.resolve_regions(); Util.mark_pdirty()
  end

end

function UI.region_passes_filter(reg)
  local s = R.region_search
  if s and s ~= "" and not reg.name:lower():find(s:lower(), 1, true) then return false end
  local f = R.region_filter
  if f == 0 then return true
  elseif f == 1 then return reg.status == "unassigned" or reg.status == "ambiguous"
  elseif f == 2 then return reg.status == "auto" or reg.status == "assigned"
  else return reg.status == "ignored" end
end

-- Status of a region: label for the dropdown preview, dot colour, name colour, tooltip word.
function UI.region_look(reg)
  local st = reg.status
  if st == "auto" then
    return Util.name_of(reg.pdf) .. " (auto)", COL.GREEN, nil, "Auto-matched by name"
  elseif st == "assigned" then
    return Util.name_of(reg.pdf), COL.GREEN, nil, "Assigned"
  elseif st == "ignored" then
    return "(ignored)", COL.GREY, COL.GREY, "Ignored - no PDF"
  elseif st == "ambiguous" then
    return "(several PDFs match)", COL.YELLOW, COL.YELLOW, "Needs a PDF - several PDFs match"
  end
  return "(no PDF)", COL.YELLOW, COL.YELLOW, "Needs a PDF - no PDF yet"
end

-- One region row:  o Name  0:12 - 3:45            [ Song One.pdf (auto)  v ]
function UI.draw_region_row(ctx, i, reg)
  ImGui.PushID(ctx, "rg" .. i)
  local COMBO_W, DOT_W = CFG.REGION_COMBO_W, CFG.DOT_W
  local x = ImGui.GetCursorPosX(ctx)
  local aw = UI.panel_w(ctx)
  if R.cur_region_key == reg.key then UI.row_highlight(ctx, aw) end
  local preview, dot_col, name_col, word = UI.region_look(reg)
  local inline = (aw - DOT_W - COMBO_W - 24) >= 90

  -- the whole row (except the PDF menu) is one click area: moves the edit cursor to the region
  local clicked, hovered = UI.row_click_area(ctx, "##rowsel", inline and (aw - COMBO_W - 24) or (aw - 14))
  if clicked then r.SetEditCurPos(reg.start, true, false) end
  if hovered then ImGui.SetTooltip(ctx, word .. "\nClick to move the edit cursor to the region start.") end

  -- status dot (every row has one, so all names stay aligned)
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local fh = ImGui.GetFrameHeight(ctx)
  ImGui.Dummy(ctx, DOT_W, fh)
  -- shape + colour, so the state is clear also without colour vision:
  -- filled circle = has a PDF, ring = needs a PDF, dash = ignored
  local sdl, dcx, dcy = ImGui.GetWindowDrawList(ctx), sx + 5, sy + fh / 2
  if reg.status == "auto" or reg.status == "assigned" then
    ImGui.DrawList_AddCircleFilled(sdl, dcx, dcy, 4, dot_col)
  elseif reg.status == "ignored" then
    ImGui.DrawList_AddLine(sdl, dcx - 4, dcy, dcx + 4, dcy, dot_col, 2)
  else
    ImGui.DrawList_AddCircle(sdl, dcx, dcy, 4, dot_col, 0, 2)
  end

  -- name + time range; the dropdown goes to the next line in a narrow panel
  local text_w = inline and (aw - DOT_W - COMBO_W - 24) or (aw - DOT_W - 14)
  -- two columns: the names share one width, so every time range starts at the same x (left aligned)
  local times = Util.fmt_mmss(reg.start) .. " - " .. Util.fmt_mmss(reg.stop)
  local tw = ImGui.CalcTextSize(ctx, times)
  local col_w = math.min(R.region_name_w and R.region_name_w.w or 0, text_w - tw - 16)
  local show_times = col_w >= 40
  local name = UI.trunc_text(ctx, reg.name ~= "" and reg.name or "(unnamed region)",
    math.max(20, show_times and col_w or text_w))
  ImGui.SameLine(ctx, 0, 0)
  UI.row_text(ctx, name, name_col)
  if show_times then
    ImGui.SameLine(ctx, x + DOT_W + col_w + 16)
    UI.row_text(ctx, times, COL.TEXT_DIM)
  end

  -- dropdown: always shows the result for this region
  if inline then ImGui.SameLine(ctx, x + aw - COMBO_W - 14)
  else ImGui.SetCursorPosX(ctx, x + DOT_W) end
  if UI.combo(ctx, "##assign", preview, inline and COMBO_W or (aw - DOT_W - 14)) then
    local choice
    if ImGui.Selectable(ctx, "(auto-match by name)", not P.assign[reg.key] and not P.ignore[reg.key]) then choice = 0 end
    if ImGui.Selectable(ctx, "(ignore this region)", P.ignore[reg.key] == true) then choice = 1 end
    for j, p in ipairs(P.pdfs) do
      local sel = P.assign[reg.key] and Util.same_path(p, P.assign[reg.key]) or false
      if ImGui.Selectable(ctx, Util.name_of(p) .. "##pdf" .. j, sel) then choice = j + 1 end
    end
    ImGui.EndCombo(ctx)
    if choice then
      Project.set_region_choice(reg, (choice == 0 and "auto") or (choice == 1 and "ignore") or P.pdfs[choice - 1])
      if R.cur_region_key == reg.key then R.cur_region_key = nil end
    end
  end
  if reg.pdf then UI.tip(ctx, reg.pdf) end
  ImGui.PopID(ctx)
end

function UI.draw_regions_tab(ctx)
  local ch

  if UI.heading(ctx, "Region settings", "Switch PDF at regions: the PDF changes when the play cursor "
    .. "(or the edit cursor while stopped) enters a region that has a PDF.\n\n"
    .. "Rescan project: regions and markers are read again automatically after each project change. "
    .. "Use the button only if something looks wrong.\n\n"
    .. "Saved in this project, except 'Keep last page' (this computer).", nil, "rgn_settings") then
    ch, P.auto_switch = UI.checkbox(ctx, "Switch PDF at regions", P.auto_switch)
    if ch then
      Util.mark_pdirty()
      if P.auto_switch then R.cur_region_key = nil -- re-evaluate the region under the play cursor
      else Project.restore_stash() end
    end
    UI.tip(ctx, "The PDF changes when the play cursor enters a region that has a PDF.")
    ch, S.keep_last_page = UI.checkbox(ctx, "Keep last page", S.keep_last_page)
    UI.scope_after(ctx, "computer")
    if ch then Util.mark_dirty() end
    UI.tip(ctx, "During playback, a region without a PDF keeps the last page on screen, with a yellow note at the top.\n"
      .. "When playback stops, the region's buttons (add a PDF, choose, ignore) are shown.")
    if UI.full_button(ctx, "Rescan project##regions", "primary") then Project.rescan("regions") end
    UI.tip(ctx, "Markers and regions are rescanned automatically after each project change.\nUse this only if something looks wrong.")
    UI.section_msg(ctx, "regions")
  end -- "Region settings" open

  UI.group_sep(ctx)
  UI.heading(ctx, string.format("Region list (%d)", #R.regions), "A region is matched to a PDF when its name matches the PDF filename.\n"
    .. "Case and \".pdf\" are ignored; hyphens, underscores and repeated spaces count as one space.\n"
    .. "Example: region \"Song One\" matches \"song one.pdf\".\n\n"
    .. "Search: shows the regions whose name contains the text.\n"
    .. "Show: all, needs PDF (no PDF or several matches), assigned, ignored.\n"
    .. "Symbol: green filled circle = has a PDF, yellow ring = needs a PDF, grey dash = ignored.\n"
    .. "Blue row = the region under the play cursor / edit cursor.\n"
    .. "Click a region row to move the edit cursor to its start.", "project")
  if #R.regions == 0 then ImGui.TextDisabled(ctx, "No regions in this project."); return end
  -- search + "Show" menu, the same row as in the Library (menu text rebuilt only when a count changes)
  local c = UI.region_counts()
  local ck = c.all .. "," .. c.need .. "," .. c.assigned .. "," .. c.ignored
  if not R.region_show or R.region_show.key ~= ck then
    R.region_show = { key = ck, items = string.format("Show: all (%d)\0Show: needs PDF (%d)\0Show: assigned (%d)\0Show: ignored (%d)\0",
      c.all, c.need, c.assigned, c.ignored) }
  end
  R.region_search, R.region_filter = UI.search_row(ctx, "rgn", R.region_search or "", "Search regions...",
    R.region_filter, R.region_show.items)
  -- name column width: the widest region name, measured only when the region list changes
  -- (Project.scan_project makes a new R.regions table)
  if not R.region_name_w or R.region_name_w.regs ~= R.regions then
    local w = 0
    for _, rg in ipairs(R.regions) do
      w = math.max(w, (ImGui.CalcTextSize(ctx, rg.name ~= "" and rg.name or "(unnamed region)")))
    end
    R.region_name_w = { regs = R.regions, w = w }
  end
  UI.push_row_style(ctx)
  for i, reg in ipairs(R.regions) do
    if UI.region_passes_filter(reg) then UI.draw_region_row(ctx, i, reg) end
  end
  UI.pop_row_style(ctx)
end
-- Rows of one cue list (shared by the single-song view and the "(all songs)" view).
-- Red border around the last item, with the reason as its tooltip.
function UI.mark_invalid(ctx, reason)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = ImGui.GetItemRectMax(ctx)
  ImGui.DrawList_AddRect(ImGui.GetWindowDrawList(ctx), x0, y0, x1, y1, COL.RED, 4, 0, 1.5)
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, reason .. "\nType a correct value, or press Esc to keep the old one.") end
end

-- Small round remove button: a red ring with a red X; filled red with a white X on hover.
-- Drawn with lines (not a font glyph), so it looks the same with every font.
function UI.remove_x_button(ctx, id, size)
  local hit = ImGui.InvisibleButton(ctx, id, size, size)
  local hov = ImGui.IsItemHovered(ctx)
  if hov then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local cx, cy = x0 + size / 2, y0 + size / 2
  local rad = math.floor(size * 0.36)
  local d = rad * 0.45
  if hov then ImGui.DrawList_AddCircleFilled(dl, cx, cy, rad, COL.RED)
  else ImGui.DrawList_AddCircle(dl, cx, cy, rad, COL.RED, 0, 1.5) end
  local xc = hov and COL.WHITE or COL.RED
  ImGui.DrawList_AddLine(dl, cx - d, cy - d, cx + d, cy + d, xc, 1.8)
  ImGui.DrawList_AddLine(dl, cx - d, cy + d, cx + d, cy - d, xc, 1.8)
  return hit
end

-- first: the number of the first row (in "(all songs)" the numbers run on across the songs);
-- total: the highest number in the whole view, so every song's "#" column has the same width
function UI.draw_cue_rows(ctx, reg, list, first, total)
  local POS_W, NUM_W = 120, 70
  first = first or 1
  local key = Cues.key(reg)
  -- the cue that plays now (blue row)
  local now_i
  if Util.playing() and Cues.key(Cues.playing_region()) == key then
    local p = Cues.from_time(reg, r.GetPlayPosition())
    for i, c in ipairs(list) do if c.pos <= p + 1e-6 then now_i = i end end
  end
  -- columns, like an event list: # | Position | Page | Scroll % | X  (x relative to the row start)
  local IDX_W = math.max(28, (ImGui.CalcTextSize(ctx, tostring(total or (first + #list - 1)))) + 14)
  local POS_X = IDX_W
  local PAGE_X, SCROLL_X = POS_X + POS_W + 16, POS_X + POS_W + NUM_W + 24
  local DEL_X = POS_X + POS_W + NUM_W * 2 + 32
  local x0 = ImGui.GetCursorPosX(ctx)
  ImGui.TextDisabled(ctx, "#")
  ImGui.SameLine(ctx, x0 + POS_X); ImGui.TextDisabled(ctx, "Position")
  UI.tip(ctx, P.cue_unit == "seconds" and "Time from the song start (m:ss)." or "Bar.beat from the song start.")
  ImGui.SameLine(ctx, x0 + PAGE_X); ImGui.TextDisabled(ctx, "Page")
  ImGui.SameLine(ctx, x0 + SCROLL_X); ImGui.TextDisabled(ctx, "Scroll %")
  local remove_i, moved
  -- One cue field. `apply(raw)` saves a valid value and returns nil, or returns the reason it is
  -- not accepted: then the typed text stays, with a red border (no silent revert). Esc keeps the old value.
  local function cue_field(k, label, w, shown, apply)
    ImGui.SetNextItemWidth(ctx, w)
    local ch, txt = ImGui.InputText(ctx, label, R.cue_err[k] and R.cue_text[k] or shown)
    if ch then R.cue_text[k] = txt end
    if ImGui.IsItemDeactivated(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_Escape(), false) then
      R.cue_err[k], R.cue_text[k] = nil, nil
    elseif ImGui.IsItemDeactivatedAfterEdit(ctx) then
      local e = apply(Util.trim(R.cue_text[k] or ""))
      if e then R.cue_err[k] = e else R.cue_err[k], R.cue_text[k] = nil, nil end
    end
    if R.cue_err[k] then UI.mark_invalid(ctx, R.cue_err[k]) end
  end
  UI.push_row_style(ctx)
  for i, c in ipairs(list) do
    ImGui.PushID(ctx, "cue" .. key .. i)
    local aw = UI.panel_w(ctx)
    if i == now_i then UI.row_highlight(ctx, aw) end
    local id = key .. ":" .. i
    -- number of the cue in this list
    ImGui.SetCursorPosX(ctx, x0)
    UI.row_text(ctx, tostring(first + i - 1), COL.TEXT_DIM)
    -- position
    ImGui.SameLine(ctx, x0 + POS_X)
    cue_field(id .. "p", "##pos", POS_W, Cues.label(reg, c.pos), function(raw)
      local v = Cues.parse_label(reg, raw)
      if not v then return "Position not understood. Use bar.beat (e.g. 9.1.00) or m:ss (e.g. 0:24.5)." end
      c.pos = v; Cues.sort(list); Util.mark_pdirty(); moved = true
    end)
    -- page (checked against the page count of this song's PDF)
    ImGui.SameLine(ctx, x0 + PAGE_X)
    cue_field(id .. "g", "##page", NUM_W, c.page and tostring(c.page) or "", function(raw)
      if raw == "" then c.page = nil; Util.mark_pdirty(); return end
      local v, maxp = tonumber(raw), Cues.max_page(reg)
      if not v or v < 1 then return "The page must be a number from 1." end
      if maxp and v > maxp then return string.format("This PDF has only %d page(s).", maxp) end
      c.page = math.floor(v); Util.mark_pdirty()
    end)
    UI.tip(ctx, "Page to show from this cue. Empty = keep the page.")
    -- scroll (an empty field removes the scroll point; a wrong value never does)
    ImGui.SameLine(ctx, x0 + SCROLL_X)
    cue_field(id .. "s", "##scroll", NUM_W, c.scroll and string.format("%g", c.scroll) or "", function(raw)
      if raw == "" then c.scroll = nil; Util.mark_pdirty(); return end
      local v = tonumber((raw:gsub("%%$", "")))
      if not v or v < 0 or v > 100 then return "Scroll must be a number from 0 to 100." end
      c.scroll = v; Util.mark_pdirty()
    end)
    UI.tip(ctx, "Scroll position at this cue: 0 = top, 100 = bottom. Empty = no scroll point.\n"
      .. "Between two scroll points the page moves smoothly.")
    -- remove
    ImGui.SameLine(ctx, x0 + DEL_X)
    if UI.remove_x_button(ctx, "##del", UI.h(ctx)) then remove_i = i end
    UI.tip(ctx, "Remove this cue")
    ImGui.PopID(ctx)
  end
  UI.pop_row_style(ctx)
  if remove_i then Cues.remove(reg, remove_i) end
  -- rows changed place: field states are stored by row number, so they would point to other cues
  if remove_i or moved then R.cue_err, R.cue_text = {}, {} end
end

-- Cue list editor (Autoscroll tab, shown when the mode is "Cue list")
function UI.draw_cue_list(ctx)
  local ch
  -- part 1: cue settings (unit, song, recording, tools; can be closed); part 2 below: the cue list itself
  local open = UI.heading(ctx, "Cue settings", "A cue list does the same as PDF markers (PDFPAGE / PDFSCROLL), but it is stored in the project "
    .. "data, not as markers. Use it when another program (for example a setlist program) must not see extra markers.\n\n"
    .. "Easiest way: turn on 'Record cues' (R), play the song and press 'Add page turn' (C key) at each page turn, and 'Add scroll point' "
    .. "(S key) where the page must move. A MIDI button can do the same (Settings > MIDI).\n\n"
    .. "Each song (region) has its own cues. The times are counted from the region start, so the cues move with the region.\n"
    .. "Beats: a cue stays on its bar and beat when the tempo changes. Seconds: a cue stays at its time.", "project", "cue_settings")
  if open then -- fold block 1: mode note, unit, song menu
    -- not in the Cue list mode: say so first, with a one-click fix (blue, like the other main buttons)
    if Nav.scroll_mode() ~= "cues" then
      UI.note(ctx, "The autoscroll mode is not Cue list. The cues do not move the page.", COL.YELLOW)
      if UI.full_button(ctx, "Use Cue list mode", "primary") then Nav.set_scroll_mode("cues") end
    end

    -- unit (per project)
    UI.field(ctx, "Count time in")
    local ui = (P.cue_unit == "seconds") and 1 or 0
    ch, ui = ImGui.Combo(ctx, "##cueunit", ui, "Beats (bar.beat)\0Seconds\0")
    if ch then Cues.set_unit(ui == 1 and "seconds" or "beats") end
    UI.tip(ctx, "Saved with this project. Existing cues keep their place when you switch.")

    -- which song: (all songs), (current song), each region, (whole project) when needed.
    -- "Current song" = the region at the play cursor during playback, at the edit cursor when stopped
    -- (REAPER's names for the two cursors), see Project.time_pos.
    local entries = { { label = "(all songs)", key = "_all" }, { label = "(current song)", key = nil } }
    for _, rg in ipairs(R.regions) do
      entries[#entries + 1] = { label = (rg.name ~= "" and rg.name or "(unnamed region)"), key = rg.key, reg = rg }
    end
    local proj_cues = P.cues["_project"] and #P.cues["_project"] > 0
    if #R.regions == 0 or proj_cues then
      entries[#entries + 1] = { label = "(whole project, no region)", key = "_project" }
    end
    local sel, labels = 1, {}
    for i, e in ipairs(entries) do
      labels[i] = e.label
      if e.key == R.cue_edit_key then sel = i - 1 end
    end
    UI.field(ctx, "Song")
    ch, sel = ImGui.Combo(ctx, "##cuereg", sel, table.concat(labels, "\0") .. "\0")
    if ch then R.cue_edit_key = entries[sel + 1].key end
    UI.tip(ctx, "(current song): the song at the play cursor during playback, at the edit cursor when stopped.\n"
      .. "(all songs) shows the cues of every song, with the song name above each list.\n"
      .. "(whole project, no region) is only for projects without regions.")
    -- "(current song)": which song that is, next to the menu (below it when there is no room)
    if R.cue_edit_key == nil then
      local cur = Project.region_at(Project.time_pos())
      local txt = "Editing: " .. (cur and (cur.name ~= "" and cur.name or "(unnamed region)") or "whole project (no region)")
      local free =ImGui.GetWindowPos(ctx) + ImGui.GetWindowWidth(ctx) - 12 - (ImGui.GetItemRectMax(ctx) + 10)
      if free >= 80 then
        ImGui.SameLine(ctx, 0, 10)
        UI.row_text(ctx, UI.trunc_text(ctx, txt, free), COL.TEXT_DIM)
      else
        UI.note(ctx, txt, COL.TEXT_DIM)
      end
    end
  end -- fold block 1

  -- the song shown below: worked out also when "Cue settings" is closed
  local all = (R.cue_edit_key == "_all")
  local reg
  if not all then
    if R.cue_edit_key == nil then
      reg = Project.region_at(Project.time_pos())
    elseif R.cue_edit_key ~= "_project" then
      reg = Project.region_by_key(R.cue_edit_key)
      if not reg then R.cue_edit_key = "_all" end -- the region was deleted: back to the default
    end
  end
  if open then -- fold block 2: recording, tools, questions, messages
    UI.vgap(ctx, UI.sp("LIST"))

    -- recording: the toggle, then "Add page turn" and "Add scroll point" in the same row
    -- (the toggle is only usable in the Cue list mode: disabled otherwise, with the reason)
    local can = Nav.scroll_mode() == "cues"
    local _, rec_cx, rec_cw = UI.form(ctx, "Record cues (R)")
    if not can then ImGui.BeginDisabled(ctx, true) end
    local rch, rv = UI.checkbox(ctx, "Record cues (R)", R.rec)
    if not can then ImGui.EndDisabled(ctx) end -- always paired with BeginDisabled above
    if can and rch and rv ~= R.rec then UI.toggle_rec() end
    if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
      ImGui.SetTooltip(ctx, can and ("While on, the C and S keys and the MIDI cue buttons add cues. Not saved: it is off when Chart Cue starts.\n"
        .. "The two buttons next to it always work.") or "Works only in the Cue list mode. Click 'Use Cue list mode' above.")
    end
    do
      ImGui.SameLine(ctx, 0, 12)
      local bx = ImGui.GetCursorPosX(ctx)
      local avail = rec_cx + rec_cw - bx
      local bw = math.floor((avail - 8) / 2)
      local need = math.max((ImGui.CalcTextSize(ctx, "Add page turn (C)")), (ImGui.CalcTextSize(ctx, "Add scroll point (S)"))) + 20
      if bw < need then ImGui.NewLine(ctx); ImGui.SetCursorPosX(ctx, rec_cx); bx = rec_cx; bw = math.floor((rec_cw - 8) / 2) end
      local nc, nv = UI.push_kind(ctx, "primary")
      if UI.button(ctx, "Add page turn (C)", bw, UI.h(ctx)) then Cues.add_page_turn() end
      UI.tip(ctx, "The next page after the cue before it, at the top. Added at the play cursor, in the current song.")
      ImGui.SameLine(ctx, 0, 8)
      if UI.button(ctx, "Add scroll point (S)", bw, UI.h(ctx)) then Cues.add_scroll_point() end
      UI.tip(ctx, "The same page as the cue before it, at the current scroll position. Added at the play cursor, in the current song.")
      UI.pop_kind(ctx, nc, nv)
    end
    -- tools, grouped by subject: markers (copy | remove) first, then the most dangerous action last
    local song = all and "_all" or Cues.key(reg) -- an open question closes when the song changes
    local c1, c3 = UI.button_pair2(ctx, "Copy markers into cues", "primary", "Remove PDF markers...", "danger",
      all and "Copies the PDF markers of every song into its cue list."
        or "Copies the PDF markers of this song into its cue list.",
      (all and "All songs: " or "This song: ")
        .. "removes only markers named PDFPAGE ... or PDFSCROLL ... (one undo step).\n"
        .. "Use it after 'Copy markers into cues', so a setlist program sees no extra markers.")
    local c2 = UI.danger_button(ctx, "Remove all cues...")
    if c1 then
      local n = 0
      if all then
        for _, rg in ipairs(R.regions) do n = n + Cues.convert_markers(rg) end
        if #R.regions == 0 then n = Cues.convert_markers(nil) end
      else
        n = Cues.convert_markers(reg)
      end
      if n > 0 then
        Msg.notify(string.format("%d cue(s) made from markers. You can now remove the PDF markers.", n), false, "cues")
      else
        Msg.notify("No PDFPAGE or PDFSCROLL markers found.", false, "cues")
      end
    end
    if c2 then
      local key = song
      local count = 0
      if all then for _, l in pairs(P.cues) do count = count + #l end else count = #Cues.list(reg) end
      if count == 0 then
        Msg.notify("There are no cues to remove.", false, "cues")
      else
        local what = all and "all songs" or (reg and ('"' .. reg.name .. '"') or "the whole project")
        UI.ask("cues_all", string.format("Remove all %d cue(s) of %s? This cannot be undone.", count, what),
          "Yes, remove", function()
            Cues.remove_all(key)
            Msg.notify(string.format("%d cue(s) removed.", count), false, "cues")
          end, song)
      end
    end
    -- remove the Chart Cue markers of this song (or of all songs) - e.g. after copying them into cues
    if c3 then
      if all or not reg then UI.ask_remove_markers("cue_markers", -math.huge, math.huge, "the whole project", song)
      else UI.ask_remove_markers("cue_markers", reg.start, reg.stop, '"' .. reg.name .. '"', song) end
    end
    UI.draw_ask(ctx, "cues_all", song)
    UI.draw_ask(ctx, "cue_markers", song)
    UI.section_msg(ctx, "cues")
  end -- fold block 2

  -- part 2: the cue list, as its own section (more space and its own heading)
  UI.group_sep(ctx)
  local ncues = 0 -- the cues shown below: this song, or every song for "(all songs)"
  if all then for _, l in pairs(P.cues) do ncues = ncues + #l end else ncues = #Cues.list(reg) end
  UI.heading(ctx, string.format("Cue list (%d)", ncues), "Type a new position, page or scroll value to change a cue; click the red X to remove it.\n"
    .. "A red border means the value is not accepted: move the mouse over it to see why, then correct it or press Esc.\n"
    .. "Blue row = the cue that plays now.", "project")
  if all then
    local shown, num = 0, 1 -- num: the number of the next cue (runs on across the songs)
    local function block(rg, title)
      local list = Cues.list(rg)
      if #list == 0 then return end
      shown = shown + 1
      UI.song_title(ctx, title, rg)
      UI.draw_cue_rows(ctx, rg, list, num, ncues)
      num = num + #list
    end
    for _, rg in ipairs(R.regions) do block(rg, rg.name ~= "" and rg.name or "(unnamed region)") end
    block(nil, "(whole project, no region)")
    if shown == 0 then
      UI.note(ctx, "No cues yet. Play a song and press 'Add page turn' (C) at each page turn.", COL.GREY)
    end
    return
  end
  local list = Cues.list(reg)
  UI.song_title(ctx, reg and (reg.name ~= "" and reg.name or "(unnamed region)") or "(whole project, no region)", reg)
  if #list == 0 then
    UI.note(ctx, "No cues yet. Play the song and press 'Add page turn' (C) at each page turn, "
      .. "and 'Add scroll point' (S) where the page must move.", COL.GREY)
    return
  end
  UI.draw_cue_rows(ctx, reg, list)
end
function UI.draw_autoscroll_tab(ctx)
  local ch
  UI.heading(ctx, "Mode", "Autoscroll mode and Turn pages: saved in this project.\n"
    .. "Default for new projects: saved on this computer (the mode of a project where you have not chosen one).\n\n"
    .. "Turn pages: show the next page a little before its page turn (PDFPAGE marker or page-turn cue), "
    .. "so you can read ahead.")
  local mi = 0
  for i, m in ipairs(SCROLL_MODES) do if m == Nav.scroll_mode() then mi = i - 1 end end
  UI.field(ctx, "Autoscroll mode")
  ch, mi = ImGui.Combo(ctx, "##ascroll", mi, SCROLL_ITEMS)
  if ch then Nav.set_scroll_mode(SCROLL_MODES[mi + 1]) end
  -- default for projects that have no mode of their own (S.scroll_mode)
  local di = 0
  for i, m in ipairs(SCROLL_MODES) do if m == S.scroll_mode then di = i - 1 end end
  UI.field(ctx, "Default for new projects")
  ch, di = ImGui.Combo(ctx, "##ascrolldef", di, SCROLL_ITEMS)
  if ch then S.scroll_mode = SCROLL_MODES[di + 1]; Util.mark_dirty() end
  UI.scope_after(ctx, "computer")
  UI.tip(ctx, "The mode of a project where you have not chosen a mode yet.")
  local mode = Nav.scroll_mode()
  if mode == "off" then
    UI.note(ctx, "Autoscroll is off. The page moves only when you scroll it.", COL.GREY)
    return
  end
  -- turn pages early (Markers and Cue list), saved in this project like the mode
  do
    local EARLY = { 0, 0.5, 1, 2 }
    local ei = 0
    for i, v in ipairs(EARLY) do if math.abs(P.turn_early - v) < 1e-6 then ei = i - 1 end end
    UI.field(ctx, "Turn pages")
    local ech
    ech, ei = ImGui.Combo(ctx, "##turnearly", ei, "On time\0Half a beat early\0One beat early\0Two beats early\0")
    if ech then P.turn_early = EARLY[ei + 1]; Util.mark_pdirty() end
    UI.tip(ctx, "Shows the next page a little before its page turn, so you can read ahead.\n"
      .. "The new page starts at the top. Saved in this project.")
  end

  -- only the settings of the chosen mode are shown
  UI.group_sep(ctx)
  if mode == "cues" then UI.note(ctx, "Edit the cues in the Cues tab.", COL.GREY); return end

  UI.heading(ctx, "Marker settings", "PDFSCROLL 0..100 sets the scroll position as a percentage of the current page.\n"
    .. "0 = top, 100 = bottom. The position is interpolated between markers by playback position.\n\n"
    .. "PDFPAGE n turns to page n and resets scroll to 0.\n"
    .. "If a PDFSCROLL marker occurs at the same time, PDFSCROLL wins.\n"
    .. "Marker names are case-insensitive.\n\n"
    .. "The markers inside a region work from the region start to the region end.", "project")
  local rs, rm = UI.button_pair2(ctx, "Rescan project##markers", "primary", "Remove PDF markers...##markers", "danger",
    "Markers and regions are rescanned automatically after each project change.\nUse this only if something looks wrong.",
    "Removes only PDF markers (names starting with PDFPAGE or PDFSCROLL).\n"
    .. "Regions and other markers are not changed. One undo step (Ctrl+Z).")
  if rs then Project.rescan("cues") end
  if rm then UI.ask_remove_markers("markers_all", -math.huge, math.huge, "the whole project") end
  UI.draw_ask(ctx, "markers_all")
  UI.section_msg(ctx, "cues")
  local nwarn = #R.marker_warns
  UI.note(ctx, string.format("%d PDFSCROLL markers, %d PDFPAGE markers, %d invalid.", #R.scroll_pts, #R.page_pts, nwarn),
    nwarn == 0 and COL.GREEN or COL.YELLOW)
  for i, w in ipairs(R.marker_warns) do
    if i > 5 then UI.note(ctx, string.format("... and %d more invalid markers", nwarn - 5), COL.YELLOW); break end
    UI.note(ctx, w, COL.YELLOW)
  end
end

function UI.draw_midi_tab(ctx)
  local ch

  UI.heading(ctx, "Mode", "MIDI control is optional. Ignore this tab if you do not use a controller.\n\n"
    .. "Absolute: a knob/fader position (0-127) sets the scroll position.\n"
    .. "Relative: an endless encoder moves the page up or down. Pick the encoding your controller sends.", "computer")
  UI.field(ctx, "MIDI mode")
  local mi = (S.mode == "absolute") and 0 or 1
  ch, mi = ImGui.Combo(ctx, "##midimode", mi, MODE_ITEMS)
  if ch then S.mode = (mi == 0) and "absolute" or "relative"; Util.mark_dirty() end
  -- only the rows of the chosen MIDI mode
  if S.mode == "absolute" then
    UI.field(ctx, "Absolute CC #")
    ch, S.cc_abs = ImGui.InputInt(ctx, "##ccabs", S.cc_abs, 1, 8)
    if ch then S.cc_abs = Util.clamp(S.cc_abs, 0, 127); Util.mark_dirty() end
  else
    UI.field(ctx, "Relative CC #")
    ch, S.cc_rel = ImGui.InputInt(ctx, "##ccrel", S.cc_rel, 1, 8)
    if ch then S.cc_rel = Util.clamp(S.cc_rel, 0, 127); Util.mark_dirty() end
    UI.field(ctx, "Relative encoding")
    local ri = S.rel_encoding - 1
    ch, ri = ImGui.Combo(ctx, "##relenc", ri, REL_ITEMS)
    if ch then S.rel_encoding = ri + 1; Util.mark_dirty() end
    ch, S.rel_invert = UI.checkbox(ctx, "Invert direction", S.rel_invert)
    if ch then Util.mark_dirty() end
    UI.field(ctx, "Sensitivity (px/tick)")
    ch, S.sensitivity = ImGui.SliderDouble(ctx, "##sens", S.sensitivity, 1, 200, "%.0f")
    if ch then Util.mark_dirty() end
  end

  UI.group_sep(ctx)
  UI.heading(ctx, "Input", "'Read MIDI directly' uses the CC numbers above. "
    .. "Leave it off if the script is bound to a CC in the Action List.\n\n"
    .. "Turn pages with MIDI: a CC value of 64 or more turns the page (direct input only).", "computer")
  ch, S.direct_midi = UI.checkbox(ctx, "Read MIDI directly", S.direct_midi)
  UI.tip(ctx, "Reads the CC numbers above directly from your MIDI inputs (no Action List binding needed).")
  if ch then
    Util.mark_dirty()
    if S.direct_midi and r.MIDI_GetRecentInputEvent then
      R.last_midi_seq = (r.MIDI_GetRecentInputEvent(0)) or 0
    end
  end
  if not S.direct_midi then UI.draw_midi_debug(ctx); return end -- the options below need direct input
  ch, S.midi_page_turn = UI.checkbox(ctx, "Turn pages with MIDI", S.midi_page_turn)
  UI.tip(ctx, "A CC value of 64 or more counts as a button press.")
  if ch then Util.mark_dirty() end
  if S.midi_page_turn then
    UI.field(ctx, "Next-page CC #")
    ch, S.cc_page_next = ImGui.InputInt(ctx, "##ccnext", S.cc_page_next, 1, 8)
    if ch then S.cc_page_next = Util.clamp(S.cc_page_next, 0, 127); Util.mark_dirty() end
    UI.field(ctx, "Previous-page CC #")
    ch, S.cc_page_prev = ImGui.InputInt(ctx, "##ccprev", S.cc_page_prev, 1, 8)
    if ch then S.cc_page_prev = Util.clamp(S.cc_page_prev, 0, 127); Util.mark_dirty() end
  end
  ch, S.midi_add_cue = UI.checkbox(ctx, "Add cues with MIDI", S.midi_add_cue)
  if ch then Util.mark_dirty() end
  UI.tip(ctx, "Same as 'Add page turn' and 'Add scroll point' in the Cues tab.\n"
    .. "A value of 64 or more counts as a press.")
  if S.midi_add_cue then
    UI.field(ctx, "Page turn CC #")
    ch, S.cc_add_cue = ImGui.InputInt(ctx, "##ccaddcue", S.cc_add_cue, 1, 8)
    if ch then S.cc_add_cue = Util.clamp(S.cc_add_cue, 0, 127); Util.mark_dirty() end
    UI.field(ctx, "Scroll point CC #")
    ch, S.cc_add_scroll = ImGui.InputInt(ctx, "##ccaddscroll", S.cc_add_scroll, 1, 8)
    if ch then S.cc_add_scroll = Util.clamp(S.cc_add_scroll, 0, 127); Util.mark_dirty() end
  end
  UI.draw_midi_debug(ctx)
end

-- "Show MIDI debug" (Troubleshooting, end of the MIDI section): the last CC that Chart Cue received.
function UI.draw_midi_debug(ctx)
  local ch
  UI.group_sep(ctx)
  UI.heading(ctx, "Troubleshooting", nil, "computer")
  ch, S.show_midi_debug = UI.checkbox(ctx, "Show MIDI debug", S.show_midi_debug)
  if ch then Util.mark_dirty() end
  UI.tip(ctx, "Shows the last CC number and value that Chart Cue received. Use it to find the CC number of your knob.")
  if S.show_midi_debug then
    local d = R.dbg
    UI.note(ctx, string.format("Last raw CC number: %s", d.cc and tostring(d.cc) or "unknown (action-bound)"))
    UI.note(ctx, string.format("Last raw CC value: %s", d.val and tostring(d.val) or "-"))
    UI.note(ctx, "Decoded: " .. (d.decoded or "-"))
    UI.note(ctx, "MIDI mode: " .. S.mode .. (S.mode == "relative" and (" (encoding " .. S.rel_encoding .. ")") or ""))
    UI.note(ctx, "Source: " .. (d.src or "-"))
  end
end

-- Poppler path + status. Shown inside "Rendering", only when the PDF engine is Poppler.
function UI.draw_poppler_settings(ctx)
  local ch
  local _, _, fw = UI.form(ctx) -- measure at the row start, before the label moves the cursor
  UI.field(ctx, "pdftoppm.exe")
  ImGui.SetNextItemWidth(ctx, math.max(60, fw - CFG.SMALL_BTN_W - 8))
  ch, S.pdftoppm_path = ImGui.InputText(ctx, "##exe", S.pdftoppm_path)
  if ch then Util.mark_dirty() end
  UI.tip(ctx, "Poppler for Windows: select pdftoppm.exe. pdfinfo.exe must be in the same folder.")
  local edited = ImGui.IsItemDeactivatedAfterEdit(ctx)
  ImGui.SameLine(ctx, 0, 8)
  if UI.button(ctx, "Browse...", CFG.SMALL_BTN_W, 0) then PDF.browse_exe() end
  if edited then
    R.exe = PDF.find_pdftoppm(); PDF.check_pdfinfo()
    if S.pdf_path ~= "" then PDF.open_pdf(S.pdf_path, true) end
  end
  if not R.exe then UI.note(ctx, "pdftoppm.exe not found. Select it, or use the Windows engine.", COL.RED)
  elseif not R.pdfinfo_ok then UI.note(ctx, POPPLER_PDFINFO_WARN, COL.YELLOW)
  else UI.note(ctx, "OK - pdftoppm.exe and pdfinfo.exe found.", COL.GREEN) end
end

-- "Reset all settings": back to the defaults copied before settings.ini was read (asked first, inline).
function UI.reset_all_settings()
  for k, v in pairs(CFG.S_DEFAULTS) do
    if not CFG.KEEP_ON_RESET[k] then S[k] = v end
  end
  R.dpi_edit = S.dpi; R.exe = nil; R.force_scale = false
  R.reset_layout = true
  Util.save_settings(); R.dirty = false
  if S.pdf_path ~= "" then PDF.open_pdf(S.pdf_path, true) end
  Msg.notify("All settings were reset to the defaults.", false, "display")
end

-- Display and view: sorted by what you do (View on stage, Page quality, Layout, Troubleshooting).
function UI.draw_display_tab(ctx)
  local ch
  UI.heading(ctx, "View", "What you see during playback.\n\n"
    .. "Page brightness: lower than 100% makes the white paper darker for dark stages. The page is not prepared again.\n\n"
    .. "Page-turn flash: a short blue frame around the page when it turns during playback.\n\n"
    .. "Hide controls when playing: only a small toolbar shows during playback. "
    .. "The status bar shows only when there is an error.", "computer")
  -- one slider: 100% = not dimmed (S.dim_page stays in settings.ini, set from the slider)
  UI.field(ctx, "Page brightness")
  local pct = S.dim_page and math.floor(S.dim_level * 100 + 0.5) or 100
  ch, pct = ImGui.SliderInt(ctx, "##dimlevel", pct, 30, 100, "%d%%")
  if ch then S.dim_page = pct < 100; S.dim_level = pct / 100; Util.mark_dirty() end
  UI.tip(ctx, "Lower than 100% makes the white paper darker for dark stages.")
  ch, S.turn_flash = UI.checkbox(ctx, "Page-turn flash", S.turn_flash)
  if ch then Util.mark_dirty() end
  ch, S.hide_controls_playing = UI.checkbox(ctx, "Hide controls when playing", S.hide_controls_playing)
  if ch then Util.mark_dirty() end

  UI.group_sep(ctx)
  UI.heading(ctx, "Page quality", "Page sharpness (DPI) sets how sharp the page images are. Higher = sharper, but slower and more disk space.\n\n"
    .. "'Match DPI to current view' sets the DPI for the current zoom.", "computer")
  UI.field(ctx, "PDF engine")
  local ei = (PDF.engine() == "poppler") and 1 or 0
  ch, ei = ImGui.Combo(ctx, "##engine", ei, "Windows (built in)\0Poppler (pdftoppm.exe)\0")
  if ch then
    S.engine = (ei == 1) and "poppler" or "windows"; Util.mark_dirty()
    if S.engine == "poppler" and not R.exe then R.exe = PDF.find_pdftoppm(); PDF.check_pdfinfo() end
    Msg.set_error(nil)
    if S.pdf_path ~= "" then PDF.open_pdf(S.pdf_path, true) end
  end
  UI.tip(ctx, "Windows (built in): no extra software (Windows 10/11).\nPoppler: optional; select pdftoppm.exe below.")
  if PDF.engine() == "poppler" then UI.draw_poppler_settings(ctx) end
  -- the DPI number: shown as text with "Change"; the field appears only when you want to type a value
  -- (or when no PDF is open yet, so there is no quality note and no "Match DPI" button)
  if R.dpi_manual or not R.last_ratio then
    UI.field(ctx, "Page sharpness (DPI)")
    ch, R.dpi_edit = ImGui.InputInt(ctx, "##dpi", R.dpi_edit or S.dpi, 25, 50)
    if ImGui.IsItemDeactivatedAfterEdit(ctx) then
      local d = Util.clamp(R.dpi_edit, 50, 600)
      R.dpi_edit = d
      if d ~= S.dpi then S.dpi = d; Util.mark_dirty(); if S.pdf_path ~= "" then PDF.open_pdf(S.pdf_path, true) end end
    end
  else
    local cx, cw = UI.row_start(ctx, "Page sharpness")
    local txt = string.format("%d DPI", S.dpi)
    UI.row_text(ctx, txt)
    local bw = UI.btn_w(ctx, "Change", CFG.SMALL_BTN_W)
    ImGui.SameLine(ctx, math.max(cx + (ImGui.CalcTextSize(ctx, txt)) + 12, cx + cw - bw))
    if UI.row_button(ctx, "Change##dpi", bw, "ghost") then R.dpi_manual = true; R.dpi_edit = S.dpi end
    UI.tip(ctx, "Type the DPI by hand. Usually 'Match DPI to current view' below is enough.")
  end
  if R.last_ratio then
    local q, qcol
    if R.last_ratio > 1.05 then q, qcol = "Blurry - raise the DPI", COL.YELLOW
    elseif R.last_ratio < 0.6 then q, qcol = "Soft - lower the DPI or zoom in", COL.YELLOW
    else q, qcol = "Sharp", COL.GREEN end
    UI.note(ctx, "Page quality: " .. q, qcol)
    UI.tip(ctx, string.format("Image scale on screen: %.2fx (1.00 = pixel-perfect)", R.last_ratio))
    if R.scale_to then
      UI.note(ctx, "Maximum page size reached.", COL.GREY)
      UI.tip(ctx, string.format("Pages are capped at %d px (CFG.MAX_IMAGE_DIM); the DPI cannot go higher for this PDF.", R.scale_to))
    elseif UI.full_button(ctx, "Match DPI to current view", "primary") then
      local target = Util.clamp(math.floor(S.dpi * R.last_ratio * 1.25 / 10 + 0.5) * 10, 72, 600)
      if target ~= S.dpi then
        S.dpi = target; R.dpi_edit = target; Util.mark_dirty()
        if S.pdf_path ~= "" then PDF.open_pdf(S.pdf_path, true) end
        Msg.notify(string.format("Page sharpness set to %d DPI.", target), false, "display")
      else
        Msg.notify(string.format("Page sharpness already fits the view (%d DPI).", S.dpi), false, "display")
      end
    end
  end

  UI.group_sep(ctx)
  UI.heading(ctx, "Layout", "Comfortable layout: more empty space between rows and sections. Buttons, fields and tabs keep their size.\n\n"
    .. "Reset window layout: moves the window back to its default size and place.", "computer")
  ch, S.comfortable = UI.checkbox(ctx, "Comfortable layout", S.comfortable)
  if ch then Util.mark_dirty() end
  UI.tip(ctx, "More empty space between rows and sections. Buttons, fields and tabs keep their size.")
  if UI.full_button(ctx, "Reset window layout", "primary") then
    R.reset_layout = true
    Msg.notify("Window layout reset.", false, "display")
  end

  UI.group_sep(ctx)
  UI.heading(ctx, "Troubleshooting", "Write diagnostic log: writes technical events (visibility, docking, recovered errors) "
    .. "to the REAPER console. Use it only to report a problem.\n\n"
    .. "Page cache: the pages are stored on disk so a PDF opens fast the next time. "
    .. "Clearing it never deletes the page on screen; pages are prepared again when needed.\n\n"
    .. "Reset all settings: sets the settings of this computer back to the defaults. "
    .. "Your projects (library, regions) are not changed.", "computer")
  ch, S.log_diag = UI.checkbox(ctx, "Write diagnostic log", S.log_diag)
  if ch then Util.mark_dirty() end
  UI.tip(ctx, "Writes technical events to the REAPER console.")
  -- page cache: one row "<size>  [Clear...]". The size is calculated in the background when this
  -- section is shown and no size is known yet (never every frame: the job runs once, then the result stays).
  local clearing = R.cache_clear_t and Util.now() - R.cache_clear_t < 2 -- wait for the delete to run
  if not R.cache_size and not R.size_job and not clearing then Util.start_dir_size(CFG.CACHE_ROOT, 3) end
  do
    local cx, cw = UI.row_start(ctx, "Page cache")
    local bw = UI.btn_w(ctx, "Clear...", CFG.SMALL_BTN_W)
    local size_txt = (R.size_job or clearing or not R.cache_size) and "Calculating..." or Util.fmt_bytes(R.cache_size)
    UI.row_text(ctx, size_txt, COL.TEXT_DIM)
    UI.tip(ctx, "Total size of the page cache of all PDFs.\nFolder: " .. (R.cache_dir or CFG.CACHE_ROOT))
    -- the button at the right end of the control column (after the text when the column is narrow)
    ImGui.SameLine(ctx, math.max(cx + (ImGui.CalcTextSize(ctx, size_txt)) + 12, cx + cw - bw))
    if UI.row_button(ctx, "Clear...", bw, true) then
      UI.ask("cache_clear", "Delete the whole page cache? The page on screen is kept; pages are prepared again when needed.",
        "Yes, delete", function()
          PDF.clear_all_cache(); R.cache_size = nil
          Msg.notify("Page cache cleared.", false, "display")
        end)
    end
  end
  UI.draw_ask(ctx, "cache_clear")
  if UI.danger_button(ctx, "Reset all settings...") then
    UI.ask("reset_all", "Reset all Chart Cue settings on this computer to the defaults? This resets the PDF engine, "
      .. "page sharpness, window, MIDI and autoscroll settings. Your projects (library, regions, cues) are not changed.",
      "Yes, reset", UI.reset_all_settings)
  end
  UI.draw_ask(ctx, "reset_all")
  UI.section_msg(ctx, "display")
end

function UI.draw_project_tab(ctx)
  local ch
  UI.heading(ctx, "Current project", nil, "project")
  do -- Project file: label | path | "Show in Explorer" right-aligned, across the full panel width
    local x0 = ImGui.GetCursorPosX(ctx)
    local aw = UI.panel_w(ctx)
    local bw = UI.btn_w(ctx, "Show in Explorer", CFG.EXPLORER_BTN_W)
    local btn_x = x0 + aw - bw - 14
    local saved = (R.projfn ~= "")
    local _, cx, _, wide = UI.form(ctx)
    UI.row_text(ctx, "Project file")
    if wide then ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, cx) end
    local tw = math.max(40, btn_x - ImGui.GetCursorPosX(ctx) - 8)
    UI.row_text(ctx, UI.trunc_left(ctx, saved and R.projfn or "(not saved yet)", tw), COL.GREY)
    if saved then UI.tip(ctx, R.projfn) else UI.tip(ctx, "Chart Cue settings are saved with the project when you save it.") end
    ImGui.SameLine(ctx, btn_x)
    if not saved then ImGui.BeginDisabled(ctx, true) end
    local hit = UI.row_button(ctx, "Show in Explorer", bw, "ghost")
    if not saved then ImGui.EndDisabled(ctx) end -- always paired with BeginDisabled above
    if hit and saved then Util.show_in_explorer(R.projfn) end
  end

  UI.group_sep(ctx)
  UI.heading(ctx, "Open and close Chart Cue",
    "Open automatically: Chart Cue opens when you open (or switch to) any project that contains Chart Cue data. "
    .. "It adds 3 marked lines to REAPER's __startup.lua (with a backup) and needs one REAPER restart. No SWS needed.\n\n"
    .. "Close: Chart Cue closes when you close the project tab, or when File > Close / New / Open project "
    .. "replaces the project in the same tab. Switching tabs and 'Save as' keep it open.", "computer")

  -- main method: automatic open for all Chart Cue projects
  local on = Autostart.installed()
  ch, on = UI.checkbox(ctx, "Open automatically", on)
  if ch then
    if on then Autostart.install() else Autostart.uninstall() end
  end
  UI.tip(ctx, "Chart Cue opens by itself when you open a project that uses it.\nNeeds one REAPER restart after you change it.")
  UI.section_msg(ctx, "project")

  -- close
  ch, S.close_with_project = UI.checkbox(ctx, "Close with project", S.close_with_project)
  if ch then Util.mark_dirty() end
  UI.tip(ctx, "Chart Cue closes when its project tab closes, or when File > Close / New / Open project replaces it.")

  -- cleanup only: older versions could open Chart Cue with an SWS project startup action
  if Autostart.sws_installed() then
    UI.vgap(ctx, UI.sp("TITLE_BEFORE"))
    UI.note(ctx, "Older projects only: if you used an SWS startup action for Chart Cue, remove it here.", COL.GREY)
    if UI.danger_button(ctx, "Remove the SWS startup action...") then
      local clr, set = Autostart.sws_clear_action_id(), Autostart.sws_startup_action_id()
      if clr then
        r.Main_OnCommand(clr, 0)
        Msg.notify("SWS startup action cleared. Save the project (Ctrl+S) to keep the change.", false, "project", true)
      elseif set then
        r.Main_OnCommand(set, 0)
        Msg.notify("In the SWS dialog delete the command ID (leave it empty) and press OK, then save the project.", false, "project", true)
      else
        Msg.notify("Run 'SWS/S&M: Set project startup action', leave the command ID empty, press OK and save the project.", false, "project", true)
      end
    end
    UI.tip(ctx, "Two open methods can start Chart Cue twice. 'Open automatically' is enough.")
    UI.section_msg(ctx, "project")
  end
end

---------------------------------------------------------------------------
-- HELP: one text for the Help panel ("?" at the end of the tab strip) and the browser guide.
--   text = simple words, shown in the panel AND the guide
--   more = extra details, shown only in the browser guide
-- Format: blank line = new paragraph, "- " = bullet, "1. " = numbered step.
---------------------------------------------------------------------------
local HELP_TOPICS = {
  { title = "Getting started", text = [==[
Chart Cue shows your sheet music or chord charts (PDF files) inside REAPER. It can also move the page for you while the song plays.

1. Click the Library tab, then click "Add PDF..." and pick a PDF file.
2. Click the PDF in the list. The first page appears.
3. Use the < and > buttons at the top to go to the previous or next page. Use - and + to make the page smaller or bigger.
4. Optional: in REAPER, make a region with the same name as the PDF. For example, a region named "Song One" for the file "Song One.pdf". Chart Cue then opens that PDF by itself when the song plays.
5. Optional: choose an autoscroll mode at the top right, so the page moves by itself while REAPER plays.

Click a tab to open it. Click the same tab again to hide it and get more space for the music. The Settings tab has 4 sections: Autoscroll, MIDI, Display and Project. Click a section name to open or close it. Only one section is open at a time. The first section of the Library, Regions and Cues tabs can also be closed with the arrow before its name.]==],
    more = [==[
- You can dock the Chart Cue window like any other REAPER window. Chart Cue remembers where it was.
- The first time a PDF opens, Chart Cue prepares the pages in the background ("Loading PDF" and "Preparing page"). After that, the PDF opens at once.
- The status bar at the bottom shows the scroll position, the current region and the autoscroll mode. Its second line shows the most important message, for example an error or a hint. When there is no message, it shows the page ("Page 2 / 5") and, in the Cue list and Markers modes, the next page turn ("Next: page 3 at 17.1.00"). Without a PDF, it shows the keyboard shortcuts.
- Most settings have a round "?" icon. Move the mouse over it for a short explanation.]==] },

  { title = "Library: your PDFs", text = [==[
The Library is the list of PDFs in this project.

- "Add PDF..." adds one file. "Add PDFs from folder..." adds all PDFs in a folder.
- When "Copy into project" is on, Chart Cue copies each PDF into a folder named "PDFs" next to your project file. Your original file is not changed. The project then also works on another computer.
- Click a PDF in the list to show it. "Show in Explorer" opens its folder. The red X takes it off the list (it asks first); the file itself is not deleted.
- The blue row is the PDF that is on the screen now.
- A red name means that the file cannot be found. Click "Relocate..." and pick the file again.
- Use the search box and the sort menu above the list to find a PDF quickly.]==],
    more = [==[
- "Include subfolders" makes "Add PDFs from folder..." also look in all folders inside the chosen folder.
- Copies run in the background, so REAPER and playback do not stop. The status bar shows how many are left.
- If a file with the same name is already in the PDFs folder: an identical file is used as it is. A different file opens a question: Yes = replace it, No = keep the existing copy, Cancel = skip this PDF.
- "Copy all PDFs into the project" copies the PDFs that are still outside the project folder. Use it one time for older projects.
- In a project that is not saved yet, there is no project folder. Chart Cue then uses the original files. Save the project and use "Copy all PDFs into the project".
- PDFs inside the project folder are stored with a short path (for example PDFs/Song One.pdf). If you move the whole project folder, Chart Cue still finds them.
- After "Relocate...", Chart Cue also looks in the same folder for the other missing PDFs, by file name.
- The page count shows after a PDF was opened one time.
- Turn off "Copy into project" to use the original files directly (link mode). The project is then not portable.]==] },

  { title = "Regions: one PDF per song", text = [==[
If your project contains several songs, each song can have its own PDF. Mark each song with a REAPER region.

- If the region has the same name as a PDF, Chart Cue connects them by itself. Capital letters, ".pdf", hyphens and underscores do not matter.
- You can also choose the PDF for a region in the menu on the right of the region.
- The symbol shows the state: green filled circle = has a PDF, yellow ring = needs a PDF, grey dash = ignored.
- The blue row is the region where the play cursor is now.
- Click a region row to move the edit cursor to the start of that region.
- When the play cursor enters a region without a PDF, the page area shows buttons: add a PDF, choose a PDF from the list, or ignore the region.
- "Keep last page" (Regions tab, on by default): when a song has no PDF, during playback the last page stays on screen with a yellow note at the top. The buttons show when playback stops.
- "Switch PDF at regions" turns this whole function on or off.]==],
    more = [==[
- Matching example: region "Song One" matches "song one.pdf", "Song_One.pdf" and "song-one.PDF".
- If several PDFs match the same region, the dot is yellow and the menu shows "(several PDFs match)". Choose the correct one.
- The menu choices: "(auto-match by name)" uses the name rule, "(ignore this region)" shows no PDF there, or a PDF name assigns that PDF.
- Above the list: a search field (region name) and the "Show" menu: all, needs PDF, assigned, ignored.
- While REAPER is stopped, Chart Cue uses the edit cursor instead of the play cursor.
- If regions overlap, the region that starts last is used.
- Regions and markers are read again automatically after each change in the project. "Rescan project" does it by hand.]==] },

  { title = "Autoscroll: the page moves by itself", text = [==[
Autoscroll moves the page while REAPER plays. Choose the mode at the top right, or in Settings > Autoscroll. Each project saves its own mode.

- Off: the page moves only when you scroll it.
- Markers: you put markers in your REAPER project that tell Chart Cue what to show.
- Cue list: the same as markers, but Chart Cue keeps the list itself. No markers are added to your project. Use this if another program (for example a setlist program) must not see extra markers.

Marker names for the "Markers" mode:
- PDFPAGE 2 means: from here, show page 2.
- PDFSCROLL 50 means: here, show the middle of the page. 0 is the top, 100 is the bottom. Between two PDFSCROLL markers, the page moves smoothly.

How to make a cue list (Cues tab):
1. Choose "Cue list" as the autoscroll mode, or click "Use Cue list mode" in the Cues tab.
2. Play the song.
3. At each page turn, click "Add page turn" or press the C key. Chart Cue chooses the next page by itself.
4. Where the page must move down, scroll it by hand and click "Add scroll point" or press the S key.
5. To change a cue, type a new position, page or scroll value in the list. To delete it, click the red X at the end of its row. A red border means the value is not accepted: move the mouse over it to see why, then correct it or press Esc.

If you scroll by hand during playback, autoscroll waits a moment and then continues.]==],
    more = [==[
- Example for a 2-page song: PDFPAGE 1 at the start, PDFSCROLL 0 at bar 1, PDFSCROLL 100 at bar 16, PDFPAGE 2 at bar 17, PDFSCROLL 0 at bar 17, PDFSCROLL 100 at bar 32.
- Marker names are not case-sensitive ("pdfpage 2" works). Markers with a wrong number are ignored and listed as a warning.
- A PDFPAGE marker always starts the page at the top. If a PDFSCROLL marker is at exactly the same time, the PDFSCROLL marker wins.
- "Turn pages" (Settings > Autoscroll): "One beat early" shows the next page one beat before its PDFPAGE marker or page-turn cue, so you can read ahead. It is saved in the project.
- The smooth movement never continues past a PDFPAGE marker.
- With regions, the markers inside a region control the PDF of that region. They work from the region start to the region end.
- Manual scrolling (wheel, drag, MIDI) pauses autoscroll for 1.5 seconds.
- Cue list: each song (region) has its own cues, counted from the region start. If you move a region, its cues move with it. Without regions, the cues count from the project start ("whole project").
- Cue list: "Count time in" is chosen per project. Beats: a cue stays on its bar and beat when the tempo changes. Seconds: a cue stays at the same time. Switching keeps every cue at its current place.
- Cue list: a cue has a page, a scroll position, or both. Between two scroll points the page moves smoothly. A new cue at the same place replaces the old one.
- "Add page turn" uses the page after the cue before it (the first page turn gives page 2), at the top of the page. If you add a page turn between existing cues, the following page numbers go up by one.
- "Add scroll point" uses the page of the cue before it and the current scroll position.
- A page number higher than the last page of the song's PDF is not accepted.
- "(current song)" in the Song menu is the song at the play cursor during playback, or at the edit cursor when REAPER is stopped.
- "(all songs)" in the Song menu shows the cues of every song, with the song name above each list. "Remove all cues..." asks before it deletes.
- "(whole project, no region)" is only for projects without regions. Its times count from the project start.
- "Copy markers into cues" copies the PDF markers (PDFPAGE / PDFSCROLL) of the song into its cue list. The markers stay.
- "Remove PDF markers..." then removes them (for this song, for all songs, or in Settings > Autoscroll > Marker settings for the whole project). Only PDF markers are removed; regions and other markers are not changed. It is one undo step, so Edit > Undo (Ctrl+Z) brings them back.
- The cue list is saved in the project, like the library. Save the project after changes.]==] },

  { title = "MIDI controller", text = [==[
You can scroll the page with a knob, fader or endless encoder on a MIDI controller. This is optional.

1. Open Settings > MIDI.
2. Tick "Read MIDI directly".
3. Set "MIDI mode" and the CC number that your knob sends.

- Absolute: the knob position is the page position. Use this for normal knobs and faders.
- Relative: turning moves the page up or down. Use this for endless encoders. If the page moves the wrong way or jumps, try another "Relative encoding", or tick "Invert direction".
- Turn pages with MIDI: two buttons on your controller can go to the next and previous page.
- Add cues with MIDI: one button adds a page turn, another one adds a scroll point (Cues tab).
- These two options show only when "Read MIDI directly" is on. The tab shows only the rows of the chosen MIDI mode.]==],
    more = [==[
- Another way: bind the Chart Cue action to a knob in REAPER's Action List (Add shortcut, then move the knob). When REAPER asks about the running script, choose "New instance" and "Remember my answer". The new instance only sends the value to the open Chart Cue.
- With an Action List binding, do NOT tick "Read MIDI directly".
- "Sensitivity" sets how far the page moves for each step of a relative encoder.
- "Show MIDI debug" (Troubleshooting, at the end of Settings > MIDI) shows the last CC number and value that Chart Cue received. Use it to find the CC number of your knob.
- Page turning works with direct MIDI input. A value of 64 or more counts as a button press.]==] },

  { title = "Display and view", text = [==[
- PDF engine: "Windows (built in)" needs no extra software. "Poppler" is an optional alternative.
- Page sharpness (DPI): a higher number gives sharper pages, but the first preparation takes longer. "Page quality" tells you if the page looks sharp.
- Hide controls when playing: while REAPER plays, only a small toolbar is shown, so the music gets more space. If there is an error, one red line is shown.
- Page brightness (View): lower than 100% makes the white paper darker for dark stages. 100% = not dimmed.
- Page-turn flash (View): a short blue frame when the page turns during playback.
- Comfortable layout (Layout): more empty space between rows and sections; buttons, fields and tabs keep their size.
- Page cache (Troubleshooting): Chart Cue keeps the pages on your disk, so PDFs open fast. Its size is shown next to "Clear...", which clears it at any time. It is filled again when needed.]==],
    more = [==[
- "Match DPI to current view" sets the DPI that fits your current zoom.
- Chart Cue prepares all pages of a PDF in the background. The pages near the current page come first.
- Very large pages are limited to 4096 pixels. Then the DPI cannot go higher for that PDF.
- The Windows engine uses Windows PowerShell in the background. The first time a PDF opens, this takes about 1 second.
- Poppler: choose "Poppler (pdftoppm.exe)" as the engine, then select pdftoppm.exe. pdfinfo.exe must be in the same folder.
- Each engine and each DPI has its own cache folder.
- "Write diagnostic log" (Troubleshooting) writes technical events to the REAPER console. Use it only to report a problem.
- "Reset all settings..." (Troubleshooting) sets the settings of this computer back to the defaults. Your projects are not changed.
- "Reset window layout" (Layout) moves the window back to its default size and place.]==] },

  { title = "Project: saving, opening, closing", text = [==[
Chart Cue saves the library and the region choices inside your REAPER project. They move with the project when you copy it or use "Save as". Save the project after changes, as with any other change.

The round "?" next to a heading tells you where its settings are saved: in this project, or on this computer (the same for all your projects). A dim "This project" or "This computer" next to a setting marks the few settings that are saved in a different place than the rest of their section.

- "Open automatically": Chart Cue opens by itself when you open a project that uses it. Restart REAPER one time after you turn this on.
- "Close with project": Chart Cue closes together with its project.]==],
    more = [==[
- Saved in the project (.rpp): the library, region choices, ignored regions, "Switch PDF at regions", the autoscroll mode and the PDF on screen.
- Saved for your computer (Scripts\Chart Cue\settings.ini): the PDF engine, DPI, window and dock place, MIDI settings and the default autoscroll mode (used by projects that have no mode yet).
- Automatic open adds 3 marked lines at the end of REAPER's Scripts\__startup.lua. A backup is saved first (__startup.lua.chartcue-backup). Turning the option off removes only these 3 lines.
- Chart Cue closes when you close the project tab, or when File > Close project, New project or Open project replaces the project in the same tab. Switching tabs and "Save as" keep it open.
- Older versions could also open Chart Cue with an SWS project startup action. If a project still has one, click "Remove the SWS startup action..." and save the project, or Chart Cue can start twice.]==] },

  { title = "Keyboard and mouse", text = [==[
- Left arrow or Page Up: previous page
- Right arrow or Page Down: next page
- Home: go to the top of the page
- F: performance mode (only the page is shown). F or Esc goes back.
- L: lock (during playback the page ignores the mouse and the keys; MIDI and autoscroll still work). The lock button is in the toolbar.
- R: record cues on / off (Cue list mode only; the red dot button in the toolbar does the same). REC shows on the page while it is on.
- C: add a page turn at the play cursor (only while Record cues is on)
- S: add a scroll point at the play cursor (only while Record cues is on)
- Ctrl and +: zoom in. Ctrl and -: zoom out. Ctrl and 0: fit the page width.
- Mouse wheel: scroll the page. Ctrl and mouse wheel: zoom.
- Drag the page with the mouse to move it.
- Drag the bar on the right of the page to scroll.
- Drag the thin line under the settings panel to change its height.

The keys work when the Chart Cue window is active. Click on it first.]==],
    more = [==[
- The fit menu at the top has: Fit width, Fit height, Fit page and 100% (the real size of the page). Each PDF remembers its own fit and zoom (saved in the project).
- Click "Page 3 / 12" in the toolbar to type a page number, then press Enter.
- In performance mode, move the mouse to the top-right corner of the page for an exit button.
- A horizontal mouse wheel or tilt wheel moves the page left and right when it is wider than the window.
- There is no key to close Chart Cue, so it cannot close by mistake during a performance. Use the X of the window, run the Chart Cue action again, or close the project.]==] },

  { title = "Problems and solutions", text = [==[
- "No PDF open": open a PDF in the Library tab.
- "Loading PDF" or "Preparing page" stays for a long time: wait a moment. Large PDFs need more time the first time. If nothing changes, click "Retry rendering" in the status bar.
- A PDF name is red: the file was moved or renamed. Click "Relocate..." in the Library tab.
- The page looks blurry: click "Match DPI to current view" in Settings > Display and view > Page quality (or "Change" to type a higher DPI).
- The wrong PDF opens for a song: check the menu of that region in the Regions tab.
- Chart Cue opens twice, or REAPER asks about a running script: use only one way to open Chart Cue automatically (Settings > Project).
- Nothing helps: change the PDF engine in Settings > Display and view and try again.]==],
    more = [==[
- Password-protected PDFs cannot be shown. Save a copy without a password.
- "Marker warning" in the status bar: a PDFPAGE or PDFSCROLL marker has a wrong number. The message shows its name and time.
- "Marker autoscroll is on but no PDFSCROLL or PDFPAGE markers were found": add markers, or choose another autoscroll mode.
- PDFs on network drives or in online-only cloud folders can be slow or not found. Copy them into the project (Library tab).
- To report a problem: turn on "Write diagnostic log" (Settings > Display and view > Troubleshooting), repeat the problem, and copy the text from the REAPER console.]==] },
}

HELP_TOPICS[#HELP_TOPICS + 1] = { title = "Remove Chart Cue", guide_only = true, text = [==[
To remove Chart Cue completely from this computer:

1. Settings > Project: turn off "Open automatically". This removes the 3 Chart Cue lines from __startup.lua.
2. If you used SWS startup actions: in each of those projects, click "Remove the SWS startup action..." and save the project.
3. Close Chart Cue. In REAPER's Action List, find "Script: Chart Cue.lua", right-click it and choose "Remove".
4. Delete the folder Scripts\Chart Cue in the REAPER resource folder (Options > Show REAPER resource path). It contains the settings, the page cache, the guide and the helper scripts.
5. Delete the file Chart Cue.lua.]==],
  more = [==[
- Your projects are not damaged. They only contain a small Chart Cue data section, which REAPER ignores without Chart Cue.
- The PDFs folders next to your projects contain your own copies of the PDFs. Keep them or delete them, as you like.
- If Chart Cue changed __startup.lua, a backup of the earlier version is in Scripts\__startup.lua.chartcue-backup.]==] }


local function html_esc(t)
  return (t:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

-- Converts the help text format (paragraphs, "- " bullets, "1. " steps) to HTML.
local function help_to_html(text)
  local out, list = {}, nil
  local function close_list() if list then out[#out + 1] = "</" .. list .. ">"; list = nil end end
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    local bullet = line:match("^%- (.*)$")
    local step = line:match("^%d+%. (.*)$")
    if bullet or step then
      local want = bullet and "ul" or "ol"
      if list ~= want then close_list(); out[#out + 1] = "<" .. want .. ">"; list = want end
      out[#out + 1] = "<li>" .. html_esc(bullet or step) .. "</li>"
    elseif line:match("^%s*$") then
      close_list()
    else
      close_list(); out[#out + 1] = "<p>" .. html_esc(line) .. "</p>"
    end
  end
  close_list()
  return table.concat(out, "\n")
end

function UI.write_guide()
  local h = {}
  h[#h + 1] = [==[<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>Chart Cue Guide</title>
<style>
:root { --bg:#ffffff; --fg:#1d1f24; --muted:#5b6170; --accent:#3b82f6; --card:#f4f6fa; --line:#dfe3ea; }
@media (prefers-color-scheme: dark) { :root { --bg:#16181d; --fg:#e6e8ee; --muted:#9aa1b0; --card:#1f2128; --line:#2f333d; } }
body { background:var(--bg); color:var(--fg); font:16px/1.6 "Segoe UI", system-ui, sans-serif; margin:0; }
main { max-width:820px; margin:0 auto; padding:32px 20px 64px; }
h1 { font-size:30px; margin:0 0 4px; } .sub { color:var(--muted); margin:0 0 28px; }
nav { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:14px 20px; margin-bottom:32px; }
nav ol { margin:6px 0 0; padding-left:22px; } nav a { color:var(--accent); text-decoration:none; }
section { border-top:2px solid var(--accent); padding-top:8px; margin-top:36px; }
h2 { font-size:22px; margin:6px 0 12px; } h3 { font-size:16px; color:var(--muted); margin:22px 0 6px; text-transform:uppercase; letter-spacing:.04em; }
.more { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:4px 18px 8px; }
li { margin:4px 0; } a.top { font-size:13px; color:var(--muted); }
@media print { nav, a.top { display:none; } section { break-inside:avoid-page; } }
</style></head><body><main>
<h1>Chart Cue Guide</h1><p class="sub">PDF charts and sheet music inside REAPER &middot; Version VERSION_HERE</p>
<nav><strong>Contents</strong><ol>]==]
  for i, t in ipairs(HELP_TOPICS) do
    h[#h + 1] = string.format('<li><a href="#t%d">%s</a></li>', i, html_esc(t.title))
  end
  h[1] = h[1]:gsub("VERSION_HERE", CFG.VERSION)
  h[#h + 1] = "</ol></nav>"
  for i, t in ipairs(HELP_TOPICS) do
    h[#h + 1] = string.format('<section id="t%d"><h2>%d. %s</h2>', i, i, html_esc(t.title))
    h[#h + 1] = help_to_html(t.text)
    if t.more then
      h[#h + 1] = '<h3>More details</h3><div class="more">' .. help_to_html(t.more) .. "</div>"
    end
    h[#h + 1] = '<p><a class="top" href="#">Back to top</a></p></section>'
  end
  h[#h + 1] = string.format('<p class="sub" style="margin-top:40px">Chart Cue %s &middot; %s &middot; MIT License</p>',
    html_esc(CFG.VERSION), html_esc(CFG.AUTHOR))
  h[#h + 1] = "</main></body></html>"
  Util.ensure_dir(CFG.BASE_DIR)
  local f = io.open(CFG.GUIDE_FILE, "wb")
  if not f then return false end
  f:write(table.concat(h, "\n")); f:close()
  return true
end

function UI.open_guide()
  if UI.write_guide() then
    r.ExecProcess('cmd.exe /C start "" "' .. CFG.GUIDE_FILE .. '"', CFG.EXEC_NOWAIT)
  else
    Msg.notify("Cannot write the guide to " .. CFG.GUIDE_FILE, true, "help")
  end
end

-- Help panel (opened with the "?" button at the end of the tab strip)
function UI.draw_help_tab(ctx)
  UI.heading(ctx, "Help")
  if UI.full_button(ctx, "Open the full guide in your browser") then UI.open_guide() end
  UI.tip(ctx, "Opens a longer guide with more details, a table of contents and a print option.")
  UI.section_msg(ctx, "help")
  UI.vgap(ctx, UI.sp("LIST"))
  UI.list_header(ctx, { { "Topics - click a topic to open or close it", 0 } })
  for i, t in ipairs(HELP_TOPICS) do
    if t.guide_only then goto continue end
    if R.help_open == i then ImGui.SetNextItemOpen(ctx, true); R.help_open = nil end
    if ImGui.CollapsingHeader(ctx, t.title .. "##help" .. i) then
      ImGui.Indent(ctx, 8)
      UI.wrapped(ctx, t.text)
      ImGui.Unindent(ctx, 8)
      UI.vgap(ctx, UI.sp("LIST"))
    end
    ::continue::
  end

  UI.group_sep(ctx)
  UI.heading(ctx, "About")
  UI.value(ctx, "Version", CFG.VERSION)
  UI.value(ctx, "Author", CFG.AUTHOR)
  UI.value(ctx, "License", "MIT")
  UI.value(ctx, "Report a problem", "Turn on 'Write diagnostic log' (Settings > Display and view > Troubleshooting), repeat the problem, "
    .. "and copy the text from the REAPER console.")
end

-- Cues tab: the cue list; a note and a mode button when the mode is not Cue list.
function UI.draw_cues_tab(ctx)
  UI.draw_cue_list(ctx) -- the "Use Cue list mode" note is the first row of its "Cue settings" section
end

-- Settings tab: one collapsible section per area. The open section is saved (S.settings_open).
local SETTINGS_SECTIONS = {
  { "Autoscroll", UI.draw_autoscroll_tab },
  { "MIDI", UI.draw_midi_tab },
  { "Display and view", UI.draw_display_tab },
  { "Project", UI.draw_project_tab },
}
-- One section open at a time (or none): a click on a section closes the open one.
-- The headers use the larger bold font, so they stand one level above the headings inside them.
function UI.draw_settings_tab(ctx)
  local cur = S.settings_open:find("1", 1, true) or 0 -- the open section (older settings may list several: the first wins)
  for i, sec in ipairs(SETTINGS_SECTIONS) do
    local open, clicked = UI.heading(ctx, sec[1], nil, nil, cur == i, true)
    if clicked then
      cur = open and i or 0
      local t = {}
      for j = 1, #SETTINGS_SECTIONS do t[j] = (j == cur) and "1" or "0" end
      S.settings_open = table.concat(t)
      Util.mark_dirty()
    end
    if open and cur == i then
      ImGui.Indent(ctx, 8)
      ImGui.PushID(ctx, sec[1]) -- the sections share one panel: keep their widget IDs apart
      sec[2](ctx)
      ImGui.PopID(ctx)          -- always paired with PushID above
      ImGui.Unindent(ctx, 8)
      UI.group_sep(ctx)
    end
  end
end

local TAB_DRAW = { UI.draw_library_tab, UI.draw_regions_tab, UI.draw_cues_tab, UI.draw_settings_tab, UI.draw_help_tab }

---------------------------------------------------------------------------
-- UI: TOOLBAR, TAB STRIP, PANEL, STATUS, VIEW
---------------------------------------------------------------------------
-- Tab strip: the selected tab is taller, in the panel colour, with an accent bar on top, and it
-- merges into the panel below it. Other tabs are text only, with a soft hover fade.
function UI.draw_tab_strip(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  local n = #TAB_NAMES
  local gap, h = CFG.TAB_GAP, CFG.TAB_H
  local lift = 6                         -- the selected tab is this much taller
  local help_w = h
  local tab_w = math.floor((aw - help_w - gap * n - CFG.TAB_GROUP_GAP - 8) / n)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local strip_b = y0 + h + lift          -- bottom of the strip = top of the panel
  local open = S.panel_open
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x0 + aw, strip_b, COL.TAB_BG, 8,
    open and ImGui.DrawFlags_RoundCornersTop() or ImGui.DrawFlags_RoundCornersAll())

  local attn = UI.attention_count()
  local clicked
  local function tab(i, label, w, x)
    local active = (S.tab == i)
    local merged = active and open
    -- the selected tab starts at the top of the strip, so the gap below the toolbar (UI.sp "EDGE")
    -- is the same as the gap above it; other tabs are lower by `lift`
    local top = merged and y0 or (y0 + lift)
    local bottom = merged and (strip_b + 1) or (strip_b - 4)
    ImGui.SetCursorScreenPos(ctx, x, top)
    ImGui.InvisibleButton(ctx, "##tab" .. i, w, bottom - top)
    local hov = ImGui.IsItemHovered(ctx)
    if ImGui.IsItemClicked(ctx) then clicked = i end
    if hov then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
    local hv = UI.anim("tab" .. i, hov and 1 or 0)
    if merged then
      ImGui.DrawList_AddRectFilled(dl, x, top, x + w, bottom, COL.PANEL_BG, 8, ImGui.DrawFlags_RoundCornersTop())
      ImGui.DrawList_AddRectFilled(dl, x + 8, top, x + w - 8, top + 3, COL.ACCENT, 2)
    else
      if hv > 0 then
        ImGui.DrawList_AddRectFilled(dl, x, top, x + w, bottom, Util.lerp_col(COL.TAB_BG, COL.TAB_HOVER, hv), 7)
      end
      if active then ImGui.DrawList_AddRect(dl, x, top, x + w, bottom, COL.ACCENT, 7, 0, 1.5) end
    end
    UI.push_bold_font(ctx, merged)
    local tw, th = ImGui.CalcTextSize(ctx, label)
    local dim = (i >= TAB_FIRST_SETTING and i ~= TAB_HELP) and Util.lerp_col(COL.TEXT_DIM, COL.TAB_BG, 0.35) or COL.TEXT_DIM
    local col = merged and COL.TEXT_MAIN or Util.lerp_col(dim, COL.TEXT_MAIN, hv)
    if i == TAB_REGIONS and attn > 0 and not merged then col = COL.YELLOW end
    ImGui.DrawList_AddText(dl, x + math.floor((w - tw) / 2), UI.text_y(ctx, top, bottom - top), col, label)
    UI.pop_font(ctx)
  end

  local x = x0 + 4
  for i, name in ipairs(TAB_NAMES) do
    if i == TAB_FIRST_SETTING then x = x + CFG.TAB_GROUP_GAP end
    local label = name
    if i == TAB_REGIONS and attn > 0 then
      -- use the longest badge variant that fits the tab width
      UI.push_bold_font(ctx)
      local variants = { string.format("%s (%d need a PDF)", name, attn), string.format("%s (%d)", name, attn), name .. "!" }
      label = variants[#variants]
      for _, v in ipairs(variants) do
        if (ImGui.CalcTextSize(ctx, v)) <= tab_w - 16 then label = v; break end
      end
      UI.pop_font(ctx)
    end
    tab(i, label, tab_w, x)
    x = x + tab_w + gap
  end
  tab(TAB_HELP, "?", help_w, x)
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Help: how Chart Cue works") end

  local below = open and 0 or UI.sp("CLOSED_TABS")
  ImGui.SetCursorScreenPos(ctx, x0, strip_b + below)
  ImGui.Dummy(ctx, 0, 0)
  ImGui.SetCursorScreenPos(ctx, x0, strip_b + below)

  if clicked then
    R.ask = nil -- an open question belongs to the tab it was asked in
    if S.tab == clicked then S.panel_open = not S.panel_open -- active tab again: collapse / expand
    else S.tab = clicked; S.panel_open = true end
    Util.mark_dirty()
  end
end

-- The open tab's panel: a child window whose bottom edge can be dragged to resize.
-- The child scrolls vertically when its content is taller than the panel.
function UI.draw_panel(ctx, status_h)
  local _, free_h = ImGui.GetContentRegionAvail(ctx)
  local max_h = math.max(CFG.PANEL_MIN_H, free_h - status_h - CFG.MIN_VIEW_H - CFG.SPLIT_H - 6)
  local want = (S.panel_h > 0) and S.panel_h or math.floor((free_h - status_h) * CFG.PANEL_DEFAULT_FRAC)
  local ph = Util.clamp(want, CFG.PANEL_MIN_H, max_h)

  -- panel background drawn here: square top (joins the selected tab), rounded bottom
  do
    local px, py = ImGui.GetCursorScreenPos(ctx)
    local pw = ImGui.GetContentRegionAvail(ctx)
    ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx), px, py, px + pw, py + ph, COL.PANEL_BG, 8,
      ImGui.DrawFlags_RoundCornersBottom())
  end
  local vis = ImGui.BeginChild(ctx, "##panel" .. S.tab, 0, ph)
  if vis then
    ImGui.SetCursorPosY(ctx, UI.sp("PANEL")) -- exact top gap (no row spacing above the first item)
    ImGui.Indent(ctx, 10)
    TAB_DRAW[S.tab](ctx)
    ImGui.Unindent(ctx, 10)
    ImGui.Dummy(ctx, 0, UI.sp("PANEL")) -- same gap at the bottom
    ImGui.EndChild(ctx)
  end

  -- resize grip under the panel
  local gx, gy = ImGui.GetCursorScreenPos(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  aw = math.max(1, aw)
  ImGui.InvisibleButton(ctx, "##panelgrip", aw, CFG.SPLIT_H)
  local hov, act = ImGui.IsItemHovered(ctx), ImGui.IsItemActive(ctx)
  if hov or act then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeNS()) end
  if act then
    local _, dy = ImGui.GetMouseDelta(ctx)
    if dy ~= 0 then S.panel_h = Util.clamp(ph + dy, CFG.PANEL_MIN_H, max_h); Util.mark_dirty() end
  end
  local dl = ImGui.GetWindowDrawList(ctx)
  local cx = gx + aw / 2
  local col = (hov or act) and COL.ACCENT or COL.GRIP
  ImGui.DrawList_AddRectFilled(dl, cx - 24, gy + CFG.SPLIT_H / 2 - 1.5, cx + 24, gy + CFG.SPLIT_H / 2 + 1.5, col, 2)
end

-- The project has cues or PDF markers that the current mode does not use:
-- returns message, mode to switch to, button label (or nil).
-- Status line 2 with a PDF open: "Page 2 / 5", plus "Next: page 3 at <time>" in the Cue list
-- (time in the project's cue unit) and Markers modes. Rebuilt at most every 0.1 s.
function UI.page_status_text()
  local now = Util.now()
  if R.page_status and now - R.page_status_t < 0.1 then return R.page_status end
  local txt = string.format("Page %d / %d", S.page, R.total)
  local mode, t = Nav.scroll_mode(), Project.time_pos()
  if mode == "cues" then
    local reg = Cues.playing_region()
    local p = Cues.from_time(reg, t)
    for _, c in ipairs(Cues.list(reg)) do
      if c.page and c.pos > p + 1e-6 then
        txt = txt .. string.format("  |  Next: page %d at %s", c.page, Cues.label(reg, c.pos)); break
      end
    end
  elseif mode == "marker" then
    for _, m in ipairs(R.page_pts) do
      if m.t > t + 1e-6 then
        txt = txt .. string.format("  |  Next: page %d at %s", m.page, r.format_timestr_pos(m.t, "", 2)); break
      end
    end
  end
  R.page_status, R.page_status_t = txt, now
  return txt
end

function UI.mode_hint()
  if P.hint_off then return nil end -- "Not now" for this project
  local mode = Nav.scroll_mode()
  local ncues = 0
  for _, list in pairs(P.cues) do ncues = ncues + #list end
  local nmark = #R.page_pts + #R.scroll_pts
  if ncues > 0 and mode ~= "cues" and not (mode == "marker" and nmark > 0) then
    return string.format("This project has %d cue(s).", ncues), "cues", "Switch to Cue list"
  end
  if nmark > 0 and ncues == 0 and mode ~= "marker" then
    return string.format("This project has %d PDF marker(s).", nmark), "marker", "Switch to Markers"
  end
  return nil
end

function UI.draw_status(ctx)
  local pct = (R.max_y > 0) and (S.scroll_y / R.max_y * 100) or 0
  local reg = R.cur_region_key and Project.region_by_key(R.cur_region_key)
  local parts = {}
  parts[#parts + 1] = string.format("Scroll %.0f%%", pct)
  if reg then parts[#parts + 1] = "Region: " .. reg.name end
  parts[#parts + 1] = "Autoscroll: " .. UI.autoscroll_state_text()
  if Nav.scroll_mode() == "marker" and R.marker_pct and R.autoscroll_active then
    parts[#parts + 1] = string.format("marker %.0f%%", R.marker_pct)
  end
  if UI.midi_in_use() then
    parts[#parts + 1] = string.format("MIDI %s%s", S.mode, R.last_cc and (" CC=" .. R.last_cc) or "")
  end
  local aw = ImGui.GetContentRegionAvail(ctx)
  ImGui.Text(ctx, UI.trunc_text(ctx, table.concat(parts, "  |  "), aw - 6))

  -- line 2, by priority: errors > import progress > region has no PDF > warnings > normal
  local needs = R.empty_region
  local recent = Msg.recent(nil, true)
  if R.error then
    UI.row_text(ctx, UI.trunc_text(ctx, R.error, aw - 140), COL.RED)
    ImGui.SameLine(ctx)
    if UI.button(ctx, "Retry rendering") then PDF.retry_failed() end
  elseif PDF.engine() == "poppler" and R.exe == nil then
    ImGui.TextColored(ctx, COL.RED, UI.trunc_text(ctx, PDF.poppler_help(), aw - 6))
  elseif R.picker then
    ImGui.TextColored(ctx, COL.YELLOW, "Waiting for the folder dialog...")
  elseif R.import then
    ImGui.TextColored(ctx, COL.YELLOW, string.format("Importing folder... %d PDF(s) added so far", R.import.added))
  elseif R.copy or #R.copyq > 0 then
    ImGui.TextColored(ctx, COL.YELLOW, string.format("Copying PDFs into the project... %d left", Project.copy_pending()))
  elseif needs then
    ImGui.TextColored(ctx, COL.YELLOW, UI.trunc_text(ctx, string.format(
      needs.status == "ignored" and 'Region "%s" is ignored (no PDF).' or 'No PDF assigned to region "%s".', needs.name), aw - 6))
  elseif recent then
    ImGui.TextColored(ctx, recent.err and COL.RED or COL.GREEN, UI.trunc_text(ctx, recent.text, aw - 6))
  elseif PDF.engine() == "poppler" and not R.pdfinfo_ok then
    ImGui.TextColored(ctx, COL.YELLOW, "pdfinfo.exe missing next to pdftoppm.exe - see Settings > Display and view.")
  elseif R.warn then
    ImGui.TextColored(ctx, COL.YELLOW, UI.trunc_text(ctx, R.warn, aw - 6))
  elseif #R.marker_warns > 0 then
    ImGui.TextColored(ctx, COL.YELLOW, UI.trunc_text(ctx, string.format("Marker warning: %s%s", R.marker_warns[1],
      #R.marker_warns > 1 and string.format(" (+%d more)", #R.marker_warns - 1) or ""), aw - 6))
  elseif UI.mode_hint() then
    local txt, mode, lbl = UI.mode_hint()
    UI.row_text(ctx, UI.trunc_text(ctx, txt, aw - 230), COL.YELLOW)
    ImGui.SameLine(ctx)
    if UI.button(ctx, lbl .. "##modehint") then Nav.set_scroll_mode(mode) end
    ImGui.SameLine(ctx)
    if UI.button(ctx, "Not now##modehint") then P.hint_off = true; Util.mark_pdirty() end
    UI.tip(ctx, "Hides this hint for this project. It is saved with the project.")
  elseif Nav.scroll_mode() == "cues" and R.total > 0 and #Cues.list(Cues.playing_region()) == 0 then
    ImGui.TextColored(ctx, COL.YELLOW, "Cue list is on, but this song has no cues yet (Cues tab).")
  elseif Nav.scroll_mode() == "marker" and #R.scroll_pts == 0 and #R.page_pts == 0 then
    ImGui.TextColored(ctx, COL.YELLOW, "Marker autoscroll is on but no PDFSCROLL or PDFPAGE markers were found.")
  elseif R.total > 0 then
    ImGui.Text(ctx, UI.trunc_text(ctx, UI.page_status_text(), aw - 6))
  else
    ImGui.TextDisabled(ctx, UI.trunc_text(ctx, "Arrows/PgUp/PgDn page | Home top | Ctrl +/-/0 zoom | F performance | L lock | R record cues | C page turn | S scroll point", aw - 6))
  end
end

-- Only the error line of the status bar (used while controls are hidden during playback).
function UI.draw_error_line(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  UI.row_text(ctx, UI.trunc_text(ctx, R.error, aw - 140), COL.RED)
  ImGui.SameLine(ctx)
  if UI.button(ctx, "Retry rendering") then PDF.retry_failed() end
end

-- Lock icon (drawn, no icon font): body + shackle; the shackle is lifted and open when unlocked.
function UI.draw_lock_icon(dl, cx, cy, closed, col)
  local bw, bh = 12, 9                 -- body
  local bx0, by0 = cx - bw / 2, cy - 1
  ImGui.DrawList_AddRectFilled(dl, bx0, by0, bx0 + bw, by0 + bh, col, 2)
  local rr = 3.5                       -- shackle radius
  local sx = closed and cx or (cx + 3) -- open: moved right
  local sy = closed and (by0 - 1) or (by0 - 3)
  ImGui.DrawList_PathArcTo(dl, sx, sy - 2, rr, math.pi, 2 * math.pi)
  ImGui.DrawList_PathLineTo(dl, sx + rr, sy + (closed and 1 or 0))
  ImGui.DrawList_PathStroke(dl, col, 0, 2)
  ImGui.DrawList_AddLine(dl, sx - rr, sy - 2, sx - rr, closed and (sy + 1) or (sy - 0.5), col, 2)
end

function UI.toggle_lock()
  R.lock = not R.lock
  Msg.notify(R.lock and "Locked: the page ignores the mouse and the keys during playback (L to unlock)."
    or "Unlocked.", false)
end

function UI.locked() return R.lock and Util.playing() end

-- Record cues (R): only in the Cue list mode, never while locked.
function UI.toggle_rec()
  if not R.rec and Nav.scroll_mode() ~= "cues" then
    -- R key in another mode: a hint, not an error (the Record button is hidden in that mode)
    Msg.notify("Record cues works only in the Cue list autoscroll mode.", false); return
  end
  R.rec = not R.rec
  Msg.notify(R.rec and "Record cues on: C, S and the MIDI cue buttons add cues (R to stop)."
    or "Record cues off.", false)
end

-- C / S keys and the MIDI cue CCs add cues only when this is true.
function UI.can_record() return R.rec and Nav.scroll_mode() == "cues" and not UI.locked() end

-- Record icon: a filled circle; full red when armed, dim red when off.
function UI.draw_rec_icon(dl, cx, cy, armed)
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, 5.5, armed and COL.RED or ((COL.RED & 0xFFFFFF00) | 0x80))
end

function UI.toggle_perf()
  R.perf = not R.perf
  R.perf_t = Util.now()
end

function UI.handle_keys(ctx)
  if not ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_RootAndChildWindows()) or ImGui.IsAnyItemActive(ctx) then return end
  local K = function(name) return r["ImGui_Key_" .. name]() end
  local ctrl = (ImGui.GetKeyMods(ctx) & ImGui.Mod_Ctrl()) ~= 0
  -- these keys always work, also in lock mode (so you can never lock yourself out)
  if not ctrl and ImGui.IsKeyPressed(ctx, K("F"), false) then UI.toggle_perf() end
  if R.perf and ImGui.IsKeyPressed(ctx, K("Escape"), false) then UI.toggle_perf() end
  if not ctrl and ImGui.IsKeyPressed(ctx, K("L"), false) then UI.toggle_lock() end
  if UI.locked() then return end
  if ImGui.IsKeyPressed(ctx, K("LeftArrow")) or ImGui.IsKeyPressed(ctx, K("PageUp")) then Nav.go_page(S.page - 1) end
  if ImGui.IsKeyPressed(ctx, K("RightArrow")) or ImGui.IsKeyPressed(ctx, K("PageDown")) then Nav.go_page(S.page + 1) end
  if not ctrl and ImGui.IsKeyPressed(ctx, K("R"), false) then UI.toggle_rec() end
  if not ctrl and UI.can_record() then
    if ImGui.IsKeyPressed(ctx, K("C"), false) then Cues.add_page_turn() end
    if ImGui.IsKeyPressed(ctx, K("S"), false) then Cues.add_scroll_point() end
  end
  if ImGui.IsKeyPressed(ctx, K("Home"), false) then
    S.scroll_y = 0; R.abs_target = nil; Util.touch_override(); Util.mark_dirty()
  end
  if ctrl then
    if ImGui.IsKeyPressed(ctx, K("Equal")) then Nav.zoom_by(CFG.ZOOM_STEP) end
    if ImGui.IsKeyPressed(ctx, K("Minus")) then Nav.zoom_by(1 / CFG.ZOOM_STEP) end
    if ImGui.IsKeyPressed(ctx, K("0"), false) then Nav.fit_width() end
  end
end

-- Centered empty state when no PDF is loaded; its buttons are the Library tab's actions.
function UI.draw_empty_state(ctx, x0, y0, area_w, view_h, dl)
  local cx, cy = x0 + area_w / 2, y0 + view_h / 2
  UI.push_bold_font(ctx)
  local msg = "No PDF open"
  local tw = ImGui.CalcTextSize(ctx, msg)
  ImGui.DrawList_AddText(dl, cx - tw / 2, cy - 54, COL.TEXT_BRIGHT, msg)
  UI.pop_font(ctx)
  local b1, b2 = "Add PDF...", "Add PDFs from folder..."
  local bw = math.max((ImGui.CalcTextSize(ctx, b1)), (ImGui.CalcTextSize(ctx, b2))) + 40
  ImGui.SetCursorScreenPos(ctx, cx - bw / 2, cy - 20)
  local nc, nv = UI.push_kind(ctx, "primary")
  local hit1 = UI.button(ctx, b1, bw, 30)
  UI.pop_kind(ctx, nc, nv)
  if hit1 then PDF.browse_add_pdf(true) end
  ImGui.SetCursorScreenPos(ctx, cx - bw / 2, cy + 18)
  if UI.button(ctx, b2, bw, 30) then Project.start_folder_pick() end
  -- link-style button to the "Getting started" help topic
  local link = "New to Chart Cue? Read 'Getting started'"
  local lw = ImGui.CalcTextSize(ctx, link) + 16
  ImGui.SetCursorScreenPos(ctx, cx - lw / 2, cy + 58)
  ImGui.PushStyleColor(ctx, ImGui.Col_Button(), COL.TRANSPARENT)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered(), COL.ACTIVE_BG)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive(), COL.ACTIVE_BG)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.ACCENT_HOVER)
  if UI.button(ctx, link, lw, 0) then
    S.tab = TAB_HELP; S.panel_open = true; R.help_open = 1; Util.mark_dirty()
  end
  ImGui.PopStyleColor(ctx, 4)
end

-- Empty state for a region with no assigned PDF: large region name, message, one big central action
-- and smaller secondary actions. Works while playing or stopped, with controls shown or hidden.
function UI.draw_region_empty_state(ctx, x0, y0, area_w, view_h, reg)
  local cx = x0 + area_w / 2
  local inner_w = math.max(120, area_w - 40)
  local ambiguous = (reg.status == "ambiguous")

  -- keep the dropdown selection in sync with the region (ambiguous: preselect the first match)
  if R.empty_sel_key ~= reg.key then
    R.empty_sel_key = reg.key; R.empty_sel = 0; R.choose_existing = false
    if ambiguous and reg.cands[1] then
      for j, p in ipairs(P.pdfs) do if Util.same_path(p, reg.cands[1]) then R.empty_sel = j - 1 end end
    end
  end
  R.empty_sel = Util.clamp(R.empty_sel, 0, math.max(0, #P.pdfs - 1))
  local show_combo = (ambiguous or R.choose_existing)
  local lib_empty = (#P.pdfs == 0)
  local use_assign = show_combo and not lib_empty -- main button assigns the selected PDF

  -- sizes (compact when the PDF area is short so nothing spills outside the view)
  local compact = view_h < (show_combo and 215 or 185)
  local main_h, sec_h, name_h = compact and 30 or 44, compact and 24 or 26, compact and 20 or 38
  local gap = compact and 6 or 10
  local total = name_h + gap + 20 + gap + (show_combo and (26 + gap) or 0) + main_h + gap + sec_h
  local y = y0 + math.max(2, math.floor((view_h - total) / 2))

  -- region name (large)
  if not compact then UI.push_big_font(ctx) end
  local label = UI.trunc_text(ctx, reg.name ~= "" and reg.name or "(unnamed region)", inner_w)
  local nw = ImGui.CalcTextSize(ctx, label)
  ImGui.SetCursorScreenPos(ctx, cx - nw / 2, y)
  ImGui.Text(ctx, label)
  if not compact then UI.pop_font(ctx) end
  y = y + name_h + gap

  -- message
  local ignored = (reg.status == "ignored")
  local msg = ambiguous and "Several PDFs match this region's name. Choose one."
      or (ignored and "This region is ignored. No PDF is shown." or "No PDF assigned to this region.")
  local mw = ImGui.CalcTextSize(ctx, msg)
  ImGui.SetCursorScreenPos(ctx, cx - math.min(mw, inner_w) / 2, y)
  ImGui.TextColored(ctx, COL.YELLOW, UI.trunc_text(ctx, msg, inner_w))
  y = y + 20 + gap

  -- dropdown (ambiguous regions, or "Choose from library")
  local btn_w = math.min(inner_w, 360)
  if show_combo then
    ImGui.SetCursorScreenPos(ctx, cx - btn_w / 2, y)
    if lib_empty then
      ImGui.TextColored(ctx, COL.GREY, "The PDF library is empty.")
    else
      ImGui.SetNextItemWidth(ctx, btn_w)
      local ch
      ch, R.empty_sel = ImGui.Combo(ctx, "##emptypdf", R.empty_sel, UI.pdf_items_string())
    end
    y = y + 26 + gap
  end

  -- main action
  ImGui.SetCursorScreenPos(ctx, cx - btn_w / 2, y)
  if use_assign then
    local pnc, pnv = UI.push_kind(ctx, "primary")
    local assign_hit = UI.button(ctx, "Assign selected PDF", btn_w, main_h)
    UI.pop_kind(ctx, pnc, pnv)
    if assign_hit then
      Project.assign_region_pdf(reg, P.pdfs[R.empty_sel + 1]); return
    end
  else
    local pnc, pnv = UI.push_kind(ctx, "primary")
    local add_hit = UI.button(ctx, "+ Add PDF for this region", btn_w, main_h)
    UI.pop_kind(ctx, pnc, pnv)
    if add_hit then
      local ok, f = r.GetUserFileNameForRead("", "Select a PDF for region \"" .. reg.name .. "\"", "pdf")
      if ok and f and f ~= "" then Project.import_for_region(reg, f); return end
    end
  end
  y = y + main_h + gap

  -- secondary actions
  local sec_total = math.min(inner_w, 440)
  local hw = math.floor((sec_total - 8) / 2)
  ImGui.SetCursorScreenPos(ctx, cx - sec_total / 2, y)
  local sec1 = (ambiguous or R.choose_existing) and "+ Add PDF for this region" or "Choose from library"
  if UI.button(ctx, sec1 .. "##sec1", hw, sec_h) then
    if ambiguous or R.choose_existing then
      local ok, f = r.GetUserFileNameForRead("", "Select a PDF for region \"" .. reg.name .. "\"", "pdf")
      if ok and f and f ~= "" then Project.import_for_region(reg, f); return end
    else
      R.choose_existing = true
    end
  end
  ImGui.SameLine(ctx, 0, 8)
  if ignored then
    if UI.button(ctx, "Stop ignoring##sec2", hw, sec_h) then Project.unignore_region(reg); return end
  else
    if UI.button(ctx, "Ignore this region##sec2", hw, sec_h) then Project.ignore_region(reg); return end
  end
end

-- Page tint: white, or grey in dim mode (ImGui multiplies the image colours by this value).
function UI.page_tint()
  if not S.dim_page then return COL.WHITE end
  local v = math.floor(255 * Util.clamp(S.dim_level, 0.3, 1) + 0.5)
  return (v << 24) | (v << 16) | (v << 8) | 0xFF
end

-- Scroll points (0..100) that belong to the page on screen, in Markers or Cue list mode.
function UI.scroll_marks()
  local mode = Nav.scroll_mode()
  local reg_key = (mode == "cues") and Cues.key(Cues.playing_region())
    or (R.active_region and R.active_region.key) or ""
  local c = R.marks_cache
  if c and c.mode == mode and c.reg == reg_key and c.page == S.page and c.ver == R.lib_ver
      and c.cc == R.state_cc and c.P == P then
    return c.out
  end
  local out = UI.scroll_marks_build(mode)
  R.marks_cache = { mode = mode, reg = reg_key, page = S.page, ver = R.lib_ver, cc = R.state_cc, P = P, out = out }
  return out
end

function UI.scroll_marks_build(mode)
  local pp, sp
  if mode == "cues" then
    pp, sp = Cues.points(Cues.playing_region())
  elseif mode == "marker" then
    pp, sp = R.page_pts, R.scroll_pts
    local reg = R.active_region
    if reg then -- only the markers of the song on screen
      local fp, fs = {}, {}
      for _, p in ipairs(pp) do if p.t >= reg.start and p.t < reg.stop then fp[#fp + 1] = p end end
      for _, q in ipairs(sp) do if q.t >= reg.start and q.t < reg.stop then fs[#fs + 1] = q end end
      pp, sp = fp, fs
    end
  else
    return {}
  end
  local out = {}
  for _, q in ipairs(sp) do
    local page = 1
    for _, p in ipairs(pp) do if p.t <= q.t then page = p.page else break end end
    if page == S.page then out[#out + 1] = q.pct end
  end
  return out
end

function UI.draw_view(ctx, view_w, view_h)
  local sbw = CFG.SCROLLBAR_W
  local area_w = math.max(1, view_w - sbw - 4)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)

  -- a region without a PDF shows its empty state instead of whatever PDF was open before
  -- (during playback the last page can stay: R.kept_key, with a banner)
  local kept = R.empty_region and R.kept_key == R.empty_region.key
  local blocked = (not kept) and R.empty_region or nil
  local img, iw, ih
  if not blocked then img, iw, ih = PDF.get_page_image(S.page) end
  local scale, disp_w, disp_h = 1, 1, 1
  if img then
    scale = Nav.effective_scale(iw, ih, area_w, view_h)
    R.last_ratio = scale -- screen px per image px (1.0 = pixel-perfect)
    disp_w, disp_h = math.floor(iw * scale + 0.5), math.floor(ih * scale + 0.5)
    R.max_y = math.max(0, disp_h - view_h)
    R.max_x = math.max(0, disp_w - area_w)
  else
    R.max_y, R.max_x = 0, 0
  end

  local hovered, active = false, false
  local locked = UI.locked()
  if img then
    ImGui.InvisibleButton(ctx, "##pageview", area_w, view_h)
    hovered, active = ImGui.IsItemHovered(ctx), ImGui.IsItemActive(ctx)
    if locked then hovered, active = false, false end -- lock mode: no wheel, no dragging
  else
    -- No page image (empty states): a plain Dummy keeps the layout but, unlike an InvisibleButton,
    -- it does not capture hover/clicks, so the empty-state buttons drawn on top are clickable.
    ImGui.Dummy(ctx, area_w, view_h)
  end
  if hovered then
    local wv, wh = ImGui.GetMouseWheel(ctx)
    if wv ~= 0 or wh ~= 0 then
      local ctrl = (ImGui.GetKeyMods(ctx) & ImGui.Mod_Ctrl()) ~= 0
      if ctrl and img then
        Nav.set_zoom_from_scale(scale * (wv > 0 and CFG.ZOOM_STEP or 1 / CFG.ZOOM_STEP), iw, area_w)
      else
        if wv ~= 0 then Nav.scroll_by(-wv * CFG.WHEEL_STEP) end
        if wh ~= 0 then S.scroll_x = Util.clamp(S.scroll_x - wh * CFG.WHEEL_STEP, 0, R.max_x); Util.mark_dirty() end
      end
    end
  end
  if active and not R.perf_btn_over then -- a click on the performance-mode exit button is not a drag
    local dx, dy = ImGui.GetMouseDelta(ctx)
    if dy ~= 0 then Nav.scroll_by(-dy) end
    if dx ~= 0 then S.scroll_x = Util.clamp(S.scroll_x - dx, 0, R.max_x); Util.mark_dirty() end
  end

  ImGui.SetCursorScreenPos(ctx, x0 + area_w + 4, y0)
  ImGui.InvisibleButton(ctx, "##vscroll", sbw, view_h)
  local sb_active = ImGui.IsItemActive(ctx) and not locked
  local thumb_h = (disp_h > 0) and Util.clamp(view_h * view_h / disp_h, 24, view_h) or view_h
  if sb_active and R.max_y > 0 then
    local _, my = ImGui.GetMousePos(ctx)
    local frac = Util.clamp((my - y0 - thumb_h / 2) / math.max(1, view_h - thumb_h), 0, 1)
    S.scroll_y = frac * R.max_y; R.abs_target = nil; Util.touch_override(); Util.mark_dirty()
  end

  Nav.update_motion()

  ImGui.DrawList_AddRectFilled(dl, x0, y0, x0 + area_w, y0 + view_h, CFG.PAGE_BG)
  if img then
    -- snap to whole screen pixels so the texture is never sampled at half-pixel offsets (blur)
    local dw = math.floor(math.min(disp_w, area_w) + 0.5)
    local dh = math.floor(math.min(disp_h, view_h) + 0.5)
    local ox = math.floor(x0 + (area_w - dw) / 2 + 0.5)
    local oy = math.floor(y0 + 0.5)
    local sx, sy = math.floor(S.scroll_x + 0.5), math.floor(S.scroll_y + 0.5)
    local u0, u1 = sx / disp_w, (sx + dw) / disp_w
    local v0, v1 = sy / disp_h, (sy + dh) / disp_h
    ImGui.DrawList_AddImage(dl, img, ox, oy, ox + dw, oy + dh, u0, v0, u1, v1, UI.page_tint())
  elseif blocked then
    UI.draw_region_empty_state(ctx, x0, y0, area_w, view_h, blocked)
  elseif R.info_job then
    ImGui.DrawList_AddText(dl, x0 + 20, y0 + 20, COL.TEXT, "Loading PDF...")
  elseif R.total == 0 then
    UI.draw_empty_state(ctx, x0, y0, area_w, view_h, dl)
  else
    ImGui.DrawList_AddText(dl, x0 + 20, y0 + 20, COL.TEXT, string.format("Preparing page %d...", S.page))
    if not R.error then
      ImGui.SetCursorScreenPos(ctx, x0 + 20, y0 + 44)
      ImGui.ProgressBar(ctx, R.batches_done / math.max(1, PDF.total_batches()), 260, 0,
        string.format("%d / %d batches", R.batches_done, PDF.total_batches()))
    end
  end

  local sx = x0 + area_w + 4
  ImGui.DrawList_AddRectFilled(dl, sx, y0, sx + sbw, y0 + view_h, COL.SCROLL_TRACK, 4)
  local ty = y0 + ((R.max_y > 0) and (S.scroll_y / R.max_y) or 0) * (view_h - thumb_h)
  ImGui.DrawList_AddRectFilled(dl, sx, ty, sx + sbw, ty + thumb_h, sb_active and COL.SCROLL_THUMB_ACTIVE or COL.SCROLL_THUMB, 4)
  -- scroll points of this page (Markers / Cue list) as small marks on the scrollbar
  if img and R.max_y > 0 then
    for _, pct in ipairs(UI.scroll_marks()) do
      local my = y0 + thumb_h / 2 + (pct / 100) * (view_h - thumb_h)
      ImGui.DrawList_AddRectFilled(dl, sx - 3, my - 1, sx + sbw + 3, my + 1, COL.ACCENT_HOVER, 1)
    end
  end
  -- page-turn flash
  if S.turn_flash and img then
    local t = Util.now() - R.flash_t
    if t >= 0 and t < CFG.FLASH_SEC then
      local a = math.floor(255 * (1 - t / CFG.FLASH_SEC))
      local c = (COL.ACCENT & 0xFFFFFF00) | a
      local hw = CFG.FLASH_W / 2
      ImGui.DrawList_AddRect(dl, x0 + hw, y0 + hw, x0 + area_w - hw, y0 + view_h - hw, c, 6, 0, CFG.FLASH_W)
    end
  end
  -- banner: kept page (region without a PDF during playback); does not block the page
  local badge_y = y0 + 10
  if kept then
    local reg = R.empty_region
    local txt = UI.trunc_text(ctx, string.format('No PDF for "%s" - showing the last page. Autoscroll paused.',
      reg.name ~= "" and reg.name or "(unnamed region)"), area_w - 24)
    local _, th = ImGui.CalcTextSize(ctx, txt)
    ImGui.DrawList_AddRectFilled(dl, x0, y0, x0 + area_w, y0 + th + 10, 0x3A3200E6)
    ImGui.DrawList_AddText(dl, x0 + 10, y0 + 5, COL.YELLOW, txt)
    badge_y = y0 + th + 18
  end
  -- badges (top left): lock, record cues
  local bx = x0 + 10
  local function badge(txt, col)
    local tw, th = ImGui.CalcTextSize(ctx, txt)
    ImGui.DrawList_AddRectFilled(dl, bx - 6, badge_y - 4, bx + tw + 6, badge_y + th + 4, 0x000000AA, 6)
    ImGui.DrawList_AddText(dl, bx, badge_y, col, txt)
    bx = bx + tw + 20
  end
  if R.lock then badge(locked and "LOCKED" or "Lock on (active during playback)", locked and COL.YELLOW or COL.GREY) end
  if R.rec and Nav.scroll_mode() == "cues" then badge("REC", COL.RED) end
  -- performance mode: a hint after entering, and an exit button in the top-right corner on hover
  R.perf_btn_over = false
  if R.perf then
    local mx, my = ImGui.GetMousePos(ctx)
    local lbl = "Exit performance mode (F / Esc)"
    local tw, th = ImGui.CalcTextSize(ctx, lbl)
    local bx1, by0 = x0 + area_w - 10, y0 + 10
    local bx0, by1 = bx1 - tw - 20, by0 + th + 12
    local near = mx >= x0 + area_w - 260 and mx <= x0 + area_w and my >= y0 and my <= y0 + 60
    -- a click / tap on the page also shows the button (touch screens have no hover)
    if ImGui.IsMouseClicked(ctx, 0) and mx >= x0 and mx <= x0 + area_w and my >= y0 and my <= y0 + view_h then
      if not near then R.perf_tap_t = Util.now() end
    end
    if near or Util.now() - R.perf_t < 2.5 or Util.now() - R.perf_tap_t < 3 then
      local over = mx >= bx0 and mx <= bx1 and my >= by0 and my <= by1
      R.perf_btn_over = over
      ImGui.DrawList_AddRectFilled(dl, bx0, by0, bx1, by1, over and COL.ACCENT or 0x000000BB, 6)
      ImGui.DrawList_AddText(dl, bx0 + 10, by0 + 6, COL.WHITE, lbl)
      if over and ImGui.IsMouseClicked(ctx, 0) then UI.toggle_perf() end
    end
  end

  ImGui.SetCursorScreenPos(ctx, x0, y0 + view_h + 2)
end

---------------------------------------------------------------------------
-- DOCKING
---------------------------------------------------------------------------
-- "Reset window layout": float the window at the default position/size.
function Dock.reset(ctx)
  ImGui.SetNextWindowPos(ctx, CFG.DEFAULT_WIN[1], CFG.DEFAULT_WIN[2], ImGui.Cond_Always())
  ImGui.SetNextWindowSize(ctx, CFG.DEFAULT_WIN[3], CFG.DEFAULT_WIN[4], ImGui.Cond_Always())
  ImGui.SetNextWindowDockID(ctx, 0, ImGui.Cond_Always())
  S.dock_id = 0; S.panel_h = 0; R.reset_layout = false; Util.mark_dirty()
end

-- Restore the saved dock once at startup.
function Dock.apply(ctx)
  if not R.dock_applied then
    R.dock_applied = true
    if type(S.dock_id) ~= "number" or S.dock_id ~= S.dock_id then S.dock_id = 0 end
    if S.dock_id ~= 0 then ImGui.SetNextWindowDockID(ctx, S.dock_id, ImGui.Cond_Once()) end
  end
end

-- Track dock id and (when floating) window position/size. Call between Begin and End.
function Dock.track(ctx)
  local docked = ImGui.IsWindowDocked(ctx) and true or false
  if docked ~= R.last_docked then
    if R.last_docked ~= nil then Msg.diag(docked and "Window docked." or "Window undocked.") end
    R.last_docked = docked
    R.dock_settle = R.frames + CFG.DOCK_SETTLE_FRAMES -- wait before saving a new dock state
  end
  if R.frames > CFG.DOCK_SETTLE_FRAMES and R.frames > (R.dock_settle or 0) then
    local did = 0
    if docked then
      did = ImGui.GetWindowDockID(ctx)
    end
    if did ~= S.dock_id then S.dock_id = did; Util.mark_dirty() end
  end
  if not docked then
    local wx, wy = ImGui.GetWindowPos(ctx)
    local ww, wh = ImGui.GetWindowSize(ctx)
    if wx ~= S.win_x or wy ~= S.win_y or ww ~= S.win_w or wh ~= S.win_h then
      S.win_x, S.win_y, S.win_w, S.win_h = wx, wy, ww, wh; Util.mark_dirty()
    end
  end
end

---------------------------------------------------------------------------
-- FRAME
---------------------------------------------------------------------------
function UI.frame()
  local ctx = R.ctx
  Midi.poll_forwarded_midi()
  Midi.poll_direct_midi()
  Project.project_tick()
  Project.region_tick()
  Project.pick_tick()
  Project.import_tick()
  Project.copy_tick()
  PDF.info_tick()
  PDF.render_tick()
  Util.dir_size_tick()
  if Util.now() - (R.hb_t or 0) >= 0.25 then -- single-instance heartbeat (timeout is 1 s)
    R.hb_t = Util.now()
    r.SetExtState(CFG.EXT, "heartbeat", tostring(R.hb_t), false)
  end
  R.frames = R.frames + 1

  -- window placement / docking
  if R.reset_layout then
    Dock.reset(ctx)
  else
    Dock.apply(ctx)
    ImGui.SetNextWindowPos(ctx, S.win_x, S.win_y, ImGui.Cond_FirstUseEver())
    ImGui.SetNextWindowSize(ctx, S.win_w, S.win_h, ImGui.Cond_FirstUseEver())
  end

  -- ReaImGui rule (differs from Dear ImGui C++): call End() ONLY when Begin() returned true.
  -- Begin() returns false when the window is in an inactive dock tab or collapsed.
  UI.push_theme(ctx) -- popped after End() below (and by UI.loop after an error)
  local visible, open = ImGui.Begin(ctx, CFG.TITLE, true)
  if visible ~= R.was_visible then
    Msg.diag(visible and "Chart Cue is visible." or "Chart Cue is hidden.")
    R.was_visible = visible
  end
  if visible then
    R.in_window = true
    Dock.track(ctx)
    UI.handle_keys(ctx)

    local perf = R.perf -- performance mode: only the page
    local hide = perf or (S.hide_controls_playing and Util.playing())
    -- while hidden, the status bar shows only one red line when there is an error
    local status_h = ImGui.GetTextLineHeightWithSpacing(ctx) + ImGui.GetFrameHeightWithSpacing(ctx) + 4
    if hide then status_h = R.error and (ImGui.GetFrameHeightWithSpacing(ctx) + 2) or 6 end
    if perf then
      -- nothing above the page
    elseif hide then
      UI.draw_centered_toolbar(ctx, true)  -- minimal toolbar while playing
      UI.vgap(ctx, UI.sp("EDGE"))
    else
      UI.draw_centered_toolbar(ctx, false)
      UI.vgap(ctx, UI.sp("EDGE")) -- same gap below the toolbar as above it
      UI.draw_tab_strip(ctx)
      if S.panel_open then UI.draw_panel(ctx, status_h) end
    end

    local aw, ah = ImGui.GetContentRegionAvail(ctx)
    local vh = math.max(60, ah - status_h)
    R.view_w, R.view_h = aw - CFG.SCROLLBAR_W - 4, vh
    UI.draw_view(ctx, aw, vh)
    if not hide then UI.draw_status(ctx)
    elseif R.error then UI.draw_error_line(ctx)
    else
      -- draw_view ends with SetCursorScreenPos(); ImGui requires an item after it before End()
      ImGui.Dummy(ctx, 0, 0)
    end
    R.in_window = false
    ImGui.End(ctx)
  end
  UI.pop_theme(ctx)
  if not open then R.quit = true end

  if R.dirty and Util.now() - R.last_save > 2 then Util.save_settings(); R.dirty = false; R.last_save = Util.now() end
end

---------------------------------------------------------------------------
-- MAIN LOOP / LIFECYCLE
---------------------------------------------------------------------------
function UI.cleanup()
  Project.cancel_copies()
  Util.save_settings()
  Project.save_project_cfg()
  r.SetExtState(CFG.EXT, "heartbeat", "", false)
  r.SetExtState(CFG.EXT, "midi_q", "", false)
  if R.picker then os.remove(R.picker.out_f); os.remove(R.picker.done_f) end
  if sect_id and cmd_id and cmd_id ~= 0 then
    r.SetToggleCommandState(sect_id, cmd_id, 0); r.RefreshToolbar2(sect_id, cmd_id)
  end
  R.ctx = nil
end

function UI.loop()
  local ok, err = pcall(UI.frame)
  if not ok then
    r.ShowConsoleMsg("[" .. CFG.TITLE .. "] Error: " .. tostring(err) .. "\n")
    Msg.set_error("Internal error: " .. tostring(err))
    if not r.ImGui_ValidatePtr(R.ctx, "ImGui_Context*") then
      -- the context is gone: stop cleanly instead of using a dead context
      r.ShowConsoleMsg("[" .. CFG.TITLE .. "] ImGui context is no longer valid; Chart Cue stopped.\n")
      R.ctx = nil; R.quit = true
    elseif R.in_window then
      -- the error happened between Begin() and End(): close the window so the stack stays balanced
      pcall(r.ImGui_End, R.ctx) -- protected: the window stack may be unbalanced after the error
      Msg.diag("Recovered from an ImGui error inside the window.")
    end
    R.in_window = false
    if R.ctx then UI.pop_theme(R.ctx) end -- remove the theme pushes of the failed frame
  end
  if R.quit then UI.cleanup(); return end
  r.defer(UI.loop)
end

function UI.init()
  Util.ensure_dir(CFG.CACHE_ROOT); Util.ensure_dir(CFG.TMP_DIR)
  r.SetExtState(CFG.EXT, "quit", "", false) -- a flag left by an instance that stopped before reading it
  Util.load_settings()
  S.dpi = Util.clamp(math.floor(S.dpi), 50, 600)
  if S.tab_ver < 3 then
    if S.tab_ver < 2 and S.tab >= TAB_CUES then S.tab = S.tab + 1 end -- old numbers had no Cues tab
    -- v2 numbers: 4..7 = Autoscroll, MIDI, Display, Project (now one Settings tab), 8 = Help
    if S.tab >= 8 then S.tab = TAB_HELP elseif S.tab >= 4 then S.tab = TAB_FIRST_SETTING end
    S.tab_ver = 3; Util.mark_dirty()
  end
  S.tab = Util.clamp(math.floor(S.tab), 1, TAB_HELP)
  R.ctx = r.ImGui_CreateContext(CFG.TITLE)
  UI.init_fonts(R.ctx)
  R.dpi_edit = S.dpi
  if r.MIDI_GetRecentInputEvent then R.last_midi_seq = (r.MIDI_GetRecentInputEvent(0)) or 0 end
  if sect_id and cmd_id and cmd_id ~= 0 then
    r.SetToggleCommandState(sect_id, cmd_id, 1); r.RefreshToolbar2(sect_id, cmd_id)
  end
  r.atexit(UI.cleanup)
  -- the autostart watcher finds Chart Cue by this named command ID (persisted)
  local cs = Autostart.command_string()
  if cs then r.SetExtState(CFG.EXT, "cmd", cs, true) end
  if Autostart.installed(true) then Autostart.write_script() end -- keep the watcher up to date

  PDF.write_engine_script()
  for _, f in ipairs(Util.list_files(CFG.TMP_DIR)) do -- leftovers of cancelled page-count jobs
    if f:match("^info_%d+%.") then os.remove(CFG.TMP_DIR .. SEP .. f) end
  end
  if PDF.engine() == "poppler" then -- the Poppler search runs only when Poppler is used
    R.exe = PDF.find_pdftoppm()
    if not R.exe then Msg.set_error(PDF.poppler_help()) else PDF.check_pdfinfo() end
  end

  -- Same startup path whether launched manually, from the action list, or as an SWS project startup
  -- action: load the project's config, rescan markers/regions, reopen its active PDF.
  -- Playback-linked autoscroll never starts on its own (it only moves while REAPER is playing).
  Project.check_project(true)
  if launched_by_midi then Midi.handle_scroll_value(act_val, "action-bound MIDI CC", nil) end
  UI.loop()
end

UI.init()
