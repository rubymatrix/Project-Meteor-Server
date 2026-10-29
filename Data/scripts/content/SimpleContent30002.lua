require ("global")

-- The Limsa opening battle area. The fight itself is content/quest/opening.lua.

function onCreate(starterPlayer, contentArea, director)
    director:AddMember(starterPlayer);
    director:AddMember(director);
    director:StartContentGroup();

    StartContent("QuestDirectorMan0l001", "", contentArea, starterPlayer, { director = director });
end

function onDestroy()

end
