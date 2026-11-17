-- @description Mono Merge: make stereo (with edits)
-- @version 1.0
-- @author Nick Gkogkomitros
-- @license MIT
-- @noindex
-- @about
--   Mono Merge - select 2 mono items and run the action: 1 new stereo file, the top item left, the other right.
--   "With edits" uses what you hear (trims, fades, item and take volume, take FX, rate); "raw files" uses the
--   full original files with only their start aligned. The shorter side gets silence. The new stereo item goes
--   on a new track below (REAPER's glue makes the file), and the 2 mono items are muted. 1 undo step.
--   No extensions needed.
-- @provides
--   [main] Mono Merge - Make stereo (raw files).lua
-- @changelog
--   First version.

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

local r = reaper

local CFG = {
  VERSION = "1.0",
  TITLE = "Mono Merge",
  GLUE = 40362, -- Item: Glue items, ignoring time selection
}

-- the mode: "edits" (this file run as an action) or "raw" (set by "Mono Merge - Make stereo (raw files).lua")
local MODE = rawget(_G, "MonoMergeMode") == "raw" and "raw" or "edits"
local TESTING = rawget(_G, "MonoMergeTest") ~= nil

---------------------------------------------------------------------------
-- Util: names
---------------------------------------------------------------------------
local Util = {}

local function trim_sep(s)
  return (s:gsub("^[%s%-_%.%(%)%[%]]+", ""):gsub("[%s%-_%.%(%)%[%]]+$", ""))
end

-- the common part of 2 names ("Kick In" + "Kick Out" = "Kick"); else "A + B"
function Util.common_name(a, b)
  a, b = trim_sep(a or ""), trim_sep(b or "")
  if a == "" then return b ~= "" and b or "Stereo" end
  if b == "" or a == b then return a end
  local n = 0
  while n < #a and n < #b and a:sub(n + 1, n + 1):lower() == b:sub(n + 1, n + 1):lower() do n = n + 1 end
  local pre = trim_sep(a:sub(1, n))
  n = 0
  while n < #a and n < #b and a:sub(-n - 1, -n - 1):lower() == b:sub(-n - 1, -n - 1):lower() do n = n + 1 end
  local suf = trim_sep(n > 0 and a:sub(-n) or "")
  local best = #pre >= #suf and pre or suf
  if #best >= 2 then return best end
  return a .. " + " .. b
end

---------------------------------------------------------------------------
-- Merge: check the 2 items, glue copies of them into 1 stereo item on a new track
---------------------------------------------------------------------------
local Merge = {}

local function root_source(src)
  while true do
    local parent = r.GetMediaSourceParent(src)
    if not parent then return src end
    src = parent
  end
end

local function item_name(item)
  local take = r.GetActiveTake(item)
  local name = take and select(2, r.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)) or ""
  return (name:gsub("%.%w+$", ""))
end

local function track_name(item)
  local _, name = r.GetTrackName(r.GetMediaItem_Track(item))
  return name
end

local CHANMODE = { [2] = "Mono (downmix)", [3] = "Mono (left)", [4] = "Mono (right)" }

-- nil when the item can be merged in this mode, else the message; in raw mode a stereo file that plays as mono
-- (take channel mode) gives nil + a question (use the channel mode anyway?)
function Merge.check(item, mode)
  local take = r.GetActiveTake(item)
  local name = item_name(item)
  if name == "" then name = track_name(item) end
  if not take or r.TakeIsMIDI(take) then
    return '"' .. name .. '" has no audio (MIDI or an empty item).'
  end
  local src = root_source(r.GetMediaItemTake_Source(take))
  local nch = r.GetMediaSourceNumChannels(src)
  local file = r.GetMediaSourceFileName(src)
  if nch < 1 or (file ~= "" and not r.file_exists(file)) then return '"' .. name .. '": its file is missing or offline.' end
  local chanmode = r.GetMediaItemTakeInfo_Value(take, "I_CHANMODE") -- 2-4: mono downmix, left, right
  if nch == 1 or (mode == "edits" and CHANMODE[chanmode]) then return nil end
  if CHANMODE[chanmode] then
    return nil, '"' .. name .. '" is a stereo file that plays as mono (Channel mode: ' .. CHANMODE[chanmode] ..
      ").\n\nRaw files ignores all edits. Use its channel mode anyway (and still ignore the other edits)?"
  end
  return '"' .. name .. '" is not mono (' .. nch .. " channels).\n\nMono Merge joins 2 mono items into 1 stereo file."
