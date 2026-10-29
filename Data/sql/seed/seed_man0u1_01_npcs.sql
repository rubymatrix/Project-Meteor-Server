-- Man0u1 "Court in the Sands": the private areas, actor classes, triggers, spawns and battle pools
-- man0u1.lua and its two duties use. Restart the map server after applying. A class spawned with an
-- empty classPath crashes the client, so every one spawned here gets the populace class.
--
-- The Market Wards actors and the stage and camp triggers stand in public zones, so every player
-- sees them; only a player on the matching step can use them.

-- ---- (1) private areas ---------------------------------------------------------------------------

INSERT INTO server_zones_privateareas (parentZoneId, className, privateAreaName, privateAreaType, canExitArea, music)
SELECT v.parentZoneId, '/Area/PrivateArea/PrivateAreaMasterPast', 'PrivateAreaMasterPast', v.privateAreaType, 0, v.music
FROM (SELECT 170 AS parentZoneId, 4 AS privateAreaType, 68 AS music
      UNION ALL SELECT 209, 6, 66
      UNION ALL SELECT 209, 8, 66
      UNION ALL SELECT 209, 10, 66) v
WHERE NOT EXISTS (SELECT 1 FROM server_zones_privateareas p
                  WHERE p.parentZoneId = v.parentZoneId AND p.privateAreaName = 'PrivateAreaMasterPast'
                    AND p.privateAreaType = v.privateAreaType);

-- ---- (2) populace class fills --------------------------------------------------------------------

UPDATE gamedata_actor_class SET
    classPath = '/Chara/Npc/Populace/PopulaceStandard',
    propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id IN (
    1000038, 1000690, 1000699, 1000807, 1000808, 1000809, 1000810, 1000811, 1000812, 1000814,
    1000815, 1000816, 1000817, 1000895, 1000936, 1000937, 1000938, 1000939, 1000940, 1000941,
    1000948, 1000981, 1000995, 1000997, 1000999, 1001020, 1001054, 1001207, 1001210, 1001286,
    1001287, 1001288, 1001289, 1001290
) AND classPath = '';

-- The Slow-witted Miner has a classPath but no talk condition.
UPDATE gamedata_actor_class SET propertyFlags = 19, eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id = 1000689 AND eventConditions IS NULL;

-- ---- (3) emote conditions ------------------------------------------------------------------------
-- F'lhaminn and the two miners answer the six taught emotes (103, 108, 121, 125, 140, 135) as
-- emoteDefault1-6 in teach order.

UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"emoteEventConditions":[{"unknown1":4,"unknown2":0,"emoteId":103,"conditionName":"emoteDefault1"},{"unknown1":4,"unknown2":0,"emoteId":108,"conditionName":"emoteDefault2"},{"unknown1":4,"unknown2":0,"emoteId":121,"conditionName":"emoteDefault3"},{"unknown1":4,"unknown2":0,"emoteId":125,"conditionName":"emoteDefault4"},{"unknown1":4,"unknown2":0,"emoteId":140,"conditionName":"emoteDefault5"},{"unknown1":4,"unknown2":0,"emoteId":135,"conditionName":"emoteDefault6"}]}'
WHERE id IN (1000842, 1001283, 1001284) AND (classPath = '' OR eventConditions IS NULL OR eventConditions NOT LIKE '%emoteEventConditions%');

-- ---- (4) push triggers ---------------------------------------------------------------------------

UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 1, eventConditions = '{"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"pushWithCircleEventConditions":[{"isEnabled":"false","radius":"10.0","outwards":"false","silent":"false","conditionName":"pushDefault"}]}' WHERE id = 1090285;
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 1, eventConditions = '{"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"pushWithCircleEventConditions":[{"isEnabled":"false","radius":"6.0","outwards":"false","silent":"false","conditionName":"pushDefault"}]}' WHERE id = 1090286;
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 1, eventConditions = '{"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"pushWithCircleEventConditions":[{"isEnabled":"false","radius":"6.0","outwards":"false","silent":"false","conditionName":"pushDefault"}]}' WHERE id = 1090288;
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 1, eventConditions = '{"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"pushWithCircleEventConditions":[{"isEnabled":"false","radius":"2.0","outwards":"false","silent":"false","conditionName":"pushDefault"}]}' WHERE id = 1090120;
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 1, eventConditions = '{"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"pushWithCircleEventConditions":[{"isEnabled":"false","radius":"2.0","outwards":"false","silent":"false","conditionName":"pushDefault"}]}' WHERE id = 1090121;

