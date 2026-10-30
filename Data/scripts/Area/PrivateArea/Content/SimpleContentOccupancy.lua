require("Global")

--[[
content areas whose content scripts (Content/Occupancy, Content/HamletDefense) do the setup.
--]]

function onCreate(starterPlayer, contentArea, director)
	director:AddMember(starterPlayer)
	director:AddMember(director)
	director:StartContentGroup()
end

function onDestroy()

end
