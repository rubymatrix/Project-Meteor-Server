-- Hand-maintained (NOT generated): open-world monsters in zones 145, 151, 152, 154 and 172 placed
-- from the "7u" XIV_MON logs (caps/extracted/7u: gridania_to_coerthas, combat_autoattack,
-- teleport_to_camp_*, teleport_to_gridania, war_quest_update2/3) [CAP]. These are the same
-- xivl-captures seed_bnpc_08 used for zone 150, and the source of the bestiary's unnamed "retail
-- capture" points that seed_bnpc_05 assigned to monsters by model class alone.
-- Provenance caveat: the logs' game clock reads 2012-12-31 (after the 2012-11-11 shutdown) and only
-- 1-3 other players ever appear. They are treated as retail 1.23b captures, as seed_bnpc_08 does,
-- but they are one walk-through each: one sighting per actor, no respawn timing.
-- Apply after seed_bnpc_01..11 (again after re-applying 02, 04 or 05).
-- Idempotent: deletes its own ID range first (pools/groups 2400001-2400099, bnpcIds 2400101-2400999).
-- Needs a Map (+World) restart. Rollback: seed_bnpc_17_capture_7u_rollback.sql.
--
-- Rules
--  * Position, rotation, client class (0x00CC) and level (/_init state_mainSkillLevel) from the
--    first placement of each captured actor; Y from the capture (the loader snaps it to the navmesh).
--  * One pool + group per zone and client class; group levels = min..max captured for that class.
--    HP/MP come from battle/stats.lua at spawn, so groups keep hp = mp = 0.
--  * Monster names from the "Eorzea 1.x Bestiary" artifact by client class id (tier in brackets).
--    Pools copy combat, skill, spell and mod columns from that monster's generator pool; groups
--    copy the respawn time of a group of that pool (same zone first). No loot list: this server
--    has no drop lists yet, so dropListId is 0.
--  * Replaces, not duplicates. Retired generator rows (bnpcId 1000001-1999999, listed below):
--    - every "retail-1.23b-capture" row within 40 units of a captured actor: those are this
--      capture rounded to 10 units, with the monster guessed from the model class (several sat on
--      the wrong class: galago points as marmots, a slug point as a galago, a squirrel as a doe);
--    - map-spot / AuroraFlare rows of the same model class within 12 units of a captured point
--      (seed_bnpc_08 rule).
--    Groups left without spawn points stay (harmless; the rollback refills them).
--
-- Decisions
--  * North Shroud (152), Emerald Moss camps: the capture names three galago variants that share
--    one display name (Curious Galago): 2100516 Lv10-12, 2100517 Lv13-15, 2100518 Lv17-19. The
--    generator had only 2100516 at Lv13-16 and a map-spot Young Galago Lv15-19 group; the capture
--    puts 2100518 where that map spot is, so the map-spot rows on captured points are retired.
--  * East Shroud (151): Goblin Butcher 2110308 Lv67 seen 80 units south of the Camp Nine Ivies
--    aetheryte is NOT placed: bestiary tier C (client name only), one sighting, never seen
--    fighting, and seed_bnpc_11 already dropped the generator goblin by that camp. DESIGN; a
--    capture of it in combat (or a second source) would bring it in.
--  * Western Thanalan (172): the Lv76-88 camp (Puroboros, Spinesnap Ogre, Sabotender del Sol,
--    Amalj'aa Grappler) around (-1100, 0) is placed as captured: open-world spawns (area @0AC00, no
--    private area), and GE has a Puroboros map spot at Thanalan (14,33) next to it. It sits 200+
--    units from Scorpion Keep and Camp Horizon, beside Lv25 cactuars, as in the capture.
--  * Not placed: zone 150 (seed_bnpc_08 already places the first sighting of each actor; the rest
--    are re-sightings of the same mobs 12-38 units off) and fst0Field01a / zone 162 (the
--    party_battle_leve copy of the Central Shroud: leve content, not open world).

DELETE FROM `server_battlenpc_spawn_locations` WHERE `bnpcId` BETWEEN 2400101 AND 2400999;
DELETE FROM `server_battlenpc_groups` WHERE `groupId` BETWEEN 2400001 AND 2400099;
DELETE FROM `server_battlenpc_pool_mods` WHERE `poolId` BETWEEN 2400001 AND 2400099;
DELETE FROM `server_battlenpc_pools` WHERE `poolId` BETWEEN 2400001 AND 2400099;

