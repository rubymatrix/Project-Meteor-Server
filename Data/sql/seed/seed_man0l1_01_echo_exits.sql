-- Man0l1 "Treasures of the Main": the boundary rings of the Drowning Wench, Marauders' Guild and
-- Fishermen's Guild echoes. Restart the map server after applying.
DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId IN
    ('man0l1_wench_echo_exit', 'man0l1_msk_echo_exit', 'man0l1_fsh_echo_exit');
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
  (1290002, 'man0l1_wench_echo_exit', 133, 'PrivateAreaMasterPast', 2, -447.395, 39.518, 193.12, 0, 0),
  (1290002, 'man0l1_msk_echo_exit',   230, 'PrivateAreaMasterPast', 3, -614.84, 43.0, -65.578, 0, 0),
  (1290002, 'man0l1_fsh_echo_exit',   230, 'PrivateAreaMasterPast', 5, -611.0, 4.55, 354.304, 0, 0);
