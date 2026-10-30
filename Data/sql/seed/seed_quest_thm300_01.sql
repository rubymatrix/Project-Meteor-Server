-- Thm300 "Revelry in Rivalry" (110241): the Ossuary rival in Ul'dah, the bizarre blacksmith's push trigger in
-- Lower La Noscea, and the pools for the Ignis Fatuus duty (directors/Quest/QuestDirectorThm30001.lua).
-- Baderon (133), Bodenolf (230) and Yayake (209) already stand in the base tables.
-- Apply, then restart the Map Server. Rollback: seed_quest_thm300_99_rollback.sql. Idempotent.
--
-- Positions are private-server placements, not capture. Both are quest actors
-- (server_eventnpc_quest_gated). The rival class 1000607 is shared with Thm306.
-- The smith trigger is the smith's own class (1001008) as a push circle (flags 1, radius 6).
-- Battle classes: the smith on FighterAllyOpeningAttacker, the wisp on the client's
-- BombLesserScenarioThmLv30. Pool id = actor class id + 6000000; auto-attack only: the smith
-- genus 29 marauder (4), the wisp genus 64 as the bombs.

UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id = 1000607 AND classPath = '';
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 1,
    eventConditions = '{"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"pushWithCircleEventConditions":[{"isEnabled":"false","radius":"6.0","outwards":"false","silent":"false","conditionName":"pushDefault"}]}'
WHERE id = 1001008 AND classPath = '';

UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2290004
  SET t.classPath = '/Chara/Npc/Monster/Fighter/FighterAllyOpeningAttacker',
      t.propertyFlags = s.propertyFlags, t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id = 2290023 AND t.classPath = '';
UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2201601
  SET t.classPath = '/Chara/Npc/Monster/Bomb/BombLesserScenarioThmLv30',
      t.propertyFlags = s.propertyFlags, t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id = 2201603 AND t.classPath = '';

DELETE FROM server_battlenpc_pools WHERE poolId IN (8290023, 8201603);
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8290023, 2290023, 'thm300_bizarre_blacksmith', 29, 4, 1, 4200, 1, 0, 0, 0, 0, 0),  -- ally
  (8201603, 2201603, 'thm300_ignis_fatuus',       64, 0, 1, 4200, 1, 1, 0, 0, 0, 0);

DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'thm300\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1000607, 'thm300_ossuary_rival', 209, '', 0, -341.840, 206.500, 232.680, 0.000, 0),
    (1001008, 'thm300_smith_trigger', 128, '', 0, -494.716, 45.882, -385.102, 0.000, 0);

CREATE TABLE IF NOT EXISTS server_eventnpc_quest_gated (
    zoneId   int(10) unsigned NOT NULL,
    uniqueId varchar(32)      NOT NULL,
    questId  int(10) unsigned NOT NULL,
    PRIMARY KEY (zoneId, uniqueId, questId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
DELETE FROM server_eventnpc_quest_gated WHERE questId = 110241;
INSERT INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId) VALUES
    (209, 'thm300_ossuary_rival', 110241),
    (128, 'thm300_smith_trigger', 110241);