-- Client classes with no classPath (or no flags/conditions) in gamedata_actor_class; the capture
-- binds them as these classes (0x00CC). Fills only empty values, like seed_bnpc_08.
UPDATE `gamedata_actor_class` SET `classPath` = '/Chara/Npc/Monster/Petitghost/PetitghostLesserStandard' WHERE `id` = 2104305 AND (`classPath` IS NULL OR `classPath` = '');
UPDATE `gamedata_actor_class` SET `classPath` = '/Chara/Npc/Monster/Mole/MoleMoleStandard' WHERE `id` = 2105706 AND (`classPath` IS NULL OR `classPath` = '');
UPDATE `gamedata_actor_class` SET `classPath` = '/Chara/Npc/Monster/Firefly/FireflyNormalStandard' WHERE `id` = 2105803 AND (`classPath` IS NULL OR `classPath` = '');
UPDATE `gamedata_actor_class` SET `propertyFlags` = 23 WHERE `propertyFlags` = 0 AND `id` IN (2100301, 2100502, 2100516, 2100517, 2100518, 2100907, 2100915, 2101112, 2101608, 2102103, 2102503, 2104006, 2104011, 2104018, 2104022, 2104102, 2104217, 2104305, 2105603, 2105706, 2105803, 2105904, 2105916, 2106506);
UPDATE `gamedata_actor_class` SET `eventConditions` = '{\n  "talkEventConditions": [],\n  "noticeEventConditions": [\n    {\n      "unknown1": 0,\n      "unknown2": 1,\n      "conditionName": "noticeEvent"\n    }\n  ],\n  "emoteEventConditions": [],\n  "pushWithCircleEventConditions": []\n}' WHERE `eventConditions` IS NULL AND `id` IN (2100301, 2100502, 2100516, 2100517, 2100518, 2100907, 2100915, 2101112, 2101608, 2102103, 2102503, 2104006, 2104011, 2104018, 2104022, 2104102, 2104217, 2104305, 2105603, 2105706, 2105803, 2105904, 2105916, 2106506);

