-- @noindex
-- FX Link: turn the link of the selected link group on or off. Give this action a key or a toolbar button in
-- REAPER's Action List. FX Link must be open.
local q = reaper.GetExtState("FX Link", "cmd_q")
if #q > 200 then q = "" end -- never let the queue grow without limit
reaper.SetExtState("FX Link", "cmd_q", q .. "toggle,", false)
