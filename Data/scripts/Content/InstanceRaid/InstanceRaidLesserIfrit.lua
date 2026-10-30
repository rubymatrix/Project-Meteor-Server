--[[
The Bowl of Embers, director InstanceRaidLesserIfrit: Content/InstanceRaid/Ifrit.lua with its lesser numbers.
The Grand Company quest's raid, so it takes the party in and ends like the other story raids
(Content/InstanceRaid/StoryRaid.lua).
--]]
local StoryRaid = require("Content/InstanceRaid/StoryRaid")
local Ifrit = require("Content/InstanceRaid/Ifrit"):as("lesser")
Ifrit.area = Ifrit.areaFor("InstanceRaidLesserIfrit")
Ifrit.story = { quests = 16, bonus = "company", exit = { zone = 206, at = { 19.5, 22.2, -1557.5, 2.4 } } }

local ifritStart = Ifrit.onStart

function Ifrit:onStart()
	StoryRaid.begin(self)
	ifritStart(self)
end

Ifrit.onEnd = StoryRaid.onEnd

return Ifrit
