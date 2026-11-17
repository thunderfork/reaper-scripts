-- @noindex
-- Mono Merge: make stereo (raw files). Select 2 mono items and run this action: 1 new stereo file from the
-- full original files (no trims, fades, volume or FX), with their start aligned. The top item becomes left.
rawset(_G, "MonoMergeMode", "raw")
local here = ({ reaper.get_action_context() })[2]:match("^(.*)[/\\]")
dofile(here .. "\\Mono Merge.lua")
rawset(_G, "MonoMergeMode", nil)
