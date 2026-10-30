-- Story actors that exist only for players on the quest step that uses them (retail: quest actors are
-- not part of the public city). A spawn listed here is not sent to a player unless one of its quests is
-- active for them and that quest's onStateChange called SetENpc(classId, ..., isSpawned = true).
-- Loaded at Map start (WorldManager.LoadENPCQuestGates); a missing table leaves every spawn public.
-- Idempotent. Rollback: seed_quest_gated_npcs_99_rollback.sql. Apply, then restart the Map Server.
--
-- Left public on purpose: Fulke (c0g_fulke, GC officer for everyone), the Adders' Nest exit
-- (c0g_adders_exit), the raid entry guides gc1_g104_garuda_gate / gc1_g106_castrum_gate (the guide script
-- refuses players not on the step), and every private-area spawn (already per-player instances).

CREATE TABLE IF NOT EXISTS server_eventnpc_quest_gated (
    zoneId   int(10) unsigned NOT NULL,
    uniqueId varchar(32)      NOT NULL,
    questId  int(10) unsigned NOT NULL,
    PRIMARY KEY (zoneId, uniqueId, questId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

INSERT IGNORE INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId) VALUES
    -- Man1g0 (110007) push triggers
    (150, 'msqg_m1g0_stump_approach', 110007),
    (206, 'msqg_m1g0_growery_door',  110007),
    (206, 'msqg_m1g0_hold_inside',   110007),
    -- Man2g0 (110008) push trigger
    (206, 'msqg_m2g0_amphitheatre',  110008),
    -- Man300 (110015)
    (171, 'm3g_man300_drybone',      110015),
    (171, 'm3g_man300_mesa',         110015),
    (171, 'm3g_man300_nananoby',     110015),
    -- Man304 (110016) burial spots
    (190, 'm3g_man304_spot1',        110016),
    (190, 'm3g_man304_spot2',        110016),
    (190, 'm3g_man304_spot3',        110016),
    (190, 'm3g_man304_spot4',        110016),
    (190, 'm3g_man304_spot5',        110016),
    -- Man308 (110017)
    (174, 'm3g_man308_gate',         110017),
    (174, 'm3g_man308_inside',       110017),
    -- Man402 (110018)
    (151, 'm3g_man402_nineivies',    110018),
    -- Man406 (110019)
    (190, 'm3g_man406_toll',         110019),
    -- Com0g1 (111601)
    (154, 'c0g_ailith',              111601),
    (154, 'c0g_g1_seize',            111601),
    -- Com0g4 (111604)
    (152, 'c0g_g4_imperials',        111604),
    (171, 'c0g_radulf',              111604),
    -- Com0g5 (111605)
    (206, 'c0g_g5_amphitheatre',     111605),
    (206, 'c0g_papalymo',            111605),
    (154, 'c0g_g5_rootslake',        111605),
    (154, 'c0g_urianger',            111605),
    -- Com0g6 (111606)
    (206, 'c0g_cid',                 111606),
    (206, 'c0g_lewin',               111606),
    (151, 'c0g_g6_clearing',         111606),
    -- Gcg102 (111627)
    (151, 'gc1_g102_flutaint',       111627),
    (151, 'gc1_g102_arthur',         111627),
    (151, 'gc1_g102_pfrymloef',      111627),
    (151, 'gc1_g102_yarborough',     111627),
    (155, 'gc1_landing_cid',         111627),
    (155, 'gc1_landing_ebrelnaux',   111627),
    (155, 'gc1_landing_bardo',       111627),
    -- Gcg103 (111629)
    (206, 'gc1_fane_kanesenna',      111629),
    (206, 'gc1_fane_brookstone',     111629),
    (153, 'gc1_g103_swethyna',       111629),
    -- Gcl104 Twin Adder (111630)
    (154, 'gc1_g104_quarrymill',     111630),
    (234, 'gc1_nest_cid',            111630),
    (206, 'gc1_fane_kanesenna',      111630),
    -- Gcl105 Twin Adder (111631)
    (190, 'gc1_g105_brittlebark_cid', 111631),
    (190, 'gc1_g105_strongbox',      111631),
    (206, 'gc1_fane_clearing',       111631),
    (206, 'gc1_fane_papalymo',       111631),
    -- Gcl106 Twin Adder (111632)
    (190, 'gc1_g106_ryder',          111632),
    (190, 'gc1_g106_yarborough',     111632),
    (190, 'gc1_g106_flutaint',       111632),
    -- Gcl107 Twin Adder (111633)
    (155, 'gc1_landing_cid',         111633),
    (145, 'gc1_g107_glory_site',     111633);
