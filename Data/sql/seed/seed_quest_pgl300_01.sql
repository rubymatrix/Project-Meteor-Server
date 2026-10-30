-- Pgl300 "Here There Be Pirates" (110061): Hurrey's spawn in Ul'dah (also used by Pgl306), his class fill,
-- and the Kraken deckhands' pool for the boarding (directors/Quest/QuestDirectorPgl30001.lua). Waekbyrt,
-- Mytesyn, Titinin, Melisie, Halstein and Gagaruna already stand in the base tables.
-- Apply, then restart the Map Server. Rollback: seed_quest_pgl300_99_rollback.sql. Idempotent.
--
-- Hurrey's position is a private-server placement beside the Pugilists' Guild, not capture. He is a quest
-- actor: shown only while Pgl300 or Pgl306 declares him (server_eventnpc_quest_gated).
-- Deckhand class path FighterEnemyMarauderStandard is a 1.23b client class; which class id binds to it is
-- inference from the name. Pool id = actor class id + 6000000; genus 29 person, marauder (4),
-- auto-attack only.

UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id = 1000603 AND classPath = '';

UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2290004
  SET t.classPath = '/Chara/Npc/Monster/Fighter/FighterEnemyMarauderStandard',
      t.propertyFlags = s.propertyFlags, t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id = 2280217 AND t.classPath = '';

DELETE FROM server_battlenpc_pools WHERE poolId = 8280217;
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8280217, 2280217, 'pgl300_kraken_deckhand', 29, 4, 1, 4200, 1, 1, 0, 0, 0, 0);

DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'pgl300\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1000603, 'pgl300_hurrey', 175, '', 0, -178.460, 190.000, 102.620, 0.000, 0);

CREATE TABLE IF NOT EXISTS server_eventnpc_quest_gated (
    zoneId   int(10) unsigned NOT NULL,
    uniqueId varchar(32)      NOT NULL,
    questId  int(10) unsigned NOT NULL,
    PRIMARY KEY (zoneId, uniqueId, questId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
DELETE FROM server_eventnpc_quest_gated WHERE questId = 110061;
INSERT INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId) VALUES
    (175, 'pgl300_hurrey', 110061);
