require("global");

properties = {
    permissions = 0,
    parameters = "sss",
    description =
[[
Adds experience <qty> to player or <targetname>.
!giveexp <qty> |
!giveexp <qty> <targetname> |
]],
}

function onTrigger(player, argc, animType, modelAnim, effectId)
    local sender = "[battleaction] ";

    local actor = GetWorldManager():GetActorInWorld(player.currentTarget) or nil;
    if player and actor then
        aid = tonumber(animType) or 0
        mid = tonumber(modelAnim) or 0
        eid = tonumber(effectId) or 0
        local id = bit.lshift(aid, 24);
        id = bit.bor(id, bit.lshift(mid, 12));
        id = bit.bor(id, eid) % 0x100000000 -- keep it positive: LuaJIT's bit can return a negative number
        print((tonumber(id)))
        player:DoBattleAction(30301, id);
    else
        print(sender.."unable to add experience, ensure player name is valid.");
    end;
end;