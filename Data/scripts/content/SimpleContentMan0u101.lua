function onCreate(starterPlayer, contentArea, director)
	director:AddMember(starterPlayer);
	director:AddMember(director);
	director:StartContentGroup();
end

function onDestroy()
end
