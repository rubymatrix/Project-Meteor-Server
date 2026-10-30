-- Cul200 "Showdown" (110440): the finale trigger at the Bismarck's rear exit. Hand-maintained. Apply, then
-- restart the Map Server (classes and spawns load at boot). Rollback: seed_quest_cul200_99_rollback.sql.
-- Idempotent: class fills only touch rows still empty; spawns and gates are deleted and re-inserted by the
-- 'cul200_' prefix.
--
-- Sources: spawn positions are ported scene placements of mixed provenance, several invented (round
-- offsets, rotation 0); none is retail-confirmed.

DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'cul200\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1090008, 'cul200_finale_trigger', 230, '', 0, -495.090, 39.990, 30.640, 0.000, 0);

CREATE TABLE IF NOT EXISTS server_eventnpc_quest_gated (
    zoneId   int(10) unsigned NOT NULL,
    uniqueId varchar(32)      NOT NULL,
    questId  int(10) unsigned NOT NULL,
    PRIMARY KEY (zoneId, uniqueId, questId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
DELETE FROM server_eventnpc_quest_gated WHERE uniqueId LIKE 'cul200\_%';
INSERT INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId) VALUES
    (230, 'cul200_finale_trigger', 110440);
