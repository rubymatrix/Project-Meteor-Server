require ("global")

--[[
Content areas whose content scripts (content/occupancy, content/hamletdefense) do the setup.
--]]

function onCreate(starterPlayer, contentArea, director)
    director:AddMember(starterPlayer);
    director:AddMember(director);
    director:StartContentGroup();
end

function onDestroy()

end
