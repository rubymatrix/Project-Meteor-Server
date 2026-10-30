function onGain(owner, effect, actionContainer)
    if (owner.Brain ~= nil) then
        owner.Brain:AddBehavior("Charm", "charm", { source = effect:GetSource() });
    end
end;

function onLose(owner, effect, actionContainer)
    if (owner.Brain ~= nil) then
        owner.Brain:Remove("charm", "status lost");
    end
end;
