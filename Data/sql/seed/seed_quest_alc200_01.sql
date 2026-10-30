-- Alc200 "Sleep, Cousin of Death" (110420): S'lyhhia's spawn and class fill. Hand-maintained. Apply, then
-- restart the Map Server (classes and spawns load at boot). Rollback: seed_quest_alc200_99_rollback.sql.
-- Idempotent: the class fill only touches a row still empty; spawns are deleted and re-inserted by the
-- 'alc200_' prefix. Nogeloix and Nomomo are already placed.
--
-- Sources: spawn positions are ported scene placements of mixed provenance, several invented (round
-- offsets, rotation 0); none is retail-confirmed.

UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id = 1000932 AND classPath = '';

DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'alc200\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1000932, 'alc200_slyhhia', 209, '', 0, -215.880, 229.500, 300.480, 0.000, 0);
