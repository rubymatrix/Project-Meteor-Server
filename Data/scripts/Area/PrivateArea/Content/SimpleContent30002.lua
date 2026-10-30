require("Global")

--[[
The Limsa opening battle area. The fight itself is Content/Quest/Opening.lua.
--]]

function onCreate(starterPlayer, contentArea, director)
	director:AddMember(starterPlayer)
	director:AddMember(director)
	director:StartContentGroup()

	StartContent("QuestDirectorMan0l001", "", contentArea, starterPlayer, { director = director })
end

function onDestroy()

end
