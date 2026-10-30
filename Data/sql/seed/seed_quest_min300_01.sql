-- Min300 "Little Saboteurs" (110461): event-NPC class fills, quest-gated spawns and battle pools the quest
-- script and its duty director use. Hand-maintained. Apply, then restart the Map Server (classes, spawns and
-- pools load at boot). Rollback: seed_quest_min300_99_rollback.sql. Idempotent: class fills only touch rows
-- still empty; spawns, gates and pools are deleted and re-inserted by the 'min300_' prefix / pool id.
--
-- Sources: spawn positions and fight placements are ported scene placements of mixed provenance, several
-- invented (round offsets, rotation 0); none is retail-confirmed. Battle class paths and jobs follow the
-- shipped Fighter/monster classes; pools are auto-attack only.

-- ---- (1) event NPC class fills (spawning an empty classPath crashes the client) -------------------
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id IN (1000604, 1000857, 1000858, 1700010) AND classPath = '';

-- ---- (4) spawns and quest gates ------------------------------------------------------------------
DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'min300\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1700010, 'min300_coach_driver', 155, '', 0, 62.040, 10.560, -1241.930, 0.000, 0),
    (1090008, 'min300_buried_box', 154, '', 0, 1504.370, -0.240, 1312.720, 0.000, 0),
    (1000604, 'min300_nenekko', 209, '', 0, -135.930, 201.500, 266.430, 0.000, 0),
    (1000857, 'min300_popokkuli', 209, '', 0, -95.660, 195.600, 316.790, 0.000, 0),
    (1000858, 'min300_seserukka', 209, '', 0, -94.570, 195.600, 316.460, 0.000, 0);

CREATE TABLE IF NOT EXISTS server_eventnpc_quest_gated (
    zoneId   int(10) unsigned NOT NULL,
    uniqueId varchar(32)      NOT NULL,
    questId  int(10) unsigned NOT NULL,
    PRIMARY KEY (zoneId, uniqueId, questId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
DELETE FROM server_eventnpc_quest_gated WHERE uniqueId LIKE 'min300\_%';
INSERT INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId) VALUES
    (155, 'min300_coach_driver', 110461),
    (154, 'min300_buried_box', 110461),
    (209, 'min300_nenekko', 110461),
    (209, 'min300_popokkuli', 110461),
    (209, 'min300_seserukka', 110461);
