-- Man308 "Lord Errant" (110017): the Gold Court trigger, the Waking Sands crowd the return scene talks
-- to, the class fills and the Bowl of Embers battle pools. Hand-maintained.
-- Apply, then restart the Map Server (actor classes, spawns, gates and pools load at boot).
-- Rollback: seed_quest_man308_99_rollback.sql. Idempotent: class fills only touch empty rows, spawns and
-- gates are deleted and re-inserted by their 'man308_' prefix, pools by id.
--
-- Sources: the client quest_marker rows 110017xx and the quest's scene marks for the triggers and the
-- cell; every other placement (the Gold Court trigger, the Merchants Ward crowd, the Bowl's arena posts in
-- the director script) is a ported calibration, not retail data. The Paglth'an gate and approach
-- triggers are the m3g_man308_* rows of seed_msq_gridania_10_man3xx.sql. The cell, the Gold Court and the
-- Bowl spawn their actors from their content scripts (Data/scripts/content/SimpleContentMan3080*.lua).

-- ---- (1) class fills -----------------------------------------------------------------------------
-- Spawning a class with an empty classPath crashes the client.

-- The Gold Court trigger (push, radius 6).
UPDATE gamedata_actor_class SET
    classPath = '/Chara/Npc/Populace/PopulaceStandard',
    propertyFlags = 1,
    eventConditions = '{"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"pushWithCircleEventConditions":[{"isEnabled":"false","radius":"6.0","outwards":"false","silent":"false","conditionName":"pushDefault"}]}'
WHERE id = 1090187 AND classPath = '';

-- The Merchants Ward crowd at the return (processEvent090_9..14).
UPDATE gamedata_actor_class SET
    classPath = '/Chara/Npc/Populace/PopulaceStandard',
    propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id IN (
    1000812,  -- troubled trader
    1001379,  -- burly-voiced brute
    1001015,  -- nonchalant goldsmith
    1000835,  -- soil-scented botanist
    1001222   -- stern-faced sea wolf
) AND classPath = '';

-- The Bowl's battle npcs take the property flags and conditions of a shipped imperial battle class.
UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2180011
  SET t.classPath = CASE t.id
        WHEN 2289001 THEN '/Chara/Npc/Monster/Fighter/FighterEnemyPugilistStandard'
        WHEN 2289002 THEN '/Chara/Npc/Monster/Fighter/FighterEnemyPugilistStandard'
        WHEN 2289003 THEN '/Chara/Npc/Monster/Fighter/FighterEnemyPugilistStandard'
        WHEN 2206508 THEN '/Chara/Npc/Monster/Lizardman/LizardmanLancerStandard'
        WHEN 2206512 THEN '/Chara/Npc/Monster/Lizardman/LizardmanArcherStandard'
        WHEN 2206518 THEN '/Chara/Npc/Monster/Lizardman/LizardmanThaumaturgeStandard'
      END,
      t.propertyFlags = s.propertyFlags,
      t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id IN (2289001, 2289002, 2289003, 2206508, 2206512, 2206518) AND t.classPath = '';

-- ---- (2) battle pools ----------------------------------------------------------------------------
-- Pool id = actor class id + 6000000. Auto-attack only (skill lists 0). The captives hold at 1 HP in
-- the director; aggro 0: they only ever spawn inside the duty, which sends them.
DELETE FROM server_battlenpc_pools WHERE poolId IN (8289001, 8289002, 8289003, 8206508, 8206512, 8206518);
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8289001, 2289001, 'man308_tempered_captive_1', 29, 22, 1, 4200, 1, 0, 0, 0, 0, 0),
  (8289002, 2289002, 'man308_tempered_captive_2', 29, 22, 1, 4200, 1, 0, 0, 0, 0, 0),
  (8289003, 2289003, 'man308_tempered_captive_3', 29, 22, 1, 4200, 1, 0, 0, 0, 0, 0),
  (8206508, 2206508, 'man308_amaljaa_lancer',     23,  8, 1, 4200, 1, 0, 0, 0, 0, 0),
  (8206512, 2206512, 'man308_amaljaa_archer',     23,  7, 1, 4200, 1, 0, 0, 0, 0, 0),
  (8206518, 2206518, 'man308_amaljaa_augur',      23, 22, 1, 4200, 1, 0, 0, 0, 0, 0);

-- ---- (3) spawns ----------------------------------------------------------------------------------

DELETE FROM server_eventnpc_spawn_locations WHERE uniqueId LIKE 'man308\_%';
INSERT INTO server_eventnpc_spawn_locations
    (actorClassId, uniqueId, zoneId, privateAreaName, privateAreaLevel, positionX, positionY, positionZ, rotation, motionPack)
VALUES
    -- Ul'dah 209: the Gold Court trigger (offer).
    (1090187, 'man308_gold_court',          209, '', 0, -147.633, 198.000, 160.064, 0.000, 0),
    -- The Merchants Ward (181 public) at the return.
    (1000812, 'man308_troubled_trader',     181, '', 0, -165.500, 0.000, -132.000, 2.900, 1033),
    (1001015, 'man308_nonchalant_goldsmith', 181, '', 0, -181.500, -2.000, -181.000, -2.700, 0),
    (1001222, 'man308_stern_faced_sea_wolf', 181, '', 0, -191.500, 2.000, -139.000, 1.500, 1040),
    (1001379, 'man308_burly_voiced_brute',  181, '', 0, -174.000, 0.000, -157.500, -3.000, 1016),
    (1000835, 'man308_soil_scented_botanist', 181, '', 0, -190.500, -3.000, -219.000, 2.500, 1017);

-- ---- (4) quest gates -----------------------------------------------------------------------------
-- Seen only while Man308 declares them (the trigger on offer, the crowd at Seq 20).

CREATE TABLE IF NOT EXISTS server_eventnpc_quest_gated (
    zoneId   int(10) unsigned NOT NULL,
    uniqueId varchar(32)      NOT NULL,
    questId  int(10) unsigned NOT NULL,
    PRIMARY KEY (zoneId, uniqueId, questId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DELETE FROM server_eventnpc_quest_gated WHERE uniqueId LIKE 'man308\_%';
INSERT INTO server_eventnpc_quest_gated (zoneId, uniqueId, questId) VALUES
    (209, 'man308_gold_court',            110017),
    (181, 'man308_troubled_trader',       110017),
    (181, 'man308_nonchalant_goldsmith',  110017),
    (181, 'man308_stern_faced_sea_wolf',  110017),
    (181, 'man308_burly_voiced_brute',    110017),
    (181, 'man308_soil_scented_botanist', 110017);
