-- Min306 "Runaway Little Girl" (110462): event-NPC class fills, quest-gated spawns and battle pools the quest
-- script and its duty director use. Hand-maintained. Apply, then restart the Map Server (classes, spawns and
-- pools load at boot). Rollback: seed_quest_min306_99_rollback.sql. Idempotent: class fills only touch rows
-- still empty; spawns, gates and pools are deleted and re-inserted by the 'min306_' prefix / pool id.
--
-- Sources: spawn positions and fight placements are ported scene placements of mixed provenance, several
-- invented (round offsets, rotation 0); none is retail-confirmed. Battle class paths and jobs follow the
-- shipped Fighter/monster classes; pools are auto-attack only.

-- ---- (1) event NPC class fills (spawning an empty classPath crashes the client) -------------------
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id IN (1000604) AND classPath = '';

-- ---- (4) spawns and quest gates ------------------------------------------------------------------
DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'min306\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1090008, 'min306_sildih_view', 170, '', 0, 131.000, 152.250, 487.000, 0.000, 0),
    (1000604, 'min306_nenekko_border', 172, '', 0, -728.060, 122.810, -357.150, 0.000, 0),
    (1000604, 'min306_nenekko_stop1', 172, '', 0, -1139.750, 60.240, -345.400, 0.000, 0),
    (1000604, 'min306_nenekko_stop2', 172, '', 0, -1549.040, 56.220, -397.320, 0.000, 0),
    (1000604, 'min306_nenekko_stop3', 172, '', 0, -1864.750, 55.830, -409.910, 0.000, 0),
    (1090008, 'min306_dig_s1a', 172, '', 0, -1143.750, 60.240, -345.400, 0.000, 0),
    (1090008, 'min306_dig_s1b', 172, '', 0, -1135.750, 60.240, -345.400, 0.000, 0),
    (1090008, 'min306_dig_s2a', 172, '', 0, -1553.040, 56.220, -397.320, 0.000, 0),
    (1090008, 'min306_dig_s2b', 172, '', 0, -1545.040, 56.220, -397.320, 0.000, 0),
    (1090008, 'min306_dig_s3a', 172, '', 0, -1868.750, 55.830, -409.910, 0.000, 0),
    (1090008, 'min306_dig_s3b', 172, '', 0, -1860.750, 55.830, -409.910, 0.000, 0),
    (1000604, 'min306_nenekko_docks', 172, '', 0, -2155.000, 14.390, -428.000, 0.000, 0);

CREATE TABLE IF NOT EXISTS server_eventnpc_quest_gated (
    zoneId   int(10) unsigned NOT NULL,
    uniqueId varchar(32)      NOT NULL,
    questId  int(10) unsigned NOT NULL,
    PRIMARY KEY (zoneId, uniqueId, questId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
DELETE FROM server_eventnpc_quest_gated WHERE uniqueId LIKE 'min306\_%';
INSERT INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId) VALUES
    (170, 'min306_sildih_view', 110462),
    (172, 'min306_nenekko_border', 110462),
    (172, 'min306_nenekko_stop1', 110462),
    (172, 'min306_nenekko_stop2', 110462),
    (172, 'min306_nenekko_stop3', 110462),
    (172, 'min306_dig_s1a', 110462),
    (172, 'min306_dig_s1b', 110462),
    (172, 'min306_dig_s2a', 110462),
    (172, 'min306_dig_s2b', 110462),
    (172, 'min306_dig_s3a', 110462),
    (172, 'min306_dig_s3b', 110462),
    (172, 'min306_nenekko_docks', 110462);

-- Nenekko and the triggers share one class each: the sequence range picks which spawn exists at each step
-- (needs the minSequence/maxSequence columns from seed_quest_port_00_shared.sql).
UPDATE server_eventnpc_quest_gated SET minSequence = 5,  maxSequence = 5  WHERE questId = 110462 AND uniqueId = 'min306_sildih_view';
UPDATE server_eventnpc_quest_gated SET minSequence = 10, maxSequence = 10 WHERE questId = 110462 AND uniqueId = 'min306_nenekko_border';
UPDATE server_eventnpc_quest_gated SET minSequence = 13, maxSequence = 13 WHERE questId = 110462 AND uniqueId LIKE 'min306\_nenekko\_stop%';
UPDATE server_eventnpc_quest_gated SET minSequence = 13, maxSequence = 13 WHERE questId = 110462 AND uniqueId LIKE 'min306\_dig\_%';
UPDATE server_eventnpc_quest_gated SET minSequence = 15, maxSequence = 15 WHERE questId = 110462 AND uniqueId = 'min306_nenekko_docks';
