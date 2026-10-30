-- Lnc306 "Necessary Evils" (110182): event-NPC class fills, quest-gated spawns and battle pools the quest
-- script and its duty director use. Hand-maintained. Apply, then restart the Map Server (classes, spawns and
-- pools load at boot). Rollback: seed_quest_lnc306_99_rollback.sql. Idempotent: class fills only touch rows
-- still empty; spawns, gates and pools are deleted and re-inserted by the 'lnc306_' prefix / pool id.
--
-- Sources: spawn positions and fight placements are ported scene placements of mixed provenance, several
-- invented (round offsets, rotation 0); none is retail-confirmed. Battle class paths and jobs follow the
-- shipped Fighter/monster classes; pools are auto-attack only.

-- ---- (1) event NPC class fills (spawning an empty classPath crashes the client) -------------------
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id IN (1000403) AND classPath = '';

-- ---- (3) duty battle npcs -------------------------------------------------------------------------
-- Pool id = actor class id + 6000000. Class flags and conditions come from the Tourney Gladiator (2280157).
UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2280157
  SET t.classPath = '/Chara/Npc/Monster/Elemental/ElementalStandard', t.propertyFlags = s.propertyFlags,
      t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id = 2205202 AND t.classPath = ''; -- woodsent elemental
DELETE FROM server_battlenpc_pools WHERE poolId IN (8205202);
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8205202, 2205202, 'lnc306_woodsent_elemental', 1007, 0, 1, 4200, 1, 0, 0, 0, 0, 0);

-- ---- (4) spawns and quest gates ------------------------------------------------------------------
DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'lnc306\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1090008, 'lnc306_caravan_trig', 150, '', 0, 394.230, 5.455, -782.400, 0.000, 0),
    (1000403, 'lnc306_brazen_broker', 150, '', 0, 299.320, 4.346, -539.690, 0.000, 0);

CREATE TABLE IF NOT EXISTS server_eventnpc_quest_gated (
    zoneId   int(10) unsigned NOT NULL,
    uniqueId varchar(32)      NOT NULL,
    questId  int(10) unsigned NOT NULL,
    PRIMARY KEY (zoneId, uniqueId, questId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
DELETE FROM server_eventnpc_quest_gated WHERE uniqueId LIKE 'lnc306\_%';
INSERT INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId) VALUES
    (150, 'lnc306_caravan_trig', 110182),
    (150, 'lnc306_brazen_broker', 110182);
