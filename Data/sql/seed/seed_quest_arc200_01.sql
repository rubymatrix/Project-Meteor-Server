-- Arc200 "Filling the Quiver" (110160): Keelty's spawn, the fence trigger, and the yarzon invader pools
-- of the Fallgourd battle (QuestDirectorArc20001). Hand-maintained. Apply, then restart the Map Server
-- (classes, spawns and pools load at boot). Rollback: seed_quest_arc200_99_rollback.sql. Idempotent:
-- class fills only touch rows still empty; spawns, gates and pools are deleted and re-inserted by the
-- 'arc200_' prefix / pool id.
--
-- Sources: spawn positions are ported scene placements of mixed provenance, several invented (round
-- offsets, rotation 0); none is retail-confirmed.
-- Battle class paths are the shipped Longlegs class; pools copy the sand
-- yarzon leve pool (genus 39, TP moves 1039) Apply after
-- seed_bnpc_02_actor_classes.sql and seed_leve_02_mobs.sql (the class flags are copied from there).

UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id = 1000587 AND classPath = '';

-- ---- duty battle npcs (pool id = actor class id + 6000000) -------------------------------------------
UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2205501
  SET t.classPath = '/Chara/Npc/Monster/Longlegs/LonglegsStandard', t.propertyFlags = s.propertyFlags,
      t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id IN (2205503, 2205504, 2205505) AND t.classPath = '';
DELETE FROM server_battlenpc_pools WHERE poolId IN (8205503, 8205504, 8205505);
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8205503, 2205503, 'arc200_yarzon_invader_a', 39, 0, 1, 4200, 1, 1, 0, 0, 0, 1039),
  (8205504, 2205504, 'arc200_yarzon_invader_b', 39, 0, 1, 4200, 1, 1, 0, 0, 0, 1039),
  (8205505, 2205505, 'arc200_yarzon_invader_c', 39, 0, 1, 4200, 1, 1, 0, 0, 0, 1039);

-- ---- spawns and quest gates ---------------------------------------------------------------------------
DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'arc200\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1000587, 'arc200_keelty', 206, '', 0, 261.380, 14.000, -1264.700, 0.000, 0),
    (1090008, 'arc200_fence_trigger', 152, '', 0, -1067.160, 20.293, -1764.700, 0.000, 0);

CREATE TABLE IF NOT EXISTS server_eventnpc_quest_gated (
    zoneId   int(10) unsigned NOT NULL,
    uniqueId varchar(32)      NOT NULL,
    questId  int(10) unsigned NOT NULL,
    PRIMARY KEY (zoneId, uniqueId, questId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
DELETE FROM server_eventnpc_quest_gated WHERE uniqueId LIKE 'arc200\_%';
INSERT INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId) VALUES
    (152, 'arc200_fence_trigger', 110160);
