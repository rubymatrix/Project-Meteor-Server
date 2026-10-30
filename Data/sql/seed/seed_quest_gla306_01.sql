-- Gla306 "Thrill of the Fight" (110082): event-NPC class fills, quest-gated spawns and battle pools the quest
-- script and its duty director use. Hand-maintained. Apply, then restart the Map Server (classes, spawns and
-- pools load at boot). Rollback: seed_quest_gla306_99_rollback.sql. Idempotent: class fills only touch rows
-- still empty; spawns, gates and pools are deleted and re-inserted by the 'gla306_' prefix / pool id.
--
-- Sources: spawn positions and fight placements are ported scene placements of mixed provenance, several
-- invented (round offsets, rotation 0); none is retail-confirmed. Battle class paths and jobs follow the
-- shipped Fighter/monster classes; pools are auto-attack only.

-- ---- (1) event NPC class fills (spawning an empty classPath crashes the client) -------------------
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id IN (1000601, 1001076) AND classPath = '';

-- ---- (3) duty battle npcs -------------------------------------------------------------------------
-- Pool id = actor class id + 6000000. Class flags and conditions come from the Tourney Gladiator (2280157).
UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2280157
  SET t.classPath = '/Chara/Npc/Monster/Fighter/FighterEnemyMarauderStandard', t.propertyFlags = s.propertyFlags,
      t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id = 2289010 AND t.classPath = ''; -- the Ala Mhigan bladedancer
UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2280157
  SET t.classPath = '/Chara/Npc/Monster/Fighter/FighterEnemyGladiatorStandard', t.propertyFlags = s.propertyFlags,
      t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id = 2289011 AND t.classPath = ''; -- the Ala Mhigan challenger (Echo)
DELETE FROM server_battlenpc_pools WHERE poolId IN (8289010, 8289011);
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8289010, 2289010, 'gla306_ala_mhigan_bladedancer', 29, 4, 1, 4200, 1, 0, 0, 0, 0, 0),
  (8289011, 2289011, 'gla306_ala_mhigan_challenger', 29, 3, 1, 4200, 1, 0, 0, 0, 0, 0);

-- ---- (4) spawns and quest gates ------------------------------------------------------------------
DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'gla306\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1001076, 'gla306_yoyobina_second', 209, '', 0, -177.120, 195.050, 221.190, 0.000, 0),
    (1000601, 'gla306_echo_challenger', 209, '', 0, -177.890, 195.050, 205.090, 0.000, 0),
    (1000601, 'gla306_echo_challenger2', 209, '', 0, -177.400, 195.050, 222.470, 0.000, 0),
    (1090008, 'gla306_stands_trig', 209, '', 0, -185.260, 195.050, 179.740, 0.000, 0),
    (1090008, 'gla306_bazaar_trig', 172, '', 0, -1342.940, 56.000, 487.890, 0.000, 0);

CREATE TABLE IF NOT EXISTS server_eventnpc_quest_gated (
    zoneId   int(10) unsigned NOT NULL,
    uniqueId varchar(32)      NOT NULL,
    questId  int(10) unsigned NOT NULL,
    PRIMARY KEY (zoneId, uniqueId, questId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
DELETE FROM server_eventnpc_quest_gated WHERE uniqueId LIKE 'gla306\_%';
INSERT INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId) VALUES
    (209, 'gla306_yoyobina_second', 110082),
    (209, 'gla306_echo_challenger', 110082),
    (209, 'gla306_echo_challenger2', 110082),
    (209, 'gla306_stands_trig', 110082),
    (172, 'gla306_bazaar_trig', 110082);

-- Yoyobina's class has two spots: the first (Gla300's spawn) through 5, the second from 23 (needs the
-- minSequence/maxSequence columns from seed_quest_port_00_shared.sql; apply after seed_quest_gla300_01.sql).
UPDATE server_eventnpc_quest_gated SET minSequence = 0,  maxSequence = 5     WHERE questId = 110082 AND uniqueId = 'gla300_yoyobina';
UPDATE server_eventnpc_quest_gated SET minSequence = 23, maxSequence = 65534 WHERE questId = 110082 AND uniqueId = 'gla306_yoyobina_second';