end

-- the 2 items in order: left = the item on the higher track; on the same track the earlier item
function Merge.order(a, b)
  local ta = r.GetMediaTrackInfo_Value(r.GetMediaItem_Track(a), "IP_TRACKNUMBER")
  local tb = r.GetMediaTrackInfo_Value(r.GetMediaItem_Track(b), "IP_TRACKNUMBER")
  if tb < ta then return b, a end
  if ta == tb and r.GetMediaItemInfo_Value(b, "D_POSITION") < r.GetMediaItemInfo_Value(a, "D_POSITION") then
    return b, a
  end
  return a, b
end

-- the name of the result: the common part of the track names; on 1 track, of the item names
function Merge.name(left, right)
  if r.GetMediaItem_Track(left) ~= r.GetMediaItem_Track(right) then
    return Util.common_name(track_name(left), track_name(right))
  end
  return Util.common_name(item_name(left), item_name(right))
end

-- a copy of the item on the new track, panned hard to its side (-1 left, 1 right): "edits" = the same item
-- (unmuted); "raw" = the whole source file at pos, without fades or volume (the take channel mode is kept)
local function place_copy(tr, item, mode, pan, pos, offs)
  local copy = r.AddMediaItemToTrack(tr)
  if mode == "edits" then
    local _, chunk = r.GetItemStateChunk(item, "", false)
    chunk = chunk:gsub("\n%s*I?GUID [^\n]*", ""):gsub("\n%s*GROUP [^\n]*", "")
    r.SetItemStateChunk(copy, chunk, false)
    r.SetMediaItemInfo_Value(copy, "B_MUTE", 0)
    r.SetMediaItemInfo_Value(copy, "C_LOCK", 0) -- REAPER does not glue a locked item
    -- a take pan envelope would override the hard pan: turn it off on the copy
    local env = r.GetTakeEnvelopeByName(r.GetActiveTake(copy), "Pan")
    if env then
      local _, ec = r.GetEnvelopeStateChunk(env, "", false)
      r.SetEnvelopeStateChunk(env, (ec:gsub("\nACT %d+", "\nACT 0", 1)), false)
    end
  else
    local src = root_source(r.GetMediaItemTake_Source(r.GetActiveTake(item)))
    local take = r.AddTakeToMediaItem(copy)
    r.SetMediaItemTake_Source(take, r.PCM_Source_CreateFromFile(r.GetMediaSourceFileName(src)))
    -- a stereo file that plays as mono keeps its channel mode (the user said yes to the question)
    r.SetMediaItemTakeInfo_Value(take, "I_CHANMODE", r.GetMediaItemTakeInfo_Value(r.GetActiveTake(item), "I_CHANMODE"))
    r.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", offs)
    local len = r.GetMediaSourceLength(r.GetMediaItemTake_Source(take)) - offs
    for k, v in pairs({ D_POSITION = pos, D_LENGTH = len, D_VOL = 1, D_FADEINLEN = 0, D_FADEOUTLEN = 0,
      D_FADEINLEN_AUTO = 0, D_FADEOUTLEN_AUTO = 0, B_LOOPSRC = 0 }) do
      r.SetMediaItemInfo_Value(copy, k, v)
    end
  end
  r.SetMediaItemTakeInfo_Value(r.GetActiveTake(copy), "D_PAN", pan)
  r.UpdateItemInProject(copy)
  return copy
end

