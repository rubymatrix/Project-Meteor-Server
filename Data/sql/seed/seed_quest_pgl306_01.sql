-- Pgl306 "Two Sides to Every Chip" (110062): Lady Lewena's handmaiden and the Silver Bazaar trigger, Hurrey's
-- gate for this quest, and the pools for the ambush (directors/Quest/QuestDirectorPgl30601.lua).
-- Needs seed_quest_pgl300_01.sql (Hurrey's spawn 'pgl300_hurrey' and class).
-- Apply, then restart the Map Server. Rollback: seed_quest_pgl306_99_rollback.sql. Idempotent.
--
-- Positions are private-server placements (the handmaiden by the Pugilists' Guild, the trigger at the
-- Silver Bazaar), not capture. All three are quest actors (server_eventnpc_quest_gated).
-- The push trigger is the shared invisible trigger class 1090008 (client data: PopulaceStandard,
-- property flags 1, push radius 6); the server routes its push to the quest that owns the spawn.
-- Class paths are 1.23b client classes; the binding to these class ids is inference from the names.
-- Pool id = actor class id + 6000000; genus 29 person, auto-attack only. Hurrey is a pugilist (2),
-- the almstakers thaumaturges (22) on the pugilist enemy model.

UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id IN (1000603, 1001013) AND classPath = '';

UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2290004
  SET t.classPath = CASE t.id
        WHEN 2290022 THEN '/Chara/Npc/Monster/Fighter/FighterAllyOpeningAttacker'
        WHEN 2289014 THEN '/Chara/Npc/Monster/Fighter/FighterEnemyPugilistStandard'
      END,
      t.propertyFlags = s.propertyFlags, t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id IN (2290022, 2289014) AND t.classPath = '';

DELETE FROM server_battlenpc_pools WHERE poolId IN (8290022, 8289014);
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8290022, 2290022, 'pgl306_hurrey',            29,  2, 1, 4200, 1, 0, 0, 0, 0, 0),  -- ally
  (8289014, 2289014, 'pgl306_ossuary_almstaker', 29, 22, 1, 4200, 1, 1, 0, 0, 0, 0);

DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'pgl306\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1001013, 'pgl306_lewena_handmaiden',     175, '', 0, -181.810, 190.000, 71.350, 0.000, 0),
    (1090008, 'pgl306_silver_bazaar_trigger', 172, '', 0, -1387.260, 56.000, 304.200, 0.000, 0);

CREATE TABLE IF NOT EXISTS server_eventnpc_quest_gated (
    zoneId   int(10) unsigned NOT NULL,
    uniqueId varchar(32)      NOT NULL,
    questId  int(10) unsigned NOT NULL,
    PRIMARY KEY (zoneId, uniqueId, questId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
DELETE FROM server_eventnpc_quest_gated WHERE questId = 110062;
INSERT INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId) VALUES
    (175, 'pgl300_hurrey',                110062),
    (175, 'pgl306_lewena_handmaiden',     110062),
    (172, 'pgl306_silver_bazaar_trigger', 110062);
