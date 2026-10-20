require("modifiers")
require("battleutils")

--Cure, Cura, Regen, Esuna, Enhancing spells (Hardcoded as Stoneskin and Sanguine since we dont have a good way to check what's an enhancing spell)
supportedSpells = {[27346] = true, [27347] = true, [27358] = true, [27357] = true, [27350] = true, [27307] = true}

function onMagicCast(effect, caster, skill)
    if supportedSpells[skill.id] then
        skill.castTimeMs = skill.castTimeMs * 1.5;
        skill.aoeType = TargetFindAOEType.Circle;
        skill.aoeRange = 15;
    end
end

function onCommandFinish(effect, owner, skill, actionContainer)
    if supportedSpells[skill.id] then
        owner.statusEffects:RemoveStatusEffect(effect, actionContainer, 30331, false);
    end
end;