-- Thm200 "The Big Payback" (110240): the vengeance trigger in Western Thanalan and the herd's pools
-- (directors/Quest/QuestDirectorThm20001.lua). I'llofii and Yayake already stand in Ul'dah (209).
-- Apply, then restart the Map Server. Rollback: seed_quest_thm200_99_rollback.sql. Idempotent.
--
-- The trigger's position is a private-server placement, not capture; it is a quest actor
-- (server_eventnpc_quest_gated).
-- The push trigger is the shared invisible trigger class 1090008 (client data: PopulaceStandard,
-- property flags 1, push radius 6); the server routes its push to the quest that owns the spawn.
-- The nannygoat and the enraged nannygoat take the client's YakFemaleStandard (the billygoat class already
-- has YakMaleStandard); flags and conditions from the billygoat (2202303). Pool id = actor class id +
-- 6000000; genus 1 as the aldgoats, auto-attack only.

UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2202303
  SET t.classPath = '/Chara/Npc/Monster/Yak/YakFemaleStandard',
      t.propertyFlags = s.propertyFlags, t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id IN (2102313, 2202307) AND t.classPath = '';

DELETE FROM server_battlenpc_pools WHERE poolId IN (8102313, 8202303, 8202307);
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8102313, 2102313, 'thm200_nannygoat',              1, 0, 1, 4200, 1, 1, 0, 0, 0, 0),
  (8202303, 2202303, 'thm200_death_marked_billygoat', 1, 0, 1, 4200, 1, 1, 0, 0, 0, 0),
  (8202307, 2202307, 'thm200_enraged_nannygoat',      1, 0, 1, 4200, 1, 1, 0, 0, 0, 0);

DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'thm200\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1090008, 'thm200_vengeance_trigger', 172, '', 0, -1229.530, 57.000, -310.290, 0.000, 0);

CREATE TABLE IF NOT EXISTS server_eventnpc_quest_gated (
    zoneId   int(10) unsigned NOT NULL,
    uniqueId varchar(32)      NOT NULL,
    questId  int(10) unsigned NOT NULL,
    PRIMARY KEY (zoneId, uniqueId, questId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
DELETE FROM server_eventnpc_quest_gated WHERE questId = 110240;
INSERT INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId) VALUES
    (172, 'thm200_vengeance_trigger', 110240);