-- the whole merge (call it inside an undo block): a new track below the lower of the 2 tracks with the 2 copies
-- panned left and right, glued by REAPER into 1 stereo item; the 2 mono items are muted.
-- Returns the new item and its file, or nil + message.
function Merge.run(a, b, mode)
  local left, right = Merge.order(a, b)
  for _, it in ipairs({ left, right }) do
    local msg = Merge.check(it, mode)
    if msg then return nil, msg end
  end
  local name = Merge.name(left, right)
  local below = math.floor(math.max(r.GetMediaTrackInfo_Value(r.GetMediaItem_Track(left), "IP_TRACKNUMBER"),
    r.GetMediaTrackInfo_Value(r.GetMediaItem_Track(right), "IP_TRACKNUMBER")))
  r.InsertTrackAtIndex(below, true)
  local tr = r.GetTrack(0, below)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true) -- glue names the file after the track
  r.SetMediaTrackInfo_Value(tr, "I_NCHAN", 2)
  -- the lower track closes a folder: the new track becomes the last track of that folder
  local upper = r.GetTrack(0, below - 1)
  local depth = r.GetMediaTrackInfo_Value(upper, "I_FOLDERDEPTH")
  if depth < 0 then
    r.SetMediaTrackInfo_Value(upper, "I_FOLDERDEPTH", 0)
    r.SetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH", depth)
  end

  -- raw: both files start where the left file starts on the timeline (not before 0)
  local pos, offs = 0, 0
  if mode == "raw" then
    local ltake = r.GetActiveTake(left)
    pos = r.GetMediaItemInfo_Value(left, "D_POSITION")
      - r.GetMediaItemTakeInfo_Value(ltake, "D_STARTOFFS") / r.GetMediaItemTakeInfo_Value(ltake, "D_PLAYRATE")
    if pos < 0 then offs, pos = -pos, 0 end
  end
  local lcopy = place_copy(tr, left, mode, -1, pos, offs)
  local rcopy = place_copy(tr, right, mode, 1, pos, offs)

  local sel = {}
  for i = 0, r.CountSelectedMediaItems(0) - 1 do sel[#sel + 1] = r.GetSelectedMediaItem(0, i) end
  r.SelectAllMediaItems(0, false)
  r.SetMediaItemSelected(lcopy, true)
  r.SetMediaItemSelected(rcopy, true)
  r.Main_OnCommand(CFG.GLUE, 0)
  local item = r.CountTrackMediaItems(tr) == 1 and r.GetTrackMediaItem(tr, 0)
  local take = item and r.GetActiveTake(item)
  if not take then
    r.DeleteTrack(tr)
    r.SelectAllMediaItems(0, false)
    for _, it in ipairs(sel) do if r.ValidatePtr2(0, it, "MediaItem*") then r.SetMediaItemSelected(it, true) end end
    return nil, "REAPER could not glue the 2 items. Nothing was added."
  end
  r.GetSetMediaItemTakeInfo_String(take, "P_NAME", name, true)
  r.SetMediaItemInfo_Value(left, "B_MUTE", 1)
  r.SetMediaItemInfo_Value(right, "B_MUTE", 1)
  r.SelectAllMediaItems(0, false)
  r.SetMediaItemSelected(item, true)
  return item, r.GetMediaSourceFileName(r.GetMediaItemTake_Source(take))
end

---------------------------------------------------------------------------
-- TESTS: tests/monomerge.lua sets MonoMergeTest: hand it the modules and do not run
---------------------------------------------------------------------------
if TESTING then
  local test = rawget(_G, "MonoMergeTest")
  test.CFG, test.Util, test.Merge = CFG, Util, Merge
  return
end

---------------------------------------------------------------------------
-- the action
---------------------------------------------------------------------------
local function main()
  if r.CountSelectedMediaItems(0) ~= 2 then
    r.MB("Select 2 mono items, then run Mono Merge again.\n\nThe top item becomes left, the other one right.",
      CFG.TITLE, 0)
    return
  end
  local a, b = r.GetSelectedMediaItem(0, 0), r.GetSelectedMediaItem(0, 1)
  for _, it in ipairs({ a, b }) do
    local bad, ask = Merge.check(it, MODE)
    if bad then r.MB(bad, CFG.TITLE, 0); return end
    if ask and r.MB(ask, CFG.TITLE, 4) ~= 6 then return end -- 4 = Yes / No, 6 = Yes
  end
  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)
  local item, msg = Merge.run(a, b, MODE)
  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock(MODE == "raw" and "Mono Merge: make stereo (raw files)" or "Mono Merge: make stereo (with edits)",
    -1)
  if not item then r.MB(msg, CFG.TITLE, 0) end
end

main()
