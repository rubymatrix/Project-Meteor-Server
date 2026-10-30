require ("global")

--[[
The Gridania opening battle area. The fight itself is content/quest/opening.lua.
--]]

function onCreate(starterPlayer, contentArea, director)
    contentArea:SpawnActor(1090384, "openingstoper", 356.09, 3.74, -701.62, -1.41);

    director:AddMember(starterPlayer);
    director:AddMember(director);
    director:StartContentGroup();

    StartContent("QuestDirectorMan0g001", "", contentArea, starterPlayer, { director = director });
end

function onDestroy()

end
