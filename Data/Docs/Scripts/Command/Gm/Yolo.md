# Yolo: dev test command

Script: [`Data/scripts/Command/Gm/Yolo.lua`](../../../../scripts/Command/Gm/Yolo.lua)

The quests, expTable and commandCost tables belong to an older quest-exp check that used to be
the command's onTrigger. It is kept here for reference:

```lua
function onTrigger(player, argc, id, level, weight)
    id = tonumber(id) or 111807;
    level = tonumber(level) or quests[id].level;
    weight = tonumber(weight) or quests[id].weight;
    local messageId = MESSAGE_TYPE_SYSTEM_ERROR;
    local sender = "yolo";

    if id == 1 then
        return
    end
    local message = calcSkillPoint(player, level, weight);
    if player then
        player.SendMessage(messageId, sender, string.format("calculated %s | expected %s", message, quests[id].rewardexp));
    end;
    printf("calculated %s | expected %s", message, quests[id].rewardexp);
end;
```
