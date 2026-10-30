-- Thm306 "Law and the Order" (110242): the overweening thaumaturge at the Western Thanalan wreck site and
-- his pool for the duel (directors/Quest/QuestDirectorThm30601.lua). I'llofii and Yayake already stand in
-- Ul'dah (209). Apply, then restart the Map Server. Rollback: seed_quest_thm306_99_rollback.sql. Idempotent.
--
-- The position is a private-server placement, not capture; he is a quest actor
-- (server_eventnpc_quest_gated). The rival class 1000607 is shared with Thm300.
-- Battle class: FighterEnemyPugilistStandard, a 1.23b client class; the binding is inference.
-- Pool id = actor class id + 6000000; genus 29 person, thaumaturge (22), auto-attack only.

UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id = 1000607 AND classPath = '';

UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2290004
  SET t.classPath = '/Chara/Npc/Monster/Fighter/FighterEnemyPugilistStandard',
      t.propertyFlags = s.propertyFlags, t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id = 2289015 AND t.classPath = '';

DELETE FROM server_battlenpc_pools WHERE poolId = 8289015;
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8289015, 2289015, 'thm306_overweening_thaumaturge', 29, 22, 1, 4200, 1, 1, 0, 0, 0, 0);

DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'thm306\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1000607, 'thm306_wreck_rival', 172, '', 0, -1849.756, 24.922, -284.174, 0.000, 0);

CREATE TABLE IF NOT EXISTS server_eventnpc_quest_gated (
    zoneId   int(10) unsigned NOT NULL,
    uniqueId varchar(32)      NOT NULL,
    questId  int(10) unsigned NOT NULL,
    PRIMARY KEY (zoneId, uniqueId, questId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
DELETE FROM server_eventnpc_quest_gated WHERE questId = 110242;
INSERT INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId) VALUES
    (172, 'thm306_wreck_rival', 110242);
