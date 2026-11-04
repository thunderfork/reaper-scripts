-- @noindex
-- Chart Cue: next song of the setlist. Bind this action to a key, foot pedal or OSC message in REAPER's
-- Action List. It ends a pause ("Wait for Next song" or a timed pause) and plays the next song; during a
-- song it goes to the next song at once. Only with "Play in setlist order" on. Chart Cue must be open.
local q = reaper.GetExtState("ChartCue", "cmd_q")
if #q > 200 then q = "" end -- never let the queue grow without limit
reaper.SetExtState("ChartCue", "cmd_q", q .. "nextsong,", false)
