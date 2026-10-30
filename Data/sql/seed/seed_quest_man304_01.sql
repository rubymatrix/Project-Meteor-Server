-- Man304 "Forever Taken" (110016): the Waking Sands main-hall trigger. Hand-maintained.
-- The Consortium and the Waking Sands atrium are Man300's copies (seed_quest_man300_01.sql); the five
-- Silvertear soil points are the m3g_man304_spot rows of seed_msq_gridania_10_man3xx.sql; the hall's
-- companion is spawned by Data/scripts/content/SimpleContentMan30401.lua.
-- Apply after seed_quest_man300_01.sql, then restart the Map Server.
-- Rollback: seed_quest_man304_99_rollback.sql. Idempotent: the class fill only touches an empty row,
-- spawns are deleted and re-inserted by their 'man304_' prefix.
--
-- The placement is the ported server's (a calibration at the top of the hall stairs), not retail data.

UPDATE gamedata_actor_class SET
    classPath = '/Chara/Npc/Populace/PopulaceStandard',
    propertyFlags = 1,
    eventConditions = '{"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"pushWithCircleEventConditions":[{"isEnabled":"false","radius":"3.0","outwards":"false","silent":"false","conditionName":"pushDefault"}]}'
WHERE id = 1090186 AND classPath = '';

DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'man304\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    -- SEQ_010/020: the main hall stairs (marker 11001606), 181 PA 12.
    (1090186, 'man304_ws_hall_trig', 181, 'PrivateAreaMasterPast', 12, -193.460, -2.000, -177.310, 0, 0);
