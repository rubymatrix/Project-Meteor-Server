-- Removes what seed_leve_00_local.sql and the gamedata_passivegl_craft dump added (held local leves'
-- crafting progress included). gamedata_recipes is base data and stays.
ALTER TABLE `characters_quest_guildleve_local` DROP COLUMN IF EXISTS `questData`;
DROP TABLE IF EXISTS `gamedata_passivegl_craft`;
