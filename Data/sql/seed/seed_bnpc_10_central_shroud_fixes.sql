-- Central Shroud (zone 150) spawn clean-up from play-testing, 2026-10-13.
-- Apply after seed_bnpc_01..08 (and again after re-applying 04, 05 or 08). Idempotent.
-- Needs a Map (+World) restart. Rollback: seed_bnpc_19_central_shroud_fixes_rollback.sql.
-- Black Shroud zones 151-154: seed_bnpc_11_black_shroud_fixes.sql.
--
-- Sources: "Eorzea 1.x Bestiary" artifact (species/zone/level, Mooglebox [MB] and Gamer Escape [GE]
-- map spots with levels, AuroraFlare [AF] points), seed_bnpc_08 retail captures [CAP].
-- Starter belt = Blue Badger Gate exit (333,-943) to Camp Bentbranch (288,-544): MB/CAP put only
-- Lv1-9 camps there (Star Marmot, Chigoe, Forest Funguar, Bogy).
--
-- DESIGN rule for removals: a single low-trust spot (GE map spot or AF point, +-100 units) of a
-- monster 20+ levels above a corroborated (MB or CAP) low-level camp within 250 units, with no
-- corroborated camp near its own level, is dropped from the zone: it cannot be placed without
-- landing on the starter camp. A placement capture or a second source would bring it back.

-- 1. Removed groups
--  100275 Sabotender Lv68, 100279/100280 Sabotender del Sol Lv75-78: GE spots only, on Bentbranch.
--         (Play-test call; GE does list them in the Central Shroud.)
--  100597 Lightning Elemental Lv30-39 (160,-940), 100813 Water Elemental Lv30-42 (60,-840): GE spots
--         only, 100-220 units from the gate road and the MB Lv4-5 chigoe camp.
--  100621 Morbol Lv63-74 (760,-1140): one GE spot, no level; 250 units from MB Lv1-3 marmots.
--  100825 Wild Hog Lv40-49 (-340,-840): GE spot with no level on the MB/GE Lv4-5 chigoe camp
--         (same map square as that camp's entry).
--  100598 Lindwurm Lv31-74 (360,-40): GE spot, no level, on the MB Lv10 Sabletooth Spriggan camp.
--  100386 sand piranha (2204502 = Greedy Angler), 100388/100389 yak models (Lowland Nanny/Billygoat):
--         captured in the leve copy of this field; the bestiary lists these only as leve-or-quest
--         spawns in the Central Shroud [GE], so they are not world mobs.
DELETE s FROM `server_battlenpc_spawn_locations` s
    JOIN `server_battlenpc_groups` g ON g.`groupId` = s.`groupId`
    WHERE g.`zoneId` = 150 AND (g.`poolId` IN (100134, 100135)
        OR g.`groupId` IN (100386, 100388, 100389, 100597, 100598, 100621, 100813, 100825));
DELETE FROM `server_battlenpc_groups` WHERE `zoneId` = 150 AND (`poolId` IN (100134, 100135)
    OR `groupId` IN (100386, 100388, 100389, 100597, 100598, 100621, 100813, 100825));

-- 2. Leve-copy points next to Bentbranch. seed_bnpc_08 placed the party_battle_leve capture
--    (fst0Fld01a) in the open field. MB/GE put the Lv25-39 Humblehearth camps at x <= 60; these three
--    points (Mirror Roselet Lv25-29 x2, Ladybug Lv26-29) are within 160 units of the Bentbranch
--    aetheryte. DESIGN: keep the leve-copy points that are 175+ units from it.
DELETE FROM `server_battlenpc_spawn_locations` WHERE `bnpcId` IN (2100063, 2100064, 2100074);

-- 3. Level bands. These groups took the bestiary's all-zone range because no source gives a level at
--    the spot. DESIGN: the lowest five levels of that range (nearest MB/CAP camps are Lv5-19).
UPDATE `server_battlenpc_groups` SET `minLevel` = 18, `maxLevel` = 22 WHERE `groupId` = 100145; -- Goblin Freesword, was 18-63
UPDATE `server_battlenpc_groups` SET `minLevel` = 18, `maxLevel` = 22 WHERE `groupId` = 100157; -- Goblin Thug, was 18-39
UPDATE `server_battlenpc_groups` SET `minLevel` = 14, `maxLevel` = 18 WHERE `groupId` = 100172; -- Imptrap, was 14-59
UPDATE `server_battlenpc_groups` SET `minLevel` = 5,  `maxLevel` = 9  WHERE `groupId` = 100519; -- Honeybee Swarm, was 5-45
UPDATE `server_battlenpc_groups` SET `minLevel` = 8,  `maxLevel` = 12 WHERE `groupId` IN (100769, 100770); -- Toxic Toad, was 8-54

-- 4. Star Marmots on the gate road (DESIGN placement, levels from MB).
--    2300001: outside the Blue Badger Gate, Lv1-2 [DESIGN].
--    2300002: MB "Star Marmot Lv1" spot at map (34,30) = world (360,-740), between the gate and the
--             captured Lv1-3 funguars.
--    Y snapped to the zone navmesh (TrySnapToGround from y 5).
DELETE FROM `server_battlenpc_spawn_locations` WHERE `bnpcId` BETWEEN 2300001 AND 2300006;
DELETE FROM `server_battlenpc_groups` WHERE `groupId` IN (2300001, 2300002);
INSERT INTO `server_battlenpc_groups`
    (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,
     `spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
VALUES
    (2300001, 100162, 'star_marmot', 1, 2, 90, 0, 0, 0, 0, 0, 0, 0, '', 0, 150),
    (2300002, 100162, 'star_marmot', 1, 1, 90, 0, 0, 0, 0, 0, 0, 0, '', 0, 150);
INSERT INTO `server_battlenpc_spawn_locations` (`bnpcId`,`customDisplayName`,`groupId`,`positionX`,`positionY`,`positionZ`,`rotation`)
VALUES
    (2300001, '', 2300001, 357.5, 4.57, -918.5, -2.37),
    (2300002, '', 2300001, 361.7, 4.65, -920.6, -2.37),
    (2300003, '', 2300001, 363.9, 4.65, -924.8, -2.37),
    (2300004, '', 2300002, 360.0, 5.04, -750.0, 1.10),
    (2300005, '', 2300002, 380.0, 3.60, -810.0, -0.40),
    (2300006, '', 2300002, 340.0, 6.77, -840.0, 2.60);
