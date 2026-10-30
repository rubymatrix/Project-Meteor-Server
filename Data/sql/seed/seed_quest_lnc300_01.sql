-- Lnc300 "Culture Shock" (110181): event-NPC class fills, quest-gated spawns and battle pools the quest
-- script and its duty director use. Hand-maintained. Apply, then restart the Map Server (classes, spawns and
-- pools load at boot). Rollback: seed_quest_lnc300_99_rollback.sql. Idempotent: class fills only touch rows
-- still empty; spawns, gates and pools are deleted and re-inserted by the 'lnc300_' prefix / pool id.
--
-- Sources: spawn positions and fight placements are ported scene placements of mixed provenance, several
-- invented (round offsets, rotation 0); none is retail-confirmed. Battle class paths and jobs follow the
-- shipped Fighter/monster classes; pools are auto-attack only.

-- ---- (1) event NPC class fills (spawning an empty classPath crashes the client) -------------------
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id IN (1000402, 1000403) AND classPath = '';

-- ---- (3) duty battle npcs -------------------------------------------------------------------------
-- Pool id = actor class id + 6000000. Class flags and conditions come from the Tourney Gladiator (2280157).
UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2280157
  SET t.classPath = '/Chara/Npc/Monster/Winglizard/WinglizardStandard', t.propertyFlags = s.propertyFlags,
      t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id = 2200108 AND t.classPath = ''; -- woodsent pteroc
UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2280157
  SET t.classPath = '/Chara/Npc/Monster/Serow/SerowFemaleStandard', t.propertyFlags = s.propertyFlags,
      t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id = 2200304 AND t.classPath = ''; -- woodsent doe
DELETE FROM server_battlenpc_pools WHERE poolId IN (8200108, 8200304);
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8200108, 2200108, 'lnc300_woodsent_pteroc', 45, 0, 1, 4200, 1, 0, 0, 0, 0, 0),
  (8200304, 2200304, 'lnc300_woodsent_doe', 2, 0, 1, 4200, 1, 0, 0, 0, 0, 0);

-- ---- (4) spawns and quest gates ------------------------------------------------------------------
DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'lnc300\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1000402, 'lnc300_dreues', 175, '', 0, -177.900, 190.550, 95.830, 0.000, 0),
    (1000403, 'lnc300_brazen_broker', 206, '', 0, 187.480, 27.500, -1583.960, 0.000, 0),
    (1090008, 'lnc300_caravan_trig', 150, '', 0, 379.700, 6.188, -14.300, 0.000, 0);

CREATE TABLE IF NOT EXISTS server_eventnpc_quest_gated (
    zoneId   int(10) unsigned NOT NULL,
    uniqueId varchar(32)      NOT NULL,
    questId  int(10) unsigned NOT NULL,
    PRIMARY KEY (zoneId, uniqueId, questId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
DELETE FROM server_eventnpc_quest_gated WHERE uniqueId LIKE 'lnc300\_%';
INSERT INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId) VALUES
    (175, 'lnc300_dreues', 110181),
    (206, 'lnc300_brazen_broker', 110181),
    (150, 'lnc300_caravan_trig', 110181);
