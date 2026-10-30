-- Man206 "Together We Stand" (110014): this quest's Waking Sands (181 PA 11), the Gridania rendezvous and
-- Camp Nine Ivies triggers, and the grove sentries' pools. Hand-maintained.
-- The grove duty's sylphs and companion are spawned by Data/scripts/content/SimpleContentMan20601.lua,
-- the sentries by Data/scripts/directors/Quest/QuestDirectorMan20601.lua.
-- Apply after seed_duty_01_mobs.sql (the triarius and speculator pools), then restart the Map Server.
-- Rollback: seed_quest_man206_99_rollback.sql. Idempotent: the private area is only inserted when
-- missing, class fills only touch empty rows, spawns are deleted and re-inserted by their 'man206_'
-- prefix, pools by id.
--
-- Placements are the ported server's, a mix of capture-derived and calibrated points; none is retail
-- data. Map objects (doors, flags) are left out: they need layout ids.

-- ---- (1) private area ------------------------------------------------------------------------------
-- 181 11: the Waking Sands for Man206 (the sylphs in the Solar); Man300 returns here after its briefing.
INSERT INTO server_zones_privateareas (parentZoneId, className, privateAreaName, privateAreaType, canExitArea, music)
SELECT 181, '/Area/PrivateArea/PrivateAreaMasterPast', 'PrivateAreaMasterPast', 11, 0, 58
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM server_zones_privateareas p
                  WHERE p.parentZoneId = 181 AND p.privateAreaName = 'PrivateAreaMasterPast' AND p.privateAreaType = 11);

-- ---- (2) class fills -------------------------------------------------------------------------------
-- Spawning a class with an empty classPath crashes the client.
UPDATE gamedata_actor_class SET
    classPath = '/Chara/Npc/Populace/PopulaceStandard',
    propertyFlags = 1,
    eventConditions = CONCAT('{"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],',
        '"pushWithCircleEventConditions":[{"isEnabled":"false","radius":"',
        CASE id WHEN 1090177 THEN '6.0' WHEN 1090296 THEN '4.0' END,
        '","outwards":"false","silent":"false","conditionName":"pushDefault"}]}')
WHERE id IN (
    1090177,  -- SEQ_010: the rendezvous at the Gridania aetheryte plaza (marker 11001402)
    1090296   -- SEQ_015-025: the duty start at Camp Nine Ivies (marker 11001403)
) AND classPath = '';

-- The imperial retiarius and hastatus client classes, the same family as the triarius and
-- speculator fills in seed_duty_01_mobs.sql.
UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2180011
  SET t.classPath = CASE t.id
        WHEN 2280004 THEN '/Chara/Npc/Monster/Empire/EmpireGladiatorStandard'
        WHEN 2280005 THEN '/Chara/Npc/Monster/Empire/EmpireLancerStandard'
      END,
      t.propertyFlags = s.propertyFlags,
      t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id IN (2280004, 2280005) AND t.classPath = '';

-- ---- (3) battle pools ------------------------------------------------------------------------------
-- Pool id = actor class id + 6000000. Auto-attack only; aggro is the director's (it sets their sight).
DELETE FROM server_battlenpc_pools WHERE poolId IN (8280004, 8280005);
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8280004, 2280004, 'man206_imperial_retiarius', 29, 8, 1, 4200, 1, 0, 0, 0, 0, 0),
  (8280005, 2280005, 'man206_imperial_hastatus',  29, 8, 1, 4200, 1, 0, 0, 0, 0, 0);

-- ---- (4) spawns ------------------------------------------------------------------------------------
DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'man206\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    -- The Waking Sands, 181 PA 11.
    (1000843, 'man206_ws_minfilia',    181, 'PrivateAreaMasterPast', 11, -123.998,  1.200, -162.070, -0.784, 1017),
    (1001046, 'man206_ws_tataru',      181, 'PrivateAreaMasterPast', 11, -199.563,  0.000, -162.347, -1.500, 1017),
    (1001373, 'man206_ws_sahja_zhwan', 181, 'PrivateAreaMasterPast', 11, -156.327,  0.000, -156.190, -1.842, 1015),
    (1001374, 'man206_ws_nenekani',    181, 'PrivateAreaMasterPast', 11, -162.314,  0.000, -140.110,  3.100, 1017),
    (1001375, 'man206_ws_godfrey',     181, 'PrivateAreaMasterPast', 11, -188.765,  0.000, -155.780, -1.550, 1040),
    (1001376, 'man206_ws_fenana',      181, 'PrivateAreaMasterPast', 11, -197.455, -2.000, -178.362,  1.000, 1015),
    (1001377, 'man206_ws_nonoru',      181, 'PrivateAreaMasterPast', 11, -177.750,  0.000, -156.924, -3.135, 0),
    (1001378, 'man206_ws_seranelien',  181, 'PrivateAreaMasterPast', 11, -137.165,  1.000, -162.520, -1.516, 1016),
    (1001086, 'man206_ws_zoxio',       181, 'PrivateAreaMasterPast', 11, -121.670,  1.200, -155.731, -2.918, 0),
    (1001178, 'man206_ws_diluxio',     181, 'PrivateAreaMasterPast', 11, -124.862,  1.200, -157.354,  2.749, 0),
    (1001085, 'man206_ws_almxio',      181, 'PrivateAreaMasterPast', 11, -126.080,  1.200, -164.375, -0.017, 0),
    (1090160, 'man206_ws_exit_door',   181, 'PrivateAreaMasterPast', 11, -209.000,  0.000, -160.000,  0.000, 0),
    (1090161, 'man206_ws_office_w',    181, 'PrivateAreaMasterPast', 11, -137.000,  1.000, -160.000,  0.000, 0),
    (1090162, 'man206_ws_office_e',    181, 'PrivateAreaMasterPast', 11, -134.500,  1.000, -160.000,  0.000, 0),
    (1200135, 'man206_ws_retainerbell', 181, 'PrivateAreaMasterPast', 11, -199.977, 0.000, -162.959,  0.000, 0),
    -- SEQ_010: the rendezvous, Gridania aetheryte plaza (public 206).
    (1090177, 'man206_rendezvous',     206, '', 0, -111.430, 16.850, -1342.049, 0, 0),
    -- SEQ_015-025: Camp Nine Ivies (public 151).
    (1090296, 'man206_duty_start',     151, '', 0, 1700.490, 20.300,  -868.110, 0, 0);
