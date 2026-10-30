require("Battle/Stats")

--[[
Mighty Strikes (223252, from 27189 WAR50, 15 s): every attack made with an axe crits. Axes are the
MRD/WAR weapon, so every physical hit (auto-attack or weaponskill) by a MRD-class owner crits.
It checks the class because auto-attacks carry no skill.job. Spells are not axe attacks.
--]]

function onPreAction(effect, caster, target, skill, action, actionContainer)
	if stats.classOf(caster) == 4 and tostring(action.actionType) == "Physical" then
		action.critRate = 100.0
	end
end
