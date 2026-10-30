--[[
The Howling Eye, director InstanceRaidLesserGaruda: Content/InstanceRaid/StoryRaid.lua with Garuda.
--]]
local Raid = require("Content/InstanceRaid/StoryRaid"):as("LesserGaruda")
Raid.area, Raid.entry = Raid:areaFor("InstanceRaidLesserGaruda")
return Raid
