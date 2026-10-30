-- Grand Company story quests shared by all three companies: It Kills with Fire and Gcl104-Gcl107 for the
-- Maelstrom (111416, 111430-111433) and the Immortal Flames (111816, 111830-111833), on the Gcl scripts
-- the Twin Adder versions use (quests/gcl/gcl101, gcl104-gcl107, gc_company.lua). Hand-maintained.
-- Needs seed_msq_gridania_30_gc.sql (the halls, push triggers and story spawns this extends) first.
-- Apply, then restart the Map Server (quest gamedata, actor classes and spawns load at boot).
-- Rollback: seed_gc_story_shared_99_rollback.sql. Idempotent: class fills only touch empty rows,
-- spawns are deleted and re-inserted by their 'gcs_' prefix, the rest is INSERT IGNORE.
--
-- Spec: client/docs/gridania_story_quests.md §0.1, §0.2, §10, §13-§16; client/docs/gc_quest_contracts.md
-- §2.1 for the markers. Cid in Maelstrom Command is at his Gcl104 marker (111813 05); the rest is
-- on the navmesh floor: the halls are staged private areas (their client maps are not server zones), and
-- the Hall of Flames Cid and Rhiki by Jagged Crest Cave have no marker row.

-- ---- (1) client classes ---------------------------------------------------------------------------
-- The client's staticactor.san maps every company's version of these quests to the Gcl class (the Gcu
-- scripts are empty stubs). The offer check finds the script by this column, so it must say Gcl.
UPDATE gamedata_quests SET className = CONCAT('Gcl', SUBSTRING(className, 4))
WHERE id IN (111416, 111430, 111431, 111432, 111433, 111816, 111830, 111831, 111832, 111833)
  AND className NOT LIKE 'Gcl%';

-- ---- (2) prerequisites ----------------------------------------------------------------------------
-- The client has none; the order is the Twin Adder chain's (seed_msq_gridania_03_chain.sql) [inference]:
-- the enlistment quest (Com0x7) -> It Kills with Fire -> the company's 102 / 103 (nation seeds) -> 104-107.
INSERT IGNORE INTO gamedata_quest_prerequisites (questId, prerequisite) VALUES
    (111416, 111407),   -- Com0l7 Till Sea Swallows All
    (111430, 111429),   -- Gcl103 Deus ex Machina
    (111431, 111430),
    (111432, 111431),
    (111433, 111432),
    (111816, 111807),   -- Com0u7 By Fire Reborn
    (111830, 111829),   -- Gcu103 Careless Whispers
    (111831, 111830),
    (111832, 111831),
    (111833, 111832);

-- ---- (3) populace class fills ---------------------------------------------------------------------
-- The marshals stand in their leader's hall and at the Lotus Stand council. Spawning a class with an
-- empty classPath crashes the client.
UPDATE gamedata_actor_class SET
    classPath = '/Chara/Npc/Populace/PopulaceStandard',
    propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id IN (
    1060024,  -- Storm Marshal Eynzahr
    1060026   -- Flame Marshal Roaille ("Eline")
) AND classPath = '';

-- ---- (4) quest-gated story actors at the shared sites ----------------------------------------------
-- The Twin Adder quests' story actors (seed_msq_gridania_30_gc / seed_quest_gated_npcs) are sent only to
-- players on those quests; the other companies' versions use the same sites. Not copied: Cid in the
-- Adders' Nest (each company meets him in its own headquarters, below) and Kan-E-Senna before the Fane
-- for 111630 (Gcl104 SEQ_025 is the Twin Adder's scene; the others go to their own leader's hall).
INSERT IGNORE INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId)
SELECT g.zoneId, g.uniqueId, g.questId + o.delta
FROM server_eventnpc_quest_gated g
CROSS JOIN (SELECT -200 AS delta UNION ALL SELECT 200) o
WHERE g.questId IN (111630, 111631, 111632, 111633)
  AND g.uniqueId NOT IN ('gc1_nest_cid', 'gc1_fane_kanesenna');

-- Cid in the company headquarters for Gcl104 SEQ_020 ("a meeting with Cid"), next to the officer, and
-- the Maelstrom's commander by Jagged Crest Cave for Gcl106 (CommonNavi_Rashaht_01).
INSERT IGNORE INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId) VALUES
    (232, 'gcs_hq_cid', 111430),
    (233, 'gcs_hq_cid', 111830),
    (190, 'gcs_g106_rhiki', 111432);

-- ---- (5) spawns -----------------------------------------------------------------------------------

DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'gcs\_%';

INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    -- Cid in Maelstrom Command (232, marker 11181305) and the Hall of Flames (233, by Aubrey: the
    -- headquarters share the Adders' Nest layout, so he stands where he does there).
    (1001572, 'gcs_hq_cid',           232, '', 0, 174.50, 0.00, -172.40, 0.4, 0),
    (1001572, 'gcs_hq_cid',           233, '', 0, 165.00, 0.09, -178.00, 0.4, 0),
    -- Storm Commander Rhiki ("Rashaht", class filled by seed_msq_limsa_20_com0l) beside Ryder, Yarborough
    -- and Flutaint by Jagged Crest Cave (190; no navmesh there, height between theirs).
    (1001810, 'gcs_g106_rhiki',       190, '', 0, -362.00, -16.00, -33.00, 0.6, 0),
    -- Merlwyb's stateroom (133 PA 61, Merlwyb from seed_msq_gridania_30_gc): Cid and Eynzahr for the
    -- Maelstrom's Gcl104 SEQ_030 and Gcl106 (LimsaInstance_*).
    (1001572, 'gcs_stateroom_cid',    133, 'PrivateAreaMasterPast', 61, -446.00, 21.10, 175.00, 2.0, 0),
    (1060024, 'gcs_stateroom_eynzahr', 133, 'PrivateAreaMasterPast', 61, -447.00, 21.07, 179.00, 2.4, 0),
    -- The Fragrant Chamber (209 PA 61, Raubahn from seed_msq_gridania_30_gc): Cid and Eline for the
    -- Immortal Flames' Gcl104 SEQ_030 and Gcl106 (UldahInstance_*).
    (1001572, 'gcs_chamber_cid',      209, 'PrivateAreaMasterPast', 61, -123.00, 226.15, 240.00, -0.4, 0),
    (1060026, 'gcs_chamber_eline',    209, 'PrivateAreaMasterPast', 61, -115.00, 225.82, 240.00, -1.2, 0),
    -- The Lotus Stand (206 PA 61): the other leaders and marshals for the Gcl105 council (SEQ_055-060)
    -- and the Gcl107 council, where all three companies meet (spec §16).
    (1001568, 'gcs_lotus_merlwyb',    206, 'PrivateAreaMasterPast', 61, -335.00, 6.25, -1694.00, 0.4, 0),
    (1002051, 'gcs_lotus_raubahn',    206, 'PrivateAreaMasterPast', 61, -336.00, 6.90, -1698.00, 0.5, 0),
    (1060024, 'gcs_lotus_eynzahr',    206, 'PrivateAreaMasterPast', 61, -332.00, 6.33, -1696.00, 0.3, 0),
    (1060026, 'gcs_lotus_eline',      206, 'PrivateAreaMasterPast', 61, -339.00, 6.90, -1700.00, 0.6, 0);