-- Shipped trigger classes that lack the push circle the quest arms.
UPDATE gamedata_actor_class SET eventConditions = '{"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"pushWithCircleEventConditions":[{"isEnabled":"false","radius":"3.0","outwards":"false","silent":"false","conditionName":"pushDefault"}]}'
WHERE id = 1090119 AND (eventConditions IS NULL OR eventConditions NOT LIKE '%pushWithCircle%');
UPDATE gamedata_actor_class SET eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"pushWithCircleEventConditions":[{"isEnabled":"false","radius":"12.0","outwards":"false","silent":"false","conditionName":"pushDefault"}]}'
WHERE id = 1090283 AND eventConditions NOT LIKE '%pushWithCircle%';
UPDATE gamedata_actor_class SET eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"pushWithCircleEventConditions":[{"isEnabled":"false","radius":"10.0","outwards":"false","silent":"false","conditionName":"pushDefault"}]}'
WHERE id = 1090077 AND eventConditions NOT LIKE '%pushWithCircle%';

-- ---- (5) duty battle npcs ------------------------------------------------------------------------
-- The Tourney Gladiator (Coliseum match), F'lhaminn and the chinchillas (escort).

UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2290004
  SET t.classPath = CASE t.id
        WHEN 2280157 THEN '/Chara/Npc/Monster/Fighter/FighterEnemyGladiatorStandard'
        WHEN 2290008 THEN '/Chara/Npc/Monster/Fighter/FighterAllyGuarded'
      END,
      t.propertyFlags = s.propertyFlags,
      t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id IN (2280157, 2290008) AND t.classPath = '';
-- The chinchilla takes the wharf rat's model class.
UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2104001
  SET t.classPath = s.classPath, t.propertyFlags = s.propertyFlags, t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id = 2204010 AND t.classPath = '';

DELETE FROM server_battlenpc_pools WHERE poolId IN (8280157, 8290008, 8204010);
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8280157, 2280157, 'man0u1_tourney_gladiator', 29, 3, 1, 4200, 1, 1, 0, 0, 0, 0),
  (8290008, 2290008, 'man0u1_escort_flhaminn',   29, 2, 1, 4200, 1, 0, 0, 0, 0, 0),
  (8204010, 2204010, 'man0u1_chinchilla',        12, 0, 1, 4200, 1, 1, 0, 0, 0, 0);

-- ---- (6) spawns ----------------------------------------------------------------------------------

DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'man0u1\\_%';

INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1000940, 'man0u1_qs_upbeat_adventurer', 175, 'PrivateAreaMasterPast', 4, -71.000, 195.000, 68.500, -0.600, 0),
    (1000936, 'man0u1_qs_undaunted_adventurer', 175, 'PrivateAreaMasterPast', 4, -79.000, 195.000, 70.000, 0.800, 0),
    (1000937, 'man0u1_qs_greedy_merchant', 175, 'PrivateAreaMasterPast', 4, -82.500, 195.000, 76.500, 1.600, 0),
    (1000938, 'man0u1_qs_lionhearted_adv', 175, 'PrivateAreaMasterPast', 4, -68.000, 195.000, 82.000, -2.600, 0),
    (1000939, 'man0u1_qs_spry_salesman', 175, 'PrivateAreaMasterPast', 4, -77.500, 195.000, 84.500, 2.900, 0),
    (1000941, 'man0u1_qs_seemingly_calm_adv', 175, 'PrivateAreaMasterPast', 4, -84.000, 195.000, 70.500, 1.200, 0),
    (1000948, 'man0u1_qs_thancred', 175, 'PrivateAreaMasterPast', 4, -76.500, 195.000, 80.500, 2.400, 0),
    (1000864, 'man0u1_qs_otopa_pottopa', 175, 'PrivateAreaMasterPast', 4, -70.500, 195.000, 76.000, -2.200, 0),
    (1000807, 'man0u1_qs_overcompetitive_adv', 175, 'PrivateAreaMasterPast', 4, -66.500, 195.000, 72.500, -1.800, 0),
    (1290002, 'man0u1_exit', 175, 'PrivateAreaMasterPast', 4, -67.695, 195.210, 60.553, -1.189, 0),
    (1000863, 'man0u1_lulutsu_lobby', 209, 'PrivateAreaMasterPast', 10, -193.460, 195.050, 183.650, 0.610, 0),
    (1000962, 'man0u1_papawa_lobby', 209, 'PrivateAreaMasterPast', 10, -190.338, 194.506, 198.992, 1.399, 0),
    (1000965, 'man0u1_abylgo_hamylgo', 209, 'PrivateAreaMasterPast', 10, -190.501, 194.506, 201.258, 1.897, 0),
    (1000964, 'man0u1_fruhybolg', 209, 'PrivateAreaMasterPast', 10, -186.801, 193.204, 198.547, 1.598, 1016),
    (1000969, 'man0u1_qmhalawi', 209, 'PrivateAreaMasterPast', 10, -184.852, 193.200, 191.435, 0.643, 0),
    (1001020, 'man0u1_undefeated_gladiator', 209, 'PrivateAreaMasterPast', 10, -175.070, 193.201, 206.422, -0.244, 0),
    (1000995, 'man0u1_poorly_outfitted_glad', 209, 'PrivateAreaMasterPast', 10, -176.463, 189.972, 218.279, -1.552, 0),
    (1000997, 'man0u1_aggrieved_gladiator', 209, 'PrivateAreaMasterPast', 10, -178.990, 189.950, 222.340, -2.280, 1010),
    (1000967, 'man0u1_swerdahrm', 209, 'PrivateAreaMasterPast', 10, -183.328, 190.105, 221.679, 2.370, 1015),
    (1000999, 'man0u1_disheartened_gladiator', 209, 'PrivateAreaMasterPast', 10, -177.483, 189.953, 222.403, -2.896, 1034),
    (1290002, 'man0u1_exit', 209, 'PrivateAreaMasterPast', 10, -186.537, 193.296, 196.796, 1.202, 0),
    (1090283, 'man0u1_arena_gate_trig', 209, 'PrivateAreaMasterPast', 10, -184.969, 190.150, 219.708, -1.550, 0),
    (1000863, 'man0u1_lulutsu_lobby_6', 209, 'PrivateAreaMasterPast', 6, -193.460, 195.050, 183.650, 0.610, 0),
    (1000962, 'man0u1_papawa_lobby_6', 209, 'PrivateAreaMasterPast', 6, -190.338, 194.506, 198.992, 1.399, 0),
    (1000965, 'man0u1_abylgo_hamylgo_6', 209, 'PrivateAreaMasterPast', 6, -190.501, 194.506, 201.258, 1.897, 0),
    (1000964, 'man0u1_fruhybolg_6', 209, 'PrivateAreaMasterPast', 6, -186.801, 193.204, 198.547, 1.598, 1016),
    (1000969, 'man0u1_qmhalawi_6', 209, 'PrivateAreaMasterPast', 6, -184.852, 193.200, 191.435, 0.643, 0),
    (1001020, 'man0u1_undefeated_gladiator_6', 209, 'PrivateAreaMasterPast', 6, -175.070, 193.201, 206.422, -0.244, 0),
    (1000995, 'man0u1_poorly_outfitted_glad_6', 209, 'PrivateAreaMasterPast', 6, -176.463, 189.972, 218.279, -1.552, 0),
    (1000997, 'man0u1_aggrieved_gladiator_6', 209, 'PrivateAreaMasterPast', 6, -178.990, 189.950, 222.340, -2.280, 1010),
    (1000967, 'man0u1_swerdahrm_6', 209, 'PrivateAreaMasterPast', 6, -183.328, 190.105, 221.679, 2.370, 1015),
    (1000999, 'man0u1_disheartened_gladiator_6', 209, 'PrivateAreaMasterPast', 6, -177.483, 189.953, 222.403, -2.896, 1034),
    (1290002, 'man0u1_exit_6', 209, 'PrivateAreaMasterPast', 6, -186.537, 193.296, 196.796, 1.202, 0),
    (1090286, 'man0u1_stairs_trig', 209, 'PrivateAreaMasterPast', 6, -177.756, 193.200, 208.163, -3.134, 0),
    (1000842, 'man0u1_flhaminn_teach', 209, 'PrivateAreaMasterPast', 5, -96.303, 195.500, 314.276, 1.800, 0),
    (1000861, 'man0u1_linette_scene', 209, 'PrivateAreaMasterPast', 5, -92.380, 195.600, 313.430, -1.430, 0),
    (1000637, 'man0u1_shilgen', 209, 'PrivateAreaMasterPast', 5, -91.810, 195.600, 314.820, -1.050, 0),
    (1600042, 'man0u1_nortmoen', 209, 'PrivateAreaMasterPast', 5, -90.840, 195.600, 315.940, -0.820, 0),
    (1001289, 'man0u1_monitoring_miner', 209, 'PrivateAreaMasterPast', 5, -110.303, 194.204, 319.273, 0.201, 0),
    (1001287, 'man0u1_maudlin_miner', 209, 'PrivateAreaMasterPast', 5, -114.625, 194.204, 316.557, -2.385, 0),
    (1001203, 'man0u1_tyago_moui', 209, 'PrivateAreaMasterPast', 5, -116.040, 194.200, 313.080, 0.870, 0),
    (1000895, 'man0u1_astonished_adv', 209, 'PrivateAreaMasterPast', 5, -104.933, 194.204, 320.552, -0.324, 0),
    (1001288, 'man0u1_mocking_miner', 209, 'PrivateAreaMasterPast', 5, -110.039, 194.204, 322.382, 0.327, 0),
    (1000690, 'man0u1_muscular_miner', 209, 'PrivateAreaMasterPast', 5, -102.399, 194.204, 321.979, -1.244, 0),
    (1001290, 'man0u1_displeased_dancer', 209, 'PrivateAreaMasterPast', 5, -101.226, 194.201, 327.378, -2.770, 0),
    (1001284, 'man0u1_maddened_miner', 209, 'PrivateAreaMasterPast', 5, -107.467, 195.000, 324.192, 0.426, 0),
    (1001283, 'man0u1_manic_miner', 209, 'PrivateAreaMasterPast', 5, -108.381, 195.000, 325.881, 0.700, 0),
    (1001054, 'man0u1_corguevais_scene', 209, 'PrivateAreaMasterPast', 5, -105.653, 195.000, 327.774, -2.187, 1080),
    (1001286, 'man0u1_nittma_guttma', 209, 'PrivateAreaMasterPast', 5, -105.418, 195.000, 329.616, -2.363, 0),
    (1000981, 'man0u1_closefisted_woman', 209, 'PrivateAreaMasterPast', 5, -115.018, 194.204, 321.846, 0.903, 0),
    (1290002, 'man0u1_exit_5', 209, 'PrivateAreaMasterPast', 5, -104.394, 194.200, 318.220, 0.843, 0),
    (1000842, 'man0u1_flhaminn_teach_8', 209, 'PrivateAreaMasterPast', 8, -111.075, 194.234, 314.516, -2.598, 1093),
    (1000861, 'man0u1_linette_scene_8', 209, 'PrivateAreaMasterPast', 8, -92.380, 195.600, 313.430, -1.430, 1041),
    (1000637, 'man0u1_shilgen_8', 209, 'PrivateAreaMasterPast', 8, -91.810, 195.600, 314.820, -1.050, 1015),
    (1600042, 'man0u1_nortmoen_8', 209, 'PrivateAreaMasterPast', 8, -90.840, 195.600, 315.940, -0.820, 1041),
    (1001289, 'man0u1_monitoring_miner_8', 209, 'PrivateAreaMasterPast', 8, -104.678, 194.200, 322.742, -1.926, 0),
    (1001287, 'man0u1_maudlin_miner_8', 209, 'PrivateAreaMasterPast', 8, -109.955, 194.200, 319.943, -1.929, 0),
    (1001203, 'man0u1_tyago_moui_8', 209, 'PrivateAreaMasterPast', 8, -116.040, 194.200, 313.080, 0.870, 1017),
    (1000690, 'man0u1_muscular_miner_8', 209, 'PrivateAreaMasterPast', 8, -112.026, 194.200, 321.597, 2.839, 0),
    (1001054, 'man0u1_corguevais_scene_8', 209, 'PrivateAreaMasterPast', 8, -111.870, 194.234, 313.202, 0.544, 1102),
    (1001286, 'man0u1_nittma_guttma_8', 209, 'PrivateAreaMasterPast', 8, -105.875, 195.034, 329.334, -2.808, 0),
    (1001290, 'man0u1_displeased_dancer_8', 209, 'PrivateAreaMasterPast', 8, -114.363, 194.234, 318.290, 2.834, 0),
    (1290002, 'man0u1_exit_8', 209, 'PrivateAreaMasterPast', 8, -104.394, 194.200, 318.220, 0.843, 0),
    (1090285, 'man0u1_gate_trig', 170, '', 0, -34.540, 183.000, -68.880, 0.000, 0),
    (1090077, 'man0u1_camp_echo_trig', 170, '', 0, 45.500, 200.000, -475.500, 0.000, 0),
    (1000042, 'man0u1_ascilia_echo', 170, 'PrivateAreaMasterPast', 4, 41.927, 200.000, -479.950, -1.733, 1103),
    (1001054, 'man0u1_corguevais_echo', 170, 'PrivateAreaMasterPast', 4, 41.986, 200.000, -479.990, -1.988, 1102),
    (1000038, 'man0u1_flhaminn_echo', 170, 'PrivateAreaMasterPast', 4, 42.881, 200.000, -481.131, -0.288, 1093),
    (1000811, 'man0u1_regarding_roegadyn', 170, 'PrivateAreaMasterPast', 4, 40.565, 200.000, -482.754, 0.293, 1021),
    (1000814, 'man0u1_unsavory_cur', 170, 'PrivateAreaMasterPast', 4, 38.783, 200.000, -481.714, 1.086, 0),
    (1000808, 'man0u1_untidy_outlander', 170, 'PrivateAreaMasterPast', 4, 42.825, 200.000, -482.713, -0.202, 0),
    (1000817, 'man0u1_helpless_hyur', 170, 'PrivateAreaMasterPast', 4, 43.861, 200.000, -482.195, -0.320, 0),
    (1000812, 'man0u1_troubled_trader', 170, 'PrivateAreaMasterPast', 4, 45.182, 200.000, -479.291, -1.950, 1033),
    (1000810, 'man0u1_frightened_lalafell', 170, 'PrivateAreaMasterPast', 4, 44.976, 200.000, -478.349, -2.085, 1035),
    (1000809, 'man0u1_malnourished_midlander', 170, 'PrivateAreaMasterPast', 4, 42.872, 200.000, -476.774, -2.834, 0),
    (1000816, 'man0u1_brinemonger', 170, 'PrivateAreaMasterPast', 4, 39.755, 200.000, -477.685, 2.274, 1053),
    (1000815, 'man0u1_malodorous_mister', 170, 'PrivateAreaMasterPast', 4, 38.277, 200.000, -478.118, 2.084, 0),
    (1290002, 'man0u1_exit', 170, 'PrivateAreaMasterPast', 4, 42.355, 200.000, -479.924, -1.809, 0),
    (1090288, 'man0u1_stage_trig', 209, '', 0, -90.338, 196.113, 323.454, -1.910, 0),
    (1090121, 'man0u1_seq100_trig', 180, '', 0, -148.578, 2.000, -179.000, 0.000, 0),
    (1090120, 'man0u1_seq105_trig', 180, '', 0, -208.399, 0.074, -159.982, 0.000, 0),
    (1000689, 'man0u1_slowwitted_miner', 180, '', 0, -191.233, 0.000, -165.667, 3.125, 0),
    (1000699, 'man0u1_qualmish_miner', 180, '', 0, -190.809, -2.000, -178.704, -0.280, 1031),
    (1000690, 'man0u1_muscular_miner_ward', 180, '', 0, -196.664, -2.000, -174.713, 2.363, 0),
    (1001207, 'man0u1_worrisome_assistant', 180, '', 0, -155.354, 0.000, -158.791, -1.613, 0),
    (1001210, 'man0u1_wellwashed_leech', 180, '', 0, -160.914, 2.000, -181.741, 0.689, 0);
