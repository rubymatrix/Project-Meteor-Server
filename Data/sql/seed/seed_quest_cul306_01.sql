-- Cul306 "Something in the Soup" (110442): the 6-4 statue, bethel and ramp triggers in Limsa Lominsa.
-- Hand-maintained. Apply, then restart the Map Server (classes and spawns load at boot). Rollback:
-- seed_quest_cul306_99_rollback.sql. Idempotent: class fills only touch rows still empty; spawns and gates
-- are deleted and re-inserted by the 'cul306_' prefix.
--
-- Sources: spawn positions are ported scene placements of mixed provenance, several invented (round
-- offsets, rotation 0); none is retail-confirmed.

DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'cul306\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1090008, 'cul306_64_trigger',     230, '', 0, -567.900,  8.000, 108.090, 0.000, 0),
    (1090008, 'cul306_bethel_trigger', 230, '', 0, -597.400,  8.000,  59.630, 0.000, 0),
    (1090008, 'cul306_ramp_trigger',   230, '', 0, -527.340, 37.000,  83.000, 0.000, 0);

CREATE TABLE IF NOT EXISTS server_eventnpc_quest_gated (
    zoneId   int(10) unsigned NOT NULL,
    uniqueId varchar(32)      NOT NULL,
    questId  int(10) unsigned NOT NULL,
    PRIMARY KEY (zoneId, uniqueId, questId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
DELETE FROM server_eventnpc_quest_gated WHERE uniqueId LIKE 'cul306\_%';
INSERT INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId) VALUES
    (230, 'cul306_64_trigger', 110442),
    (230, 'cul306_bethel_trigger', 110442),
    (230, 'cul306_ramp_trigger', 110442);
