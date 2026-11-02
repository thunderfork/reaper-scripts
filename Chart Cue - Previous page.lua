-- @noindex
-- Chart Cue: previous page. Bind this action to a key, foot pedal or OSC message in REAPER's Action List.
-- It works when the Chart Cue window has no focus. Chart Cue must be open (else nothing happens).
local q = reaper.GetExtState("ChartCue", "cmd_q")
if #q > 200 then q = "" end -- never let the queue grow without limit
reaper.SetExtState("ChartCue", "cmd_q", q .. "prev,", false)