-- Pools and groups
-- 145 Coerthas Eastern Lowlands: Antelope Doe 2100301 [A], Lv25/26 captured at 2 points [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400001, 2100301, 'cap7u_antelope_doe', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100010;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400001, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100010;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400001, 2400001, 'cap7u_antelope_doe', 25, 26,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100010 ORDER BY (`zoneId` = 145) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 145
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400001);
-- 145 Coerthas Eastern Lowlands: Arbor Squirrel 2104006 [A], Lv25 captured at 1 point [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400002, 2104006, 'cap7u_arbor_squirrel', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100012;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400002, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100012;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400002, 2400002, 'cap7u_arbor_squirrel', 25, 25,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100012 ORDER BY (`zoneId` = 145) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 145
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400002);
-- 151 East Shroud: Molting Miteling 2101112 [A], Lv36 captured at 1 point [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400003, 2101112, 'cap7u_molting_miteling', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100097;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400003, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100097;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400003, 2400003, 'cap7u_molting_miteling', 36, 36,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100097 ORDER BY (`zoneId` = 151) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 151
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400003);
-- 151 East Shroud: Dormouse 2104018 [A], Lv41 captured at 1 point [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400004, 2104018, 'cap7u_dormouse', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100046;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400004, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100046;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400004, 2400004, 'cap7u_dormouse', 41, 41,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100046 ORDER BY (`zoneId` = 151) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 151
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400004);
-- 152 North Shroud: Curious Galago 2100516 [A], Lv10/11/12 captured at 20 points [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400005, 2100516, 'cap7u_curious_galago_a', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100041;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400005, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100041;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400005, 2400005, 'cap7u_curious_galago_a', 10, 12,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100041 ORDER BY (`zoneId` = 152) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 152
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400005);
-- 152 North Shroud: Curious Galago 2100517 [A], Lv13/14/15 captured at 12 points [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400006, 2100517, 'cap7u_curious_galago_b', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100041;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400006, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100041;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400006, 2400006, 'cap7u_curious_galago_b', 13, 15,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100041 ORDER BY (`zoneId` = 152) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 152
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400006);
-- 152 North Shroud: Curious Galago 2100518 [A], Lv17/18/19 captured at 12 points [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400007, 2100518, 'cap7u_curious_galago_c', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100041;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400007, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100041;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400007, 2400007, 'cap7u_curious_galago_c', 17, 19,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100041 ORDER BY (`zoneId` = 152) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 152
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400007);
-- 152 North Shroud: Thistletail Marmot 2104011 [A], Lv10/12/13/14 captured at 15 points [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400008, 2104011, 'cap7u_thistletail_marmot', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100167;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400008, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100167;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400008, 2400008, 'cap7u_thistletail_marmot', 10, 14,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100167 ORDER BY (`zoneId` = 152) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 152
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400008);
-- 152 North Shroud: Bristletail Marmot 2104022 [A], Lv10 captured at 9 points [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400009, 2104022, 'cap7u_bristletail_marmot', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100028;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400009, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100028;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400009, 2400009, 'cap7u_bristletail_marmot', 10, 10,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100028 ORDER BY (`zoneId` = 152) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 152
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400009);
-- 152 North Shroud: Cave Bat 2104102 [A], Lv10/14 captured at 3 points [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400010, 2104102, 'cap7u_cave_bat', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100034;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400010, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100034;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400010, 2400010, 'cap7u_cave_bat', 10, 14,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100034 ORDER BY (`zoneId` = 152) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 152
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400010);
-- 152 North Shroud: Carrion Chigoe 2105603 [B], Lv10/14 captured at 3 points [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400011, 2105603, 'cap7u_carrion_chigoe', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100033;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400011, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100033;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400011, 2400011, 'cap7u_carrion_chigoe', 10, 14,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100033 ORDER BY (`zoneId` = 152) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 152
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400011);
-- 152 North Shroud: Snapping Shrew 2105706 [B], Lv5 captured at 1 point [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400012, 2105706, 'cap7u_snapping_shrew', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100151;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400012, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100151;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400012, 2400012, 'cap7u_snapping_shrew', 5, 5,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100151 ORDER BY (`zoneId` = 152) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 152
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400012);
-- 152 North Shroud: Lightning Beetle 2105803 [A], Lv16/17 captured at 2 points [CAP]; client class is the firefly model; bestiary lists it under Lightning Beetle
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400013, 2105803, 'cap7u_lightning_beetle', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100090;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400013, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100090;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400013, 2400013, 'cap7u_lightning_beetle', 16, 17,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100090 ORDER BY (`zoneId` = 152) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 152
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400013);
-- 152 North Shroud: Mature Funguar 2105916 [A], Lv12/13 captured at 9 points [CAP]; pool copies faerie_funguar (same genus/skills as the seed_bnpc_11 mature_funguar pool)
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400014, 2105916, 'cap7u_mature_funguar', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100055;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400014, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100055;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400014, 2400014, 'cap7u_mature_funguar', 12, 13,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100055 ORDER BY (`zoneId` = 152) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 152
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400014);
-- 154 South Shroud: Canopy Galago 2100502 [A], Lv21/23 captured at 2 points [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400015, 2100502, 'cap7u_canopy_galago', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100032;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400015, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100032;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400015, 2400015, 'cap7u_canopy_galago', 21, 23,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100032 ORDER BY (`zoneId` = 154) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 154
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400015);
-- 154 South Shroud: Tree Slug 2104217 [A], Lv24/26 captured at 2 points [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400016, 2104217, 'cap7u_tree_slug', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100170;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400016, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100170;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400016, 2400016, 'cap7u_tree_slug', 24, 26,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100170 ORDER BY (`zoneId` = 154) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 154
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400016);
-- 154 South Shroud: Faerie Funguar 2105904 [A], Lv16 captured at 1 point [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400017, 2105904, 'cap7u_faerie_funguar', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100055;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400017, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100055;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400017, 2400017, 'cap7u_faerie_funguar', 16, 16,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100055 ORDER BY (`zoneId` = 154) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 154
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400017);
-- 172 Western Thanalan: Sabotender del Sol 2100907 [A], Lv78 captured at 1 point [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400018, 2100907, 'cap7u_sabotender_del_sol', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100135;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400018, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100135;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400018, 2400018, 'cap7u_sabotender_del_sol', 78, 78,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100135 ORDER BY (`zoneId` = 172) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 172
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400018);
-- 172 Western Thanalan: Cactuar 2100915 [A], Lv25/26 captured at 3 points [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400019, 2100915, 'cap7u_cactuar', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100030;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400019, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100030;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400019, 2400019, 'cap7u_cactuar', 25, 26,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100030 ORDER BY (`zoneId` = 172) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 172
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400019);
-- 172 Western Thanalan: Puroboros 2101608 [A], Lv76/78 captured at 2 points [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400020, 2101608, 'cap7u_puroboros', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100118;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400020, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100118;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400020, 2400020, 'cap7u_puroboros', 76, 78,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100118 ORDER BY (`zoneId` = 172) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 172
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400020);
-- 172 Western Thanalan: Lead Coblyn 2102103 [B], Lv18 captured at 1 point [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400021, 2102103, 'cap7u_lead_coblyn', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100088;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400021, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100088;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400021, 2400021, 'cap7u_lead_coblyn', 18, 18,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100088 ORDER BY (`zoneId` = 172) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 172
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400021);
-- 172 Western Thanalan: Spinesnap Ogre 2102503 [A], Lv80/81/84 captured at 4 points [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400022, 2102503, 'cap7u_spinesnap_ogre', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100156;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400022, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100156;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400022, 2400022, 'cap7u_spinesnap_ogre', 80, 84,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100156 ORDER BY (`zoneId` = 172) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 172
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400022);
-- 172 Western Thanalan: Bloated Bogy 2104305 [B], Lv22 captured at 1 point [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400023, 2104305, 'cap7u_bloated_bogy', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100023;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400023, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100023;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400023, 2400023, 'cap7u_bloated_bogy', 22, 22,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100023 ORDER BY (`zoneId` = 172) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 172
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400023);
-- 172 Western Thanalan: Amalj'aa Grappler 2106506 [A], Lv88 captured at 1 point [CAP]
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2400024, 2106506, 'cap7u_amaljaa_grappler', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`, `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100005;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2400024, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100005;
INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`)
    SELECT 2400024, 2400024, 'cap7u_amaljaa_grappler', 88, 88,
        COALESCE((SELECT `respawnTime` FROM `server_battlenpc_groups` WHERE `poolId` = 100005 ORDER BY (`zoneId` = 172) DESC, `groupId` LIMIT 1), 90),
        0, 0,
        0,
        0, 0, 0, 0, '', 0, 172
    FROM DUAL WHERE EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2400024);

-- Retire generator rows on captured points (see Rules).
--  145 1000146 g100024 antelope_doe (1840, 1740): rounded copy of this capture (4u from captured NuteaterStandard)
--  152 1000285 g100052 bristletail_marmot (-1580, -1910): rounded copy of this capture (4u from captured MonkeyLesserStandard)
--  152 1000286 g100052 bristletail_marmot (-1200, -1800): rounded copy of this capture (4u from captured HareStandard)
--  152 1000287 g100052 bristletail_marmot (-1420, -1770): rounded copy of this capture (4u from captured MonkeyLesserStandard)
--  152 1000288 g100052 bristletail_marmot (-1540, -1760): rounded copy of this capture (36u from captured HareStandard)
--  152 1000289 g100052 bristletail_marmot (-1270, -1740): rounded copy of this capture (3u from captured HareStandard)
--  152 1000290 g100052 bristletail_marmot (-1530, -1850): rounded copy of this capture (3u from captured HareStandard)
--  152 1000291 g100052 bristletail_marmot (-1390, -1720): rounded copy of this capture (4u from captured HareStandard)
--  152 1000292 g100052 bristletail_marmot (-1510, -1790): rounded copy of this capture (3u from captured HareStandard)
--  152 1000293 g100052 bristletail_marmot (-1410, -1810): rounded copy of this capture (4u from captured HareStandard)
--  152 1000294 g100052 bristletail_marmot (-1520, -1730): rounded copy of this capture (1u from captured HareStandard)
--  152 1000326 g100059 carrion_chigoe (-1460, -1750): rounded copy of this capture (4u from captured MonkeyLesserStandard)
--  152 1000453 g100077 curious_galago (-1600, -1890): rounded copy of this capture (5u from captured MonkeyLesserStandard)
--  152 1000454 g100077 curious_galago (-1030, -1610): rounded copy of this capture (4u from captured MonkeyLesserStandard)
--  152 1000455 g100077 curious_galago (-1420, -1740): rounded copy of this capture (5u from captured MonkeyLesserStandard)
--  152 1000456 g100077 curious_galago (-1220, -1690): rounded copy of this capture (3u from captured MonkeyLesserStandard)
--  152 1000457 g100077 curious_galago (-1530, -1850): rounded copy of this capture (3u from captured HareStandard)
--  152 1000458 g100077 curious_galago (-1460, -1780): rounded copy of this capture (3u from captured MonkeyLesserStandard)
--  152 1000459 g100077 curious_galago (-1070, -1650): rounded copy of this capture (2u from captured MonkeyLesserStandard)
--  152 1000460 g100077 curious_galago (-1560, -1870): rounded copy of this capture (5u from captured MonkeyLesserStandard)
--  152 1000461 g100077 curious_galago (-1080, -1620): rounded copy of this capture (4u from captured MonkeyLesserStandard)
--  152 1000462 g100077 curious_galago (-1040, -1660): rounded copy of this capture (6u from captured MonkeyLesserStandard)
--  152 1001642 g100292 mature_funguar (-1280, -1690): rounded copy of this capture (3u from captured FunguarLesserStandard)
--  152 1001643 g100292 mature_funguar (-1280, -1670): rounded copy of this capture (2u from captured FunguarLesserStandard)
--  152 1001644 g100292 mature_funguar (-1280, -1670): rounded copy of this capture (2u from captured FunguarLesserStandard)
--  152 1001645 g100292 mature_funguar (-1300, -1670): rounded copy of this capture (3u from captured FunguarLesserStandard)
--  152 1001689 g100305 shroud_shrew (-1130, -1670): rounded copy of this capture (18u from captured BatNormalStandard)
--  152 1001690 g100305 shroud_shrew (-1200, -1720): rounded copy of this capture (5u from captured MonkeyLesserStandard)
--  152 1001713 g100314 snapping_shrew (-1144, -1646.9): map-spot spot, same model 10u from a captured point
--  152 1001908 g100349 thistletail_marmot (-1000, -1600): rounded copy of this capture (4u from captured HareStandard)
--  152 1001909 g100349 thistletail_marmot (-1060, -1630): rounded copy of this capture (5u from captured MonkeyLesserStandard)
--  152 1001910 g100349 thistletail_marmot (-1130, -1730): rounded copy of this capture (6u from captured HareStandard)
--  152 1002058 g100370 young_galago (-1544, -1846.9): map-spot spot, same model 11u from a captured point
--  152 1002061 g100370 young_galago (-1544, -1846.9): map-spot spot, same model 11u from a captured point
--  152 1002062 g100371 retail_batnormalstandard (-1140, -1660): rounded copy of this capture (5u from captured BatNormalStandard)
--  152 1002063 g100371 retail_batnormalstandard (-1150, -1660): rounded copy of this capture (4u from captured BatNormalStandard)
--  152 1002064 g100371 retail_batnormalstandard (-1140, -1660): rounded copy of this capture (5u from captured BatNormalStandard)
--  152 1002065 g100372 retail_batnormalstandard (-1400, -1730): rounded copy of this capture (5u from captured FireflyNormalStandard)
--  154 1002088 g100381 retail_monkeylesserstandard (840, 1160): rounded copy of this capture (5u from captured SlugLesserStandard)
--  154 1002089 g100381 retail_monkeylesserstandard (900, 1080): rounded copy of this capture (5u from captured MonkeyLesserStandard)
--  154 1002097 g100387 retail_sluglesserstandard (890, 1110): rounded copy of this capture (6u from captured SlugLesserStandard)
--  172 1000265 g100045 bloated_bogy (-1032, 270): map-spot spot, same model 11u from a captured point
--  172 1000266 g100045 bloated_bogy (-1044, 276.9): map-spot spot, same model 10u from a captured point
--  172 1000267 g100045 bloated_bogy (-1044, 263.1): map-spot spot, same model 4u from a captured point
--  172 1002093 g100384 retail_orebeetlelesserstandard (-1160, 220): rounded copy of this capture (3u from captured OrebeetleLesserStandard)
--  172 1002094 g100385 retail_petitghostlesserstandard (-1040, 270): rounded copy of this capture (4u from captured PetitghostLesserStandard)
DELETE FROM `server_battlenpc_spawn_locations` WHERE `bnpcId` IN (
    1000146, 1000285, 1000286, 1000287, 1000288, 1000289, 1000290, 1000291, 1000292, 1000293,
    1000294, 1000326, 1000453, 1000454, 1000455, 1000456, 1000457, 1000458, 1000459, 1000460,
    1000461, 1000462, 1001642, 1001643, 1001644, 1001645, 1001689, 1001690, 1001713, 1001908,
    1001909, 1001910, 1002058, 1002061, 1002062, 1002063, 1002064, 1002065, 1002088, 1002089,
    1002097, 1000265, 1000266, 1000267, 1002093, 1002094);

-- Spawn points: exact capture position and rotation.
INSERT INTO `server_battlenpc_spawn_locations` (`bnpcId`,`customDisplayName`,`groupId`,`positionX`,`positionY`,`positionZ`,`rotation`)
SELECT v.* FROM (
    SELECT 2400101 AS bnpcId, '' AS customDisplayName, 2400001 AS groupId, 1862.201 AS positionX, 152.433 AS positionY, 1736.134 AS positionZ, 0.2955 AS rotation UNION ALL -- Antelope Doe Lv25 (gridania_to_coerthas)
    SELECT 2400102, '', 2400001, 1869.632, 148.934, 1755.120, 0.2326 UNION ALL -- Antelope Doe Lv26 (gridania_to_coerthas)
    SELECT 2400103, '', 2400002, 1837.626, 148.520, 1742.605, -2.1668 UNION ALL -- Arbor Squirrel Lv25 (gridania_to_coerthas)
    SELECT 2400104, '', 2400003, 1781.785, 33.576, -887.097, 2.8420 UNION ALL -- Molting Miteling Lv36 (teleport_to_camp_nine_ivies)
    SELECT 2400105, '', 2400004, 1662.707, 21.191, -808.346, -2.7999 UNION ALL -- Dormouse Lv41 (teleport_to_camp_nine_ivies)
    SELECT 2400106, '', 2400005, -1230.295, 21.855, -1666.985, -2.4396 UNION ALL -- Curious Galago Lv12 (gridania_to_coerthas)
    SELECT 2400107, '', 2400005, -1216.760, 20.969, -1691.093, 2.1586 UNION ALL -- Curious Galago Lv10 (gridania_to_coerthas)
    SELECT 2400108, '', 2400005, -1216.474, 20.323, -1664.702, -1.6762 UNION ALL -- Curious Galago Lv11 (gridania_to_coerthas)
    SELECT 2400109, '', 2400005, -1213.207, 20.323, -1666.596, 1.9641 UNION ALL -- Curious Galago Lv12 (gridania_to_coerthas)
    SELECT 2400110, '', 2400005, -1212.229, 20.235, -1653.284, 1.5824 UNION ALL -- Curious Galago Lv10 (gridania_to_coerthas)
    SELECT 2400111, '', 2400005, -1206.793, 19.565, -1661.579, 2.2211 UNION ALL -- Curious Galago Lv10 (gridania_to_coerthas)
    SELECT 2400112, '', 2400005, -1205.165, 19.133, -1655.753, 1.8336 UNION ALL -- Curious Galago Lv12 (gridania_to_coerthas)
    SELECT 2400113, '', 2400005, -1204.196, 20.513, -1716.752, -0.2551 UNION ALL -- Curious Galago Lv11 (gridania_to_coerthas)
    SELECT 2400114, '', 2400005, -1090.878, 22.926, -1635.871, -1.1327 UNION ALL -- Curious Galago Lv10 (gridania_to_coerthas)
    SELECT 2400115, '', 2400005, -1083.541, 22.730, -1618.056, -2.0644 UNION ALL -- Curious Galago Lv12 (gridania_to_coerthas)
    SELECT 2400116, '', 2400005, -1079.280, 22.523, -1644.378, -1.6691 UNION ALL -- Curious Galago Lv10 (gridania_to_coerthas)
    SELECT 2400117, '', 2400005, -1072.177, 22.985, -1649.260, -2.6741 UNION ALL -- Curious Galago Lv12 (gridania_to_coerthas)
    SELECT 2400118, '', 2400005, -1060.524, 21.482, -1650.213, -2.9062 UNION ALL -- Curious Galago Lv11 (gridania_to_coerthas)
    SELECT 2400119, '', 2400005, -1058.905, 21.014, -1625.560, -0.6516 UNION ALL -- Curious Galago Lv11 (gridania_to_coerthas)
    SELECT 2400120, '', 2400005, -1052.124, 21.023, -1639.451, -2.9377 UNION ALL -- Curious Galago Lv11 (gridania_to_coerthas)
    SELECT 2400121, '', 2400005, -1045.677, 22.554, -1663.001, 1.2024 UNION ALL -- Curious Galago Lv12 (gridania_to_coerthas)
    SELECT 2400122, '', 2400005, -1038.237, 21.773, -1649.491, -2.4322 UNION ALL -- Curious Galago Lv12 (gridania_to_coerthas)
    SELECT 2400123, '', 2400005, -1034.791, 21.814, -1627.388, -2.4213 UNION ALL -- Curious Galago Lv10 (gridania_to_coerthas)
    SELECT 2400124, '', 2400005, -1033.945, 21.375, -1611.212, 1.6456 UNION ALL -- Curious Galago Lv12 (gridania_to_coerthas)
    SELECT 2400125, '', 2400005, -1026.340, 22.525, -1618.152, -0.3891 UNION ALL -- Curious Galago Lv12 (gridania_to_coerthas)
    SELECT 2400126, '', 2400006, -1462.811, 24.015, -1735.196, 1.3401 UNION ALL -- Curious Galago Lv13 (gridania_to_coerthas)
    SELECT 2400127, '', 2400006, -1462.398, 21.389, -1782.175, -3.0096 UNION ALL -- Curious Galago Lv14 (gridania_to_coerthas)
    SELECT 2400128, '', 2400006, -1459.466, 21.743, -1746.141, 0.9647 UNION ALL -- Curious Galago Lv14 (gridania_to_coerthas)
    SELECT 2400129, '', 2400006, -1444.984, 21.014, -1756.338, -0.9318 UNION ALL -- Curious Galago Lv14 (gridania_to_coerthas)
    SELECT 2400130, '', 2400006, -1440.576, 22.102, -1785.275, -1.6703 UNION ALL -- Curious Galago Lv14 (gridania_to_coerthas)
    SELECT 2400131, '', 2400006, -1437.235, 21.023, -1765.955, 1.4524 UNION ALL -- Curious Galago Lv13 (gridania_to_coerthas)
    SELECT 2400132, '', 2400006, -1422.045, 21.746, -1776.403, -2.2960 UNION ALL -- Curious Galago Lv13 (gridania_to_coerthas)
    SELECT 2400133, '', 2400006, -1418.853, 21.896, -1766.134, -1.3478 UNION ALL -- Curious Galago Lv15 (gridania_to_coerthas)
    SELECT 2400134, '', 2400006, -1415.770, 21.379, -1738.245, -0.5402 UNION ALL -- Curious Galago Lv14 (gridania_to_coerthas)
    SELECT 2400135, '', 2400006, -1415.316, 24.025, -1786.767, -1.0337 UNION ALL -- Curious Galago Lv13 (gridania_to_coerthas)
    SELECT 2400136, '', 2400006, -1415.137, 21.814, -1754.828, 1.6975 UNION ALL -- Curious Galago Lv14 (gridania_to_coerthas)
    SELECT 2400137, '', 2400006, -1410.012, 22.570, -1747.426, -0.5283 UNION ALL -- Curious Galago Lv14 (gridania_to_coerthas)
    SELECT 2400138, '', 2400007, -1599.699, 22.552, -1894.561, -1.6644 UNION ALL -- Curious Galago Lv19 (gridania_to_coerthas)
    SELECT 2400139, '', 2400007, -1590.053, 21.373, -1863.274, -0.1077 UNION ALL -- Curious Galago Lv19 (gridania_to_coerthas)
    SELECT 2400140, '', 2400007, -1589.241, 21.535, -1900.060, 2.9426 UNION ALL -- Curious Galago Lv18 (gridania_to_coerthas)
    SELECT 2400141, '', 2400007, -1581.072, 21.756, -1906.418, 1.8827 UNION ALL -- Curious Galago Lv18 (gridania_to_coerthas)
    SELECT 2400142, '', 2400007, -1572.127, 21.252, -1903.107, 1.1161 UNION ALL -- Curious Galago Lv17 (gridania_to_coerthas)
    SELECT 2400143, '', 2400007, -1571.849, 22.110, -1916.527, -2.4475 UNION ALL -- Curious Galago Lv19 (gridania_to_coerthas)
    SELECT 2400144, '', 2400007, -1565.004, 21.246, -1900.170, 2.2527 UNION ALL -- Curious Galago Lv18 (gridania_to_coerthas)
    SELECT 2400145, '', 2400007, -1556.589, 21.651, -1873.308, -0.2560 UNION ALL -- Curious Galago Lv18 (gridania_to_coerthas)
    SELECT 2400146, '', 2400007, -1555.313, 21.315, -1895.096, -1.2800 UNION ALL -- Curious Galago Lv18 (gridania_to_coerthas)
    SELECT 2400147, '', 2400007, -1553.313, 21.239, -1881.984, 2.4526 UNION ALL -- Curious Galago Lv18 (gridania_to_coerthas)
    SELECT 2400148, '', 2400007, -1551.971, 21.600, -1901.522, 1.7636 UNION ALL -- Curious Galago Lv18 (gridania_to_coerthas)
    SELECT 2400149, '', 2400007, -1539.307, 25.283, -1857.111, 0.3061 UNION ALL -- Curious Galago Lv18 (gridania_to_coerthas)
    SELECT 2400150, '', 2400008, -1579.123, 31.805, -1732.399, 0.7743 UNION ALL -- Thistletail Marmot Lv10 (gridania_to_coerthas)
    SELECT 2400151, '', 2400008, -1571.226, 20.866, -1789.837, -1.3807 UNION ALL -- Thistletail Marmot Lv13 (gridania_to_coerthas)
    SELECT 2400152, '', 2400008, -1553.417, 21.761, -1869.705, -1.2435 UNION ALL -- Thistletail Marmot Lv13 (gridania_to_coerthas)
    SELECT 2400153, '', 2400008, -1528.166, 32.076, -1852.704, 2.5904 UNION ALL -- Thistletail Marmot Lv10 (gridania_to_coerthas)
    SELECT 2400154, '', 2400008, -1520.590, 33.233, -1729.384, 2.0747 UNION ALL -- Thistletail Marmot Lv12 (gridania_to_coerthas)
    SELECT 2400155, '', 2400008, -1512.923, 19.429, -1791.881, -2.2111 UNION ALL -- Thistletail Marmot Lv12 (gridania_to_coerthas)
    SELECT 2400156, '', 2400008, -1445.831, 33.159, -1860.420, 1.6913 UNION ALL -- Thistletail Marmot Lv14 (gridania_to_coerthas)
    SELECT 2400157, '', 2400008, -1405.851, 32.632, -1808.325, 2.9163 UNION ALL -- Thistletail Marmot Lv13 (gridania_to_coerthas)
    SELECT 2400158, '', 2400008, -1404.952, 21.359, -1719.506, -1.5607 UNION ALL -- Thistletail Marmot Lv10 (gridania_to_coerthas)
    SELECT 2400159, '', 2400008, -1397.374, 7.582, -1740.961, 1.6673 UNION ALL -- Thistletail Marmot Lv10 (gridania_to_coerthas)
    SELECT 2400160, '', 2400008, -1389.238, 21.550, -1723.651, 2.4190 UNION ALL -- Thistletail Marmot Lv10 (gridania_to_coerthas)
    SELECT 2400161, '', 2400008, -1268.049, 20.438, -1737.773, -2.2089 UNION ALL -- Thistletail Marmot Lv13 (gridania_to_coerthas)
    SELECT 2400162, '', 2400008, -1133.902, 18.987, -1734.639, 2.0299 UNION ALL -- Thistletail Marmot Lv12 (gridania_to_coerthas)
    SELECT 2400163, '', 2400008, -1051.765, 21.661, -1651.100, -1.5496 UNION ALL -- Thistletail Marmot Lv14 (gridania_to_coerthas)
    SELECT 2400164, '', 2400008, -996.280, 21.040, -1599.628, 2.3102 UNION ALL -- Thistletail Marmot Lv14 (gridania_to_coerthas)
    SELECT 2400165, '', 2400009, -1405.902, 32.632, -1811.000, 0.0482 UNION ALL -- Bristletail Marmot Lv10 (gridania_to_coerthas)
    SELECT 2400166, '', 2400009, -1400.232, 32.013, -1797.232, 1.1608 UNION ALL -- Bristletail Marmot Lv10 (gridania_to_coerthas)
    SELECT 2400167, '', 2400009, -1373.914, 33.053, -1789.185, 1.7863 UNION ALL -- Bristletail Marmot Lv10 (gridania_to_coerthas)
    SELECT 2400168, '', 2400009, -1215.428, 32.735, -1793.451, -1.0433 UNION ALL -- Bristletail Marmot Lv10 (gridania_to_coerthas)
    SELECT 2400169, '', 2400009, -1213.381, 32.943, -1786.036, -0.6751 UNION ALL -- Bristletail Marmot Lv10 (gridania_to_coerthas)
    SELECT 2400170, '', 2400009, -1211.008, 32.951, -1783.962, 2.7831 UNION ALL -- Bristletail Marmot Lv10 (gridania_to_coerthas)
    SELECT 2400171, '', 2400009, -1206.465, 32.294, -1802.370, 2.6587 UNION ALL -- Bristletail Marmot Lv10 (gridania_to_coerthas)
    SELECT 2400172, '', 2400009, -1201.056, 33.233, -1794.860, 1.0445 UNION ALL -- Bristletail Marmot Lv10 (gridania_to_coerthas)
    SELECT 2400173, '', 2400009, -1200.269, 33.233, -1796.272, 1.9341 UNION ALL -- Bristletail Marmot Lv10 (gridania_to_coerthas)
    SELECT 2400174, '', 2400010, -1410.545, 8.544, -1727.740, 0.6910 UNION ALL -- Cave Bat Lv14 (gridania_to_coerthas)
    SELECT 2400175, '', 2400010, -1152.422, 8.510, -1662.648, 3.0150 UNION ALL -- Cave Bat Lv10 (gridania_to_coerthas)
    SELECT 2400176, '', 2400010, -1144.663, 7.691, -1659.792, -2.3053 UNION ALL -- Cave Bat Lv14 (gridania_to_coerthas)
    SELECT 2400177, '', 2400011, -1548.278, 21.817, -1872.426, -2.2656 UNION ALL -- Carrion Chigoe Lv14 (gridania_to_coerthas)
    SELECT 2400178, '', 2400011, -1433.845, 21.296, -1660.832, -2.7291 UNION ALL -- Carrion Chigoe Lv10 (gridania_to_coerthas)
    SELECT 2400179, '', 2400011, -1409.716, 8.544, -1728.885, 0.9408 UNION ALL -- Carrion Chigoe Lv10 (gridania_to_coerthas)
    SELECT 2400180, '', 2400012, -1137.029, 7.567, -1653.401, 2.4279 UNION ALL -- Snapping Shrew Lv5 (gridania_to_coerthas)
    SELECT 2400181, '', 2400013, -1407.246, 8.544, -1728.673, -0.2429 UNION ALL -- Lightning Beetle Lv16 (gridania_to_coerthas)
    SELECT 2400182, '', 2400013, -1402.591, 8.087, -1726.130, 0.2513 UNION ALL -- Lightning Beetle Lv17 (gridania_to_coerthas)
    SELECT 2400183, '', 2400014, -1297.329, 32.405, -1671.062, -0.7692 UNION ALL -- Mature Funguar Lv12 (gridania_to_coerthas)
    SELECT 2400184, '', 2400014, -1296.949, 32.510, -1666.703, -0.0050 UNION ALL -- Mature Funguar Lv12 (gridania_to_coerthas)
    SELECT 2400185, '', 2400014, -1291.709, 32.497, -1680.313, -0.6861 UNION ALL -- Mature Funguar Lv12 (gridania_to_coerthas)
    SELECT 2400186, '', 2400014, -1281.431, 33.003, -1692.868, -3.1398 UNION ALL -- Mature Funguar Lv13 (gridania_to_coerthas)
    SELECT 2400187, '', 2400014, -1280.338, 32.720, -1667.879, -3.1035 UNION ALL -- Mature Funguar Lv12 (gridania_to_coerthas)
    SELECT 2400188, '', 2400014, -1279.932, 33.148, -1674.752, 0.2168 UNION ALL -- Mature Funguar Lv13 (gridania_to_coerthas)
    SELECT 2400189, '', 2400014, -1279.066, 32.647, -1658.098, -0.0920 UNION ALL -- Mature Funguar Lv12 (gridania_to_coerthas)
    SELECT 2400190, '', 2400014, -1278.648, 33.148, -1671.249, 0.2112 UNION ALL -- Mature Funguar Lv12 (gridania_to_coerthas)
    SELECT 2400191, '', 2400014, -1278.311, 33.148, -1673.873, 2.7623 UNION ALL -- Mature Funguar Lv12 (gridania_to_coerthas)
    SELECT 2400192, '', 2400015, 897.872, -11.738, 1084.568, -2.3395 UNION ALL -- Canopy Galago Lv23 (combat_autoattack+teleport_to_gridania)
    SELECT 2400193, '', 2400015, 898.125, -12.905, 1073.922, -1.6751 UNION ALL -- Canopy Galago Lv21 (combat_autoattack)
    SELECT 2400194, '', 2400016, 840.624, 0.500, 1155.199, -2.1976 UNION ALL -- Tree Slug Lv26 (combat_autoattack)
    SELECT 2400195, '', 2400016, 894.006, 0.980, 1113.847, -1.1776 UNION ALL -- Tree Slug Lv24 (combat_autoattack)
    SELECT 2400196, '', 2400017, 679.786, 0.901, 1149.561, -1.8065 UNION ALL -- Faerie Funguar Lv16 (teleport_to_camp_tranquil)
    SELECT 2400197, '', 2400018, -1132.803, 60.319, -14.557, 0.2440 UNION ALL -- Sabotender del Sol Lv78 (war_quest_update2)
    SELECT 2400198, '', 2400019, -1053.702, 56.790, 59.528, 2.7041 UNION ALL -- Cactuar Lv26 (war_quest_update2)
    SELECT 2400199, '', 2400019, -1032.286, 59.109, 46.025, -1.4896 UNION ALL -- Cactuar Lv25 (war_quest_update2)
    SELECT 2400200, '', 2400019, -1031.448, 56.679, 58.696, 2.2349 UNION ALL -- Cactuar Lv25 (war_quest_update2)
    SELECT 2400201, '', 2400020, -1142.656, 49.569, 85.412, -1.2480 UNION ALL -- Puroboros Lv76 (war_quest_update2)
    SELECT 2400202, '', 2400020, -1083.125, 33.497, 93.109, 1.8633 UNION ALL -- Puroboros Lv78 (war_quest_update2)
    SELECT 2400203, '', 2400021, -1158.483, 56.914, 222.022, 0.5421 UNION ALL -- Lead Coblyn Lv18 (war_quest_update3)
    SELECT 2400204, '', 2400022, -1155.983, 70.826, 1.912, 1.7851 UNION ALL -- Spinesnap Ogre Lv80 (war_quest_update2)
    SELECT 2400205, '', 2400022, -1143.766, 59.308, -8.750, 0.8205 UNION ALL -- Spinesnap Ogre Lv84 (war_quest_update2)
    SELECT 2400206, '', 2400022, -1124.307, 66.325, -20.234, -0.7455 UNION ALL -- Spinesnap Ogre Lv80 (war_quest_update2)
    SELECT 2400207, '', 2400022, -1021.172, 70.591, 9.136, 1.8794 UNION ALL -- Spinesnap Ogre Lv81 (war_quest_update2)
    SELECT 2400208, '', 2400023, -1042.120, 50.969, 266.912, 0.9271 UNION ALL -- Bloated Bogy Lv22 (war_quest_update3)
    SELECT 2400209, '', 2400024, -1015.165, 72.436, 19.502, 0.6724 -- Amalj'aa Grappler Lv88 (war_quest_update2)
) v WHERE EXISTS (SELECT 1 FROM `server_battlenpc_groups` g WHERE g.`groupId` = v.`groupId`);
