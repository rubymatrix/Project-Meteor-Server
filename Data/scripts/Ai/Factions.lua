--[[
Factions and how they treat each other. Same faction is always friendly; pairs nobody relates
are neutral (they fight back once attacked). Content can override relations for its own
actors (enc:relate).
--]]

Faction.define("Player")
Faction.define("PlayerAlly")
Faction.define("Monster")
Faction.define("Neutral")
Faction.define("Kobold")
Faction.define("Ixal")
Faction.define("Amaljaa")
Faction.define("Sylph")
Faction.define("Goblin")

local players = { "Player", "PlayerAlly" }

Faction.relate("Player", "PlayerAlly", "friendly")
Faction.relate("Monster", players, "hostile")
Faction.relate("Kobold", players, "hostile")
Faction.relate("Ixal", players, "hostile")
Faction.relate("Amaljaa", players, "hostile")
Faction.relate("Sylph", players, "neutral")
Faction.relate("Goblin", players, "neutral")
Faction.relate("Neutral", { "Player", "PlayerAlly", "Monster" }, "ignore")

-- Beast tribes and wild monsters leave each other alone.
for _, tribe in ipairs({ "Kobold", "Ixal", "Amaljaa", "Sylph", "Goblin" }) do
	Faction.relate("Monster", tribe, "ignore")
end
