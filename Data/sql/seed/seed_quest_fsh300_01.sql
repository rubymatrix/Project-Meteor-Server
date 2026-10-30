-- Fsh300 "The Beast of the Barrel" (110501): Sisipu's public spawn (Fsh306 uses it too) and the four
-- Barrel points. Hand-maintained. Apply, then restart the Map Server (classes and spawns load at boot).
-- Rollback: seed_quest_fsh300_99_rollback.sql. Idempotent: class fills only touch rows still empty; spawns
-- and gates are deleted and re-inserted by the 'fsh300_' prefix.
--
-- Sources: spawn positions are ported scene placements of mixed provenance, several invented (round
-- offsets, rotation 0); none is retail-confirmed.

DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'fsh300\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1000155, 'fsh300_sisipu',           230, '', 0, -620.820, 4.250, 354.550, 1.110, 0),
    (1090008, 'fsh300_barrel_trigger_a', 230, '', 0, -819.000, 1.000, 864.000, 0.000, 0),
    (1090008, 'fsh300_barrel_trigger_b', 230, '', 0, -807.000, 1.000, 864.000, 0.000, 0),
    (1090008, 'fsh300_barrel_trigger_c', 230, '', 0, -791.000, 1.000, 864.000, 0.000, 0),
    (1090008, 'fsh300_barrel_trigger_d', 230, '', 0, -780.000, 1.000, 864.000, 0.000, 0);

-- Sisipu is a guild NPC and stays public.
CREATE TABLE IF NOT EXISTS server_eventnpc_quest_gated (
    zoneId   int(10) unsigned NOT NULL,
    uniqueId varchar(32)      NOT NULL,
    questId  int(10) unsigned NOT NULL,
    PRIMARY KEY (zoneId, uniqueId, questId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
DELETE FROM server_eventnpc_quest_gated WHERE uniqueId LIKE 'fsh300\_%';
INSERT INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId) VALUES
    (230, 'fsh300_barrel_trigger_a', 110501),
    (230, 'fsh300_barrel_trigger_b', 110501),
    (230, 'fsh300_barrel_trigger_c', 110501),
    (230, 'fsh300_barrel_trigger_d', 110501);

-- Each Barrel point answers its own round's four emotes (emoteDefault 4r+1..4r+4): Bow, Welcome, Salute,
-- Kneel; Beckon, Wave, Clap, Huh; Upset, Cry, Angry, Furious; Chuckle, Laugh, Joy, Congratulate. The
-- candidates come from the round hints of the quest's text sheet; accepting any of the four is
-- The push circle stays: the points are also the push triggers of steps 10 and 25.
DELETE FROM server_eventnpc_spawn_eventconditions WHERE zoneId = 230 AND uniqueId LIKE 'fsh300\_barrel\_trigger\_%';
INSERT INTO server_eventnpc_spawn_eventconditions (zoneId, uniqueId, eventConditions) VALUES
    (230, 'fsh300_barrel_trigger_a',
     '{"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"pushWithCircleEventConditions":[{"isEnabled":"false","radius":"6.0","outwards":"false","silent":"false","conditionName":"pushDefault"}],"emoteEventConditions":[{"unknown1":4,"unknown2":0,"emoteId":105,"conditionName":"emoteDefault1"},{"unknown1":4,"unknown2":0,"emoteId":141,"conditionName":"emoteDefault2"},{"unknown1":4,"unknown2":0,"emoteId":131,"conditionName":"emoteDefault3"},{"unknown1":4,"unknown2":0,"emoteId":119,"conditionName":"emoteDefault4"}]}'),
    (230, 'fsh300_barrel_trigger_b',
     '{"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"pushWithCircleEventConditions":[{"isEnabled":"false","radius":"6.0","outwards":"false","silent":"false","conditionName":"pushDefault"}],"emoteEventConditions":[{"unknown1":4,"unknown2":0,"emoteId":108,"conditionName":"emoteDefault5"},{"unknown1":4,"unknown2":0,"emoteId":116,"conditionName":"emoteDefault6"},{"unknown1":4,"unknown2":0,"emoteId":107,"conditionName":"emoteDefault7"},{"unknown1":4,"unknown2":0,"emoteId":117,"conditionName":"emoteDefault8"}]}'),
    (230, 'fsh300_barrel_trigger_c',
     '{"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"pushWithCircleEventConditions":[{"isEnabled":"false","radius":"6.0","outwards":"false","silent":"false","conditionName":"pushDefault"}],"emoteEventConditions":[{"unknown1":4,"unknown2":0,"emoteId":140,"conditionName":"emoteDefault9"},{"unknown1":4,"unknown2":0,"emoteId":110,"conditionName":"emoteDefault10"},{"unknown1":4,"unknown2":0,"emoteId":102,"conditionName":"emoteDefault11"},{"unknown1":4,"unknown2":0,"emoteId":103,"conditionName":"emoteDefault12"}]}'),
    (230, 'fsh300_barrel_trigger_d',
     '{"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"pushWithCircleEventConditions":[{"isEnabled":"false","radius":"6.0","outwards":"false","silent":"false","conditionName":"pushDefault"}],"emoteEventConditions":[{"unknown1":4,"unknown2":0,"emoteId":120,"conditionName":"emoteDefault13"},{"unknown1":4,"unknown2":0,"emoteId":121,"conditionName":"emoteDefault14"},{"unknown1":4,"unknown2":0,"emoteId":118,"conditionName":"emoteDefault15"},{"unknown1":4,"unknown2":0,"emoteId":129,"conditionName":"emoteDefault16"}]}');
