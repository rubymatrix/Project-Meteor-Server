-- Local (crafting) leves keep their progress as JSON in characters_quest_guildleve_local.questData.
-- Their gamedata comes from the base dumps Data/sql/gamedata_passivegl_craft.sql and
-- Data/sql/gamedata_recipes.sql; load those too on a database created before them.
-- Re-runnable. Rollback: seed_leve_97_local_rollback.sql.

ALTER TABLE `characters_quest_guildleve_local` ADD COLUMN IF NOT EXISTS `questData` longtext AFTER `questId`;
