-- Run once on a database built before this change. Restart the map server after.
ALTER TABLE server_battlenpc_pools DROP COLUMN IF EXISTS spellListId, DROP COLUMN IF EXISTS skillListId;
DROP TABLE IF EXISTS server_battlenpc_skill_list;
DROP TABLE IF EXISTS server_battlenpc_spell_list;
