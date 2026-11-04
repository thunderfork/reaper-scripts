-- @noindex
-- Segue: next song of the setlist. Bind this action to a key, foot pedal or OSC message in REAPER's
-- Action List. After a Stop or during a pause it plays the next song; during a song it goes to the next
-- song at once. Segue must be open.
local q = reaper.GetExtState("Segue", "cmd_q")
if #q > 200 then q = "" end -- never let the queue grow without limit
reaper.SetExtState("Segue", "cmd_q", q .. "nextsong,", false)
