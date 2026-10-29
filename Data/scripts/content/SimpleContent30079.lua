require ("global")

-- The Ul'dah opening battle area. The fight itself is content/quest/opening.lua.

function onCreate(starterPlayer, contentArea, director)
    contentArea:SpawnActor(1090385, "openingstoper", -24.34, 192, 34.22, 0);

    director:AddMember(starterPlayer);
    director:AddMember(director);
    director:StartContentGroup();

    StartContent("QuestDirectorMan0u001", "", contentArea, starterPlayer, { director = director });
end

function onDestroy()

end
