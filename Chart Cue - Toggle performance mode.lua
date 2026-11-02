-- @noindex
-- Chart Cue: performance mode on / off (only the page is shown). Bind this action in REAPER's Action List.
-- It works when the Chart Cue window has no focus. Chart Cue must be open (else nothing happens).
local q = reaper.GetExtState("ChartCue", "cmd_q")
if #q > 200 then q = "" end -- never let the queue grow without limit
reaper.SetExtState("ChartCue", "cmd_q", q .. "perf,", false)
