-- Man300 "Toll of the Warden" (110015): the briefing copy of the Waking Sands (181 PA 12), the Peasants
-- Ward copies (zone 161 PA 1/2, standing in 181 PA 13/14 while zone 161 has no server zone), the mesa
-- duty's class fills and the fighters' pools. Hand-maintained.
-- Camp Drybone uses the shipped 1090241 spawn; the mesa trigger is the m3g_man300_mesa row of
-- seed_msq_gridania_10_man3xx.sql. The mesa duty's cast and companion are spawned by
-- Data/scripts/content/SimpleContentMan30001.lua, the fighters by QuestDirectorMan30001.lua.
-- Apply, then restart the Map Server (private areas, classes, spawns and pools load at boot).
-- Rollback: seed_quest_man300_99_rollback.sql. Idempotent: private areas are only inserted when missing,
-- class fills only touch empty rows, spawns are deleted and re-inserted by their 'man300_' prefix,
-- pools by id.
--
-- Placements are the ported server's, a mix of capture-derived and calibrated points; none is retail
-- data. Map objects (doors, flags) are left out: they need layout ids.

-- ---- (1) private areas -----------------------------------------------------------------------------
-- 181 12: the Waking Sands before Minfilia's briefing (Forever Taken's atrium too).
-- 161 1/2: the Ashcrown Consortium, arrival and report copies; 181 13/14 stand in for them.
INSERT INTO server_zones_privateareas (parentZoneId, className, privateAreaName, privateAreaType, canExitArea, music)
SELECT v.parentZoneId, '/Area/PrivateArea/PrivateAreaMasterPast', 'PrivateAreaMasterPast', v.privateAreaType, 0, v.music
FROM (SELECT 181 AS parentZoneId, 12 AS privateAreaType, 58 AS music
      UNION ALL SELECT 161, 1, 51
      UNION ALL SELECT 161, 2, 51
      UNION ALL SELECT 181, 13, 51
      UNION ALL SELECT 181, 14, 51) v
WHERE NOT EXISTS (SELECT 1 FROM server_zones_privateareas p
                  WHERE p.parentZoneId = v.parentZoneId AND p.privateAreaName = 'PrivateAreaMasterPast'
                    AND p.privateAreaType = v.privateAreaType);

-- ---- (2) class fills -------------------------------------------------------------------------------
-- Spawning a class with an empty classPath crashes the client.
UPDATE gamedata_actor_class SET
    classPath = '/Chara/Npc/Populace/PopulaceStandard',
    propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id IN (
    1001095,  -- Loyal Ixal (4000505), the mesa
    1001098,  -- Able-bodied Amalj'aa (4000508), the mesa
    1001179,  -- Lanxio, the Consortium
    1001380, 1001381, 1001382, 1001383, 1001384,   -- Yoyoka, Cliaux, Cenmin, Maucolyn, Memezofu
    1001385, 1001386, 1001387, 1001388, 1001389    -- Nyxia, Gonaxia, Zexia, Pannixia, Daxia
) AND classPath = '';

-- The fighters take the property flags of a shipped beast-tribe battle class.
UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2106537
  SET t.classPath = CASE t.id
        WHEN 2206404 THEN '/Chara/Npc/Monster/Birdman/BirdmanStandard'
        WHEN 2206503 THEN '/Chara/Npc/Monster/Lizardman/LizardmanPugilistStandard'
        WHEN 2206511 THEN '/Chara/Npc/Monster/Lizardman/LizardmanArcherStandard'
      END,
      t.propertyFlags = s.propertyFlags,
      t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id IN (2206404, 2206503, 2206511) AND t.classPath = '';

-- ---- (3) battle pools ------------------------------------------------------------------------------
-- Pool id = actor class id + 6000000. Auto-attack only; they never start a fight (the director).
DELETE FROM server_battlenpc_pools WHERE poolId IN (8206404, 8206503, 8206511);
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8206404, 2206404, 'man300_ixali_swordfighter', 24, 3, 1, 4200, 1, 0, 0, 0, 0, 0),
  (8206503, 2206503, 'man300_amaljaa_drubber',    23, 2, 1, 4200, 1, 0, 0, 0, 0, 0),
  (8206511, 2206511, 'man300_amaljaa_bowyer',     23, 7, 1, 4200, 1, 0, 0, 0, 0, 0);

-- ---- (4) spawns ------------------------------------------------------------------------------------
DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'man300\_%';

