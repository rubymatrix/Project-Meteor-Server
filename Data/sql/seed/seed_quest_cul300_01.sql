-- Cul300 "Mystery of the Gastronome Gone Home" (110441): the thickset tailor in Ul'dah and the alley
-- trigger in Limsa Lominsa. Hand-maintained. Apply, then restart the Map Server (classes and spawns load
-- at boot). Rollback: seed_quest_cul300_99_rollback.sql. Idempotent: class fills only touch rows still
-- empty; spawns and gates are deleted and re-inserted by the 'cul300_' prefix.
--
-- Sources: spawn positions are ported scene placements of mixed provenance, several invented (round
-- offsets, rotation 0); none is retail-confirmed.

UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id = 1000292 AND classPath = '';

DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'cul300\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1000292, 'cul300_thickset_tailor', 209, '', 0,   64.820, 195.590, 251.900, 0.000, 0),
    (1090008, 'cul300_alley_trigger',   230, '', 0, -491.080,  39.990,  39.040, 0.000, 0);

CREATE TABLE IF NOT EXISTS server_eventnpc_quest_gated (
    zoneId   int(10) unsigned NOT NULL,
    uniqueId varchar(32)      NOT NULL,
    questId  int(10) unsigned NOT NULL,
    PRIMARY KEY (zoneId, uniqueId, questId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
DELETE FROM server_eventnpc_quest_gated WHERE uniqueId LIKE 'cul300\_%';
INSERT INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId) VALUES
    (209, 'cul300_thickset_tailor', 110441),
    (230, 'cul300_alley_trigger', 110441);
