-- @noindex
-- Tab Viewer's Detection tab (it was the script Note Detective, decided 24 November 2026): finds the notes of a
-- separated bass track (or takes them from the tab) and writes them as markers, as text items on a "Notes" track, or
-- both. For a player who learns the part in REAPER. Tab Viewer loads this file: `dofile(...)(host)` gives the Notes
-- module (its functions below: N). The host hands over what the 2 share: the window (ImGui, COL, the UI helpers with
-- the notice and the Find tempo button, CFG for the look), the Guitar Pro reader GP, TP (Tempo.lua), R (a running Find
-- tempo), notes_changed, and entry_line / entry_text (the tab of the found notes is saved as Tab Viewer saves a tab).

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

return function(host)
local r = reaper
local GP, TP = host.GP, host.TP

---------------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------------
local CFG = {}
CFG.CTRL_GAP, CFG.SP_ROW = host.CFG.CTRL_GAP, host.CFG.SP_ROW -- (the look: Tab Viewer's)
CFG.EXT = host.CFG.EXT         -- ExtState section (this computer) and the project data section: Tab Viewer's
CFG.PEXT_KEY = "notes"         -- the project data key of the list
CFG.UNDO_NAME = "Tab Viewer"   -- the start of the undo names ("Tab Viewer: write notes")
CFG.TAG = "P_EXT:TabViewer"    -- the mark on the Notes track and on its text items
CFG.TRACK = "Notes"            -- the name of the Notes track
CFG.MODE_W, CFG.OUT_W = 150, 200 -- the Rhythm dropdown in Export, the Write dropdown
CFG.KEY_W, CFG.TUNE_LABEL_W, CFG.TUNE_MIN_W = 130, 66, 150 -- the Key / Tuning row (narrower: 2 rows)
CFG.COL_NUM_W, CFG.COL_BAR_W, CFG.COL_PLACES_W = 34, 52, 64 -- the columns of the list
CFG.UNDO_MAX = 50              -- the steps of the Undo button (the list)
CFG.KEY_MIN_NOTES = 8          -- Key.guess: fewer found notes give no suggestion
CFG.TAB_GAP_Q = 0.5            -- the tab of the found notes: a gap shorter than this (quarter notes: an 8th) is no rest
CFG.TAB_PULL8 = 0.09           -- and a start this close to an 8th (quarter notes: about a 3rd of a 16th) is on the 8th
CFG.LOOP_LAST = 4              -- s: the loop of the last row (to the end of the bass item, at most this long)
CFG.MK_MAX = 3000              -- the kept IDs of written markers (the older ones are dropped)
-- The detection (the values of the trials of 23 November 2026)
CFG.SR, CFG.HOP = TP.CFG.SR, TP.CFG.HOP -- the bass is read at 4000 Hz; 1 frame every 10 ms (as Find tempo, Tempo.lua)
CFG.YIN_W, CFG.LAG0, CFG.LAG1 = 200, 8, 130 -- YIN: the window, and the lags (500 Hz down to 31 Hz)
CFG.YIN_THR, CFG.YIN_MAX = 0.15, 0.3 -- YIN: a sure pitch; a pitch at all
CFG.GATE_DB = 35               -- a frame this far below the loud parts is silence
CFG.ATTACK_GATE_DB = 20        -- the tuning: only from frames that are not this far below the loud parts
CFG.NOTE_MIN = 0.06            -- a shorter note is not a note
CFG.GLITCH = 0.2               -- s: a note this short, a 5th above the note around it, is a glitch (Det.glitches)
CFG.START_COMP = 0.03          -- the notes start this much earlier (the smoothing reports them late)
-- The onsets (Det.onsets_of; Dev 2 of the review of 23 November 2026; trial 9): the band flux in 5 ms frames
CFG.ON_STEP, CFG.ON_DIFF = 0.005, 3 -- s per frame; the rise over this many frames
CFG.ON_BANDS, CFG.ON_F0, CFG.ON_Q = 9, 50, 5 -- bands from 50 Hz, half an octave apart (to 800 Hz), narrow (Q)
CFG.ON_BW = 25                 -- Hz: the narrowest band (a narrower one needs too long to rise: a 2nd, late onset)
CFG.ON_SMOOTH = 1              -- the level of a band: smoothed over this many periods of its frequency (at least 5 ms)
CFG.ON_FLOOR = 30              -- dB: only bands this close to the loudest one of the moment count, from this far below (Dev 5)
CFG.ON_GATE = TP.CFG.ON_GATE   -- dB: no pluck this far below the loud parts of the whole item (noise, bleed)
CFG.ON_K, CFG.ON_D = 2.0, 1.5  -- an onset: a rise of ON_K x the mean of 1 s around it + ON_D dB
CFG.ON_GAP = 0.05              -- s: onsets at least this far apart
CFG.ON_BEFORE, CFG.ON_AFTER = 0.08, 0.04 -- s: a pitch change this close after / before an onset belongs to it
CFG.ON_SKIP = 0.03             -- s: the noise of the attack, not counted for the pitch of the note
CFG.ON_HOLD = 0.15             -- s: a piece too short for a note joins the next one when that starts this soon
CFG.END_GAP = 0.05             -- s: a note ends when its pitch is gone this long
CFG.HARM = { { 0, 1 }, { 12, 0.8 }, { 19, 0.5 }, { 24, 0.4 } } -- the 2nd method: semitones above, weight
CFG.HARM_LO, CFG.HARM_HI = 24, 47 -- the 2nd method: the notes C1 to B2
-- Octaves and strings (the trials of 23 November 2026: the odd harmonics of the low octave against the even ones)
CFG.TUNINGS = { -- the open strings from the lowest (MIDI numbers); the strings keep the names of their places
  -- (in the order of the dropdown, decided 26 November 2026: 4 strings from the highest standard tuning down, the
  -- drop tunings, then 5 strings; the ids are saved in projects: they stay; the first one is the default)
  { id = "std", label = "E standard (E A D G)", open = { 28, 33, 38, 43 } },
  { id = "half", label = "Eb standard (Eb Ab Db Gb)", open = { 27, 32, 37, 42 } },
  { id = "dstd", label = "D standard (D G C F)", open = { 26, 31, 36, 41 } },
  { id = "cstd", label = "C standard (C F Bb Eb)", open = { 24, 29, 34, 39 } },
  { id = "bstd", label = "B standard (B E A D)", open = { 23, 28, 33, 38 } },
  { id = "dropd", label = "Drop D (D A D G)", open = { 26, 33, 38, 43 } },
  { id = "dropcs", label = "Drop C# (C# G# C# F#)", open = { 25, 32, 37, 42 } },
  { id = "dropc", label = "Drop C (C G C F)", open = { 24, 31, 36, 41 } },
  { id = "dropb", label = "Drop B (B F# B E)", open = { 23, 30, 35, 40 } },
  { id = "five", label = "5-string B standard (B E A D G)", open = { 23, 28, 33, 38, 43 } },
  { id = "five_half", label = "5-string Bb standard (Bb Eb Ab Db Gb)", open = { 22, 27, 32, 37, 42 } },
  { id = "five_a", label = "5-string A standard (A D G C F)", open = { 21, 26, 31, 36, 41 } },
  { id = "five_dropa", label = "5-string Drop A (A E A D G)", open = { 21, 28, 33, 38, 43 } },
}
CFG.STRING_NAMES = { [4] = { "E", "A", "D", "G" }, [5] = { "B", "E", "A", "D", "G" } }
CFG.OCT_DB = -6                -- the odd harmonics this far below the even ones: the higher octave (Det.octave_limit:
CFG.OCT_FIT_LO, CFG.OCT_FIT_HI = -20, 0 -- the limit of each song between these, in its emptiest place: the fewest values
CFG.OCT_VALLEY, CFG.OCT_GAP = 3, 0.05 -- within this many dB, at most this share of the notes; at least OCT_FIT_MIN notes)
CFG.OCT_FIT_MIN = 30
CFG.OCT_SURE = 8               -- dB from that limit: sure, even when YIN disagrees (trial 5i: fewer yellow lines,
                               -- song 2: 24 yellow of which 22 wrong, instead of 37 of which 29)
CFG.FRET_MAX = 7               -- a high note goes on the lowest string with this fret or a lower one
-- Slides and repeated notes (trial 6d, 23 November 2026)
CFG.SLIDE_MIN = 2              -- semitones: a pitch that glides this far into a note (no new attack) is a slide
CFG.SLIDE_STEPS = 8            -- frames (10 ms) that the pitch moves at least (a plain note change takes 2-3; song 2:
                               -- 5 gave 24 slides that the score does not have, 8 gave 3)
CFG.SLIDE_MAX = 0.25           -- s: the longest glide
CFG.REP_DB = 4                 -- dB: a 16th inside a note with dip + REP_RISE x rise of this size is a new note
CFG.REP_RISE = 0.5
CFG.REP_EDGE = 0.05            -- s: no new note this close to the start or the end of a note
-- Fingering for runs (trial 4c: 398 of 410 notes in the same place as a Guitar Pro score, "few shifts")
CFG.RUN_MIN = 4                -- a row with this many notes or more is a run: every note gets its string and fret
CFG.FRETS = 15                 -- the highest fret that the fingering uses
-- Export (MIDI)
CFG.MIDI_TRACK = "Bass MIDI"   -- the name of the track of the MIDI item
CFG.MIDI_VEL = 96              -- the velocity of the exported notes
CFG.PPQ = 960                  -- the ticks per quarter note of the .mid file
CFG.GRIDS = { { 0.25, "16th notes" }, { 0.5, "8th notes" }, { 0, "No quantize" } } -- Rhythm (quarter notes)
CFG.FINGER = { move = 0.5, shift = 3, str = 0.3, same = 5, high = 0.2, open = 1, stretch = 0.3 } -- the costs: a hand
                               -- move per fret, any hand move, a string change, the same note on another string,
                               -- per fret above 5, an open string, a stretch over 4 frets low on the neck
CFG.BAR_TOL = 0.03             -- s: a note that starts this much before a bar line is the "1" of that bar (strict bars)
CFG.HELD_MIN = 0.15            -- s: a note that rings this long into the next bar is that bar's first note too
CFG.SPAN_GAP = 0.15           -- the same note again within this time is the same part
CFG.SEC_LEN = 2               -- "Every note change": a silence this long starts a new line
CFG.SECTION_BARS = 8           -- a repeat of this many bars starts a new section
CFG.STEP = TP.CFG.STEP         -- s of work per frame while Find notes runs (as Find tempo)

local COL = host.COL           -- (Tab Viewer's colours: the theme changes them in place)
local ImGui = host.ImGui
local ctx                      -- (the window of Tab Viewer: N.attach, before the first frame)

local Util, Key, Det, Group, List, Project, Find, Out, Export, Imp = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
local Songs, Lists = {}, {}     -- the songs of the project, and 1 list per song (decided 26 November 2026)
local UI = setmetatable({}, { __index = host.UI }) -- (the helpers of Tab Viewer: button, toggle, notice ...)
local N = {}                   -- what Tab Viewer calls (the end of this file)

-- R: runtime state of the Detection tab (not saved). P: the list (the project data). S: its settings (this computer).
local R = {
  proj = nil, projfn = "", state_cc = -1, plast_txt = "", pdirty = false, sdirty = false,
  find = nil,        -- the running Find notes: { item, take, proj, rd (the reader), co (the detection), done 0-1 }
  sel = nil,         -- the selected row (its index in P.rows)
  edit = nil,        -- the row whose notes are typed: { i, txt, focus }
  undo = {},         -- the Undo button: the older project data texts
  redo = {},         -- the Redo arrow: the texts that Undo took back
  view = nil,        -- the texts of the list rows (UI.view; rebuilt after a change)
  src_name = nil,    -- the name of the bass item (cached until the project changes)
  trk = nil,         -- the Track row: your choice (not saved; Find.track)
  written_lbl = nil, -- "Written (12 markers)" next to Write, until the list changes (Out.written_text)
  loop = nil,        -- the loop of a row (UI.play_row): { proj, rep, ts (before it), t0, t1 }
  trk_lbl = nil,     -- the text of the Track row (of the track trk_for; cached until the project changes)
  trk_for = nil,
  trk_def = nil,     -- the default track (false: none; nil: not looked for yet)
  finish = nil,      -- the open Done: clean up window (More...)
  export = nil,      -- the open Export window: { item, file, step (Rhythm), open }
  lists = nil,       -- the saved lists of the songs: { ids = { the song ids in order }, txt = { [id] = the list text } }
  song = nil,        -- the song of the shown list P (its id; "": a project without songs)
  hist = {},         -- the Undo and Redo steps of the other songs: { [id] = { undo, redo } } (this session)
  follow_last = nil, -- the song at the cursor when the list last followed it (Lists.follow)
  songs = nil,       -- the songs (Songs.get; made again when the project or the Track row changes)
  st = nil,          -- the song header (N.song_head)
  song_lbls = nil,   -- the texts of the song list of the header
  flash = nil,       -- the time the list last followed the cursor to another song (the header flashes)
}
local P
local S = {
  out = "markers",   -- what Write makes: "markers", "track" (the Notes track) or "both"
  frets = true,      -- Settings > Detection > String for high notes
  finger = true,     -- Settings > Detection > Fingering for runs
  strings = "letters", -- Settings > Detection > String names: "letters" (E A D G) or "numbers" (4 3 2 1)
  export_dir = "",   -- the folder of the .mid files ("": the project folder)
  splits = false,    -- Settings > Detection > Split repeated notes (after Set tempo; off by default, decided 25 November 2026)
  song_follow = true, -- Settings > Detection > Follow the song (the list follows the edit cursor; 26 November 2026)
}

---------------------------------------------------------------------------
-- UTIL
---------------------------------------------------------------------------
function Util.now() return r.time_precise() end
function Util.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
function Util.clean(s) return ((s or ""):gsub("[\t\r\n]", " "):gsub("^%s+", ""):gsub("%s+$", "")) end
-- After a change of the list: saved at the end of the frame; the texts of the list and the tab of the found notes
-- are made again (host.notes_changed).
function Util.mark_pdirty()
  R.pdirty, R.view, R.places, R.written_lbl = true, nil, nil, nil
  host.notes_changed()
end
-- The item of this project with this GUID (nil: none; TP.item_by_guid).
function Util.item_by_guid(guid) return TP.item_by_guid(R.proj, guid) end
-- The play position while playing, else the edit cursor (Tab Viewer's, with its count-in; a new project before Tab
-- Viewer has seen it: the edit cursor).
function Util.cursor()
  if host.R.proj == R.proj then return UI.cursor() end
  return r.GetCursorPositionEx(R.proj)
end
function Util.playing() return R.proj ~= nil and r.GetPlayStateEx(R.proj) & 1 == 1 end
-- A folder picker (as in MIDI Pilot): the js_ReaScriptAPI extension's, else on Windows the Windows folder window
-- (REAPER waits until it closes). Returns the folder, or nil.
function Util.browse_folder(title, start)
  if r.JS_Dialog_BrowseForFolder then
    local rv, folder = r.JS_Dialog_BrowseForFolder(title, start or "")
    if rv == 1 and folder and folder ~= "" then return folder end
    return nil
  end
  if not r.GetOS():match("^Win") then return nil end
  local sp = (start or ""):gsub("/", "\\"):gsub("'", "''")
  local cmd = 'powershell -NoProfile -STA -WindowStyle Hidden -Command "Add-Type -AssemblyName System.Windows.Forms; '
    .. "$f = New-Object System.Windows.Forms.FolderBrowserDialog; $f.SelectedPath = '" .. sp .. "'; "
    .. "if ($f.ShowDialog() -eq 'OK') { $f.SelectedPath }" .. '"'
  local h = io.popen(cmd)
  if not h then return nil end
  local out = h:read("a") or ""
  h:close()
  out = out:match("^%s*(.-)%s*$")
  return out ~= "" and out or nil
end
function Util.settings_lines()
  return { "out=" .. S.out, "frets=" .. (S.frets and "1" or "0"), "finger=" .. (S.finger and "1" or "0"),
    "strings=" .. S.strings, "export_dir=" .. S.export_dir, "splits=" .. (S.splits and "1" or "0"),
    "song_follow=" .. (S.song_follow and "1" or "0") }
end
function Util.apply_setting(k, v)
  if k == "splits" then S.splits = (v ~= "0")
  elseif k == "song_follow" then S.song_follow = (v ~= "0")
  elseif k == "export_dir" then S.export_dir = Util.clean(v)
  elseif k == "strings" then S.strings = v == "numbers" and v or "letters"
  elseif k == "finger" then S.finger = (v ~= "0")
  elseif k == "frets" then S.frets = (v ~= "0")
  elseif k == "out" then S.out = (v == "track" or v == "both") and v or "markers" end
end
function Util.load_settings()
  for k in pairs(S) do -- (every key of S is a setting)
    local v = r.GetExtState(CFG.EXT, k)
    if v ~= "" then Util.apply_setting(k, v) end
  end
end
function Util.save_settings()
  for _, line in ipairs(Util.settings_lines()) do
    local k, v = line:match("^([%w_]+)=(.*)$")
    r.SetExtState(CFG.EXT, k, v, true)
  end
  R.sdirty = false
end

---------------------------------------------------------------------------
-- KEY (the key of the song and the names of the notes)
---------------------------------------------------------------------------
Key.PC = { C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11 }
Key.SHARP = { [0] = "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }
Key.FLAT = { [0] = "C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B" }
local TONIC = { -- the usual name of each tonic
  major = { [0] = "C", "Db", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B" },
  minor = { [0] = "C", "C#", "D", "Eb", "E", "F", "F#", "G", "G#", "A", "Bb", "B" },
}
local FLAT_KEY = { major = { [1] = true, [3] = true, [5] = true, [8] = true, [10] = true },
  minor = { [0] = true, [2] = true, [3] = true, [5] = true, [7] = true, [10] = true } }
local DEGREE = { -- the letter step of each interval (0-11 semitones above the tonic)
  major = { [0] = 0, 0, 1, 2, 2, 3, 3, 4, 5, 5, 6, 6 },
  minor = { [0] = 0, 1, 1, 2, 2, 3, 3, 4, 5, 5, 6, 6 },
}
local IN_KEY = {
  major = { [0] = true, [2] = true, [4] = true, [5] = true, [7] = true, [9] = true, [11] = true },
  minor = { [0] = true, [2] = true, [3] = true, [5] = true, [7] = true, [8] = true, [10] = true },
}
Key.LIST = {}
for pc = 0, 11 do
  Key.LIST[#Key.LIST + 1] = TONIC.major[pc] .. " major"
  Key.LIST[#Key.LIST + 1] = TONIC.minor[pc] .. " minor"
end

-- The key that the notes sound like (the musician review, 24 November 2026: a suggestion after Find notes): the time
-- of each pitch class against the major and minor profiles of Krumhansl and Kessler (the best correlation), as in
-- Key.LIST; nil with fewer than CFG.KEY_MIN_NOTES notes.
local PROFILE = {
  major = { 6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88 },
  minor = { 6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17 },
}
function Key.guess(notes)
  if #notes < CFG.KEY_MIN_NOTES then return nil end
  local w = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
  for _, n in ipairs(notes) do w[n.pc + 1] = w[n.pc + 1] + math.max(0.05, (n.t1 or n.t) - n.t) end
  local function corr(a, b)
    local ma, mb = 0, 0
    for i = 1, 12 do ma, mb = ma + a[i] / 12, mb + b[i] / 12 end
    local s, sa, sb = 0, 0, 0
    for i = 1, 12 do s, sa, sb = s + (a[i] - ma) * (b[i] - mb), sa + (a[i] - ma) ^ 2, sb + (b[i] - mb) ^ 2 end
    return sa > 0 and sb > 0 and s / math.sqrt(sa * sb) or 0
  end
  local best, bv = nil, -2
  for pc = 0, 11 do
    for _, mode in ipairs({ "major", "minor" }) do
      local rot = {}
      for i = 1, 12 do rot[i] = PROFILE[mode][(i - 1 - pc) % 12 + 1] end
      local v = corr(w, rot)
      if v > bv then best, bv = TONIC[mode][pc] .. " " .. mode, v end
    end
  end
  return best
end

function Key.pc(letter, acc)
  return (Key.PC[letter] + (acc == "#" and 1 or acc == "b" and -1 or 0)) % 12
end
-- The key tp half steps higher (Transpose: "E minor" +2 = "F# minor"); "" (not known) stays "".
function Key.shift(key, tp)
  local l, a, mode = (key or ""):match("^([A-G])([#b]?) (%a+)$")
  if not l or not TONIC[mode] or tp % 12 == 0 then return key end
  return TONIC[mode][(Key.pc(l, a) + tp) % 12] .. " " .. mode
end

-- The key in a file name ("... C minor ...", "... Cm ...", "... F# major ..."), as in Key.LIST; nil without one.
-- The last one counts (the song title comes first).
function Key.find(text)
  local pc, mode, at
  for pos, l, a, w in (text or ""):gmatch("()%f[%w]([A-G])([#b]?)[%s_]?(%a+)") do
    local m = w:lower()
    m = (m == "minor" or m == "min" or w == "m") and "minor" or (m == "major" or m == "maj") and "major" or nil
    if m and (not at or pos > at) then pc, mode, at = Key.pc(l, a), m, pos end
  end
  return pc and (TONIC[mode][pc] .. " " .. mode) or nil
end

-- The 12 note names of a key (0 = C ...): correct for the key. A note outside the key gets its usual name (F# in
-- C minor); a double sharp or flat gets the simple name. Without a key: sharps.
local names_cache = {}
function Key.names(key)
  local n = names_cache[key or ""]
  if n then return n end
  local l, a, mode = (key or ""):match("^([A-G])([#b]?) (%a+)$")
  if not l or not DEGREE[mode] then n = Key.SHARP
  else
    n = {}
    local tonic = Key.pc(l, a)
    local simple = FLAT_KEY[mode][tonic] and Key.FLAT or Key.SHARP
    local order = "CDEFGAB"
    local l0 = order:find(l, 1, true) - 1
    for i = 0, 11 do
      local pc = (tonic + i) % 12
      local k = (l0 + DEGREE[mode][i]) % 7 + 1
      local letter = order:sub(k, k)
      local d = (pc - Key.PC[letter] + 6) % 12 - 6
      local name = letter .. (d == 1 and "#" or d == -1 and "b" or "")
      local odd = name == "E#" or name == "B#" or name == "Cb" or name == "Fb"
      if math.abs(d) > 1 or (odd and not IN_KEY[mode][i]) then name = simple[pc] end
      n[pc] = name
    end
  end
  names_cache[key or ""] = n
  return n
end

-- The notes of a text with the names of another key. The text in brackets (a string and a fret) stays.
function Key.respell(text, key)
  local names = Key.names(key)
  local out, i = {}, 1
  while i <= #text do
    local a, b = text:find("%b()", i)
    local seg = text:sub(i, (a or #text + 1) - 1)
    out[#out + 1] = (seg:gsub("%f[%w#]([A-G])([#b]?)%f[^%w#]", function(l, acc) return names[Key.pc(l, acc)] end))
    if not a then break end
    out[#out + 1] = text:sub(a, b)
    i = b + 1
  end
  return table.concat(out)
end

-- A tuning of CFG.TUNINGS by its id (Standard when it is not known).
function Key.tuning(id)
  for _, t in ipairs(CFG.TUNINGS) do if t.id == id then return t end end
  return CFG.TUNINGS[1]
end
-- The lowest note of a pitch class on a bass with this lowest open string (the note with the plain name).
function Key.low(pc, lowest)
  return lowest + (pc - lowest) % 12
end
-- The names of the strings of a tuning, from the lowest: "E A D G" (the names of their places), or numbers as in tab
-- books (the lowest string has the highest number: 4 3 2 1).
function Key.string_names(tun, numbers)
  if not numbers then return CFG.STRING_NAMES[#tun.open] end
  local t = {}
  for s = 1, #tun.open do t[s] = tostring(#tun.open + 1 - s) end
  return t
end
-- The text after the name of a note: "" in the lowest octave, else " (string fret)" on the lowest string with a fret
-- of CFG.FRET_MAX or less (else the lowest fret). names: the string names (default: Key.string_names).
function Key.place(midi, tun, names)
  local open = tun.open
  if not midi or midi < open[1] + 12 then return "" end
  local best
  for s = 1, #open do
    local f = midi - open[s]
    if f >= 0 and f <= CFG.FRET_MAX then return Key.place_text({ s = s, f = f }, tun, names) end
    if f >= 0 then best = s end
  end
  return Key.place_text(best and { s = best, f = midi - open[best] }, tun, names)
end
-- The text of a place { s = the string (1 = the lowest), f = the fret }: " (A 3)" ("" for none).
function Key.place_text(pl, tun, names)
  return pl and string.format(" (%s %d)", (names or Key.string_names(tun))[pl.s], pl.f) or ""
end

-- The comfortable fingering of a row of notes (MIDI numbers): { { s, f } or false (not on the neck) } with the fewest
-- hand moves (dynamic programming over the places and the hand position; a hand covers 4 frets). The costs: CFG.FINGER.
-- forced: { [i] = a string that the user chose for note i } (optional).
function Key.finger(midis, tun, forced)
  forced = forced or {}
  local W, open, out = CFG.FINGER, tun.open, {}
  local prev, first = nil, 1
  local function finish(last) -- the best way back through the notes first..last
    local e
    for _, a in ipairs(prev or {}) do if not e or a.cost < e.cost then e = a end end
    for i = last, first, -1 do
      out[i] = e and { s = e.s, f = e.f } or false
      e = e and e.back
    end
  end
  for i, m in ipairs(midis) do
    local col = {}
    for s = 1, #open do
      local f = m - open[s]
      if f >= 0 and f <= CFG.FRETS and (not forced[i] or forced[i] == s) then
        local hands = {}
        if f == 0 then -- (an open string: the hand stays where it is)
          local seen = {}
          for _, a in ipairs(prev or { { h = 1 } }) do
            if not seen[a.h] then seen[a.h] = true; hands[#hands + 1] = a.h end
          end
        else
          for h = math.max(1, f - 3), f do hands[#hands + 1] = h end
        end
        for _, h in ipairs(hands) do
          local c = W.high * math.max(0, f - 5) + (f == 0 and W.open or 0) + ((f > 0 and h < 5 and f - h == 3) and W.stretch or 0)
          local st = { s = s, f = f, h = h, cost = c }
          if prev then
            local bv, bj = math.huge, nil
            for _, a in ipairs(prev) do
              local v = a.cost + W.move * math.abs(a.h - h) + (a.h ~= h and W.shift or 0) + W.str * math.abs(a.s - s)
              if midis[i - 1] == m and a.s ~= s then v = v + W.same end
              if v < bv then bv, bj = v, a end
            end
            st.cost, st.back = c + bv, bj
          end
          col[#col + 1] = st
        end
      end
    end
    if #col == 0 then -- (not on the neck: the fingering starts again after it)
      if prev then finish(i - 1) end
      out[i], prev, first = false, nil, i + 1
    else
      prev = col
    end
  end
  if prev then finish(#midis) end
  return out
end

---------------------------------------------------------------------------
-- DET (the notes of a bass signal)
---------------------------------------------------------------------------
-- YIN: the period of the signal at sample s. Returns the pitch (MIDI number, with a fraction) and how unsure it is.
function Det.yin(x, s, d)
  local W, L0, L1 = CFG.YIN_W, CFG.LAG0, CFG.LAG1
  local run, best, bv = 0, nil, 1e9
  for lag = 1, L1 do
    local sum = 0
    for i = s, s + W - 1 do
      local v = x[i] - x[i + lag]
      sum = sum + v * v
    end
    run = run + sum
    d[lag] = run > 0 and sum * lag / run or 1
  end
  for lag = L0, L1 - 1 do
    if d[lag] < CFG.YIN_THR and d[lag] <= d[lag + 1] then best = lag; break end
    if d[lag] < bv then bv = d[lag] end
  end
  if not best then
    for lag = L0, L1 - 1 do if d[lag] == bv then best = lag; break end end
  end
  if not best then return nil end
  local a, b, c = d[best - 1], d[best], d[best + 1]
  local den = a - 2 * b + c
  local p = best + (den ~= 0 and Util.clamp(0.5 * (a - c) / den, -0.5, 0.5) or 0)
  return 69 + 12 * math.log(CFG.SR / p / 440, 2), b
end

-- The 2nd method: of the notes C1 to B2, the one with the strongest harmonics (samples s0 to s1). Its pitch class.
function Det.harm_pc(x, s0, s1, tune)
  s0, s1 = math.max(1, s0), math.min(#x, s1)
  local n = s1 - s0 + 1
  if n < 200 then return nil end
  local buf, mag = {}, {}
  for k = 1, n do buf[k] = x[s0 + k - 1] * (0.5 - 0.5 * math.cos(2 * math.pi * (k - 0.5) / n)) end
  for m = CFG.HARM_LO, CFG.HARM_HI + CFG.HARM[#CFG.HARM][1] do
    local co = 2 * math.cos(2 * math.pi * 440 * 2 ^ ((m + tune - 69) / 12) / CFG.SR)
    local q1, q2 = 0, 0
    for k = 1, n do q1, q2 = buf[k] + co * q1 - q2, q1 end
    mag[m] = math.sqrt(math.max(0, q1 * q1 + q2 * q2 - co * q1 * q2))
  end
  local best, bv = nil, 0
  for m = CFG.HARM_LO, CFG.HARM_HI do
    local v = 0
    for _, h in ipairs(CFG.HARM) do v = v + h[2] * (mag[m + h[1]] or 0) end
    if v > bv then best, bv = m, v end
  end
  return best and best % 12 or nil
end

-- The octave: how strong the odd harmonics (1, 3, 5) of the note low are against the even ones (2, 4, 6), in dB, for
-- len s from t (s from the start of x). Far below 0: the note sounds an octave higher (the trials: CFG.OCT_DB).
function Det.odd_even(x, t, len, low, tune)
  local f = 440 * 2 ^ ((low + tune - 69) / 12)
  local s0, n = math.floor(t * CFG.SR) + 1, math.floor(len * CFG.SR)
  local function pow(hz)
    local w = 2 * math.pi * hz / CFG.SR
    local c, s = 0, 0
    for k = 0, n - 1 do
      local v = (x[s0 + k] or 0) * (0.5 - 0.5 * math.cos(2 * math.pi * k / n))
      c, s = c + v * math.cos(w * k), s + v * math.sin(w * k)
    end
    return c * c + s * s
  end
  local o = pow(f) + pow(3 * f) + pow(5 * f)
  local e = pow(2 * f) + pow(4 * f) + pow(6 * f)
  return 10 * math.log((o + 1e-12) / (e + 1e-12), 10)
end

-- Slides: a note without its own attack that the pitch glides into (CFG.SLIDE_MIN semitones or more, at most
-- CFG.SLIDE_MAX s, steadily and without a jump) gets slide = true and starts where the glide starts; the short notes
-- of the glide go, and the note before it ends there. m, ap: the YIN pitch (MIDI) and how unsure it is, per frame.
function Det.slides(notes, m, ap, tune, t_of)
  local function frame(t) return math.floor((t * CFG.SR - CFG.YIN_W / 2) / CFG.HOP) + 1 end
  local function pitch(k) return m[k] and ap[k] < CFG.YIN_MAX and m[k] - tune or nil end
  local out = {}
  for _, n in ipairs(notes) do
    local kb = frame(n.t)
    local vals = {}
    for k = kb, kb + 4 do vals[#vals + 1] = pitch(k) end
    if not n.att and #vals >= 3 then
      table.sort(vals)
      local tp = vals[(#vals + 1) // 2] -- (the pitch of the note)
      local k, last, dir, moving, flat, steps = kb - 1, tp, nil, nil, 0, 0
      while k >= math.max(1, frame(n.t - CFG.SLIDE_MAX)) do -- (back from the note: the glide)
        local v = pitch(k)
        if not v or math.abs(v - last) > 1.2 then break end -- (no pitch, or a jump: another note)
        local d = v - last
        if math.abs(d) >= 0.08 then
          local s = d > 0 and 1 or -1
          if dir and s ~= dir then break end
          dir, moving, flat, steps = s, k, 0, steps + 1
        else
          flat = flat + 1
          if flat >= 3 and moving then break end -- (the pitch stays: the glide started here)
        end
        last, k = v, k - 1
      end
      if moving and steps >= CFG.SLIDE_STEPS and math.abs(pitch(moving) - tp) >= CFG.SLIDE_MIN then
        local ts = t_of(moving)
        while out[#out] and out[#out].t >= ts - 0.01 do table.remove(out) end
        if out[#out] and out[#out].t1 > ts then out[#out].t1 = ts end
        n.slide, n.tp, n.t = true, n.t, ts -- (tp: where its pitch is steady, for the checks)
      end
    end
    out[#out + 1] = n
  end
  return out
end

-- Repeated notes: a 16th note of the song inside a note (grid: their times, project time; pos: the start of x in the
-- project) where the level dips and rises again (1 period of the note per window; dip + CFG.REP_RISE x rise of
-- CFG.REP_DB or more) starts a new note of the same pitch (rep = true). Trial 6d: about half of the repeats of a song,
-- few wrong splits.
function Det.repeats(x, notes, grid, pos)
  local SR, out, g = CFG.SR, {}, 1
  local function lev(t, per)
    local s0 = math.floor((t - pos) * SR) + 1
    local a = 0
    for k = s0, s0 + per - 1 do a = a + (x[k] or 0) ^ 2 end
    return 10 * math.log(a / per + 1e-12, 10)
  end
  for _, n in ipairs(notes) do
    local per = math.max(8, math.floor(SR / (440 * 2 ^ ((n.midi - 69) / 12)) + 0.5))
    local cur, t1 = n, n.t1
    while grid[g] and grid[g] < n.t + CFG.REP_EDGE do g = g + 1 end
    local j = g
    while grid[j] and grid[j] <= t1 - CFG.REP_EDGE do
      local tg = grid[j]
      if tg - cur.t >= CFG.REP_EDGE then
        local lo, before, after = 1e9, -1e9, -1e9
        for d = -0.03, 0.0101, 0.005 do lo = math.min(lo, lev(tg + d, per)) end
        for d = -0.07, -0.0299, 0.005 do before = math.max(before, lev(tg + d, per)) end
        for d = 0.01, 0.0501, 0.005 do after = math.max(after, lev(tg + d, per)) end
        if math.min(before - lo, after - lo) + CFG.REP_RISE * (after - lo) >= CFG.REP_DB then
          local nxt = {}
          for k, v in pairs(cur) do nxt[k] = v end
          cur.t1, nxt.t, nxt.rep, nxt.slide = tg, tg, true, nil
          out[#out + 1] = cur
          cur = nxt
        end
      end
      j = j + 1
    end
    out[#out + 1] = cur
  end
  return out
end

-- Glitches (trial 7, Burning Roads: a low C held for 4 bars became C - G - C - C - G ...): the pitch of a very low note
-- jumps to its own overtone (a 5th up) for a moment. Such a short note (CFG.GLITCH s) between 2 parts of the same note,
-- without an attack (or the 2nd method hears the note around it), goes, and the 2 parts join (when the 2nd has no
-- attack). Tried and dropped (they removed real notes of the song): a fading note's overtone joins the note before it;
-- 2 parts of the same note with a short gap join.
function Det.glitches(notes, x, tune)
  local W, SR = CFG.YIN_W, CFG.SR
  -- the 2nd method (the overtone pattern) says that note n is really the note before it
  local function same_as(n, prev)
    return Det.harm_pc(x, math.floor((n.t - W / 2 / SR) * SR), math.floor(math.min(n.t1, n.t + 0.3) * SR), tune) == prev.pc
  end
  local out = {}
  local k = 1
  while k <= #notes do
    local n, prev, nxt = notes[k], out[#out], notes[k + 1]
    local gap_b = prev and n.t - prev.t1 or 1e9
    local fifth = prev and (n.pc - prev.pc) % 12 == 7 -- (the overtone of the note before, a 5th up)
    if fifth and n.t1 - n.t < CFG.GLITCH and gap_b < 0.06 and nxt and nxt.pc == prev.pc and nxt.t - n.t1 < 0.06
      and (not n.att or same_as(n, prev)) then
      if nxt.att then out[#out + 1] = nxt else prev.t1 = nxt.t1 end -- (the glitch goes; the 2 parts join)
      k = k + 2
    else
      out[#out + 1] = n
      k = k + 1
    end
  end
  return out
end

-- The onsets (the plucks; Dev 2 of the review of 23 November 2026) of the signal x (sr): the band flux. The level of
-- CFG.ON_BANDS narrow bands (from CFG.ON_F0 Hz, half an octave apart) in 5 ms frames; the onset curve = the mean rise of
-- the bands over CFG.ON_DIFF frames, relative to the loudest band of the moment (Dev 5). An onset: a peak (30 ms) of at least CFG.ON_K x the mean of 1 s around +
-- CFG.ON_D, at least CFG.ON_GAP after the one before. Returns the times (s). Trial 9 (song 2 against its tab): the
-- notes found 66.6% -> 82.3%, 87.0% with the 16th grid. Tried and dropped: a high band from a 16 kHz read (1 point more:
-- not worth a 2nd read); a stronger onset for the same note again (it lost 2 real repeats for each wrong one).
function Det.onsets_of(x, sr, tick)
  local hop = math.max(1, math.floor(sr * CFG.ON_STEP + 0.5))
  local dt, bands = hop / sr, {}
  for b = 1, CFG.ON_BANDS do
    local f = CFG.ON_F0 * 2 ^ ((b - 1) / 2)
    local w0 = 2 * math.pi * f / sr
    local al = math.sin(w0) / (2 * math.min(CFG.ON_Q, f / CFG.ON_BW)) -- (at least ON_BW Hz wide: a narrow low band rises late)
    local a0 = 1 + al
    -- the level: smoothed over at least CFG.ON_SMOOTH periods of the band (5 ms is shorter than 1 period of a low
    -- band: its level would ripple with the wave, and a held note would get an onset every few frames)
    local k = 1 - math.exp(-1 / (math.max(dt, CFG.ON_SMOOTH / f) * sr))
    bands[b] = { b0 = al / a0, b2 = -al / a0, a1 = -2 * math.cos(w0) / a0, a2 = (1 - al) / a0, x1 = 0, x2 = 0, y1 = 0,
      y2 = 0, e = 0, k = k, L = {} }
  end
  local n = 0
  for i = 1, #x do -- (bandpass filters, RBJ)
    local v = x[i]
    for _, bd in ipairs(bands) do
      local y = bd.b0 * v + bd.b2 * bd.x2 - bd.a1 * bd.y1 - bd.a2 * bd.y2
      bd.x2, bd.x1, bd.y2, bd.y1 = bd.x1, v, bd.y1, y
      bd.e = bd.e + bd.k * (y * y - bd.e)
    end
    n = n + 1
    if n == hop then
      for _, bd in ipairs(bands) do bd.L[#bd.L + 1] = 10 * math.log(bd.e + 1e-12, 10) end
      n = 0
    end
    if tick and i % 4000 == 0 then tick(i / #x) end -- (about 10 ms of work: the window stays smooth)
  end
  local nf, D = #bands[1].L, CFG.ON_DIFF
  -- the loud level of the whole signal (the loudest band of each frame, its 95th percentile): a pluck far below it is
  -- noise (the bleed of a separated stem before the bass starts; lessons 23 November 2026: Set tempo aligned it)
  local top, sorted = {}, {}
  for k = 1, nf do
    local v = -1e9
    for _, bd in ipairs(bands) do v = math.max(v, bd.L[k]) end
    top[k] = v
    if v > -100 then sorted[#sorted + 1] = v end
  end
  table.sort(sorted)
  local quiet = (sorted[math.max(1, math.floor(#sorted * 0.95))] or 0) - CFG.ON_GATE
  local of, pre = {}, { 0 }
  for k = 1, nf do
    -- the rise of each band that is within ON_FLOOR dB of the loudest band of this frame, from at most ON_FLOOR dB
    -- below it (Dev 5: only levels relative to this moment count, so a soft part is as clear as a loud one, and the
    -- noise of an empty band never counts)
    local s = 0
    if k > D then
      local floor = -1e9
      for _, bd in ipairs(bands) do floor = math.max(floor, bd.L[k]) end
      floor = floor - CFG.ON_FLOOR
      for _, bd in ipairs(bands) do
        if bd.L[k] > floor then s = s + bd.L[k] - math.max(floor, math.min(bd.L[k], bd.L[k - D])) end
      end
    end
    of[k] = s / #bands
    pre[k + 1] = pre[k] + of[k]
  end
  local around, near = math.floor(1 / dt + 0.5), math.max(1, math.floor(0.03 / dt + 0.5))
  local out, last = {}, -1
  for k = D + 1, nf do
    local v = of[k]
    local a, b = math.max(1, k - around), math.min(nf, k + around)
    local lim = CFG.ON_K * (pre[b + 1] - pre[a]) / (b - a + 1) + CFG.ON_D
    if v >= lim and math.max(top[k], top[math.min(nf, k + 2 * D)]) > quiet then -- (a soft note is still rising at k)
      local peak = true
      for j = math.max(1, k - near), math.min(nf, k + near) do
        if of[j] > v or (j < k and of[j] == v) then peak = false; break end
      end
      local t = (k - D) * dt -- (the start of the rise)
      if peak and t - last >= CFG.ON_GAP then out[#out + 1], last = t, t end
    end
  end
  return out
end

-- The notes of the signal x (mono, CFG.SR): a list of { pc, midi, t, t1, doubt, slide } (seconds from the start of x) and the
-- tuning (semitones). lowest: the lowest open string (MIDI; the octave of each note starts there). tick(done 0-1) is
-- called often (it can yield).
function Det.analyse(x, tick, lowest, on)
  lowest = lowest or CFG.TUNINGS[1].open[1]
  local W, HOP, SR = CFG.YIN_W, CFG.HOP, CFG.SR
  local last = #x - W - CFG.LAG1 - 1
  local db, sorted = {}, {}
  for s = 1, last, HOP do
    local e = 0
    for i = s, s + W - 1 do e = e + x[i] * x[i] end
    local v = e > 0 and 10 * math.log(e / W, 10) or -150
    db[#db + 1] = v
    if v > -70 then sorted[#sorted + 1] = v end
  end
  tick(0.02)
  if #sorted == 0 then return {}, 0 end
  table.sort(sorted)
  local loud = sorted[math.max(1, math.floor(#sorted * 0.95))]
  -- the pitch of each frame (only above the gate of the whole item: a gate that followed the last seconds (Dev 5)
  -- found notes in the bleed before the bass; lessons 23 November 2026)
  local gate = math.max(-70, loud - CFG.GATE_DB)
  local m, ap, d = {}, {}, {}
  for k = 1, #db do
    if db[k] > gate then m[k], ap[k] = Det.yin(x, (k - 1) * HOP + 1, d) end
    if k % 20 == 0 then tick(0.02 + 0.93 * k / #db) end
  end
  -- the tuning: the mean distance from the semitone (circular)
  local cs, sn = 0, 0
  for k = 1, #db do
    if m[k] and ap[k] < 0.1 and db[k] > loud - CFG.ATTACK_GATE_DB then
      local a = 2 * math.pi * (m[k] - math.floor(m[k] + 0.5))
      cs, sn = cs + math.cos(a), sn + math.sin(a)
    end
  end
  local tune = (cs ~= 0 or sn ~= 0) and math.atan(sn, cs) / (2 * math.pi) or 0
  local pc = {}
  for k = 1, #db do pc[k] = m[k] and ap[k] < CFG.YIN_MAX and math.floor(m[k] - tune + 0.5) % 12 or false end
  -- smooth: the most common pitch class of 7 frames (70 ms)
  local sm = {}
  for k = 1, #db do
    local cnt, bp, bn = {}, nil, 0
    for j = math.max(1, k - 3), math.min(#db, k + 3) do
      local p = pc[j]
      if p then
        cnt[p] = (cnt[p] or 0) + 1
        if cnt[p] > bn then bp, bn = p, cnt[p] end
      end
    end
    sm[k] = bn >= 4 and bp or false
  end
  -- the notes (Dev 1 and 3 of the review of 23 November 2026): the onsets (Det.onsets_of) start them; a pitch change or
  -- a start after silence without an onset near it starts one too (a slide, a hammer-on, a soft note). Each note gets
  -- 1 pitch: the most common one of its frames after the noise of the attack. (Before: a run of 1 pitch, and a level
  -- rise at least 0.12 s after its start: fast repeats could never start a new note.)
  local function t_of(k) return ((k - 1) * HOP + W / 2) / SR end
  on = on or Det.onsets_of(x, SR, function() tick(0.95) end)
  local starts = {}
  for _, t in ipairs(on) do starts[#starts + 1] = { t = t, att = true } end
  local oi = 1
  for k = 1, #db do
    if sm[k] and sm[k] ~= (sm[k - 1] or false) then
      local t = t_of(k) - CFG.START_COMP
      while on[oi] and on[oi] < t - CFG.ON_BEFORE do oi = oi + 1 end
      if not (on[oi] and on[oi] <= t + CFG.ON_AFTER) then starts[#starts + 1] = { t = t, att = false } end
    end
  end
  table.sort(starts, function(a, b) return a.t < b.t end)
  local function most(votes)
    local best, bn = nil, 0
    for p, c in pairs(votes) do if c > bn or (c == bn and p < best) then best, bn = p, c end end
    return best, bn
  end
  local notes, k, held = {}, 1, nil
  for i, st in ipairs(starts) do
    local t_next = starts[i + 1] and starts[i + 1].t or math.huge
    while k <= #db and t_of(k) < st.t do k = k + 1 end
    local votes, all, first, ends, gone, k0 = {}, {}, nil, {}, {}, k
    local skip = math.min(CFG.ON_SKIP, (t_next - st.t) / 3)
    while k <= #db and t_of(k) < t_next do
      -- the end of each pitch: its last frame before a gap of CFG.END_GAP s (a note ends at its own end: not where the
      -- next note is already heard, not after a silence)
      local p = pc[k] or sm[k]
      if p and not gone[p] then
        if ends[p] and t_of(k) - t_of(ends[p]) > CFG.END_GAP then gone[p] = true else ends[p] = k end
      end
      if pc[k] then
        all[pc[k]] = (all[pc[k]] or 0) + 1
        if t_of(k) >= st.t + skip then votes[pc[k]] = (votes[pc[k]] or 0) + 1; first = first or k end
      end
      k = k + 1
    end
    local best, bn = most(votes)
    local prev = notes[#notes]
    local fin = best and ends[best]
    if best and bn >= 3 and t_of(fin) - st.t >= CFG.NOTE_MIN then
      -- a short piece just before with this pitch (or none): the early start of this note (a false onset after it)
      if held and st.t - held.st.t < CFG.ON_HOLD and (held.pc == nil or held.pc == best) then st = held.st end
      local n = { pc = best, t = st.t + (st.att and 0 or CFG.START_COMP), t1 = t_of(fin), att = st.att,
        ap = 0, n = 0, db = -150, mv = {} } -- (att: it starts at its onset, no START_COMP at the end)
      for j = k0, fin do
        if pc[j] then
          n.ap, n.n, n.db = n.ap + (ap[j] or 0.5), n.n + 1, math.max(n.db, db[j])
          if pc[j] == best and j >= first then -- (the octave of YIN: the votes of the frames)
            local v = math.floor(m[j] - tune + 0.5)
            n.mv[v] = (n.mv[v] or 0) + 1
          end
        end
      end
      notes[#notes + 1] = n
      held = nil
    else
      -- too short for a note: the tail of the note before (its pitch), else maybe the start of the next one
      local pp = most(all)
      if pp and prev and pp == prev.pc and st.t - prev.t1 < CFG.ON_HOLD then prev.t1 = t_of(ends[pp]); held = nil
      else held = { st = st, pc = pp } end
    end
  end
  if CFG.GLITCH > 0 then notes = Det.glitches(notes, x, tune) end
  notes = Det.slides(notes, m, ap, tune, t_of)
  -- the doubtful ones (n.why, UX 1): the 2 methods disagree, an unsure pitch, or a fading note that turns into its own
  -- overtone (a 5th higher, without an attack)
  local vals = {}
  for i, n in ipairs(notes) do
    local tp = n.tp or n.t -- (a slide: from where its pitch is steady)
    local s0 = math.floor((tp - W / 2 / SR) * SR)
    local s1 = math.floor(math.min(n.t1 + W / 2 / SR, tp + 0.2) * SR)
    local h = Det.harm_pc(x, s0, s1, tune)
    local before = notes[i - 1]
    local ring = before and not n.att and not n.slide and (n.pc - before.pc) % 12 == 7 and n.t - before.t1 < 0.3
      and n.db < before.db
    n.why = (h ~= nil and h ~= n.pc) and "methods" or n.ap / n.n > 0.15 and "unsure" or ring and "overtone" or nil
    -- the octave: YIN's votes and the odd / even harmonics of the low octave (from the start of the note, 0.15 s: the
    -- best window on the real songs of the trials)
    local my, mn = nil, 0
    n.low = Key.low(n.pc, lowest)
    for v, c in pairs(n.mv) do if c > mn or (c == mn and v < my) then my, mn = v, c end end
    n.my = my and math.max(n.low, my)
    local len = math.min(0.15, n.t1 - tp)
    if not (n.my and n.my >= n.low + 24) and len >= 0.08 then
      n.oe = Det.odd_even(x, tp, len, n.low, tune)
      vals[#vals + 1] = n.oe
    end
    if i % 10 == 0 then tick(0.95 + 0.05 * i / #notes) end
  end
  -- the octave limit of this song (Dev 4), then for each note: when YIN and the harmonics disagree, the harmonics win
  -- (right more often on the notes that the user marked by hand) and the note is doubtful
  local lim = Det.octave_limit(vals)
  for _, n in ipairs(notes) do
    if n.my and n.my >= n.low + 24 then n.midi = n.my -- (very high: the harmonics of the low octave tell nothing)
    elseif n.oe then
      n.midi = n.oe < lim and n.low + 12 or n.low
      if n.my and n.my ~= n.midi and math.abs(n.oe - lim) < CFG.OCT_SURE then n.why = n.why or "octave" end
    else
      n.midi = n.my and n.my >= n.low + 12 and n.low + 12 or n.low
    end
  end
  local out = {}
  for i, n in ipairs(notes) do
    out[i] = { pc = n.pc, midi = n.midi, t = math.max(0, n.t - ((n.slide or n.att) and 0 or CFG.START_COMP)), t1 = n.t1,
      doubt = n.why ~= nil, why = n.why, slide = n.slide }
  end
  return out, tune
end

-- The octave limit of a song (Dev 4 of the review of 23 November 2026): the odd / even values of its notes (Det.odd_even)
-- form 2 groups (the low and the high octave); the limit goes in the emptiest place between them (the fewest values
-- within CFG.OCT_VALLEY dB), between CFG.OCT_FIT_LO and CFG.OCT_FIT_HI. Few notes or no clear gap: CFG.OCT_DB. Trial
-- 9e (song 2, 660 notes): the gap at -12 dB, 659 right against 644 with -6 dB (the middle of the 2 groups: 652).
function Det.octave_limit(vals)
  if #vals < CFG.OCT_FIT_MIN then return CFG.OCT_DB end
  local best, bn = CFG.OCT_DB, math.huge
  for lim = CFG.OCT_FIT_LO, CFG.OCT_FIT_HI, 0.5 do
    local n = 0
    for _, v in ipairs(vals) do if math.abs(v - lim) < CFG.OCT_VALLEY then n = n + 1 end end
    if n < bn or (n == bn and math.abs(lim - CFG.OCT_DB) < math.abs(best - CFG.OCT_DB)) then best, bn = lim, n end
  end
  return bn <= #vals * CFG.OCT_GAP and best or CFG.OCT_DB
end

---------------------------------------------------------------------------
-- GROUP (the notes become the rows of the list)
---------------------------------------------------------------------------
-- The bars of a project between 2 times: { t0, t1, tol }. tol: a note that starts this much before the bar line
-- belongs to the next bar (Group.slice).
function Group.project_bars(proj, t0, t1)
  local bars = {}
  local _, m = r.TimeMap2_timeToBeats(proj, t0)
  while #bars < 5000 do
    local a, b = r.TimeMap2_beatsToTime(proj, 0, m), r.TimeMap2_beatsToTime(proj, 0, m + 1)
    if a >= t1 or b <= a then break end
    bars[#bars + 1] = { t0 = a, t1 = b, tol = CFG.BAR_TOL }
    m = m + 1
  end
  return bars
end
-- The bar and beat of a time ("7.1"); a 32nd before a beat counts as that beat.
function Group.bar_text(proj, t)
  local q = r.TimeMap2_timeToQN(proj, t) + 0.125
  local beat, m = r.TimeMap2_timeToBeats(proj, r.TimeMap2_QNToTime(proj, q))
  return string.format("%d.%d", m + 1, math.floor(beat + 0.001) + 1)
end
-- "Every note change": each new note has its own bar (octave: also the same name in another octave). A long silence
-- also starts a new one.
function Group.change_bars(notes, octave)
  local bars = {}
  for i, n in ipairs(notes) do
    local b, p = bars[#bars], notes[i - 1]
    if not b or p.pc ~= n.pc or (octave and p.midi ~= n.midi) or n.t - p.t1 > CFG.SEC_LEN then
      if b then b.t1 = n.t end
      bars[#bars + 1] = { t0 = n.t, t1 = math.huge, tol = 0.01 }
    end
  end
  return bars
end

-- The same note played again right away is 1 span { pc, midi, t, t1, bad, len, slide, n, tl } (bad: the seconds of
-- doubtful notes; n: its notes, tl: the start of the last one). octave: the same pitch class in another octave is
-- another note. A slide into the same note starts a new span.
function Group.spans(notes, octave)
  local spans = {}
  for ni, n in ipairs(notes) do
    local s, len = spans[#spans], n.t1 - n.t
    if s and s.pc == n.pc and (not octave or s.midi == n.midi) and n.t - s.t1 < CFG.SPAN_GAP and not n.slide then
      s.t1, s.len, s.bad, s.n, s.tl = n.t1, s.len + len, s.bad + (n.doubt and len or 0), s.n + 1, n.t
    else
      spans[#spans + 1] = { pc = n.pc, midi = n.midi, t = n.t, t1 = n.t1, len = len, bad = n.doubt and len or 0,
        slide = n.slide, n = 1, tl = n.t, ni = ni }
    end
  end
  return spans
end

-- The notes inside each bar: { { pc, midi, t, doubt }, ... } (the same note again is 1 part). Strict bars (decided
-- 25 November 2026): a note belongs to the bar where it starts; a start up to b.tol before a bar line counts as the
-- "1" of the next bar (the detection finds starts a few ms early or late). A note of an earlier bar that still rings
-- CFG.HELD_MIN into this bar is its first note, a plain name like the others (no brackets, decided 25 November 2026:
-- repeated 8ths that the detection hears as 1 long note are played again there).
function Group.slice(notes, bars, octave)
  local spans, out, first = Group.spans(notes, octave), {}, 1
  for i, b in ipairs(bars) do
    local parts = {}
    local tol = b.tol or 0.01
    local a0, a1 = b.t0 - tol, b.t1 - tol -- (the starts that belong to this bar)
    local carried = false -- (parts[1] rings on from an earlier bar)
    while spans[first] and spans[first].t1 < b.t0 do first = first + 1 end
    for k = first, #spans do
      local n = spans[k]
      if n.t >= a1 then break end
      if n.t >= a0 then
        local p = parts[#parts]
        if not p or p.pc ~= n.pc or (octave and p.midi ~= n.midi) or n.slide then
          p = { pc = n.pc, midi = n.midi, t = n.t, bad = 0, len = 0, slide = n.slide, n = 0, tf = n.t, ni = n.ni }
          parts[#parts + 1] = p
        end
        p.len, p.bad, p.n, p.tl = p.len + n.len, p.bad + n.bad, p.n + n.n, n.tl
        carried = false
      elseif n.t1 - b.t0 >= CFG.HELD_MIN and (not parts[1] or carried) then -- (the latest one that rings on)
        parts[1] = { pc = n.pc, midi = n.midi, t = b.t0, bad = n.bad > 0.5 * n.len and 1 or 0, len = 1, n = 0,
          tf = n.t, ni = n.ni }
        carried = true
      end
    end
    for _, p in ipairs(parts) do p.doubt = p.bad > 0.5 * p.len end
    out[i] = parts
  end
  return out
end

-- The bars that start a section: a block of CFG.SECTION_BARS bars or more (with 3 or more different bars) that was
-- played before from a marker, while the bars before the 2 blocks differ.
function Group.sections(keys)
  local start, n, L = {}, #keys, CFG.SECTION_BARS
  local fresh = {} -- (the bars with a marker of their own)
  for i = 1, n do fresh[i] = keys[i] ~= "" and keys[i] ~= keys[i - 1] end
  for i = 2, n - L + 1 do
    if keys[i] ~= "" and not fresh[i] then
      for j = 1, i - 1 do
        if fresh[j] and keys[j] == keys[i] and keys[j - 1] ~= keys[i - 1] then
          local k, kinds, seen = 0, 0, {}
          while k < L and keys[i + k] == keys[j + k] do
            if not seen[keys[i + k]] then seen[keys[i + k]] = true; kinds = kinds + 1 end
            k = k + 1
          end
          if k == L and kinds >= 3 then start[i] = true; break end
        end
      end
    end
  end
  return start
end

-- The rows: 1 per bar; a bar with the same notes as the bar before it has none, except at the start of a section.
-- opt: nil (only the names) or { tun = the tuning, names = the string names, high = the string and fret of the high
-- notes, runs = the fingering of every note in a row of CFG.RUN_MIN notes or more }. A slide into a note: no mark
-- (decided 25 November 2026), but a slide into the same note is still a note of its own.
function Group.rows(notes, bars, key, opt)
  local tp = opt and opt.tp or 0 -- (Transpose of the toolbar: the names tp half steps higher, in the transposed key)
  local slices, names = Group.slice(notes, bars, opt ~= nil and (opt.high or opt.runs)), Key.names(Key.shift(key, tp))
  -- the places: the fingering of the notes (the same as the tab; a string that the user chose in the tab stays;
  -- transposed: only the place of each high note)
  local places = tp == 0 and opt and (opt.high or opt.runs) and List.places(notes, opt.tun)
  local keys = {}
  for i, parts in ipairs(slices) do
    local t = {}
    local run = places and opt.runs and #parts >= CFG.RUN_MIN
    for k, p in ipairs(parts) do
      local pl = places and places[p.ni]
      local extra = ""
      if run then extra = Key.place_text(pl, opt.tun, opt.names)
      elseif opt and opt.high and p.midi and p.midi + tp >= opt.tun.open[1] + 12 then -- (a high note)
        extra = pl and Key.place_text(pl, opt.tun, opt.names) or Key.place(p.midi + tp, opt.tun, opt.names)
      end
      t[k] = names[(p.pc + tp) % 12] .. extra
    end
    keys[i] = table.concat(t, " - ")
  end
  local start, rows = Group.sections(keys), {}
  for i, parts in ipairs(slices) do
    if #parts > 0 and (keys[i] ~= keys[i - 1] or start[i]) then
      local row = { t = parts[1].t, text = keys[i], doubt = false, ts = {} }
      for k, p in ipairs(parts) do
        row.ts[k] = p.t
        if p.doubt then row.doubt = true end
      end
      rows[#rows + 1] = row
    end
  end
  table.sort(rows, function(a, b) return a.t < b.t end)
  return rows
end

function Group.make(notes, mode, key, proj, t_end, opt)
  if #notes == 0 then return {} end
  local bars
  if mode == "change" then bars = Group.change_bars(notes, opt ~= nil and (opt.high or opt.runs))
  else bars = Group.project_bars(proj, notes[1].t, t_end) end
  return Group.rows(notes, bars, key, opt)
end

---------------------------------------------------------------------------
-- LIST (the rows and their corrections; the project data P)
---------------------------------------------------------------------------
-- P: { key = "C minor" ("" = unknown), mode = "bar" | "change", tuning = an id of CFG.TUNINGS,
--   src = the GUID of the bass item, rows = { { t, text, doubt, ts = { the time of each note } or nil }, ... },
--   keys = { { t, key } } (a key change from that line on), mk = { the GUIDs of the written markers (also of older
--   writes: Ctrl+Z brings them back) }, notes = { the found notes { t, t1, pc, midi, doubt } (to group them again,
--   the export and the tab) }, t_end = the end of the bass item of the last Find notes, tab = the tab of the found
--   notes in Tab Viewer (an entry as Tab Viewer's tabs: your fixes, line breaks, start bar; "tab." lines) or nil }
function List.default()
  return { key = "", mode = "bar", tuning = "std", src = "", rows = {}, keys = {}, mk = {}, notes = {} }
end
-- The fingering of the saved notes (1 for the list and the tab; the strings that the user chose stay): a place
-- { s, f } or false per note (cached until the notes or the tuning change).
function List.places(notes, tun)
  notes, tun = notes or P.notes, tun or Key.tuning(P.tuning)
  local c = R.places
  if c and c.src == notes and c.tun == tun and c.n == #notes then return c.list end
  local midis, forced = {}, {}
  for k, n in ipairs(notes) do midis[k], forced[k] = n.midi or Key.low(n.pc, tun.open[1]), n.s end
  local list = Key.finger(midis, tun, forced)
  R.places = { src = notes, tun = tun, n = #notes, list = list }
  return list
end
-- Settings > Detection as they apply (the texts of Group.rows, the split repeated notes). 1 mode (decided
-- 25 November 2026: no Simple mode, no beat count, no slide mark).
function List.opt(tp)
  local tun = Key.tuning(P.tuning)
  local names = Key.string_names(tun, S.strings == "numbers")
  return { tun = tun, names = names, high = S.frets, runs = S.finger, splits = S.splits, tp = tp or host.transpose() }
end

function List.parse(txt)
  local p = List.default()
  for line in (txt .. "\n"):gmatch("([^\n]*)\n") do
    local k, v = line:match("^([%w_]+)=(.*)$")
    local tk, tv = line:match("^tab%.(%w+)=(.*)$") -- (the tab of the found notes: your fixes, lines, start bar)
    if tk then
      p.tab = p.tab or {}
      host.entry_line(p.tab, tk, tv)
    elseif k == "key" then p.key = v
    elseif k == "mode" then p.mode = v == "change" and v or "bar"
    elseif k == "tuning" then p.tuning = Key.tuning(v).id
    elseif k == "src" then p.src = v
    elseif k == "mk" then p.mk[#p.mk + 1] = v
    elseif k == "tend" then p.t_end = tonumber(v)
    elseif k == "note" then
      local t, t1, pc, midi, doubt, slide, s, man =
        v:match("^([%d%.%-]+)\t([%d%.%-]+)\t(%d+)\t(%d+)\t([01])\t?([01]?)\t?(%d*)\t?([01]?)$")
      if t then
        p.notes[#p.notes + 1] = { t = tonumber(t), t1 = tonumber(t1), pc = tonumber(pc) % 12, midi = tonumber(midi),
          doubt = doubt == "1", slide = slide == "1" or nil, s = (tonumber(s) or 0) > 0 and tonumber(s) or nil,
          man = man == "1" or nil }
      end
    elseif k == "keyat" then
      local t, key = v:match("^([%d%.%-]+)\t(.+)$")
      if t and tonumber(t) then p.keys[#p.keys + 1] = { t = tonumber(t), key = key } end
    elseif k == "row" then
      local t, doubt, ts, text = v:match("^([%d%.%-]+)\t([01])\t([^\t]*)\t(.+)$")
      if t and tonumber(t) then
        local row = { t = tonumber(t), text = text, doubt = doubt == "1" }
        if ts ~= "" then
          row.ts = {}
          for n in ts:gmatch("[%d%.%-]+") do row.ts[#row.ts + 1] = tonumber(n) end
        end
        p.rows[#p.rows + 1] = row
      end
    end
  end
  table.sort(p.rows, function(a, b) return a.t < b.t end)
  table.sort(p.keys, function(a, b) return a.t < b.t end)
  return p
end

function List.serialize(p)
  local t = {}
  if p.key ~= "" then t[#t + 1] = "key=" .. p.key end
  if p.mode ~= "bar" then t[#t + 1] = "mode=" .. p.mode end
  if p.tuning ~= "std" then t[#t + 1] = "tuning=" .. p.tuning end
  if p.src ~= "" then t[#t + 1] = "src=" .. p.src end
  for _, row in ipairs(p.rows) do
    local ts = {}
    for i, v in ipairs(row.ts or {}) do ts[i] = string.format("%.3f", v) end
    t[#t + 1] = string.format("row=%.4f\t%s\t%s\t%s", row.t, row.doubt and "1" or "0", table.concat(ts, ","), Util.clean(row.text))
  end
  for _, c in ipairs(p.keys) do t[#t + 1] = string.format("keyat=%.4f\t%s", c.t, c.key) end
  if p.t_end then t[#t + 1] = string.format("tend=%.4f", p.t_end) end
  for _, n in ipairs(p.notes) do
    t[#t + 1] = string.format("note=%.4f\t%.4f\t%d\t%d\t%s\t%s\t%d\t%s", n.t, n.t1, n.pc, n.midi or Key.low(n.pc, 28),
      n.doubt and "1" or "0", n.slide and "1" or "0", n.s or 0, n.man and "1" or "0")
  end
  for _, g in ipairs(p.mk) do t[#t + 1] = "mk=" .. g end
  if p.tab then
    for line in host.entry_text(p.tab):gmatch("[^\n]+") do t[#t + 1] = "tab." .. line end
  end
  return table.concat(t, "\n")
end

-- Before each change of the list: a step for the Undo button.
-- The list moves with the audio by d s (Tempo.align): its lines, notes, key changes and end (Undo of the list: back).
function List.shift(d)
  List.step()
  List.move_all(P, d)
  Util.mark_pdirty()
end
function List.move_all(p, d)
  for _, row in ipairs(p.rows) do
    row.t = row.t + d
    for k, t in ipairs(row.ts or {}) do row.ts[k] = t + d end
  end
  for _, n in ipairs(p.notes) do n.t, n.t1 = n.t + d, n.t1 + d end
  for _, c in ipairs(p.keys) do c.t = c.t + d end
  if p.t_end then p.t_end = p.t_end + d end
end
-- 1 Undo step (the Undo button and Ctrl+Z in the tab: 1 undo for both, decided 24 November 2026). An entry is the
-- list before a change (text), or { reaper = the REAPER undo name of a Write, Clear or Export, list = the list
-- before it (Clear) or nil }: its undo is REAPER's undo too, when that step is still REAPER's last one.
function List.step(reaper, keep_list)
  local txt = List.serialize(P)
  R.undo[#R.undo + 1] = reaper and { reaper = reaper, list = not keep_list and txt or nil } or txt
  if #R.undo > CFG.UNDO_MAX then table.remove(R.undo, 1) end
  R.redo = {}
end
-- Undo (redo false) or Redo (redo true; the toolbar arrow, Ctrl+Shift+Z): the step goes to the other list, with the
-- list as it is now (a REAPER step: REAPER's Undo / Redo too, when that step is REAPER's next one).
function List.undo(redo)
  local from, to = redo and R.redo or R.undo, redo and R.undo or R.redo
  local e = table.remove(from)
  if not e then return end
  R.written_lbl = nil
  local now = List.serialize(P)
  local txt = e
  if type(e) == "table" then
    local next_step = redo and r.Undo_CanRedo2(R.proj) or not redo and r.Undo_CanUndo2(R.proj)
    if next_step == e.reaper then r.Main_OnCommand(redo and 40030 or 40029, 0) -- Edit: Redo / Undo
    else -- (REAPER has newer steps, or it was done in REAPER already: say so, nothing seems to happen)
      UI.notice((redo and "Redo can not do \"%s\" again" or "Undo can not take back \"%s\""):format(e.reaper:match(": (.+)$") or e.reaper)
        .. " here: REAPER has other steps since then (or you did it there already). Use Edit > Undo History in REAPER.", true)
    end
    to[#to + 1] = { reaper = e.reaper, list = e.list and now or nil }
    txt = e.list
    if not txt then return end
  else
    to[#to + 1] = now
  end
  local mk = P.mk
  P = List.parse(txt)
  if #mk > 0 then P.mk = mk end -- (the newest IDs of the written markers; none after Done: clean up)
  R.edit = nil
  if R.sel and not P.rows[R.sel] then R.sel = #P.rows > 0 and #P.rows or nil end
  Util.mark_pdirty()
end

function List.doubtful()
  local n = 0
  for _, row in ipairs(P.rows) do if row.doubt then n = n + 1 end end
  return n
end
-- Why row i is doubtful (UX 1 of the review of 23 November 2026): the reasons of its doubtful notes (Det.analyse's
-- why; not saved: after a reopen only "listen to it"). Kept in the row until the rows are made again.
local WHY_TEXT = { octave = "the octave is unsure (high or low?)", methods = "the 2 methods hear different notes",
  unsure = "the pitch is unclear (noise, or a muted note?)", overtone = "maybe only the overtone of the note before (a 5th up)" }
function List.why(i)
  local row = P.rows[i]
  if not (row and row.doubt) then return nil end
  if not row.why_txt then
    local t0, t1 = row.t - 0.05, P.rows[i + 1] and P.rows[i + 1].t or math.huge
    local seen, parts = {}, {}
    for _, n in ipairs(P.notes) do
      if n.t >= t0 and n.t < t1 and n.why and not seen[n.why] then seen[n.why] = true; parts[#parts + 1] = WHY_TEXT[n.why] end
    end
    row.why_txt = "Not sure: " .. (#parts > 0 and table.concat(parts, "; ") or "listen to it") .. "."
  end
  return row.why_txt
end
-- The next doubtful row after i (it starts again at the top); nil without one.
function List.next_doubtful(i)
  local n = #P.rows
  for k = 1, n do
    local j = ((i or 0) + k - 1) % n + 1
    if P.rows[j].doubt then return j end
  end
end
-- The row that plays at a time (nil before the first one).
function List.at(t)
  local lo, hi, best = 1, #P.rows, nil
  while lo <= hi do
    local mid = (lo + hi) // 2
    if P.rows[mid].t <= t + 0.001 then best, lo = mid, mid + 1 else hi = mid - 1 end
  end
  return best
end

-- The other rows with the same notes as text.
function List.same(text, except)
  local out = {}
  for i, row in ipairs(P.rows) do if i ~= except and row.text == text then out[#out + 1] = i end end
  return out
end

-- Types the notes of a row. An empty text keeps the old one. Returns the old text when it changed.
function List.set_text(i, txt)
  local row = P.rows[i]
  txt = Util.clean(txt)
  if not row or txt == "" then return nil end
  if txt == row.text then
    if row.doubt then List.step(); row.doubt = false; Util.mark_pdirty() end -- (looked at: no longer doubtful)
    return nil
  end
  List.step()
  local old = row.text
  row.text, row.doubt, row.ts = txt, false, nil
  Util.mark_pdirty()
  return old
end
-- The same correction in other rows (1 Undo step with the first one).
function List.set_all(list, txt)
  for _, i in ipairs(list) do
    local row = P.rows[i]
    if row then row.text, row.doubt, row.ts = txt, false, nil end
  end
  Util.mark_pdirty()
end
function List.checked(i)
  if not P.rows[i] or not P.rows[i].doubt then return end
  List.step()
  P.rows[i].doubt = false
  Util.mark_pdirty()
end

function List.split_text(text)
  local t = {}
  for part in (text .. " - "):gmatch("(.-) %- ") do t[#t + 1] = part end
  return t
end
-- Joins a row with the next one.
function List.join(i)
  local a, b = P.rows[i], P.rows[i + 1]
  if not (a and b) then return end
  List.step()
  local pa, pb = List.split_text(a.text), List.split_text(b.text)
  local ts = a.ts and b.ts and #a.ts == #pa and #b.ts == #pb and {} or nil
  if ts then
    for _, v in ipairs(a.ts) do ts[#ts + 1] = v end
    for k, v in ipairs(b.ts) do if not (k == 1 and pb[1] == pa[#pa]) then ts[#ts + 1] = v end end
  end
  if pb[1] == pa[#pa] then table.remove(pb, 1) end -- (the same note goes on)
  for _, v in ipairs(pb) do pa[#pa + 1] = v end
  a.text, a.ts, a.doubt = table.concat(pa, " - "), ts, a.doubt or b.doubt
  table.remove(P.rows, i + 1)
  Util.mark_pdirty()
end
-- Splits a row in 2: at the cursor when it is inside the row, else in the middle. A row with 1 note needs the cursor
-- (the note then stands in both rows). Returns true when it did.
function List.split(i, cursor)
  local row = P.rows[i]
  if not row then return false end
  local parts = List.split_text(row.text)
  local stop = P.rows[i + 1] and P.rows[i + 1].t or math.max(row.t + 2, cursor or 0) + 0.1
  local inside = cursor and cursor > row.t + 0.02 and cursor < stop - 0.02
  if #parts < 2 and not inside then return false end
  local ts = row.ts
  if not ts or #ts ~= #parts then -- (typed notes: spread over the time of the row)
    ts = {}
    local len = math.min(stop - row.t, 4)
    for k = 1, #parts do ts[k] = row.t + len * (k - 1) / #parts end
  end
  local n = math.ceil(#parts / 2) -- the notes of the first row
  local t = ts[n + 1]
  if inside then
    n = 0
    for k = 1, #parts do if ts[k] <= cursor + 0.02 then n = k end end
    n, t = math.max(1, n), cursor
  end
  List.step()
  local a, b, ta, tb = {}, {}, {}, {}
  for k = 1, #parts do
    if k <= n then a[#a + 1], ta[#ta + 1] = parts[k], ts[k] else b[#b + 1], tb[#tb + 1] = parts[k], ts[k] end
  end
  if #b == 0 then b, tb = { parts[#parts] }, { t } end
  row.text, row.ts = table.concat(a, " - "), ta
  table.insert(P.rows, i + 1, { t = t, text = table.concat(b, " - "), doubt = row.doubt, ts = tb })
  Util.mark_pdirty()
  return true
end
-- A new row at a time, with the notes of the row before it. Returns its index.
function List.add(t)
  List.step()
  local before = List.at(t)
  local row = { t = math.max(0, t), text = before and P.rows[before].text or Key.names(List.key_at(t))[0], doubt = false }
  local i = (before or 0) + 1
  table.insert(P.rows, i, row)
  Util.mark_pdirty()
  return i
end
function List.delete(i)
  if not P.rows[i] then return end
  List.step()
  table.remove(P.rows, i)
  R.edit = nil
  R.sel = #P.rows > 0 and math.min(i, #P.rows) or nil
  Util.mark_pdirty()
end
-- Moves a row to a time (the list stays in order). Returns its new index.
function List.move(i, t)
  local row = P.rows[i]
  if not row then return nil end
  List.step()
  row.t, row.ts = math.max(0, t), nil
  table.remove(P.rows, i)
  local at = (List.at(row.t) or 0) + 1
  table.insert(P.rows, at, row)
  Util.mark_pdirty()
  return at
end
-- The key at a time: the last key change before it (P.keys), else the key of the song.
function List.key_at(t)
  local k = P.key
  for _, c in ipairs(P.keys) do
    if c.t > t + 1e-6 then break end
    k = c.key
  end
  return k
end
-- The note names of every line in the key at its time.
function List.respell()
  for _, row in ipairs(P.rows) do row.text = Key.respell(row.text, List.key_at(row.t)) end
end
-- The key change that starts at line i (its index in P.keys), or nil.
function List.key_change(i)
  local row = P.rows[i]
  if not row then return nil end
  for k, c in ipairs(P.keys) do if math.abs(c.t - row.t) < 1e-6 then return k end end
end
-- New key from line i on; key "": the key change at line i goes.
function List.key_from(i, key)
  local row = P.rows[i]
  if not row then return end
  List.step()
  local k = List.key_change(i)
  if k then table.remove(P.keys, k) end
  if key ~= "" then
    P.keys[#P.keys + 1] = { t = row.t, key = key }
    table.sort(P.keys, function(a, b) return a.t < b.t end)
  end
  List.respell()
  Util.mark_pdirty()
end
function List.set_key(key)
  if key == P.key then return end
  List.step()
  P.key = key
  List.respell()
  Util.mark_pdirty()
end
-- Groups the found notes again (the Lines dropdown).
function List.set_mode(mode)
  if mode == P.mode then return end
  List.step()
  P.mode = mode
  if #P.notes > 0 then
    P.rows = Group.make(P.notes, mode, P.key, R.proj, P.t_end, List.opt())
    List.respell()
  end
  R.sel, R.edit = nil, nil
  Util.mark_pdirty()
end
-- The tuning of the song (UX 7 of the musician review, decided 24 November 2026: no new Find notes). The found notes
-- that can now be an octave lower (Find.retune_need) are heard again (Find.retune: a short piece of the bass item
-- each); the others keep their octave. The rows follow (strings, frets); a row that you corrected keeps your text.
function List.set_tuning(id)
  if id == P.tuning then return end
  List.step()
  local old_open = Key.tuning(P.tuning).open[1]
  local auto = #P.notes > 0 and List.auto_rows() -- (the rows as the old tuning made them: to find your corrections)
  P.tuning = id
  local heard = 0
  if #P.notes > 0 then
    heard = Find.retune(P.notes, old_open, Key.tuning(id).open[1])
    List.remake(auto)
  end
  Util.mark_pdirty()
  return heard
end
-- The rows that Group.make gives now (with the key changes; tp: at this Transpose, else the toolbar's), without
-- changing P.rows.
function List.auto_rows(tp)
  local keep = P.rows
  P.rows = Group.make(P.notes, P.mode, P.key, R.proj, P.t_end, List.opt(tp))
  List.respell()
  local rows = P.rows
  P.rows = keep
  return rows
end
-- The rows again from the notes; a row that differs from auto (the rows that the notes gave before: your correction,
-- or a line you joined, split or added) stays as it is.
function List.remake(auto)
  local was = {}
  for _, row in ipairs(auto or {}) do was[string.format("%.4f", row.t)] = row.text end
  local new, by_t = List.auto_rows(), {}
  for _, row in ipairs(new) do by_t[string.format("%.4f", row.t)] = row end
  for i, row in ipairs(P.rows) do
    local k = string.format("%.4f", row.t)
    if was[k] == row.text and by_t[k] then P.rows[i] = by_t[k] end
  end
end

---------------------------------------------------------------------------
-- PROJECT
---------------------------------------------------------------------------
function Project.read()
  local n, txt = r.GetProjExtState(R.proj, CFG.EXT, CFG.PEXT_KEY)
  return (n and n > 0 and txt) or ""
end
-- The lists of the project (1 per song); the list of the song at the cursor shows (none there: the first song with a
-- list, else the first song).
function Project.load(txt)
  R.lists, R.hist, R.song, R.follow_last, R.songs, R.st = Lists.split(txt), {}, nil, nil, nil, nil
  P = List.default() -- (never the list of the project before: Songs.get stores the shown list)
  R.plast_txt, R.pdirty = txt, false
  R.sel, R.edit, R.undo, R.redo, R.view, R.finish, R.ask, R.places = nil, nil, {}, {}, nil, nil, nil, nil
  R.written, R.written_lbl = nil, nil
  Find.cancel()
  local songs = Songs.get() -- (a list whose song is gone goes to the song at its first line)
  local i = Songs.at(songs, Util.cursor())
  local id = i and songs[i].id
  if not id then for _, s in ipairs(songs) do if R.lists.txt[s.id] then id = s.id; break end end end
  id = id or (songs[1] and songs[1].id) or ""
  R.song, R.follow_last = id, i and id or nil
  P = List.parse(R.lists.txt[id] or "")
  host.notes_changed()
end
-- Writes the project data when it changed (an unchanged text does not mark the project modified).
function Project.save()
  R.pdirty = false
  if not (R.proj and r.ValidatePtr2(0, R.proj, "ReaProject*")) then return end
  Lists.store()
  local txt = Lists.join(R.lists)
  R.song_lbls = nil -- (the line counts of the song list)
  if txt == R.plast_txt then return end
  r.SetProjExtState(R.proj, CFG.EXT, CFG.PEXT_KEY, txt)
  r.MarkProjectDirty(R.proj)
  R.plast_txt = txt
end

-- Every frame: another project (a tab, or File > Open in the same tab) loads its own data. The saved text decides:
-- "Save as" keeps it, another project has another one.
function Project.update()
  local proj, fn = r.EnumProjects(-1)
  fn = fn or ""
  if proj ~= R.proj then
    if R.pdirty then Project.save() end
    R.proj, R.projfn, R.state_cc = proj, fn, r.GetProjectStateChangeCount(proj)
    R.src_name, R.trk, R.trk_lbl, R.trk_def, R.written_lbl = nil, nil, nil, nil, nil
    Project.load(Project.read())
    return
  end
  local cc = r.GetProjectStateChangeCount(proj)
  if cc ~= R.state_cc or fn ~= R.projfn then
    local other = fn ~= R.projfn
    R.state_cc, R.projfn, R.view, R.src_name = cc, fn, nil, nil -- (also the tempo: the bar numbers)
    R.trk_lbl, R.trk_def = nil, nil -- (a renamed track, another selection)
    local txt = Project.read()
    if txt ~= R.plast_txt then Project.load(txt) -- (never write the old list into the next project)
    elseif other and txt == "" then Project.load(txt) end -- (2 projects without a list: the Undo steps go too)
    if R.find then Find.check() end
  end
end

---------------------------------------------------------------------------
-- SONGS (1 notes list per song, decided 26 November 2026): a song is a region; an audio item of the bass track (the
-- Track row) whose middle is in no region is a song too. The Detection tab shows the list of the song at the play
-- position (stopped: the edit cursor); between songs the last one stays.
---------------------------------------------------------------------------
local SONG_EPS = 1e-3 -- s: a time a hair before a start (rounding) is in that song
-- The songs { id, name, t0, t1, num (a region's number) or item = true } of the regions and the bass items, sorted
-- by their start (plain: tested).
function Songs.make(regions, items)
  local list = {}
  for _, g in ipairs(regions) do list[#list + 1] = g end
  for _, it in ipairs(items) do
    local mid, inside = (it.t0 + it.t1) / 2, false
    for _, g in ipairs(regions) do if mid >= g.t0 and mid < g.t1 then inside = true; break end end
    if not inside then list[#list + 1] = it end
  end
  table.sort(list, function(a, b) if a.t0 ~= b.t0 then return a.t0 < b.t0 end return a.id < b.id end)
  return list
end
-- The index of the song at time t (2 songs there: the one that starts later), or nil (between songs).
function Songs.at(list, t)
  local best
  for i, s in ipairs(list) do
    if t >= s.t0 - SONG_EPS and t < s.t1 - SONG_EPS then best = i end
  end
  return best
end
-- How long song s and the time t0..t1 overlap (0: not at all).
function Songs.overlap(s, t0, t1) return math.max(0, math.min(s.t1, t1) - math.max(s.t0, t0)) end
-- The song that Find notes fills from the audio item it ({ id, t0, t1 }): the item's own song, else the shown song
-- (cur: its id) when the item is in it (1 long item for several regions), else the song at its middle; nil: none.
function Songs.for_item(list, it, cur)
  local shown
  for _, s in ipairs(list) do
    if s.id == it.id then return s end
    if s.id == cur and Songs.overlap(s, it.t0, it.t1) > SONG_EPS then shown = s end
  end
  if shown then return shown end
  local i = Songs.at(list, (it.t0 + it.t1) / 2)
  return i and list[i]
end
-- The songs of the project (cached until the project, the Track row or the number of regions or bass items changes:
-- a script that adds a region does not change the project's change count). A list whose song is gone goes to the
-- song at its first line (Lists.adopt).
function Songs.get()
  local tr = Find.track()
  local _, _, nr = r.CountProjectMarkers(R.proj) -- (all, markers, regions)
  local ni = tr and r.CountTrackMediaItems(tr) or 0
  local c = R.songs
  if c and c.proj == R.proj and c.cc == R.state_cc and c.tr == tr and c.nr == nr and c.ni == ni then return c.list end
  local regions, items = {}, {}
  Out.each_marker(function(_, rgn, pos, e, name, num, g)
    if rgn then regions[#regions + 1] = { id = g, name = name ~= "" and name or ("Region " .. num), t0 = pos, t1 = e, num = num } end
  end)
  for _, a in ipairs(tr and Find.audio_items(tr) or {}) do
    local _, g = r.GetSetMediaItemInfo_String(a.item, "GUID", "", false)
    local nm = Find.name(a.item)
    items[#items + 1] = { id = g, name = nm ~= "" and nm or ("Item at " .. r.format_timestr_pos(a.pos, "", 0)),
      t0 = a.pos, t1 = a.pos + a.len, item = true }
  end
  local list = Songs.make(regions, items)
  R.songs, R.st, R.song_lbls = { proj = R.proj, cc = R.state_cc, tr = tr, nr = nr, ni = ni, list = list }, nil, nil
  Lists.adopt(list)
  return list
end
-- The song of the shown list (nil: none, or it is gone).
function Songs.cur()
  for _, s in ipairs(Songs.get()) do if s.id == R.song then return s end end
end
-- The Song row's dropdown and arrows: song s shows, the edit cursor goes to its start and its bass item is selected.
-- Only while stopped (false: playing, or no song).
function Songs.go(s)
  if not s or Util.playing() then return false end
  Lists.switch(s.id)
  R.follow_last = s.id
  r.SetEditCurPos2(R.proj, s.t0, true, false)
  local tr, best, bo = Find.track(), nil, 0
  for _, a in ipairs(tr and Find.audio_items(tr) or {}) do
    local o = Songs.overlap(s, a.pos, a.pos + a.len)
    if o > bo then best, bo = a.item, o end
  end
  if best then
    r.SelectAllMediaItems(R.proj, false)
    r.SetMediaItemSelected(best, true)
  end
  r.UpdateArrange()
  return true
end
-- The texts of the Song row's dropdown: each song with its line count (cur: the shown song, without the id).
function Songs.labels()
  local songs = Songs.get()
  local c = R.song_lbls
  if c and c.songs == songs and c.song == R.song and c.n == #P.rows then return c end
  c = { songs = songs, song = R.song, n = #P.rows, items = {}, cur = "None here: pick a song" }
  for k, s in ipairs(songs) do
    local n = s.id == R.song and #P.rows or Lists.count(R.lists and R.lists.txt[s.id])
    local txt = string.format("%d: %s", k, s.name) .. (n > 0 and string.format("  (%d %s)", n, n == 1 and "line" or "lines") or "")
    c.items[k] = txt .. "##song" .. k
    if s.id == R.song then c.cur = txt end
  end
  R.song_lbls = c
  return c
end

---------------------------------------------------------------------------
-- LISTS (the saved lists of the songs: blocks "song=<id>", then the lines of its list as List.serialize writes them;
-- an older text without "song=" lines is not read, decided 26 November 2026)
---------------------------------------------------------------------------
function Lists.split(txt)
  local l, cur, buf = { ids = {}, txt = {} }, nil, {}
  local function close()
    if cur and buf[1] then Lists.set(l, cur, table.concat(buf, "\n")) end
  end
  for line in ((txt or "") .. "\n"):gmatch("([^\n]*)\n") do
    local id = line:match("^song=(.*)$")
    if id then close(); cur, buf = id, {}
    elseif cur and line ~= "" then buf[#buf + 1] = line end
  end
  close()
  return l
end
function Lists.join(l)
  local t = {}
  for _, id in ipairs(l.ids) do t[#t + 1] = "song=" .. id; t[#t + 1] = l.txt[id] end
  return table.concat(t, "\n")
end
-- The list text of song id ("": the song has no list).
function Lists.set(l, id, txt)
  if txt == "" then
    if l.txt[id] then
      l.txt[id] = nil
      for k, x in ipairs(l.ids) do if x == id then table.remove(l.ids, k); break end end
    end
    return
  end
  if not l.txt[id] then l.ids[#l.ids + 1] = id end
  l.txt[id] = txt
end
function Lists.rename(l, old, new)
  for k, x in ipairs(l.ids) do if x == old then l.ids[k] = new end end
  l.txt[new], l.txt[old] = l.txt[old], nil
end
-- The time of the first line of a list text (nil: no line and no note).
function Lists.first_t(txt)
  local t = txt:match("^row=([%d%.%-]+)") or txt:match("\nrow=([%d%.%-]+)") or txt:match("^note=([%d%.%-]+)")
    or txt:match("\nnote=([%d%.%-]+)")
  return tonumber(t)
end
-- The number of lines of a list text.
function Lists.count(txt)
  if not txt then return 0 end
  local _, n = txt:gsub("\nrow=", "")
  return n + (txt:find("^row=") and 1 or 0)
end
-- The shown list goes into the saved lists.
function Lists.store()
  if R.song and R.lists then Lists.set(R.lists, R.song, List.serialize(P)) end
end
-- A list whose song is gone (a region added or deleted, another Track) goes to the song at its first line, when that
-- song has no list yet; else it stays as it is.
function Lists.adopt(songs)
  local l = R.lists
  if not l then return end
  local ids, lost = {}, false
  for _, s in ipairs(songs) do ids[s.id] = true end
  for _, id in ipairs(l.ids) do if not ids[id] then lost = true end end
  if not lost then return end
  Lists.store()
  for _, id in ipairs({ table.unpack(l.ids) }) do
    local t = not ids[id] and Lists.first_t(l.txt[id])
    local i = t and Songs.at(songs, t)
    local s = i and songs[i]
    if s and not l.txt[s.id] then
      Lists.rename(l, id, s.id)
      if R.song == id then R.song = s.id end
      if R.follow_last == id then R.follow_last = s.id end
      R.hist[s.id], R.hist[id] = R.hist[id], nil
      R.pdirty = true
    end
  end
end
-- The list of song id shows (its own Undo steps too).
function Lists.switch(id)
  if id == R.song then return end
  Lists.store()
  if R.song then R.hist[R.song] = { R.undo, R.redo } end
  local h = R.hist[id]
  R.song, R.undo, R.redo, R.hist[id] = id, h and h[1] or {}, h and h[2] or {}, nil
  P = List.parse(R.lists and R.lists.txt[id] or "")
  R.sel, R.edit, R.view, R.places, R.written, R.written_lbl, R.src_name, R.st = nil, nil, nil, nil, nil, nil, nil, nil
  host.notes_changed()
  host.song_changed() -- (Tab Viewer: a Find tempo result was for the song before)
end
-- Every frame: the list follows the song at the cursor (only when that song changes; not while Find notes listens or
-- a window of the list is open).
function Lists.follow()
  if not S.song_follow or R.find or R.edit or R.ask or R.finish or R.export or not R.lists then return end
  local songs = Songs.get()
  local i = Songs.at(songs, Util.cursor())
  local id = i and songs[i].id
  if not id or id == R.follow_last then return end
  R.follow_last = id
  if id ~= R.song then R.flash = Util.now() end -- (the Song row flashes: the list changed by itself)
  Lists.switch(id)
end
-- The bass item of any saved list, or the item of a song that is an item (the default of the Track row), or nil.
function Lists.src_item()
  local l = R.lists
  if not l then return nil end
  for _, id in ipairs(l.ids) do
    local g = l.txt[id]:match("^src=([^\n]+)") or l.txt[id]:match("\nsrc=([^\n]+)")
    local item = g and Util.item_by_guid(g) or Util.item_by_guid(id)
    if item then return item end
  end
end

---------------------------------------------------------------------------
-- FIND (reads the selected bass item in steps)
---------------------------------------------------------------------------
-- The selected audio item. Returns item, take, or nil and the reason.
-- A new tuning: what happens to found note n (lowest: the lowest open string before / after). "hear": it can now be an
-- octave lower (it was in the lowest octave of the old tuning, and the new one goes lower for its pitch class); else
-- its new midi (the same, or up into the new lowest octave).
function Find.retune_need(n, old, new)
  local ol, nl = Key.low(n.pc, old), Key.low(n.pc, new)
  if nl < ol and n.midi == ol then return "hear" end
  if n.midi < nl then return nl end -- (below the new lowest octave: up into it)
  return n.midi
end
-- The octave of a note heard again: oe (Det.odd_even at the new lowest octave nl; nil: too short to tell) -> midi,
-- doubtful. The odd harmonics far below the even ones: the higher octave (as Det.analyse, with the default limit).
function Find.retune_pick(oe, nl)
  if not oe then return nl + 12, true end -- (too short: the octave it had, yellow)
  return oe < CFG.OCT_DB and nl + 12 or nl, math.abs(oe - CFG.OCT_DB) < CFG.OCT_SURE
end
-- Changes the octaves of the found notes for a new tuning (old / new: the lowest open strings). The notes to hear
-- again are read from the bass item of the list (P.src), a short piece each; no item (gone, or the notes of a tab):
-- they keep their octave. Returns how many were heard.
function Find.retune(notes, old, new)
  local item = Find.item()
  local take = item and r.GetActiveTake(item)
  local acc = take and not r.TakeIsMIDI(take) and r.CreateTakeAudioAccessor(take)
  local pos = item and r.GetMediaItemInfo_Value(item, "D_POSITION") or 0
  local buf, heard = r.new_array(2 * math.ceil(CFG.SR * 0.2)), 0
  for _, n in ipairs(notes) do
    local need = Find.retune_need(n, old, new)
    if need ~= "hear" then n.midi = need
    elseif acc then
      local nl = Key.low(n.pc, new)
      local t = n.t + CFG.START_COMP -- (the found start is this much early)
      local len = math.min(0.15, (n.t1 or t) - t)
      local oe
      if len >= 0.08 then
        local c = math.floor(len * CFG.SR)
        buf.clear()
        r.GetAudioAccessorSamples(acc, CFG.SR, 2, t - pos, c, buf)
        local v, x = buf.table(1, c * 2), {}
        for k = 1, c do x[k] = (v[2 * k - 1] + v[2 * k]) * 0.5 end
        oe = Det.odd_even(x, 0, len, nl, 0)
      end
      local doubt
      n.midi, doubt = Find.retune_pick(oe, nl)
      if doubt then n.doubt, n.why = true, n.why or "octave" end
      heard = heard + 1
    end
  end
  if acc then r.DestroyAudioAccessor(acc) end
  return heard
end

-- The item of the Track row to listen to: the selected item on it, else the one most in the shown song, else its
-- longest one. cands: { { sel, len, ov (the time in the shown song) } } of its audio items (a plain rule: tested).
-- Returns the index, or nil (no audio item).
function Find.pick(cands)
  local best
  for i, c in ipairs(cands) do
    if c.sel then return i end
    local b = best and cands[best]
    local ov, bov = c.ov or 0, b and b.ov or 0
    if not b or ov > bov or ov == bov and c.len > b.len then best = i end
  end
  return best
end
-- The audio items of track tr: { { item, take, sel, pos, len } }.
function Find.audio_items(tr)
  local list = {}
  for k = 0, r.CountTrackMediaItems(tr) - 1 do
    local item = r.GetTrackMediaItem(tr, k)
    local take = r.GetActiveTake(item)
    if take and not r.TakeIsMIDI(take) then
      list[#list + 1] = { item = item, take = take, sel = r.IsMediaItemSelected(item),
        pos = r.GetMediaItemInfo_Value(item, "D_POSITION"), len = r.GetMediaItemInfo_Value(item, "D_LENGTH") }
    end
  end
  return list
end
-- The Track row: your choice (R.trk; not saved), else the track of the bass item of the shown list (or of another
-- song's list), else the track of the selected item. nil: none yet. fresh: look again (Find notes), not the cached
-- default (every frame).
function Find.track(fresh)
  if R.trk and r.ValidatePtr2(R.proj, R.trk, "MediaTrack*") then return R.trk end
  R.trk = nil
  if R.trk_def and not r.ValidatePtr2(R.proj, R.trk_def, "MediaTrack*") then R.trk_def = nil end -- (deleted)
  if R.trk_def == nil or fresh then -- (cached: Find.item looks through all items; cleared when the project changes)
    local item = Find.item() or Lists.src_item() or r.GetSelectedMediaItem(R.proj, 0)
    R.trk_def = item and r.GetMediaItem_Track(item) or false
  end
  return R.trk_def or nil
end
-- The tracks with an audio item, for the Track dropdown (made when it opens): { { tr, label } }.
function Find.tracks()
  local list = {}
  for k = 0, r.CountTracks(R.proj) - 1 do
    local tr = r.GetTrack(R.proj, k)
    if #Find.audio_items(tr) > 0 then list[#list + 1] = { tr = tr, label = Find.track_label(tr) } end
  end
  return list
end
function Find.track_label(tr)
  local _, name = r.GetTrackName(tr)
  return string.format("%d: %s", math.floor(r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")), name)
end

function Find.source()
  local tr = Find.track(true)
  if not tr then return nil, "Pick the bass track first (Track)." end
  local list = Find.audio_items(tr)
  local s = Songs.cur()
  if s then for _, c in ipairs(list) do c.ov = Songs.overlap(s, c.pos, c.pos + c.len) end end
  local i = Find.pick(list)
  if not i then return nil, "The track " .. Find.track_label(tr) .. " has no audio item. Pick the bass track (Track)." end
  local item, take = list[i].item, list[i].take
  local src = r.GetMediaItemTake_Source(take)
  if not src or r.GetMediaSourceSampleRate(src) <= 0 then
    return nil, "The file of the bass item is missing or offline."
  end
  return item, take
end

-- The bass item of the list (nil when it was deleted).
function Find.item() return Util.item_by_guid(P.src) end
function Find.name(item)
  local take = item and r.GetActiveTake(item)
  return take and r.GetTakeName(take) or ""
end

-- The notes of the samples x in project time (the item starts at pos), and the tuning.
function Find.notes(x, pos, tick)
  local notes, tune = Det.analyse(x, tick, Key.tuning(P.tuning).open[1])
  for _, n in ipairs(notes) do n.t, n.t1 = n.t + pos, n.t1 + pos end
  local grid = List.opt().splits and Find.grid(pos, pos + #x / CFG.SR) -- (Settings > Detection > Split repeated notes)
  if grid then notes = Det.repeats(x, notes, grid, pos) end
  return notes, tune
end
-- The 16th notes of the project between 2 times (nil when the project has no tempo marker: its grid is not the
-- song's yet, so the repeated notes are not split).
function Find.grid(t0, t1)
  if r.CountTempoTimeSigMarkers(R.proj) == 0 then return nil end
  local g, q, q1 = {}, math.ceil(r.TimeMap2_timeToQN(R.proj, t0) * 4) / 4, r.TimeMap2_timeToQN(R.proj, t1)
  while q <= q1 do g[#g + 1] = r.TimeMap2_QNToTime(R.proj, q); q = q + 0.25 end
  return g
end

-- Listens to item (nil, or gone: Find.source). A song that is a region: only its part of the item (1 long bass item
-- for several songs).
function Find.begin(item, take)
  if not (item and r.ValidatePtr2(R.proj, item, "MediaItem*")) then item, take = Find.source() end
  if not item then UI.notice(take, true); return end
  local _, guid = r.GetSetMediaItemInfo_String(item, "GUID", "", false)
  local pos, len = r.GetMediaItemInfo_Value(item, "D_POSITION"), r.GetMediaItemInfo_Value(item, "D_LENGTH")
  local a, b = Find.part(Songs.cur(), pos, pos + len)
  R.find = { item = item, take = take, proj = R.proj, guid = guid, name = Find.name(item), done = 0,
    pos = a, t_end = b, rd = TP.reader(take, b - a, a - pos) } -- (the shared audio reader: Tempo.lua)
end
-- The part of an item (t0..t1) that Find notes reads for song s: a region's part, else all of it.
function Find.part(s, t0, t1)
  if s and not s.item and Songs.overlap(s, t0, t1) > SONG_EPS then return math.max(t0, s.t0), math.min(t1, s.t1) end
  return t0, t1
end
-- false when the item is gone (or in another project): Find stops.
function Find.check()
  local f = R.find
  if not f then return false end
  if f.proj ~= R.proj or not r.ValidatePtr2(R.proj, f.item, "MediaItem*") or not r.ValidatePtr2(R.proj, f.take, "MediaItem_Take*") then
    Find.cancel()
    return false
  end
  return true
end
function Find.step()
  local f = R.find
  if not f or not Find.check() then return end
  f.stop = Util.now() + CFG.STEP
  while not f.co do -- (first the samples, then the notes)
    if TP.read_block(f.rd) then
      f.co = coroutine.create(function()
        return Find.notes(f.rd.x, f.pos, function(v)
          f.done = 0.05 + 0.95 * v
          if Util.now() > f.stop then coroutine.yield() end
        end)
      end)
    end
    if not f.co then f.done = 0.05 * f.rd.i / math.max(1, f.rd.n) end
    if Util.now() > f.stop then return end
  end
  local ok, notes, tune = coroutine.resume(f.co)
  if not ok then Find.cancel(); UI.notice("Find notes stopped: " .. tostring(notes), true); return end
  if coroutine.status(f.co) == "dead" then
    R.find = nil
    Find.done(f, notes, tune, f.t_end)
  end
end
function Find.cancel()
  if R.find then TP.close(R.find.rd) end
  R.find = nil
end
-- The found notes become the list (the Undo button brings the old list back).
function Find.done(f, notes, tune, t_end)
  if #notes == 0 then UI.notice("No notes found. Is this the bass track (Track)?", true); return end
  List.step()
  P.notes, P.t_end, P.tab = notes, t_end, nil -- (the fixes of the tab were for the notes before)
  P.src = f.guid
  P.key = Key.find(f.name) or P.key
  P.rows = Group.make(notes, P.mode, P.key, R.proj, t_end, List.opt())
  List.respell() -- (the key changes)
  R.sel, R.edit, R.src_name = nil, nil, nil
  Util.mark_pdirty()
  UI.notice(string.format("Found %d markers, %d not sure. Tuning: A = %.0f Hz.", #P.rows, List.doubtful(), 440 * 2 ^ (tune / 12)))
  local g = P.key == "" and Key.guess(notes) -- (no key known: a suggestion)
  if g then
    UI.ask("Sounds like " .. g .. ". Use it as the key of the song? (It decides the note names: Ab or G#.)",
      "Use it", function() List.set_key(g) end, "Not now")
  end
end

---------------------------------------------------------------------------
-- OUT (writes the markers and the Notes track; Done: clean up)
---------------------------------------------------------------------------
-- Every marker and region: fn(index, is_region, pos, end, name, number, guid).
function Out.each_marker(fn)
  local i = 0
  while true do
    local n, rgn, pos, e, name, num = r.EnumProjectMarkers2(R.proj, i)
    if n == 0 then return end
    local _, g = r.GetSetProjectInfo_String(R.proj, "MARKER_GUID:" .. i, "", false)
    fn(i, rgn, pos, e, name, num, g)
    i = i + 1
  end
end
function Out.delete_markers()
  local own, del = {}, {}
  for _, g in ipairs(P.mk) do own[g] = true end
  Out.each_marker(function(i, rgn, _, _, _, _, g) if not rgn and own[g] then del[#del + 1] = i end end)
  for k = #del, 1, -1 do r.DeleteProjectMarkerByIndex(R.proj, del[k]) end
  return #del
end
function Out.add_markers()
  local before = {}
  Out.each_marker(function(_, _, _, _, _, _, g) before[g] = true end)
  for i, row in ipairs(P.rows) do r.AddProjectMarker2(R.proj, false, row.t, 0, row.text, i, 0) end
  for _, c in ipairs(P.keys) do r.AddProjectMarker2(R.proj, false, c.t, 0, "Key: " .. c.key, -1, 0) end
  Out.each_marker(function(_, rgn, _, _, _, _, g) if not rgn and not before[g] then P.mk[#P.mk + 1] = g end end)
  while #P.mk > CFG.MK_MAX do table.remove(P.mk, 1) end
end

-- The track with the mark of the Detection tab: "1" = the Notes track (the default), "midi" = the Bass MIDI track.
function Out.find_track(mark)
  for i = 0, r.CountTracks(R.proj) - 1 do
    local tr = r.GetTrack(R.proj, i)
    local _, v = r.GetSetMediaTrackInfo_String(tr, CFG.TAG, "", false)
    if v == (mark or "1") then return tr end
  end
end
-- A new track with the mark of the Detection tab next to the track of the bass item: above it (the Notes track) or below it
-- (below: the Bass MIDI track).
function Out.make_track(name, mark, below)
  local item = Find.item()
  local bass = item and r.GetMediaItemTrack(item)
  local num = bass and math.floor(r.GetMediaTrackInfo_Value(bass, "IP_TRACKNUMBER"))
  local at = num and (below and num or num - 1) or (below and r.CountTracks(R.proj) or 0)
  r.InsertTrackAtIndex(at, false)
  local tr = r.GetTrack(R.proj, at)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
  r.GetSetMediaTrackInfo_String(tr, CFG.TAG, mark, true)
  return tr
end
-- Deletes the items of a track that the Detection tab made for the shown song (their middle in the song; no songs:
-- all of them). Other items stay.
function Out.delete_marked(tr)
  local s = Songs.cur()
  for i = r.CountTrackMediaItems(tr) - 1, 0, -1 do
    local it = r.GetTrackMediaItem(tr, i)
    local _, v = r.GetSetMediaItemInfo_String(it, CFG.TAG, "", false)
    local mid = r.GetMediaItemInfo_Value(it, "D_POSITION") + r.GetMediaItemInfo_Value(it, "D_LENGTH") / 2
    if v == "1" and (not s or mid >= s.t0 and mid < s.t1) then r.DeleteTrackMediaItem(tr, it) end
  end
end
-- Removes the text items of the Detection tab (other items on the track stay), and the track when nothing is on it.
function Out.delete_items(keep_track)
  local tr = Out.find_track()
  if not tr then return end
  Out.delete_marked(tr)
  if not keep_track and r.CountTrackMediaItems(tr) == 0 and r.TrackFX_GetCount(tr) == 0 then Out.delete_track(tr) end
end
-- Deletes a track; the end of a folder moves to the track before it.
function Out.delete_track(tr)
  local depth = r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
  local num = math.floor(r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER"))
  local prev = num > 1 and r.GetTrack(R.proj, num - 2) or nil
  if depth < 0 and prev then
    r.SetMediaTrackInfo_Value(prev, "I_FOLDERDEPTH", r.GetMediaTrackInfo_Value(prev, "I_FOLDERDEPTH") + depth)
    r.SetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH", 0)
  end
  r.DeleteTrack(tr)
end
-- The end of the song: the end of the bass item, in a region at most its end (or 2 s after the last row).
function Out.song_end()
  local item, s = Find.item(), Songs.cur()
  local last = P.rows[#P.rows]
  local t = last and last.t + 2 or 0
  local e = item and r.GetMediaItemInfo_Value(item, "D_POSITION") + r.GetMediaItemInfo_Value(item, "D_LENGTH")
  if s and not s.item then e = e and math.min(e, s.t1) or s.t1 end
  if e then t = math.max(t, e) end
  return t
end
-- The text of a Notes track item: the line, and a key change on its first line when no markers show it.
function Out.item_text(i, key_line)
  local text = P.rows[i].text
  local k = key_line and List.key_change(i)
  return k and ("Key: " .. P.keys[k].key .. "\n" .. text) or text
end
-- markers: markers are written too (they show the key changes).
function Out.add_items(markers)
  local tr = Out.find_track() or Out.make_track(CFG.TRACK, "1")
  local stop = Out.song_end()
  for i, row in ipairs(P.rows) do
    local e = P.rows[i + 1] and P.rows[i + 1].t or stop
    if e > row.t then
      local it = r.AddMediaItemToTrack(tr)
      r.SetMediaItemInfo_Value(it, "D_POSITION", row.t)
      r.SetMediaItemInfo_Value(it, "D_LENGTH", e - row.t)
      r.GetSetMediaItemInfo_String(it, "P_NOTES", Out.item_text(i, not markers), true)
      r.GetSetMediaItemInfo_String(it, CFG.TAG, "1", true)
    end
  end
end

-- Clear: what the Detection tab wrote goes (its markers, the Notes track items, the Bass MIDI item; 1 undo step), and the
-- list (with its key changes and the found notes; the Undo button brings it back). The key, the Lines choice, the
-- tuning and the marker IDs stay (Ctrl+Z brings the markers back, and a new Write then replaces them).
function Out.clear()
  r.Undo_BeginBlock2(R.proj)
  r.PreventUIRefresh(1)
  Out.delete_markers()
  Out.delete_items(false)
  local mt = Out.find_track("midi")
  if mt then
    Out.delete_marked(mt)
    if r.CountTrackMediaItems(mt) == 0 and r.TrackFX_GetCount(mt) == 0 then Out.delete_track(mt) end
  end
  r.PreventUIRefresh(-1)
  r.Undo_EndBlock2(R.proj, CFG.UNDO_NAME .. ": clear", -1)
  r.TrackList_AdjustWindows(false)
  r.UpdateArrange()
  List.step(CFG.UNDO_NAME .. ": clear")
  P.rows, P.keys, P.src, P.notes, P.t_end, P.tab = {}, {}, "", {}, nil, nil
  R.sel, R.edit, R.written, R.src_name = nil, nil, nil, nil
  Util.mark_pdirty()
end

-- Writes the list: "markers", "track" or "both". Only the own markers and text items of the Detection tab are replaced.
function Out.write(what)
  if #P.rows == 0 then return end
  r.Undo_BeginBlock2(R.proj)
  r.PreventUIRefresh(1)
  Out.delete_markers()
  if what ~= "track" then Out.add_markers() end
  Out.delete_items(what ~= "markers")
  if what ~= "markers" then Out.add_items(what == "both") end
  r.PreventUIRefresh(-1)
  r.Undo_EndBlock2(R.proj, CFG.UNDO_NAME .. ": write notes", -1)
  List.step(CFG.UNDO_NAME .. ": write notes", true)
  r.TrackList_AdjustWindows(false)
  r.UpdateArrange()
  R.written = List.serialize(P)
  R.written_lbl = Out.written_text(what, #P.rows)
  R.pdirty = true
end
-- The line next to Write after a Write (until the list changes: Util.mark_pdirty, List.undo, another project).
function Out.written_text(what, n)
  local unit = what == "track" and (n == 1 and "text item" or "text items") or (n == 1 and "marker" or "markers")
  return string.format("Written (%d %s)", n, unit)
end

-- The song title in the name of a bass file: "Far Away-Bass-C minor-120bpm" -> "Far Away".
function Out.title(name)
  local s = name:gsub("%.%w+$", "")
  local a = s:lower():find("[%-_ ]+bass%f[%A]")
  if a and a > 1 then s = s:sub(1, a - 1) end
  s = s:gsub("_", " "):gsub("^%d+[%.%-%s]+", "")
  return Util.clean(s)
end
-- The artist in the name of the project file: "12 - The Band - Far Away" and the title "Far Away" -> "The Band".
function Out.artist(projname, title)
  local prev
  for part in (projname:gsub("%.[Rr][Pp][Pp]$", "") .. " - "):gmatch("(.-) %- ") do
    if part:lower() == title:lower() and prev and not prev:match("^%d+$") then return prev end
    prev = Util.clean(part)
  end
  return ""
end
function Out.region_name(artist, title, key)
  local t = {}
  for _, v in ipairs({ artist, title, (key:gsub(" (%l)", function(c) return " " .. c:upper() end)) }) do
    v = Util.clean(v)
    if v ~= "" then t[#t + 1] = v end
  end
  return table.concat(t, " - ")
end
-- The tracks that look like a metronome (not a folder).
function Out.click_tracks()
  local out = {}
  for i = 0, r.CountTracks(R.proj) - 1 do
    local tr = r.GetTrack(R.proj, i)
    local _, name = r.GetTrackName(tr)
    if TP.is_click(name) and r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") <= 0 then
      out[#out + 1] = { tr = tr, name = name }
    end
  end
  return out
end

function Out.finish_begin()
  local item = Find.item()
  local track = item and r.GetMediaItemTrack(item)
  local title = Out.title(Find.name(item))
  local fx = track and r.TrackFX_GetCount(track) or 0
  local clicks = Out.click_tracks()
  local f = { title = title, artist = Out.artist(R.projfn:match("([^/\\]*)$") or "", title), track = track, fx = fx,
    clicks = clicks, del_fx = fx > 0, del_clicks = #clicks > 0, open = true }
  f.track_name = track and select(2, r.GetTrackName(track)) or ""
  f.fresh = R.written ~= nil and R.written == List.serialize(P)
  R.finish = f
end
-- Makes (or updates) the song region, removes what is ticked, and removes the list from the project. 1 undo step.
-- A song that is a region: that region gets the name (its place stays).
function Out.finish(f)
  local name = Out.region_name(f.artist, f.title, P.key)
  local item, s = Find.item(), Songs.cur()
  local t0 = item and r.GetMediaItemInfo_Value(item, "D_POSITION") or (P.rows[1] and P.rows[1].t or 0)
  local _, m0 = r.TimeMap2_timeToBeats(R.proj, t0)
  t0 = r.TimeMap2_beatsToTime(R.proj, 0, m0)
  local stop = Out.song_end()
  local _, m1 = r.TimeMap2_timeToBeats(R.proj, stop)
  stop = r.TimeMap2_beatsToTime(R.proj, 0, m1 + 1)
  local num
  if s and not s.item then t0, stop, num = s.t0, s.t1, s.num end
  r.Undo_BeginBlock2(R.proj)
  r.PreventUIRefresh(1)
  if name ~= "" then
    if not num then Out.each_marker(function(_, rgn, _, _, nm, n) if rgn and nm == name then num = num or n end end) end
    if num then r.SetProjectMarker2(R.proj, num, true, t0, stop, name)
    else r.AddProjectMarker2(R.proj, true, t0, stop, name, -1, 0) end
  end
  if f.del_fx and f.track and r.ValidatePtr2(R.proj, f.track, "MediaTrack*") then
    for i = r.TrackFX_GetCount(f.track) - 1, 0, -1 do r.TrackFX_Delete(f.track, i) end
  end
  if f.del_clicks then
    for _, c in ipairs(f.clicks) do if r.ValidatePtr2(R.proj, c.tr, "MediaTrack*") then Out.delete_track(c.tr) end end
  end
  r.PreventUIRefresh(-1)
  r.Undo_EndBlock2(R.proj, CFG.UNDO_NAME .. ": clean up the song", -1)
  r.TrackList_AdjustWindows(false)
  r.UpdateArrange()
  List.step() -- (the Undo button brings the list back while the window is open)
  P = List.default()
  R.sel, R.edit, R.written, R.finish, R.src_name = nil, nil, nil, nil, nil
  Util.mark_pdirty()
  return name
end

---------------------------------------------------------------------------
-- EXPORT (the found notes as a MIDI item on the Bass MIDI track and as a .mid file)
---------------------------------------------------------------------------
-- How far the notes start after the grid, together (quarter notes; early: below 0). The detection finds the starts a
-- little late or early, the same for all notes (lessons, 23 November 2026: some notes were 1 16th late in Guitar
-- Pro; then "a little early" was taken for "almost a 16th late", and beat 1 moved to 4a). The fine part: the mean of
-- their places in a 16th, on a circle (exact, but it cannot tell a whole 16th); then of that, 1 16th earlier and 1
-- later, the one that puts the most notes on the beats (in a bass line the most common place; a tie: the smallest).
function Export.delay(qs)
  local c, s = 0, 0
  for _, q in ipairs(qs) do
    local a = 2 * math.pi * (q % 0.25) / 0.25
    c, s = c + math.cos(a), s + math.sin(a)
  end
  if c == 0 and s == 0 then return 0 end
  local f = math.atan(s, c) / (2 * math.pi) * 0.25
  local best, bn
  for _, d in ipairs({ f, f - 0.25, f + 0.25 }) do
    local n = 0
    for _, q in ipairs(qs) do
      local x = q - d
      if math.abs(x - math.floor(x + 0.5)) < 0.06 then n = n + 1 end
    end
    if not bn or n > bn or (n == bn and math.abs(d) < math.abs(best)) then best, bn = d, n end
  end
  return best
end
-- The found notes on the grid of the project: { { midi, q0, q1 } } in quarter notes, sorted, without overlaps (a note
-- ends where the next one starts; 2 notes on the same step: the first stays). step: the grid (0: as they are); the
-- common delay of the starts (Export.delay) is taken away first.
-- Also returns the delay (0 without a grid). A note that the user placed in the tab (man) is on the grid already: it
-- does not count for the delay and is not moved by it.
function Export.notes(notes, step)
  local list, qs, d = {}, {}, 0
  for _, n in ipairs(notes) do
    local q0, q1 = r.TimeMap2_timeToQN(R.proj, n.t), r.TimeMap2_timeToQN(R.proj, n.t1)
    list[#list + 1] = { midi = n.midi or Key.low(n.pc, CFG.TUNINGS[1].open[1]), q0 = q0, q1 = q1, i = #list + 1,
      doubt = n.doubt, slide = n.slide, man = n.man }
    if not n.man then qs[#qs + 1] = q0 end
  end
  if step > 0 then
    d = #qs > 0 and Export.delay(qs) or 0
    for _, x in ipairs(list) do
      local dx = x.man and 0 or d
      x.q0 = math.floor((x.q0 - dx) / step + 0.5) * step
      x.q1 = math.max(x.q0 + step, math.floor((x.q1 - dx) / step + 0.5) * step)
    end
  end
  table.sort(list, function(a, b) if a.q0 ~= b.q0 then return a.q0 < b.q0 end return a.i < b.i end)
  local out = {}
  for _, x in ipairs(list) do
    local p = out[#out]
    if not (p and x.q0 <= p.q0 + 1e-9) then
      if p and p.q1 > x.q0 then p.q1 = x.q0 end
      out[#out + 1] = x
    end
  end
  return out, d
end

-- The start of the bar of the first note (quarter notes), and the tempo changes from there to q_end:
-- { { q, bpm, num (0: no time signature), den } } (the first one: the tempo and time signature at the start).
function Export.tempos(q_start, q_end)
  local proj = R.proj
  local t0, t1 = r.TimeMap2_QNToTime(proj, q_start), r.TimeMap2_QNToTime(proj, q_end)
  local num, den, bpm = r.TimeMap_GetTimeSigAtTime(proj, t0)
  local out = { { q = q_start, bpm = bpm, num = num, den = den } }
  for k = 0, r.CountTempoTimeSigMarkers(proj) - 1 do
    local _, t, _, _, b, n, d = r.GetTempoTimeSigMarker(proj, k)
    if t > t0 + 1e-6 and t < t1 then
      out[#out + 1] = { q = r.TimeMap2_timeToQN(proj, t), bpm = b, num = n > 0 and n or 0, den = d }
    end
  end
  return out
end

-- A number of a MIDI file in 7-bit steps.
local function vlq(n)
  local b = { n & 0x7F }
  n = n >> 7
  while n > 0 do table.insert(b, 1, (n & 0x7F) | 0x80); n = n >> 7 end
  return string.char(table.unpack(b))
end
-- The bytes of a .mid file (format 0, 1 track): the notes (from Export.notes), the tempo changes (Export.tempos;
-- tick 0 = tempos[1].q) and the track name.
function Export.smf(list, tempos, name)
  local q0, ev = tempos[1].q, {}
  local function tick(q) return math.max(0, math.floor((q - q0) * CFG.PPQ + 0.5)) end
  local function add(q, order, bytes) ev[#ev + 1] = { tick(q), order, #ev, bytes } end
  add(q0, 0, "\xFF\x03" .. vlq(#name) .. name)
  for _, t in ipairs(tempos) do
    local us = math.floor(60000000 / t.bpm + 0.5)
    add(t.q, 1, "\xFF\x51\x03" .. string.char((us >> 16) & 0xFF, (us >> 8) & 0xFF, us & 0xFF))
    if t.num > 0 then
      add(t.q, 1, "\xFF\x58\x04" .. string.char(t.num, math.floor(math.log(t.den, 2) + 0.5), 24, 8))
    end
  end
  for _, x in ipairs(list) do
    add(x.q0, 3, string.char(0x90, x.midi, CFG.MIDI_VEL))
    add(x.q1, 2, string.char(0x80, x.midi, 0)) -- (a note ends before the next one starts on the same tick)
  end
  table.sort(ev, function(a, b)
    if a[1] ~= b[1] then return a[1] < b[1] end
    if a[2] ~= b[2] then return a[2] < b[2] end
    return a[3] < b[3]
  end)
  local body, last = {}, 0
  for _, e in ipairs(ev) do
    body[#body + 1] = vlq(e[1] - last) .. e[4]
    last = e[1]
  end
  body[#body + 1] = "\0\xFF\x2F\0"
  local track = table.concat(body)
  return "MThd" .. string.pack(">I4I2I2I2", 6, 0, 1, CFG.PPQ) .. "MTrk" .. string.pack(">I4", #track) .. track
end

-- The name of the export ("Far Away - Bass"), and the .mid file in the export folder (S.export_dir, else the project
-- folder; nil: no folder, the project is not saved).
function Export.name()
  local title = Out.title(Find.name(Find.item()))
  return (title ~= "" and title or "Song") .. " - Bass"
end
function Export.dir()
  if S.export_dir ~= "" then return (S.export_dir:gsub("[/\\]+$", "")) end
  return R.projfn:match("^(.*)[/\\]")
end
function Export.path()
  local dir = Export.dir()
  if not dir then return nil end
  return dir .. "/" .. Export.name():gsub('[\\/:*?"<>|]', "") .. ".mid"
end
-- The Guitar Pro file of a .mid path or name: the same name, .gp5.
function Export.gp_name(mid) return (mid:gsub("%.mid$", ".gp5")) end
-- Writes text to path; nil, or the notice text of a problem.
local function write_file(path, text)
  local f = io.open(path, "wb")
  if not f then return "Could not write " .. path .. " (is it open in another program?)." end
  f:write(text)
  f:close()
end

-- The MIDI item on the Bass MIDI track (below the bass; an older export of the Detection tab there is replaced).
function Export.item(list, q_start)
  local proj = R.proj
  local tr = Out.find_track("midi") or Out.make_track(CFG.MIDI_TRACK, "midi", true)
  Out.delete_marked(tr)
  local it = r.CreateNewMIDIItemInProj(tr, r.TimeMap2_QNToTime(proj, q_start), r.TimeMap2_QNToTime(proj, list[#list].q1), false)
  local take = r.GetActiveTake(it)
  for _, x in ipairs(list) do
    r.MIDI_InsertNote(take, false, false, r.MIDI_GetPPQPosFromProjQN(take, x.q0), r.MIDI_GetPPQPosFromProjQN(take, x.q1),
      0, x.midi, CFG.MIDI_VEL, true)
  end
  r.MIDI_Sort(take)
  r.GetSetMediaItemTakeInfo_String(take, "P_NAME", Export.name(), true)
  r.GetSetMediaItemInfo_String(it, CFG.TAG, "1", true)
  return it
end

-- Export: the MIDI item (1 undo step) and / or the .mid file. Returns the text of the notice, and true on a problem.
function Export.run(e)
  local list = Export.notes(P.notes, e.step)
  if #list == 0 then return "Nothing to export: find the notes first.", true end
  local _, m = r.TimeMap2_timeToBeats(R.proj, r.TimeMap2_QNToTime(R.proj, list[1].q0) + 1e-6)
  local q_start = r.TimeMap2_timeToQN(R.proj, r.TimeMap2_beatsToTime(R.proj, 0, m))
  local done = {}
  if e.item then
    r.Undo_BeginBlock2(R.proj)
    r.PreventUIRefresh(1)
    Export.item(list, q_start)
    r.PreventUIRefresh(-1)
    r.Undo_EndBlock2(R.proj, CFG.UNDO_NAME .. ": export MIDI", -1)
    List.step(CFG.UNDO_NAME .. ": export MIDI", true)
    r.TrackList_AdjustWindows(false)
    r.UpdateArrange()
    done[#done + 1] = "a MIDI item on the \"" .. CFG.MIDI_TRACK .. "\" track"
  end
  if e.file or e.gp then
    local made = #done > 0 and ("Made " .. done[1] .. ". ") or ""
    local path = Export.path()
    if not path then return made .. "No files: save the project first, or choose a folder.", true end
    r.RecursiveCreateDirectory(Export.dir(), 0)
    local names = {}
    if e.file then
      local why = write_file(path, Export.smf(list, Export.tempos(q_start, list[#list].q1), Export.name()))
      if why then return made .. why, true end
      names[#names + 1] = path:match("([^/\\]*)$")
    end
    if e.gp then
      local song = host.gp_song(Export.name())
      if not song then return made .. "No Guitar Pro file: find the notes first.", true end
      local gp = Export.gp_name(path)
      local why = write_file(gp, GP.write_gp5(song))
      if why then return made .. why, true end
      names[#names + 1] = gp:match("([^/\\]*)$")
    end
    done[#done + 1] = table.concat(names, " and ") .. (S.export_dir ~= "" and " in " .. S.export_dir or " in the project folder")
  end
  return string.format("Exported %d notes: %s.", #list, table.concat(done, ", "))
end

---------------------------------------------------------------------------
-- IMP (the tab and the list: Import to list takes the notes of Tab Viewer's tab; the found notes as a tab)
---------------------------------------------------------------------------
-- The tuning of CFG.TUNINGS with these open strings (nil: none).
function Imp.tuning(open)
  for _, t in ipairs(CFG.TUNINGS) do
    if #t.open == #open then
      local same = true
      for k, v in ipairs(open) do if t.open[k] ~= v then same = false end end
      if same then return t end
    end
  end
end
-- Import to list (the button of Tab Viewer's Tab tab, decided 24 November 2026): the notes of the tab (list =
-- { { t, t1, midi, s } } in project time; open: the open strings of its track) replace the notes of the list (the
-- strings of the tab; its tuning when it is in the list). The fixes of the found notes' tab are in them now (P.tab
-- goes). The list is made again from them; Undo brings all back. Returns the number of notes.
function Imp.apply(list, open)
  local proj = R.proj
  List.step()
  local tun = Imp.tuning(open)
  if tun then P.tuning = tun.id end
  P.notes, P.tab = {}, nil
  for _, x in ipairs(list) do
    P.notes[#P.notes + 1] = { t = x.t, t1 = x.t1, pc = x.midi % 12, midi = x.midi, s = x.s, man = true }
  end
  P.t_end = P.notes[#P.notes] and P.notes[#P.notes].t1 or nil
  P.rows = Group.make(P.notes, P.mode, P.key, proj, P.t_end or 0, List.opt())
  List.respell()
  R.sel, R.edit = nil, nil
  Util.mark_pdirty()
  return #P.notes
end

-- The found notes as a tab, for Tab Viewer's Tab tab where the song has no Guitar Pro tab (decided 24 November 2026),
-- in the form of GP.read: { found = true, tracks (1 bass track, the tuning of the list), mbars (the bars of the
-- project from the bar of the first note to the bar of the last one), m0 (the measure of its bar 1, from 0), tab() (a
-- new tab of the notes, as GP.tab gives it: Tab Viewer changes it) }. The notes on the 16th grid of the project (as the
-- export), with the strings and frets of the list (List.places). nil: no notes.
-- The tab of the found notes is written as a bass player writes it (the user, 24 November 2026: a staccato stem gave
-- a rest after almost every note): a note lasts until the next one when the gap is shorter than gap quarter notes;
-- only a longer gap is a rest. list: { q0, q1 } in order (Export.notes); changes q1.
function Imp.legato(list, gap)
  for i = 1, #list - 1 do
    local x, nx = list[i], list[i + 1]
    if nx.q0 > x.q1 and nx.q0 - x.q1 < gap - 1e-9 then x.q1 = nx.q0 end
  end
  return list
end
-- The grid of the tab of the found notes (the user, 24 November 2026: 8ths moved to 16ths, an extra 16th before a
-- note): list (Export.notes with step 0: q0, q1 not on a grid; man = from a tab) less the delay d -> on the grid.
-- 1. A start within CFG.TAB_PULL8 of an 8th goes on the 8th; else on the nearest 16th.
-- 2. A short note (at most a 16th) off the 8ths, straight before a note on an 8th that is longer: a scoop or a false
--    2nd pluck. The same note: 1 note (from the 8th); 1-2 semitones away: it goes (a slide into the note).
function Imp.grid(list, d)
  local function snap(q, man)
    if man then return math.floor(q / 0.25 + 0.5) * 0.25 end
    q = q - d
    local q8 = math.floor(q / 0.5 + 0.5) * 0.5
    if math.abs(q - q8) <= CFG.TAB_PULL8 then return q8 end
    return math.floor(q / 0.25 + 0.5) * 0.25
  end
  for _, x in ipairs(list) do
    x.q0, x.q1 = snap(x.q0, x.man), snap(x.q1, x.man)
    x.q1 = math.max(x.q1, x.q0 + 0.25)
  end
  table.sort(list, function(a, b) if a.q0 ~= b.q0 then return a.q0 < b.q0 end return a.i < b.i end)
  local out = {}
  for _, x in ipairs(list) do
    local p = out[#out]
    if p and x.q0 <= p.q0 + 1e-9 then -- (2 notes on 1 place: the first stays)
    elseif p and not p.man and x.q0 - p.q0 <= 0.25 + 1e-9 and p.q0 % 0.5 > 1e-9 and x.q0 % 0.5 < 1e-9
      and x.q1 - x.q0 > 0.25 + 1e-9 and math.abs(x.midi - p.midi) <= 2 then
      out[#out] = x -- (the short one before goes: the same note, or a slide into it)
    else
      if p and p.q1 > x.q0 then p.q1 = x.q0 end
      out[#out + 1] = x
    end
  end
  return out
end
function Imp.found_doc()
  if #P.notes == 0 then return nil end
  local proj, tun = R.proj, Key.tuning(P.tuning)
  local raw = Export.notes(P.notes, 0)
  local ons = {} -- (the found starts: the delay of the whole list, as the export)
  for _, x in ipairs(raw) do if not x.man then ons[#ons + 1] = x.q0 end end
  local list = Imp.grid(raw, #ons > 0 and Export.delay(ons) or 0)
  local places = List.places(P.notes, tun) -- (by the index of the saved note: x.i)
  local function measure(q) -- (the measure of a quarter note of the project, from 0)
    local _, m = r.TimeMap2_timeToBeats(proj, r.TimeMap2_QNToTime(proj, q) + 1e-6)
    return m
  end
  local m0, m1 = measure(list[1].q0), measure(list[#list].q1 - 1e-3)
  local mbars, starts = {}, {}
  for m = m0, math.max(m0, m1) do
    local _, qs, _, num, den = r.TimeMap_GetMeasureInfo(proj, m)
    mbars[#mbars + 1] = { num = math.max(1, math.floor(num)), den = math.max(1, math.floor(den)) }
    starts[#starts + 1] = qs
  end
  Imp.legato(list, CFG.TAB_GAP_Q)
  local open = tun.open
  local doc = { found = true, m0 = m0, mbars = mbars, tempos = 0,
    tracks = { { name = "Found notes", kind = "bass", inst = "Bass", open = open, capo = 0 } } }
  function doc.tab()
    local tab = { nstr = #open, names = {}, bars = {} }
    for s, m in ipairs(open) do tab.names[s] = GP.NAMES[m % 12] end
    for k, mb in ipairs(mbars) do
      local len = 4 * mb.num / mb.den
      tab.bars[k] = { q0 = starts[k] - starts[1], len = len, n16 = math.max(1, math.ceil(len * 4 - 1e-9)), notes = {},
        chords = {}, wb = k }
    end
    local k = 1
    for _, x in ipairs(list) do
      while starts[k + 1] and x.q0 >= starts[k + 1] - 1e-9 do k = k + 1 end
      local pl, b = places[x.i], tab.bars[k]
      if pl and b then
        local q = x.q0 - starts[k]
        local len = math.min(x.q1 - x.q0, b.len - q) -- (a note over the bar line: to the bar end; over: the rest of it,
        -- for the Guitar Pro export, Tabs.found_song)
        local over = x.q1 - x.q0 - len
        b.notes[#b.notes + 1] = { q = q, len = len, w = len, s = pl.s, fret = pl.f, over = over > 1e-3 and over or nil }
      end
    end
    return tab
  end
  return doc
end

---------------------------------------------------------------------------
-- TEMPO (Tab Viewer's Find tempo: what the list adds. The song's first note is the first found note of the list when
-- the song item is the bass item of the list, and the list moves with the audio.)
---------------------------------------------------------------------------
function N.first_note(tm)
  if P.src ~= tm.song.guid then return nil end
  local first
  for _, n in ipairs(P.notes) do if not n.man and (not first or n.t < first) then first = n.t end end
  return first
end
-- The list moves with the audio; the lists of other songs on the same bass item too (1 long item for several songs).
function N.shift(d, tm)
  if P.src == tm.song.guid and #P.notes > 0 then List.shift(d) end
  local l, key = R.lists, "src=" .. tostring(tm.song.guid) .. "\n"
  if not l then return end
  for _, id in ipairs(l.ids) do
    local txt = l.txt[id]
    if id ~= R.song and (txt .. "\n"):find(key, 1, true) then
      local h = R.hist[id] or { {}, {} }
      R.hist[id], h[1][#h[1] + 1], h[2] = h, txt, {} -- (its Undo brings it back)
      local p = List.parse(txt)
      List.move_all(p, d)
      Lists.set(l, id, List.serialize(p))
      R.pdirty = true
    end
  end
end
function N.set_extra(d)
  local s = ""
  if d and math.abs(d) >= 0.0005 and #P.mk > 0 then s = s .. " Write again: the markers follow the audio." end
  if #P.rows > 0 and P.mode == "bar" then s = s .. " Click Find notes again: the markers follow the new bars." end
  return s
end
function N.written() R.view = nil end -- (the bar numbers of the list)

---------------------------------------------------------------------------
-- TESTS: tests\notes.lua (through Tab Viewer's TabViewerTest.Notes) gets the modules
---------------------------------------------------------------------------
N.test = { CFG = CFG, S = S, R = R, Util = Util, Key = Key, Det = Det, Group = Group, List = List, Project = Project,
  Find = Find, Out = Out, Export = Export, Imp = Imp, GP = GP, TP = TP, UI = UI, Songs = Songs, Lists = Lists,
  get_P = function() return P end, set_P = function(p) P = p end, draw = function(h) N.draw(h) end,
  song_head = function() return N.song_head() end, song_go = function(dir, k) return N.song_go(dir, k) end }

---------------------------------------------------------------------------
-- UI (the Detection tab of Tab Viewer's window)
---------------------------------------------------------------------------
-- The window of Tab Viewer (its ImGui context), before the first frame.
function N.attach(c) ctx = c end

-- The Help topics of the Detection tab (Tab Viewer's Help shows them after its own).
N.HELP_TOPICS = {
  { title = "Detection: markers to learn the part", text = [[
# With a Guitar Pro tab
- Open it in the Tab tab.
- Tempo (at the top): From the tab, Find tempo, then Set tempo.
- Click Import from tab.
# Without a tab
- Put the separated bass on a track.
- Tempo: listen to the drums or a click, then Set tempo.
- Track: pick the bass. Click Find notes.
# Then
- Check the yellow lines (not sure).
- Click Write. 1 Ctrl+Z takes it all away.
- No plugins needed: Tab Viewer reads the audio itself.]] },
  { title = "Several songs in 1 project", text = [[
- Each song has its own list and tempo. A song is a region, or a bass item outside the regions.
- Which song is it? The Song row at the top. Pick another song there, or use < and > (stop first).
- It follows the edit cursor (playing: the play position); its frame flashes when it changes. Between songs the last song stays.
- Rather pick it yourself? Turn off Settings > Detection > Follow the song.
- 1 long bass item for several regions? Find tempo and Find notes listen only to the part in the song.
- Write, Clear and Export change only that song.]] },
  { title = "Checking the list", text = [[
- Click a line: it plays in a loop. Space or Escape: stop.
- Up / Down: the line before or after. N: the next yellow line.
- Double-click (or F2): type other notes, for example F (D 3).
- After a fix, Tab Viewer offers the same fix for the same notes (the Repeats column).
- Yellow but right? Click OK, or right-click > Sure.
- Join, Split (at the edit cursor), + Add, Delete. Right-click a line: more.
- Undo / Redo arrows: Ctrl+Z / Ctrl+Shift+Z.
- Start again? More... > Clear... (Undo brings it back).]] },
  { title = "The found notes as a tab", text = [[
- After Find notes, the Tab tab shows them as a bass tab.
- Fix them there, then click Import to list.
- Find notes again: a new tab (Undo: the old one).]] },
  { title = "How the notes become markers", text = [[
- Lines: 1 per bar, or Every note change. Write makes 1 marker of each line.
- 1 per bar: a bar with the same notes as the bar before gets none.
- A note belongs to the bar where it starts (up to 30 ms early counts as the 1).]] },
  { title = "Key and note names", text = [[
- Key: from the file name. Pick another: all names change (Ab or G#).
- New key in the song? Right-click its first line > New key from here.
- Low notes: the plain name ("E"). Higher: string and fret ("E (A 7)").
- Runs of 4 notes or more: string and fret for each note, with the fewest hand moves.
- Repeated notes missed? Settings > Detection > Split repeated notes.
- Numbers as in tab books ("E (3 7)")? Settings > Detection > String names.
- Only names? Turn off Settings > Detection > String for high notes and Fingering for runs.
- Tuning: pick the bass tuning of the song. The list follows.]] },
  { title = "Markers or a Notes track", text = [[
- The dropdown next to Write: markers, text items on a Notes track, or both.
- Write again any time: only the Detection tab's markers and items are replaced.]] },
  { title = "Export (Guitar Pro, MIDI)", text = [[
- More... > Export...
- Guitar Pro (.gp5): the notes as the Tab tab shows them. Guitar Pro 5 to 8 open it.
- MIDI: an item on a "Bass MIDI" track, and a .mid file. Rhythm: to 16ths, 8ths, or not.
- The files go to the project folder, or Folder > Change...
- Your typed corrections are not in the export.]] },
  { title = "Done: clean up", text = [[
- More... > Done: clean up: a region over the song (artist, title, key). Is the song a region? That region gets the name.
- If you like: it removes the bass track's plugins and the metronome track.
- The list leaves the project. The markers and the Notes track stay.
- Ctrl+Z brings the plugins and tracks back.]] },
  { title = "Why are some notes wrong?", text = [[
- Fast fills, slides, or other instruments left in the bass file.
- 2 methods listen. Where they disagree, the line is yellow. Listen once anyway.
- A fading note can turn into its overtone (a 5th higher): yellow too.]] },
}
local MODES = { { "bar", "1 per bar" }, { "change", "Every note change" } }
-- An example of each Lines choice (the grey line under it).
local MODE_EXAMPLE = { bar = "For example: Bar 5: C - G", change = "For example: C, then G, then F" }
local OUTS = { { "markers", "Markers" }, { "track", "Notes track" }, { "both", "Markers and Notes track" } }

-- UI.trunc, kept per text until the width changes (the rows of the list: not cut again every frame).
function UI.trunc_c(text, w)
  R.tc = R.tc or {}
  local e = R.tc[text]
  if e and e.w == w then return e.s end
  local cut = UI.trunc(text, w)
  R.tc[text] = { w = w, s = cut }
  return cut
end

-- A question with 2 buttons (a popup in the window). no / no_fn: the 2nd button (else "Cancel").
function UI.ask(text, yes, fn, no, no_fn)
  R.ask = { text = text, yes = yes, fn = fn, no = no, no_fn = no_fn, open = true }
end
function UI.draw_ask()
  local a = R.ask
  if not a then return end
  if a.open then ImGui.OpenPopup(ctx, "Tab Viewer##ask"); a.open = false end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if ImGui.BeginPopupModal(ctx, "Tab Viewer##ask", nil, ImGui.WindowFlags_AlwaysAutoResize()) then
    ImGui.PushTextWrapPos(ctx, 360)
    ImGui.Text(ctx, a.text)
    ImGui.PopTextWrapPos(ctx)
    UI.vgap(8)
    local no = a.no or "Cancel"
    if UI.button(a.yes, UI.btn_w(a.yes, 120)) then R.ask = nil; ImGui.CloseCurrentPopup(ctx); a.fn() end
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if UI.button(no, UI.btn_w(no, 90)) then
      R.ask = nil
      ImGui.CloseCurrentPopup(ctx)
      if a.no_fn then a.no_fn() end
    end
    ImGui.EndPopup(ctx)
  else
    R.ask = nil
  end
end

-- The texts of the list (rebuilt after a change of the list or the project, not every frame).
function UI.view()
  if R.view then return R.view end
  local count, v = {}, { n_doubt = 0 }
  for _, row in ipairs(P.rows) do count[row.text] = (count[row.text] or 0) + 1 end
  -- the lines of the table: the rows, and a "Key: D major" line before the row where a key change starts
  v.items, v.item_of = {}, {}
  for i, row in ipairs(P.rows) do
    v[i] = { num = tostring(i), bar = Group.bar_text(R.proj, row.t), places = tostring(count[row.text]) }
    if row.doubt then v.n_doubt = v.n_doubt + 1 end
    local k = List.key_change(i)
    if k then v.items[#v.items + 1] = { key = "Key: " .. P.keys[k].key, row = i } end
    v.items[#v.items + 1] = { row = i }
    v.item_of[i] = #v.items
  end
  v.status = #P.rows == 0 and "" or string.format("%d %s", #P.rows, #P.rows == 1 and "line" or "lines")
    .. (v.n_doubt > 0 and string.format(", %d not sure", v.n_doubt) or "")
  R.view = v
  return v
end

-- Plays from a time (while playing: jumps there).
function UI.play_at(t)
  local playing = r.GetPlayStateEx(R.proj) & 1 == 1
  r.SetEditCurPos2(R.proj, t, true, playing)
  if not playing then r.OnPlayButtonEx(R.proj) end
end
-- The time of row i: its start to the start of the next row (the last row: to the end of the bass item, at most
-- CFG.LOOP_LAST s). nil: no such row.
function List.row_span(i)
  local row = P.rows[i]
  if not row then return nil end
  local nx = P.rows[i + 1]
  local t1 = nx and nx.t or math.min(P.t_end or math.huge, row.t + CFG.LOOP_LAST)
  return row.t, math.max(t1, row.t + 0.2)
end
-- Plays a row in a loop (the musician review, decided 24 November 2026: hear a note again and again): REAPER's time
-- selection over the row, repeat on, from its start. Space, Escape, a stop or another project end it (Loop.off).
function UI.play_row(i)
  local t0, t1 = List.row_span(i)
  if not t0 then return end
  R.sel = i
  host.loop_off() -- (the bar loop of the Tab tab ends first: 1 loop at a time, so both give back what was before)
  local old = R.loop or { rep = r.GetSetRepeatEx(R.proj, -1), ts = { r.GetSet_LoopTimeRange2(R.proj, false, true, 0, 0, false) } }
  R.loop = { proj = R.proj, rep = old.rep, ts = old.ts, t0 = t0, t1 = t1, since = r.time_precise() }
  r.GetSet_LoopTimeRange2(R.proj, true, true, t0, t1, false)
  r.GetSetRepeatEx(R.proj, 1)
  UI.play_at(t0)
end
-- Ends the loop of a row: repeat and the time selection as before (the time selection only when it is still the
-- loop's: one that you made meanwhile stays).
function UI.loop_off()
  local l = R.loop
  if not l then return end
  R.loop = nil
  if not r.ValidatePtr(l.proj, "ReaProject*") then return end
  r.GetSetRepeatEx(l.proj, l.rep)
  local a, b = r.GetSet_LoopTimeRange2(l.proj, false, true, 0, 0, false)
  if math.abs(a - l.t0) < 1e-6 and math.abs(b - l.t1) < 1e-6 then
    r.GetSet_LoopTimeRange2(l.proj, true, true, l.ts[1], l.ts[2], false)
  end
end

function UI.select(i, play)
  if not P.rows[i] then return end
  R.scroll_to = i
  if play then UI.play_row(i) else R.sel = i end
end
function UI.edit_row(i)
  if not P.rows[i] then return end
  R.sel = i
  R.edit = { i = i, txt = P.rows[i].text, focus = true }
end
-- The typed notes of a row; then the question about the same notes in other rows.
function UI.commit_edit(i, txt)
  local old = List.set_text(i, txt)
  if not old then return end
  local same, new = List.same(old, i), P.rows[i].text
  if #same == 0 then return end
  UI.ask(string.format("%d other %s the same notes (%s). Change %s to %s too?", #same, #same == 1 and "place has" or "places have",
    old, #same == 1 and "it" or "them", new), string.format("Change all %d", #same + 1),
    function() List.set_all(same, new) end, "Only this one")
end
function UI.split(i)
  if not List.split(i, UI.cursor()) then
    UI.notice("1 note only: put the edit cursor where the new line starts, then Split.", true)
  end
end
-- Find notes: the item of the Track row (Find.source) fills the list of its song (another song: that list shows first).
function UI.find()
  local item, take = Find.source()
  if not item then UI.notice(take, true); return end
  local pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local _, g = r.GetSetMediaItemInfo_String(item, "GUID", "", false)
  local s = Songs.for_item(Songs.get(), { id = g, t0 = pos, t1 = pos + r.GetMediaItemInfo_Value(item, "D_LENGTH") }, R.song)
  if s then Lists.switch(s.id) end
  local function go() Find.begin(item, take) end
  if #P.rows > 0 then
    UI.ask("Find the notes again? The new list replaces this one (Undo brings it back).", "Find notes", go)
  else
    go()
  end
end

function UI.row_menu()
  if R.menu_open then R.menu_open = nil; ImGui.OpenPopup(ctx, "##row_menu") end
  if not ImGui.BeginPopup(ctx, "##row_menu") then return end
  local i = R.menu_row
  local row = i and P.rows[i]
  if not row then ImGui.CloseCurrentPopup(ctx)
  else
    if ImGui.MenuItem(ctx, "Type the notes...", "F2") then UI.edit_row(i) end
    if ImGui.MenuItem(ctx, "Sure", nil, false, row.doubt) then List.checked(i) end
    ImGui.Separator(ctx)
    if ImGui.MenuItem(ctx, "Join with the next line", nil, false, P.rows[i + 1] ~= nil) then List.join(i) end
    if ImGui.MenuItem(ctx, "Split") then UI.split(i) end
    if ImGui.MenuItem(ctx, "Move to the edit cursor") then R.sel = List.move(i, r.GetCursorPositionEx(R.proj)) end
    ImGui.Separator(ctx)
    if ImGui.BeginMenu(ctx, "New key from here") then
      local cur = List.key_at(row.t)
      for _, k in ipairs(Key.LIST) do
        if ImGui.MenuItem(ctx, k, nil, k == cur) and k ~= cur then List.key_from(i, k) end
      end
      ImGui.EndMenu(ctx)
    end
    if List.key_change(i) and ImGui.MenuItem(ctx, "Remove the key change") then List.key_from(i, "") end
    ImGui.Separator(ctx)
    if ImGui.MenuItem(ctx, "Delete", "Del") then List.delete(i) end
  end
  ImGui.EndPopup(ctx)
end

-- The "Notes" heading: the count of the lines and Next not sure at its right (while Find notes listens: the
-- progress under it), then the bass item.
local HEAD_NEXT = { "Next not sure", "ghost", false, "Go to the next yellow line and play it (N)." } -- (made once)
function UI.draw_top(v)
  if R.find then
    UI.heading("Notes")
    ImGui.ProgressBar(ctx, R.find.done or 0, ImGui.GetContentRegionAvail(ctx), ImGui.GetFrameHeight(ctx), "Listening...")
    return
  end
  local doubt = v.n_doubt > 0
  if UI.heading("Notes", false, doubt and HEAD_NEXT or nil, nil, v.status, doubt and COL.YELLOW or COL.TEXT_DIM) then
    UI.select(List.next_doubtful(R.sel), true)
  end
  if #P.rows == 0 then return end -- (the empty list says what to do)
  local room = math.max(40, ImGui.GetContentRegionAvail(ctx))
  if not R.src_name then
    local nm = Find.name(Find.item())
    R.src_name = nm ~= "" and ("Bass: " .. nm) or #P.notes > 0 and "The notes of the tab (Import to list)." or ""
  end
  if R.src_name == "" then return end
  UI.row_text(UI.trunc_c(R.src_name, room), COL.TEXT_DIM)
  UI.tip(R.src_name)
end

local STRING_STYLES = { { "letters", "Letters (E A D G)" }, { "numbers", "Numbers (4 3 2 1)" } }
-- Settings > Detection (Tab Viewer's Settings tab draws its heading). 1 mode (decided 25 November 2026).
function N.draw_settings()
  local ch, pick
  local function dirty(c) if c then R.sdirty = true end end -- (the Detection settings: saved by Notes.lua)
  ch, S.song_follow = UI.set_toggle("Follow the song", S.song_follow,
    "On (the default): the song at the top follows the edit cursor (playing: the play position). Off: only the arrows and the song list change it.")
  dirty(ch)
  ch, S.frets = UI.set_toggle("String for high notes", S.frets,
    "On (the default): high notes get string and fret, \"E (A 7)\". For the next Find notes.")
  dirty(ch)
  ch, S.finger = UI.set_toggle("Fingering for runs", S.finger,
    "On (the default): runs of 4+ notes get string and fret, with the fewest hand moves. For the next Find notes.")
  dirty(ch)
  ch, S.splits = UI.set_toggle("Split repeated notes", S.splits,
    "Off (the default). On: finds missed repeated plucks (after Set tempo). Held notes cut up? Turn it off. For the next Find notes.")
  dirty(ch)
  pick = UI.set_combo("String names", S.strings, STRING_STYLES,
    "\"E (A 7)\" or, as in tab books, \"E (3 7)\". For the next Find notes.")
  if pick then S.strings = pick; R.sdirty = true end
end

-- The Done: clean up window (More...; a popup in the window).
function UI.draw_finish()
  local f = R.finish
  if not f then return end
  if f.open then ImGui.OpenPopup(ctx, "Done: clean up##finish"); f.open = false end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if not ImGui.BeginPopupModal(ctx, "Done: clean up##finish", nil, ImGui.WindowFlags_AlwaysAutoResize()) then R.finish = nil; return end
  local x0 = ImGui.GetCursorPosX(ctx)
  local function field(label, v)
    UI.label(label)
    ImGui.SetCursorPosX(ctx, x0 + 60)
    ImGui.SetNextItemWidth(ctx, 240)
    local _, nv = ImGui.InputText(ctx, "##fin_" .. label, v)
    return nv
  end
  f.artist = field("Artist", f.artist)
  f.title = field("Title", f.title)
  UI.label("Region")
  ImGui.SetCursorPosX(ctx, x0 + 60)
  UI.row_text(UI.trunc(Out.region_name(f.artist, f.title, P.key), 240), COL.TEXT_DIM)
  local ch
  if f.fx > 0 then
    if f.fx_label == nil then
      f.fx_label = string.format("Remove the plugins from %s (%d)", UI.trunc(f.track_name, 120), f.fx)
    end
    ch, f.del_fx = UI.toggle_line(f.fx_label, f.del_fx, "All the plugins on the track of the bass item.")
  end
  if #f.clicks > 0 then
    if f.click_label == nil then
      local t = {}
      for i, c in ipairs(f.clicks) do t[i] = c.name end
      f.click_tip = table.concat(t, ", ")
      f.click_label = UI.trunc("Delete the metronome track: " .. f.click_tip, 280)
    end
    ch, f.del_clicks = UI.toggle_line(f.click_label, f.del_clicks, "Deletes: " .. f.click_tip)
  end
  if not f.fresh then
    ImGui.PushTextWrapPos(ctx, x0 + 300)
    ImGui.TextColored(ctx, COL.YELLOW, "The list is not written since your last change. Cancel and click Write first?")
    ImGui.PopTextWrapPos(ctx)
  end
  ImGui.PushTextWrapPos(ctx, x0 + 300)
  ImGui.TextColored(ctx, COL.TEXT_DIM, "The list leaves the project. The markers and the Notes track stay.")
  ImGui.PopTextWrapPos(ctx)
  UI.vgap(8)
  if UI.button("Clean up", 100, nil, "primary") then
    ImGui.CloseCurrentPopup(ctx)
    local name = Out.finish(f)
    UI.notice(name ~= "" and ("Done. Region: " .. name) or "Done. No region (no artist, title or key).")
  end
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Cancel", 90) then ImGui.CloseCurrentPopup(ctx); R.finish = nil end
  ImGui.EndPopup(ctx)
end

-- The Export window (a popup in the window).
function UI.draw_export()
  local e = R.export
  if not e then return end
  if e.open then
    ImGui.OpenPopup(ctx, "Export##export")
    e.open, e.path = false, nil
  end
  if e.path == nil then -- (again after Change...)
    e.path = Export.path() or false
    e.file_label = e.path and e.path:match("([^/\\]*)$") or nil
    e.dir_label = S.export_dir ~= "" and UI.trunc(S.export_dir, 190) or "The project folder"
    e.files_for = nil
  end
  local which = (e.file and 1 or 0) + (e.gp and 2 or 0) -- (the File line: only when a switch changes)
  if e.path and e.files_for ~= which then
    local mid, gp = e.file_label, Export.gp_name(e.file_label)
    e.files_for = which
    e.files_txt = which == 3 and ("Files: " .. mid .. ", " .. gp) or which == 1 and ("File: " .. mid)
      or which == 2 and ("File: " .. gp) or ""
  end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if not ImGui.BeginPopupModal(ctx, "Export##export", nil, ImGui.WindowFlags_AlwaysAutoResize()) then R.export = nil; return end
  local x0 = ImGui.GetCursorPosX(ctx)
  e.item = select(2, UI.toggle_line("MIDI item on a \"" .. CFG.MIDI_TRACK .. "\" track", e.item,
    "Below the bass, to listen to. Replaces an older export."))
  ImGui.BeginDisabled(ctx, not e.path)
  e.file = select(2, UI.toggle_line(".mid file", e.file and e.path ~= false,
    "For another program. Replaces a file with the same name."))
  e.gp = select(2, UI.toggle_line("Guitar Pro file", e.gp and e.path ~= false,
    "A .gp5 file of the Tab tab (Guitar Pro 5 to 8). Replaces a file with the same name."))
  ImGui.EndDisabled(ctx)
  UI.label("Folder")
  UI.row_text(e.dir_label, COL.TEXT_DIM)
  UI.tip(S.export_dir ~= "" and S.export_dir or "The folder of the project. Change... picks another folder for all songs.")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Change...", UI.btn_w("Change...")) then
    local dir = Util.browse_folder("Export folder", Export.dir())
    if dir then S.export_dir, R.sdirty, e.path = dir, true, nil end
  end
  UI.tip("Pick the folder of the .mid files. It stays for all songs (on this computer).")
  if S.export_dir ~= "" then
    ImGui.SameLine(ctx, 0, 4)
    if UI.button("x", 26, nil, "ghost") then S.export_dir, R.sdirty, e.path = "", true, nil end
    UI.tip("Back to the project folder.")
  end
  UI.label("Rhythm")
  local cur = CFG.GRIDS[1][2]
  for _, g in ipairs(CFG.GRIDS) do if g[1] == e.step then cur = g[2] end end
  ImGui.SetNextItemWidth(ctx, CFG.MODE_W)
  if ImGui.BeginCombo(ctx, "##grid", cur) then
    for _, g in ipairs(CFG.GRIDS) do if ImGui.Selectable(ctx, g[2], g[1] == e.step) then e.step = g[1] end end
    ImGui.EndCombo(ctx)
  end
  UI.tip("Moves the MIDI notes onto the grid.")
  ImGui.PushTextWrapPos(ctx, x0 + 320)
  if e.path then
    if e.files_txt ~= "" then ImGui.TextColored(ctx, COL.TEXT_DIM, e.files_txt) end
  else
    ImGui.TextColored(ctx, COL.YELLOW, "The project is not saved yet: save it, or choose a folder, to get the files.")
  end
  ImGui.TextColored(ctx, COL.TEXT_DIM, "The notes that Find notes found. Your text corrections in the list are not in it.")
  ImGui.PopTextWrapPos(ctx)
  UI.vgap(8)
  ImGui.BeginDisabled(ctx, not (e.item or e.file or e.gp))
  if UI.button("Export", 100, nil, "primary") then
    ImGui.CloseCurrentPopup(ctx)
    R.export = nil
    UI.notice(Export.run(e))
  end
  ImGui.EndDisabled(ctx)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Cancel", 90) then ImGui.CloseCurrentPopup(ctx); R.export = nil end
  ImGui.EndPopup(ctx)
end

local FIND_TIP = "Listens to the bass track and fills the list."
local FIND_AGAIN_TIP = "Listen again: a new list (Undo brings this one back)."
local IMPORT_TIP = "The notes of the Tab tab become the list."
local NEED_TEMPO = "Set the tempo first (Tempo, above): the notes go on the song's bars."
-- The buttons of the Bass heading (made once; their state is set each frame): Import from tab (only with a tab),
-- Find notes or Cancel.
local NB_IMPORT, NB_FIND = { "Import from tab" }, { "Find notes" }
local NB_CANCEL = { "Cancel", nil, false, "Stop. The list stays as it was." }
local NB_TWO, NB_TWO_RUN = { NB_IMPORT, NB_FIND }, { NB_IMPORT, NB_CANCEL }
-- The "Bass" section of the Detection tab (the UI/UX review of 25 November 2026, in the order of the work; folding:
-- 26 November 2026; "Bass", the buttons in the heading: 26 November 2026): Import from tab and Find notes at the
-- right of the heading (both wait for the Tempo section; the blue one is the next step: Import from tab with a tab,
-- else Find notes, only without a list; while it listens: Cancel), then Track, Key and Tuning on 1 row (2 rows when
-- narrow), Lines. The Tempo section: Tab Viewer's UI.draw_tempo_step.
function UI.draw_song()
  local has, ok = #P.rows > 0, UI.tempo_ok()
  local tab = host.R.tab ~= nil -- (Import from tab only with a tab: decided 26 November 2026)
  local busy = host.R.tempo ~= nil and host.R.tempo.run ~= nil
  NB_IMPORT[2], NB_IMPORT[3], NB_IMPORT[4] = ok and not has and "primary" or nil, R.find ~= nil or not ok,
    not ok and NEED_TEMPO or IMPORT_TIP
  NB_FIND[2], NB_FIND[3] = ok and not has and not tab and "primary" or nil, busy or not ok
  NB_FIND[4] = not ok and NEED_TEMPO or busy and "Wait for Find tempo." or has and FIND_AGAIN_TIP or FIND_TIP
  local btns = R.find and (tab and NB_TWO_RUN or NB_CANCEL) or (tab and NB_TWO or NB_FIND)
  local hit, open = UI.heading("Bass", false, btns, UI.FOLD_SONG,
    R.find and "Listening..." or has and "Notes found" or "No notes yet", has and not R.find and COL.GREEN or COL.TEXT_DIM)
  if hit then
    local b = type(hit) == "number" and btns[hit] or btns
    if b == NB_CANCEL then Find.cancel()
    elseif b == NB_FIND then UI.find()
    elseif b == NB_IMPORT then UI.import_to_list() end
  end
  if not open then return end
  local fw = UI.field_w()
  -- Track: the bass track that Find notes listens to
  UI.field("Track")
  local tr = Find.track()
  if R.trk_for ~= tr then R.trk_for, R.trk_lbl = tr, nil end
  R.trk_lbl = R.trk_lbl or (tr and Find.track_label(tr) or "Pick the bass track")
  ImGui.BeginDisabled(ctx, R.find ~= nil)
  ImGui.SetNextItemWidth(ctx, fw)
  if ImGui.BeginCombo(ctx, "##ndtrack", R.trk_lbl) then
    local list = Find.tracks()
    if not list[1] then ImGui.TextDisabled(ctx, "No tracks with audio yet.") end
    for _, e in ipairs(list) do
      if ImGui.Selectable(ctx, e.label, e.tr == tr) then R.trk = e.tr end
    end
    ImGui.EndCombo(ctx)
  end
  ImGui.EndDisabled(ctx)
  UI.tip_disabled("The separated bass (bass only, for now).")
  if not ok then -- (why they are grey: on the screen, not only in the tooltip)
    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + host.CFG.LABEL_W)
    ImGui.TextColored(ctx, COL.TEXT_DIM, NEED_TEMPO)
  end
  -- Key and Tuning: 1 row, the Tuning dropdown ends where the others end; no room: 2 rows
  UI.field("Key")
  local tw = fw - CFG.KEY_W - CFG.CTRL_GAP - CFG.TUNE_LABEL_W
  local one_row = tw >= CFG.TUNE_MIN_W
  ImGui.SetNextItemWidth(ctx, one_row and CFG.KEY_W or fw)
  if ImGui.BeginCombo(ctx, "##key", P.key ~= "" and P.key or "Not known") then
    for _, k in ipairs(Key.LIST) do
      if ImGui.Selectable(ctx, k, k == P.key) then List.set_key(k) end
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("The key decides the note names (Ab or G#).")
  if one_row then
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    local x = ImGui.GetCursorPosX(ctx)
    UI.label("Tuning")
    ImGui.SetCursorPosX(ctx, x + CFG.TUNE_LABEL_W)
  else
    UI.field("Tuning")
  end
  local tun = Key.tuning(P.tuning)
  ImGui.BeginDisabled(ctx, R.find ~= nil)
  ImGui.SetNextItemWidth(ctx, one_row and tw or fw)
  if ImGui.BeginCombo(ctx, "##tuning", tun.label) then
    for _, t in ipairs(CFG.TUNINGS) do
      if ImGui.Selectable(ctx, t.label, t.id == P.tuning) and t.id ~= P.tuning then
        local heard = List.set_tuning(t.id)
        if #P.rows > 0 then
          UI.notice("Tuning: " .. t.label .. ". The strings and frets follow it" .. (heard > 0
            and string.format("; %d low %s heard again for the octave.", heard, heard == 1 and "note" or "notes") or ".")
            .. " Undo brings the old list back.")
        end
      end
    end
    ImGui.EndCombo(ctx)
  end
  ImGui.EndDisabled(ctx)
  UI.tip_disabled("The bass tuning of this song.")
  UI.field("Lines")
  local cur = MODES[1][2]
  for _, m in ipairs(MODES) do if m[1] == P.mode then cur = m[2] end end
  local locked = #P.rows > 0 and #P.notes == 0
  ImGui.BeginDisabled(ctx, locked or R.find ~= nil)
  ImGui.SetNextItemWidth(ctx, fw)
  if ImGui.BeginCombo(ctx, "##mode", cur) then
    for _, m in ipairs(MODES) do
      if ImGui.Selectable(ctx, m[2], m[1] == P.mode) and m[1] ~= P.mode then
        if #P.rows > 0 then
          UI.ask("Make the list again? Your corrections go away (Undo brings them back).", "Make again", function() List.set_mode(m[1]) end)
        else
          List.set_mode(m[1])
        end
      end
    end
    ImGui.EndCombo(ctx)
  end
  ImGui.EndDisabled(ctx)
  UI.tip_disabled(locked and "Click Find notes again to change this." or "1 marker per line.")
  ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + host.CFG.LABEL_W) -- (under the dropdown)
  ImGui.TextColored(ctx, COL.TEXT_DIM, MODE_EXAMPLE[P.mode] or "")
end

function UI.draw_list(v, h)
  if #P.rows == 0 then -- (Find notes is in the Bass heading above, blue)
    ImGui.Dummy(ctx, 0, 4)
    ImGui.PushTextWrapPos(ctx, 0)
    ImGui.TextColored(ctx, COL.TEXT_DIM, R.find and "Listening to the bass..." or "No notes yet. Pick the bass track above, then click Find notes (bass only, for now). Have a Guitar Pro tab? Open it in the Tab tab, then click Import from tab.")
    ImGui.PopTextWrapPos(ctx)
    return
  end
  local flags = ImGui.TableFlags_ScrollY() | ImGui.TableFlags_BordersInnerH() | ImGui.TableFlags_PadOuterX()
  if not ImGui.BeginTable(ctx, "##rows", 4, flags, 0, h) then return end
  ImGui.TableSetupScrollFreeze(ctx, 0, 1)
  local fixed = ImGui.TableColumnFlags_WidthFixed()
  ImGui.TableSetupColumn(ctx, "#", fixed, CFG.COL_NUM_W)
  ImGui.TableSetupColumn(ctx, "Bar", fixed, CFG.COL_BAR_W)
  ImGui.TableSetupColumn(ctx, "Notes", ImGui.TableColumnFlags_WidthStretch(), 1)
  ImGui.TableSetupColumn(ctx, "Repeats", fixed, CFG.COL_PLACES_W)
  ImGui.TableHeadersRow(ctx)
  if not R.clipper or not ImGui.ValidatePtr(R.clipper, "ImGui_ListClipper*") then R.clipper = ImGui.CreateListClipper(ctx) end
  ImGui.ListClipper_Begin(R.clipper, #v.items)
  if R.scroll_to and v.item_of[R.scroll_to] then ImGui.ListClipper_IncludeItemByIndex(R.clipper, v.item_of[R.scroll_to] - 1) end
  if R.edit and v.item_of[R.edit.i] then -- (drawn until it is closed)
    ImGui.ListClipper_IncludeItemByIndex(R.clipper, v.item_of[R.edit.i] - 1)
  end
  local fh = ImGui.GetFrameHeight(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local now_row = r.GetPlayStateEx(R.proj) & 1 == 1 and List.at(UI.cursor()) or nil -- (a count-in: the song's start)
  local act -- (what changes the list: after the rows are drawn)
  while ImGui.ListClipper_Step(R.clipper) do
    local d0, d1 = ImGui.ListClipper_GetDisplayRange(R.clipper)
    for n = d0 + 1, math.min(d1, #v.items) do
      local item = v.items[n]
      local i = item.row
      local row, t = P.rows[i], v[i]
      ImGui.TableNextRow(ctx)
      if item.key then -- (a key change: a blue line before its row; right-click: the menu of that row)
        ImGui.TableNextColumn(ctx)
        ImGui.TableNextColumn(ctx)
        ImGui.TableNextColumn(ctx)
        UI.row_text(item.key, COL.HEADING)
        if ImGui.IsItemClicked(ctx, 1) then R.sel, R.menu_row, R.menu_open = i, i, true end
        UI.tip("The note names follow this key from here. Right-click: change or remove it.")
        goto next_item
      end
      ImGui.PushID(ctx, i)
      ImGui.TableNextColumn(ctx)
      local editing = R.edit and R.edit.i == i
      local x, y = ImGui.GetCursorScreenPos(ctx)
      local sflags = ImGui.SelectableFlags_SpanAllColumns() | ImGui.SelectableFlags_AllowDoubleClick() | ImGui.SelectableFlags_AllowOverlap()
      if ImGui.Selectable(ctx, "##row", R.sel == i, sflags, 0, fh) and not editing then
        if ImGui.IsMouseDoubleClicked(ctx, 0) then act = { "edit", i } else act = { "play", i } end
      end
      if ImGui.IsItemClicked(ctx, 1) then R.sel, R.menu_row, R.menu_open = i, i, true end
      if R.scroll_to == i then ImGui.SetScrollHereY(ctx, 0.5); R.scroll_to = nil end
      local col = row.doubt and COL.YELLOW or COL.TEXT_MAIN
      if i == now_row then -- (the line that plays: a blue mark at the left)
        ImGui.DrawList_AddRectFilled(dl, x - 4, y + 3, x - 1, y + fh - 3, COL.ACCENT, 1)
      end
      ImGui.DrawList_AddText(dl, x, UI.text_y(y, fh), COL.TEXT_DIM, t.num)
      ImGui.TableNextColumn(ctx)
      UI.row_text(t.bar, COL.TEXT_DIM)
      ImGui.TableNextColumn(ctx)
      local cw = ImGui.GetContentRegionAvail(ctx)
      local e = R.edit
      if e and editing then
        ImGui.SetNextItemWidth(ctx, cw)
        if e.focus then ImGui.SetKeyboardFocusHere(ctx) end
        local _, nv = ImGui.InputText(ctx, "##edit", e.txt, ImGui.InputTextFlags_AutoSelectAll())
        e.txt = nv
        e.focus = nil
        if ImGui.IsItemActive(ctx) then e.live = true
        elseif e.live then act = { ImGui.IsKeyPressed(ctx, ImGui.Key_Escape(), false) and "stop" or "commit", i, e.txt } end
      else
        UI.row_text(UI.trunc_c(row.text, cw), col)
        if ImGui.IsItemHovered(ctx) then -- (the text only when it shows)
          ImGui.SetTooltip(ctx, row.text .. (row.doubt and "\n" .. List.why(i) or "") .. "\nClick: hear it in a loop. Double-click: type the notes.")
        end
      end
      ImGui.TableNextColumn(ctx)
      UI.row_text(t.places, COL.TEXT_DIM)
      if row.doubt and not editing then
        ImGui.SameLine(ctx, 0, 4)
        if UI.button("OK", 34, fh, "ghost") then act = { "ok", i } end
        UI.tip("These notes are right: no longer yellow.")
      end
      ImGui.PopID(ctx)
      ::next_item::
    end
  end
  UI.row_menu()
  ImGui.EndTable(ctx)
  if act then
    if act[1] == "edit" then UI.edit_row(act[2])
    elseif act[1] == "play" then UI.play_row(act[2])
    elseif act[1] == "ok" then List.checked(act[2])
    elseif act[1] == "stop" then R.edit = nil
    else R.edit = nil; UI.commit_edit(act[2], act[3]) end
  end
end

-- Join, Split, + Add, Delete; then Write, its dropdown and More... (Export, Done: clean up, Clear...). Only with a list.
-- A ghost button of the foot (off: grey, its tip still shows); true when clicked.
function UI.foot_btn(label, on, tip)
  ImGui.BeginDisabled(ctx, not on)
  local hit = UI.button(label, UI.btn_w(label), nil, "ghost")
  ImGui.EndDisabled(ctx)
  UI.tip_disabled(tip)
  ImGui.SameLine(ctx, 0, 2)
  return hit
end
function UI.draw_foot()
  local aw = ImGui.GetContentRegionAvail(ctx)
  local sel = R.sel and P.rows[R.sel] and R.sel or nil
  if UI.foot_btn("Join", sel ~= nil and P.rows[sel + 1] ~= nil, "Puts the selected line together with the next one.") then List.join(sel) end
  if UI.foot_btn("Split", sel ~= nil, "Cuts the line at the edit cursor.") then UI.split(sel) end
  if UI.foot_btn("+ Add", true, "A new line at the edit cursor.") then
    local i = List.add(UI.cursor())
    UI.select(i)
    UI.edit_row(i)
  end
  if UI.foot_btn("Delete", sel ~= nil, "Deletes the selected line (Delete key).") then List.delete(sel) end
  ImGui.NewLine(ctx)
  -- Write (the main button; the musician review, 24 November 2026), what it makes, "Written (n markers)" until the
  -- list changes; Export and Done: clean up in More...
  local cur = OUTS[1][2]
  for _, o in ipairs(OUTS) do if o[1] == S.out then cur = o[2] end end
  local ww, mw = UI.btn_w("Write", 80), UI.btn_w("More...")
  local has = #P.rows > 0 and not R.find
  ImGui.BeginDisabled(ctx, not has)
  if UI.button("Write", ww, nil, "primary") then
    Out.write(S.out)
    UI.notice("Written. Changed your mind? Ctrl+Z (or the Undo arrow) takes it away again.")
  end
  ImGui.EndDisabled(ctx)
  UI.tip_disabled(has and "Writes the list into the project." or "Find the notes first.")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  local cw2 = math.max(60, math.min(CFG.OUT_W, aw - ww - mw - 2 * CFG.CTRL_GAP))
  ImGui.SetNextItemWidth(ctx, cw2)
  if ImGui.BeginCombo(ctx, "##out", cur) then
    for _, o in ipairs(OUTS) do
      if ImGui.Selectable(ctx, o[2], o[1] == S.out) then S.out = o[1]; R.sdirty = true end
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("What Write makes: markers, text items on a \"Notes\" track above the bass, or both.")
  if R.written_lbl then
    local room = aw - ww - cw2 - mw - 4 * CFG.CTRL_GAP
    if room > 40 then
      ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
      UI.row_text(UI.trunc_c(R.written_lbl, room), COL.GREEN)
      UI.tip("Written. After a change: Write again.")
    end
  end
  ImGui.SameLine(ctx, math.max(0, aw - mw))
  if UI.button("More...", mw) then ImGui.OpenPopup(ctx, "##ndmore") end
  UI.tip("Export, Done: clean up, Clear.")
  if ImGui.BeginPopup(ctx, "##ndmore") then
    do
      local can_export = #P.notes > 0 and not R.find
      if ImGui.MenuItem(ctx, "Export...", nil, false, can_export) then
        R.export = { item = true, file = true, gp = true, step = CFG.GRIDS[1][1], open = true }
      end
      UI.tip_disabled(can_export and "A Guitar Pro file, a MIDI item or a .mid file."
        or "Find notes first.")
    end
    if ImGui.MenuItem(ctx, "Done: clean up...", nil, false, has) then Out.finish_begin() end
    UI.tip_disabled(has and "Finished? A song region, and the list leaves the project." or "Find the notes first.")
    ImGui.Separator(ctx)
    if ImGui.MenuItem(ctx, "Clear...", nil, false, has) then
      UI.ask("Start again? This removes the list and what this tab wrote: its markers, the Notes track items and "
        .. "the Bass MIDI item. Your own markers, the tempo and the audio stay.\n\nUndo (or Ctrl+Z) brings it all back.", "Clear", Out.clear)
    end
    UI.tip_disabled("Removes the list and what this tab wrote.")
    ImGui.EndPopup(ctx)
  end
end

-- The Detection tab (in Tab Viewer's panel; h: the height it has): Tempo (Tab Viewer's), Song (Track with Find
-- notes, Key, Tuning, Lines), Notes (the count), the list, then the foot (Join ... Undo, Write, More...).
function N.draw(h)
  local v = UI.view()
  local y0 = ImGui.GetCursorPosY(ctx)
  UI.draw_tempo_step() -- (Tab Viewer's: Find tempo and Set tempo)
  UI.draw_song()
  UI.draw_top(v)
  local has = P.rows[1] ~= nil -- (the edit row, Write and More...: only with a list)
  local foot = has and 2 * ImGui.GetFrameHeight(ctx) + 2 * CFG.SP_ROW or 0
  local lh = math.max(60, h - (ImGui.GetCursorPosY(ctx) - y0) - foot)
  local y = ImGui.GetCursorPosY(ctx)
  UI.draw_list(v, lh)
  if not has then return end
  ImGui.SetCursorPosY(ctx, y + lh + CFG.SP_ROW)
  UI.draw_foot()
end
-- The windows of the Detection tab (the question, Done: clean up, Export): every frame, inside Tab Viewer's window.
function N.draw_popups()
  UI.draw_ask()
  UI.draw_finish()
  UI.draw_export()
end

-- The keys of the Detection tab (while it is open, the window has the focus and no field is typed in).
function N.keys()
  if not ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_RootAndChildWindows()) or ImGui.IsAnyItemActive(ctx)
    or R.edit or R.ask or R.finish or R.export or ImGui.IsPopupOpen(ctx, "", ImGui.PopupFlags_AnyPopup()) then return end
  local C, SH = ImGui.Mod_Ctrl(), ImGui.Mod_Shift()
  local function key(k, rep) return ImGui.IsKeyPressed(ctx, k, rep or false) end
  if ImGui.IsKeyChordPressed(ctx, C | ImGui.Key_Z()) then -- (the tab's steps first: the list, Write, Clear, Export)
    if #R.undo > 0 then List.undo() else r.Main_OnCommand(40029, 0) end -- Edit: Undo
  elseif ImGui.IsKeyChordPressed(ctx, C | SH | ImGui.Key_Z()) or ImGui.IsKeyChordPressed(ctx, C | ImGui.Key_Y()) then
    if #R.redo > 0 then List.undo(true) else r.Main_OnCommand(40030, 0) end -- Edit: Redo
  elseif ImGui.GetKeyMods(ctx) ~= ImGui.Mod_None() then return
  elseif key(ImGui.Key_Space()) then r.Main_OnCommand(40044, 0) -- Transport: Play/stop (a stop ends the loop: N.step)
  elseif key(ImGui.Key_Escape()) and R.loop then UI.loop_off()
  elseif key(ImGui.Key_N()) then UI.select(List.next_doubtful(R.sel), true)
  elseif key(ImGui.Key_UpArrow(), true) then UI.select(math.max(1, (R.sel or 2) - 1), true)
  elseif key(ImGui.Key_DownArrow(), true) then UI.select(math.min(#P.rows, (R.sel or 0) + 1), true)
  elseif key(ImGui.Key_F2()) and R.sel then UI.edit_row(R.sel)
  elseif key(ImGui.Key_Delete()) and R.sel then List.delete(R.sel) end
end

---------------------------------------------------------------------------
-- WHAT TAB VIEWER CALLS (besides N.draw, N.draw_popups, N.keys, N.draw_settings, N.attach, N.HELP_TOPICS and the
-- Find tempo hooks N.first_note, N.shift, N.set_extra, N.written)
---------------------------------------------------------------------------
-- Every frame, before the window: the list of the project (another project: its own), a running Find notes.
function N.step()
  Project.update()
  Find.step()
  Lists.follow()
  local l = R.loop -- (stopped: the loop ends; not in its first 0.5 s, while REAPER starts to play)
  if l and (l.proj ~= R.proj or r.GetPlayStateEx(R.proj) & 1 == 0 and r.time_precise() - l.since > 0.5) then UI.loop_off() end
end
-- The end of each frame: the list and the settings are saved when they changed (the settings not while a mouse button
-- is down: a toggle is clicked).
function N.save(mouse_down)
  if R.pdirty then Project.save() end
  if R.sdirty and not mouse_down then Util.save_settings() end
end
-- Ends the loop of a row (Tab Viewer: before its bar loop starts).
function N.loop_off() UI.loop_off() end
-- Transpose changed (from old): the names of the list again; a line that you corrected keeps your text.
function N.transposed(old)
  if not (P and #P.notes > 0) then return end
  List.remake(List.auto_rows(old))
  Util.mark_pdirty()
end
-- The toolbar's Undo / Redo in this tab (dir -1 / 1): false when the list has no step (then Tab Viewer uses REAPER's).
function N.has_undo(dir) return #(dir < 0 and R.undo or R.redo) > 0 end
function N.undo(dir)
  if not N.has_undo(dir) then return false end
  List.undo(dir > 0)
  return true
end
function N.has_rows() return P ~= nil and P.rows[1] ~= nil end
-- The line that the toolbar's |< (dir 0: the first one), < and > (dir -1 / 1: the line before / after the one at t)
-- and >| (dir 2: the last one) go to; nil: none.
function List.go(dir, t)
  local n = #P.rows
  if n == 0 then return nil end
  if dir == 0 then return 1 end
  if dir == 2 then return n end
  local cur = List.at(t)
  local i = cur and cur + dir or 1 -- (before the first line: < and > go to the first one)
  return i >= 1 and i <= n and i or nil
end
-- |<, <, > and >| of the toolbar: the line is selected, the edit cursor goes to its start (playing: the song jumps there).
function N.go(dir)
  local i = List.go(dir, UI.cursor())
  if not i then return end
  R.sel, R.scroll_to, R.edit = i, i, nil
  r.SetEditCurPos2(R.proj, P.rows[i].t, true, r.GetPlayStateEx(R.proj) & 1 == 1)
end
function N.exit()
  UI.loop_off()
  Find.cancel()
  if R.pdirty then Project.save() end
  if R.sdirty then Util.save_settings() end
end
function N.busy() return R.find ~= nil end -- (Find notes listens)
-- The Song row at the top of Tab Viewer's Tab and Detection tabs (decided 27 November 2026): { i (the shown song;
-- nil: none of them), n, flash (the time the list last followed the cursor to this song) }; nil: the project has no
-- songs. Made again only when the song or the songs change.
function N.song_head()
  local songs = Songs.get()
  if not songs[1] then return nil end
  local c = R.st
  if c and c.songs == songs and c.song == R.song then c.flash = R.flash; return c end
  c = { songs = songs, song = R.song, n = #songs }
  for k, s in ipairs(songs) do if s.id == R.song then c.i = k end end
  c.flash = R.flash
  R.st = c
  return c
end
-- The Song row's arrows (dir -1 / 1) and dropdown (k): that song shows, the edit cursor goes to its start and its
-- bass item is selected (false: playing, Find notes listens, or no such song).
function N.song_go(dir, k)
  local c = R.st
  if not c or R.find then return false end
  local i = k or (c.i and c.i + dir) or (dir > 0 and 1 or c.n)
  return Songs.go(c.songs[i])
end
-- The texts of the song list (Songs.labels: each song with its line count).
function N.song_list() return Songs.labels() end
-- The song of the Song row for Tab Viewer's Tempo section: its id (every frame), and its start and end (nil: none).
function N.song_id() return R.song end
function N.song_range()
  local s = Songs.cur()
  if s then return s.t0, s.t1 end
end
-- Import to list (Tab Viewer's Tab tab; list and open: Imp.apply): asks first when the list has notes. done(n): after
-- the import (n: the number of notes).
function N.import(list, open, done)
  local function go()
    local n = Imp.apply(list, open)
    UI.notice(string.format("Imported %d notes into the Notes list. Changed your mind? Undo in the Detection tab brings the old list back.", n))
    if done then done(n) end
  end
  if #P.rows > 0 then
    UI.ask("Replace the Notes list with the notes of this tab? Your list and its corrections go (Undo in the Detection tab brings them back).",
      "Replace", go)
  else
    go()
  end
end
-- The tab of the found notes (Imp.found_doc; nil: no notes) and its entry (your fixes, lines and start bar: P.tab, made
-- when it is missing; saved with the list).
function N.found_doc() return Imp.found_doc() end
function N.found_entry()
  if not P.tab then P.tab = {} end
  return P.tab
end
function N.touch() R.pdirty = true end -- (the entry changed: Tab Viewer fixed the tab of the found notes)

Util.load_settings()
P = List.default() -- (an empty list until the first frame reads the project: Tab Viewer may ask before)
return N
end
