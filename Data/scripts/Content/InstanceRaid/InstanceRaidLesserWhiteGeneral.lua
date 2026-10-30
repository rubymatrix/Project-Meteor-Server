--[[
Rivenroad, director InstanceRaidLesserWhiteGeneral: Content/InstanceRaid/StoryRaid.lua with Nael van Darnus.
--]]
local Raid = require("Content/InstanceRaid/StoryRaid"):as("LesserWhiteGeneral")
Raid.area, Raid.entry = Raid:areaFor("InstanceRaidLesserWhiteGeneral")
return Raid
