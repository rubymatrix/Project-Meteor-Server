require("global");
require("weaponskill");
require("battle/actions");

function onSkillPrepare(caster, target, skill)
    return 0;
end;

function onSkillStart(caster, target, skill)
    return 0;
end;

function onSkillFinish(caster, target, skill, action, actionContainer)
    -- Monster TP moves have no scripts of their own.
    if (skill.job == 0) then
        actions.monsterMove(caster, target, skill, action, actionContainer);
        return;
    end

    --calculate ws damage
    action.amount = skill.basePotency;

    --DoAction handles rates, buffs, dealing damage
    action:DoAction(caster, target, skill, actionContainer);

    --Try to apply status effect
    action:TryStatus(caster, target, skill, actionContainer, true);
end;