-- The Waking Sands before the briefing, 181 PA 12.
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1000843, 'man300_ws_minfilia',     181, 'PrivateAreaMasterPast', 12, -123.998,  1.200, -162.070, -0.784, 1017),
    (1001046, 'man300_ws_tataru',       181, 'PrivateAreaMasterPast', 12, -199.563,  0.000, -162.347, -1.500, 1017),
    (1001373, 'man300_ws_sahja_zhwan',  181, 'PrivateAreaMasterPast', 12, -137.500,  1.000, -162.600, -1.570, 1015),
    (1001374, 'man300_ws_nenekani',     181, 'PrivateAreaMasterPast', 12, -177.000,  0.000, -156.600, -3.100, 1017),
    (1001375, 'man300_ws_godfrey',      181, 'PrivateAreaMasterPast', 12, -188.765,  0.000, -155.780, -1.550, 1040),
    (1001376, 'man300_ws_fenana',       181, 'PrivateAreaMasterPast', 12, -197.455, -2.000, -178.362,  1.000, 1015),
    (1001377, 'man300_ws_nonoru',       181, 'PrivateAreaMasterPast', 12, -162.314,  0.000, -140.110,  3.100, 0),
    (1001378, 'man300_ws_seranelien',   181, 'PrivateAreaMasterPast', 12, -137.500,  1.000, -157.400, -1.570, 1016),
    (1090160, 'man300_ws_exit_door',    181, 'PrivateAreaMasterPast', 12, -209.000,  0.000, -160.000,  0.000, 0),
    (1090161, 'man300_ws_office_w',     181, 'PrivateAreaMasterPast', 12, -137.000,  1.000, -160.000,  0.000, 0),
    (1090162, 'man300_ws_office_e',     181, 'PrivateAreaMasterPast', 12, -134.500,  1.000, -160.000,  0.000, 0),
    (1200135, 'man300_ws_retainerbell', 181, 'PrivateAreaMasterPast', 12, -199.977,  0.000, -162.959,  0.000, 0);

-- The Consortium in zone 161: PA 1 on arrival, PA 2 (Nananoby at the door) for the report.
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
SELECT c.actorClassId, CONCAT('man300_pw', l.lvl, '_', c.name), 161, 'PrivateAreaMasterPast', l.lvl,
       c.x, c.y, c.z, c.rot, 0
FROM (SELECT 1 AS lvl UNION ALL SELECT 2) l
JOIN (SELECT 1001047 AS actorClassId, 'hedyn' AS name, -199.563 AS x, 0.000 AS y, -162.347 AS z, -1.500 AS rot
      UNION ALL SELECT 1001048, 'shanga_meshanga', -124.993, 1.517, -158.605, -1.837
      UNION ALL SELECT 1001049, 'troxia',   -125.033,  2.143, -157.408, -1.802
      UNION ALL SELECT 1001178, 'diluxio',  -169.646,  0.000, -156.853, -2.594
      UNION ALL SELECT 1001179, 'lanxio',   -188.829,  0.000, -155.238, -2.358
      UNION ALL SELECT 1001380, 'yoyoka',   -189.886, -2.000, -180.658, -0.045
      UNION ALL SELECT 1001381, 'cliaux',   -162.314,  0.015, -140.358,  2.729
      UNION ALL SELECT 1001382, 'cenmin',   -137.377,  1.015, -157.675, -1.609
      UNION ALL SELECT 1001383, 'maucolyn', -154.019,  0.000, -162.986, -1.336
      UNION ALL SELECT 1001384, 'memezofu', -194.257,  2.000, -137.838,  2.866
      UNION ALL SELECT 1001385, 'nyxia',    -148.182,  2.000, -181.725, -1.286
      UNION ALL SELECT 1001386, 'gonaxia',  -156.771,  0.000, -127.795, -2.713
      UNION ALL SELECT 1001387, 'zexia',    -146.336,  0.945, -163.133, -0.515
      UNION ALL SELECT 1001388, 'pannixia', -184.335, -2.000, -217.241, -0.327
      UNION ALL SELECT 1001389, 'daxia',    -173.985, -2.000, -200.545, -1.775
      UNION ALL SELECT 1090160, 'exit_door', -209.000, 0.000, -160.000,  0.000
      UNION ALL SELECT 1090161, 'office_w',  -137.000, 1.000, -160.000,  0.000
      UNION ALL SELECT 1090162, 'office_e',  -134.500, 1.000, -160.000,  0.000
      UNION ALL SELECT 1200135, 'bell',      -199.639, 0.000, -163.171, -0.800) c;

INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1001050, 'man300_pw2_nananoby', 161, 'PrivateAreaMasterPast', 2, -195.163, -0.006, -162.220, -1.544, 0);

-- The same two copies in 181 PA 13/14 (the scripts use them while zone 161 is not loaded).
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
SELECT s.actorClassId, s.uniqueId, 181, s.privateAreaName, s.privateAreaLevel + 12,
       s.positionX, s.positionY, s.positionZ, s.rotation, s.motionPack
FROM server_eventnpc_spawn_locations s
WHERE s.zoneId = 161 AND s.uniqueId LIKE 'man300\_pw%';
