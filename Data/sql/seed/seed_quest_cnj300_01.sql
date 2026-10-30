-- Cnj300 "Good Knight, Sweet Dreams" (110261): Brother Morys's two story spawns, Yuhelmeric, the newly
-- outfitted knight, the Amberscale trigger, and the elemental pools of the Amberscale duty
-- (QuestDirectorCnj30001). Hand-maintained. Apply, then restart the Map Server (classes, spawns and pools
-- load at boot). Rollback: seed_quest_cnj300_99_rollback.sql. Idempotent: class fills only touch rows still
-- empty; spawns, gates and pools are deleted and re-inserted by the 'cnj300_' prefix / pool id. Apply after
-- seed_leve_02_mobs.sql (the flags and conditions are copied from its earth elemental).
--
-- Sources: spawn positions are ported scene placements of mixed provenance, several invented (round
-- offsets, rotation 0); none is retail-confirmed.
-- Battle class paths are the shipped aspected-elemental classes; pools copy
-- the elemental leve pools of the same genus where one exists (spells and TP moves), else auto-attack
-- only Morys stands in the duty as content scenery (event NPC class), not as a pool.

UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id IN (1000505, 1000370, 1000573) AND classPath = '';

-- ---- duty battle npcs (pool id = actor class id + 6000000) -------------------------------------------
UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2204901
  SET t.classPath = CASE t.id
        WHEN 2204601 THEN '/Chara/Npc/Monster/Elemental/FireelementalStandard'
        WHEN 2204701 THEN '/Chara/Npc/Monster/Elemental/IceelementalStandard'
        WHEN 2204801 THEN '/Chara/Npc/Monster/Elemental/WindelementalStandard'
        WHEN 2204901 THEN '/Chara/Npc/Monster/Elemental/EarthelementalStandard'
        WHEN 2205001 THEN '/Chara/Npc/Monster/Elemental/LightningelementalStandard'
        WHEN 2205101 THEN '/Chara/Npc/Monster/Elemental/WarterelementalStandard'
      END,
      t.propertyFlags = s.propertyFlags,
      t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id IN (2204601, 2204701, 2204801, 2204901, 2205001, 2205101) AND t.classPath = '';
DELETE FROM server_battlenpc_pools WHERE poolId IN (8204601, 8204701, 8204801, 8204901, 8205001, 8205101);
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8204601, 2204601, 'cnj300_fire_elemental',      54, 0, 1, 4200, 1, 1, 0, 0,    0,    0),
  (8204701, 2204701, 'cnj300_ice_elemental',       58, 0, 1, 4200, 1, 1, 0, 0, 3006, 1058),
  (8204801, 2204801, 'cnj300_wind_elemental',      59, 0, 1, 4200, 1, 1, 0, 0,    0,    0),
  (8204901, 2204901, 'cnj300_earth_elemental',     56, 0, 1, 4200, 1, 1, 0, 0, 3008, 1056),
  (8205001, 2205001, 'cnj300_lightning_elemental', 57, 0, 1, 4200, 1, 1, 0, 0, 3009, 1057),
  (8205101, 2205101, 'cnj300_water_elemental',     55, 0, 1, 4200, 1, 1, 0, 0,    0, 1055);

-- ---- spawns and quest gates ---------------------------------------------------------------------------
DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'cnj300\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    (1000505, 'cnj300_morys_lifemend',      150, '', 0,  -792.368,  20.346, -1065.936,  0.000, 0),
    (1000505, 'cnj300_morys_forest_border', 152, '', 0, -1602.120,  32.600, -1854.220,  0.000, 0),
    (1000370, 'cnj300_yuhelmeric',          145, '', 0,  2550.820, 175.352,  1304.720, -2.269, 0),
    (1000573, 'cnj300_outfitted_knight',    145, '', 0,  2567.162, 175.709,  1309.727,  0.000, 0),
    (1090008, 'cnj300_amberscale_trigger',  150, '', 0,  -543.790,   5.000,  -511.350,  0.000, 0);

CREATE TABLE IF NOT EXISTS server_eventnpc_quest_gated (
    zoneId   int(10) unsigned NOT NULL,
    uniqueId varchar(32)      NOT NULL,
    questId  int(10) unsigned NOT NULL,
    PRIMARY KEY (zoneId, uniqueId, questId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
DELETE FROM server_eventnpc_quest_gated WHERE uniqueId LIKE 'cnj300\_%';
INSERT INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId) VALUES
    (150, 'cnj300_morys_lifemend', 110261),
    (152, 'cnj300_morys_forest_border', 110261),
    (145, 'cnj300_yuhelmeric', 110261),
    (145, 'cnj300_outfitted_knight', 110261),
    (150, 'cnj300_amberscale_trigger', 110261);
