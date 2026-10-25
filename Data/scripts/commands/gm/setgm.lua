require("global");

properties = {
    permissions = 1,
    parameters = "sss",
    description =
[[
Shows or sets a character's GM level (0 = player). Saved to the character.
You can't grant above your own level or change a higher-level GM.
!setgm                          shows your level
!setgm <level>                  sets yours
!setgm <level> <first> <last>   sets another player's
]],
}

function onTrigger(player, argc, level, firstName, lastName)
    local sender = "[setgm] ";

    if (player == nil) then
        print(sender .. "no player");
        return;
    end

    if (level == nil) then
        player:SendMessage(MESSAGE_TYPE_SYSTEM_ERROR, sender, string.format("Your GM level is %u.", player:GetGMLevel()));
        return;
    end

    local newLevel = tonumber(level);
    if (newLevel == nil or newLevel < 0 or newLevel > 65535 or newLevel % 1 ~= 0) then
        player:SendMessage(MESSAGE_TYPE_SYSTEM_ERROR, sender, "Level must be a whole number from 0 to 65535.");
        return;
    end

    local target = player;
    if (firstName ~= nil) then
        local name = lastName and (firstName .. " " .. lastName) or firstName;
        target = GetWorldManager():GetPCInWorld(name);
        if (target == nil) then
            player:SendMessage(MESSAGE_TYPE_SYSTEM_ERROR, sender, string.format("%s is not online.", name));
            return;
        end
    end

    local callerLevel = player:GetGMLevel();
    if (newLevel > callerLevel or target:GetGMLevel() > callerLevel) then
        player:SendMessage(MESSAGE_TYPE_SYSTEM_ERROR, sender, string.format("Your GM level (%u) is too low for that.", callerLevel));
        return;
    end

    target:SetGMLevel(newLevel);
    player:SendMessage(MESSAGE_TYPE_SYSTEM_ERROR, sender, string.format("%s's GM level is now %u.", target:GetName(), newLevel));
    if (target.Id ~= player.Id) then
        target:SendMessage(MESSAGE_TYPE_SYSTEM_ERROR, sender, string.format("Your GM level is now %u.", newLevel));
    end
end
