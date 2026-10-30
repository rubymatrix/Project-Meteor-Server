--[[
Castrum Novum's transmission tower, director InstanceRaidBeaconBattle: Content/InstanceRaid/StoryRaid.lua with the tower's guard.
--]]
local Raid = require("Content/InstanceRaid/StoryRaid"):as("BeaconBattle")
Raid.area, Raid.entry = Raid:areaFor("InstanceRaidBeaconBattle")
return Raid
