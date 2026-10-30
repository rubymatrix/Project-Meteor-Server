-- East/North/West/South Shroud (zones 151-154) spawn clean-up, 2026-10-13. Companion of
-- seed_bnpc_10 (zone 150); same sources, tags and rules (see its header).
-- Apply after seed_bnpc_01..08 (and again after re-applying 02, 04 or 05). Idempotent.
-- Needs a Map (+World) restart. Rollback: seed_bnpc_18_black_shroud_fixes_rollback.sql.

-- 1. Removed groups
--  152 100276 Sabotender Lv67-68, 100281 Sabotender del Sol Lv75-79: GE spots only, on Camp Emerald
--      Moss (-1052,-1760), where MB/GE/CAP put the Lv10-14 shrew, galago and marmot camps.
--      Same call as the Bentbranch sabotenders.
--  151 100149 "Goblin Freesword" Lv18-63: one captured goblin model 8 units from the Camp Nineivies
--      aetheryte; the name and hostility are the generator's guess. A camp actor, not a field mob,
--      until a capture shows it fighting.
DELETE s FROM `server_battlenpc_spawn_locations` s
    JOIN `server_battlenpc_groups` g ON g.`groupId` = s.`groupId`
    WHERE g.`groupId` IN (100149, 100276, 100281);
DELETE FROM `server_battlenpc_groups` WHERE `groupId` IN (100149, 100276, 100281);

-- 2. North Shroud 100292: the captured funguar points by Emerald Moss were matched to Screamer
--    (Lv65-69, GE only). MB has "Mature Funguar Lv11-13, 10-12 per camp" 57 units away, so they are
--    Mature Funguar (client class 2105916; bestiary tier A). The class has no classPath in
--    gamedata_actor_class; it binds as FunguarLesserStandard like the other Shroud funguars.
UPDATE `gamedata_actor_class` SET `classPath` = '/Chara/Npc/Monster/Funguar/FunguarLesserStandard'
    WHERE `id` = 2105916 AND (`classPath` IS NULL OR `classPath` = '');
DELETE FROM `server_battlenpc_pool_mods` WHERE `poolId` = 2300101;
DELETE FROM `server_battlenpc_pools` WHERE `poolId` = 2300101;
INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,`combatSkill`,`combatDelay`,
    `combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,`skillListId`)
    SELECT 2300101, 2105916, 'mature_funguar', `genusId`, `currentJob`, `combatSkill`, `combatDelay`, `combatDmgMult`,
        `aggroType`, `immunity`, `linkType`, `spellListId`, `skillListId`
    FROM `server_battlenpc_pools` WHERE `poolId` = 100139;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`)
    SELECT 2300101, `modId`, `modVal`, `isMobMod` FROM `server_battlenpc_pool_mods` WHERE `poolId` = 100139;
UPDATE `server_battlenpc_groups` SET `poolId` = 2300101, `scriptName` = 'mature_funguar', `minLevel` = 11, `maxLevel` = 13
    WHERE `groupId` = 100292 AND EXISTS (SELECT 1 FROM `server_battlenpc_pools` WHERE `poolId` = 2300101);

-- 3. Level bands. These groups took the bestiary's all-zone range (12-60 levels wide) because no
--    source gives a level for that monster there. DESIGN: use the band of the nearest MB camp within
--    250 units (else GE level spot), clamped into the monster's range; with neither, the lowest five
--    levels of the range. "near" = the evidence used.
-- East Shroud (151)
UPDATE `server_battlenpc_groups` SET `minLevel` = 40, `maxLevel` = 44 WHERE `groupId` = 100106; -- Dwarf Banemite 27-64; MB eft poacher 40-42
UPDATE `server_battlenpc_groups` SET `minLevel` = 40, `maxLevel` = 44 WHERE `groupId` = 100267; -- Ringtail 40-59; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 34, `maxLevel` = 38 WHERE `groupId` IN (100325, 100326, 100327); -- Spiny Dormouse 34-49; GE Crabfisher 33/Ironshell 35
UPDATE `server_battlenpc_groups` SET `minLevel` = 35, `maxLevel` = 39 WHERE `groupId` = 100338; -- Stoneshell 35-65; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 45, `maxLevel` = 49 WHERE `groupId` = 100339; -- Stoneshell 35-65; MB Black Eft 45-46
UPDATE `server_battlenpc_groups` SET `minLevel` = 29, `maxLevel` = 33 WHERE `groupId` = 100397; -- Anole 29-64; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 43, `maxLevel` = 47 WHERE `groupId` = 100411; -- Banescale Guivre 43-74; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 24, `maxLevel` = 28 WHERE `groupId` = 100437; -- Buzzard 24-44; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 40, `maxLevel` = 44 WHERE `groupId` = 100438; -- Buzzard 24-44; MB Black Eft 40-42
UPDATE `server_battlenpc_groups` SET `minLevel` = 38, `maxLevel` = 42 WHERE `groupId` = 100478; -- Fallen Soldier 38-64; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 40, `maxLevel` = 44 WHERE `groupId` = 100503; -- Guivre 40-69; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 40, `maxLevel` = 44 WHERE `groupId` = 100505; -- Hellbender 40-84; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 43, `maxLevel` = 47 WHERE `groupId` = 100599; -- Lindwurm 31-74; MB eft poacher 43-45
UPDATE `server_battlenpc_groups` SET `minLevel` = 47, `maxLevel` = 51 WHERE `groupId` = 100658; -- Pugot 43-79; MB Black Eft 47-49
UPDATE `server_battlenpc_groups` SET `minLevel` = 60, `maxLevel` = 64 WHERE `groupId` = 100676; -- Qiqirn Mercenary 60-99; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 35, `maxLevel` = 39 WHERE `groupId` = 100690; -- Redwing Ked 35-74; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 37, `maxLevel` = 41 WHERE `groupId` = 100737; -- Snurble 37-70; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 47, `maxLevel` = 51 WHERE `groupId` = 100760; -- Sylph Susurrus 40-56; MB Black Eft 47-49
UPDATE `server_battlenpc_groups` SET `minLevel` = 47, `maxLevel` = 49 WHERE `groupId` IN (100763, 100764); -- Toad Poacher 34-57; MB "Eft Poacher" camp 47-49
-- North Shroud (152)
UPDATE `server_battlenpc_groups` SET `minLevel` = 17, `maxLevel` = 21 WHERE `groupId` = 100060; -- Cave Bat 5-23; MB Drybone Shrew 17-19
UPDATE `server_battlenpc_groups` SET `minLevel` = 47, `maxLevel` = 51 WHERE `groupId` = 100136; -- Goblin Bouncer 37-95; MB Wild Hog 47-49
UPDATE `server_battlenpc_groups` SET `minLevel` = 44, `maxLevel` = 48 WHERE `groupId` = 100137; -- Goblin Bouncer 37-95; MB Wild Hog 44-46
UPDATE `server_battlenpc_groups` SET `minLevel` = 50, `maxLevel` = 54 WHERE `groupId` = 100150; -- Goblin Freesword 18-63; GE Scout Wolf 50 / Ixali Scout 52
UPDATE `server_battlenpc_groups` SET `minLevel` = 43, `maxLevel` = 47 WHERE `groupId` = 100151; -- Goblin Freesword 18-63; MB Ixali 43-46
UPDATE `server_battlenpc_groups` SET `minLevel` = 45, `maxLevel` = 49 WHERE `groupId` = 100193; -- Lightning Beetle 15-49; GE Scout Wolf 50, clamped
UPDATE `server_battlenpc_groups` SET `minLevel` = 15, `maxLevel` = 19 WHERE `groupId` = 100196; -- Lone Wolf 15-53; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 28, `maxLevel` = 32 WHERE `groupId` = 100209; -- Molting Miteling 28-60; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 10, `maxLevel` = 12 WHERE `groupId` = 100349; -- Thistletail Marmot [CAP] 10-19; MB Curious Galago 10-12
UPDATE `server_battlenpc_groups` SET `minLevel` = 10, `maxLevel` = 12 WHERE `groupId` = 100371; -- captured bat 10-40; MB Curious Galago 10-12
UPDATE `server_battlenpc_groups` SET `minLevel` = 13, `maxLevel` = 16 WHERE `groupId` = 100372; -- captured bat 10-40; MB Curious Galago 13-16
UPDATE `server_battlenpc_groups` SET `minLevel` = 10, `maxLevel` = 14 WHERE `groupId` = 100463; -- Emerald Bee Swarm 10-49; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 5,  `maxLevel` = 9  WHERE `groupId` = 100520; -- Honeybee Swarm 5-45; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 47, `maxLevel` = 51 WHERE `groupId` = 100662; -- Pugot 43-79; MB Wild Hog 47-49
-- West Shroud (153)
UPDATE `server_battlenpc_groups` SET `minLevel` = 20, `maxLevel` = 24 WHERE `groupId` = 100027; -- Antelope Doe 20-43; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 90, `maxLevel` = 95 WHERE `groupId` = 100140; -- Goblin Bouncer 37-95; MB Goblin Headman camp 90-97
UPDATE `server_battlenpc_groups` SET `minLevel` = 37, `maxLevel` = 41 WHERE `groupId` = 100141; -- Goblin Bouncer 37-95; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 34, `maxLevel` = 38 WHERE `groupId` = 100329; -- Spiny Dormouse 34-49; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 43, `maxLevel` = 47 WHERE `groupId` = 100412; -- Bark Eft 43-54; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 50, `maxLevel` = 54 WHERE `groupId` = 100470; -- Fallen Captain 39-79; MB Scout Vulture 50-53
UPDATE `server_battlenpc_groups` SET `minLevel` = 41, `maxLevel` = 45 WHERE `groupId` = 100495; -- Gigantoad 41-64; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 40, `maxLevel` = 44 WHERE `groupId` = 100506; -- Hellbender 40-84; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 50, `maxLevel` = 54 WHERE `groupId` = 100601; -- Lindwurm 31-74; MB Scout Vulture 50-53
UPDATE `server_battlenpc_groups` SET `minLevel` = 50, `maxLevel` = 54 WHERE `groupId` = 100731; -- Smolenkos 40-85; MB Shrieker 50-53
UPDATE `server_battlenpc_groups` SET `minLevel` = 34, `maxLevel` = 38 WHERE `groupId` IN (100767, 100768); -- Toad Poacher 34-57; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 45, `maxLevel` = 49 WHERE `groupId` = 100821; -- Wight Warrior 30-49; MB Scout Vulture 50-54, clamped
-- South Shroud (154)
UPDATE `server_battlenpc_groups` SET `minLevel` = 25, `maxLevel` = 29 WHERE `groupId` = 100031; -- Arbor Squirrel 20-29; GE Thickshell 25-29
UPDATE `server_battlenpc_groups` SET `minLevel` = 15, `maxLevel` = 19 WHERE `groupId` = 100112; -- Faerie Funguar 15-32; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 19, `maxLevel` = 23 WHERE `groupId` = 100114; -- Fallgourd Funguar 10-26; GE Saltspray Pteroc 19-21
UPDATE `server_battlenpc_groups` SET `minLevel` = 18, `maxLevel` = 22 WHERE `groupId` = 100115; -- Fallgourd Funguar 10-26; MB Oilbug 18-19
UPDATE `server_battlenpc_groups` SET `minLevel` = 21, `maxLevel` = 24 WHERE `groupId` = 100228; -- Opo-Opo 21-34; MB Canopy Galago 20-24
UPDATE `server_battlenpc_groups` SET `minLevel` = 29, `maxLevel` = 33 WHERE `groupId` = 100398; -- Anole 29-64; MB Ixali 27-29, clamped
UPDATE `server_battlenpc_groups` SET `minLevel` = 31, `maxLevel` = 35 WHERE `groupId` = 100600; -- Lindwurm 31-74; MB Young Antelope Stag 24-26, clamped
UPDATE `server_battlenpc_groups` SET `minLevel` = 63, `maxLevel` = 67 WHERE `groupId` = 100623; -- Morbol 63-74; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 60, `maxLevel` = 64 WHERE `groupId` = 100677; -- Qiqirn Mercenary 60-99; range floor
UPDATE `server_battlenpc_groups` SET `minLevel` = 25, `maxLevel` = 29 WHERE `groupId` = 100782; -- Toxic Toad 8-54; MB Popoto-opoto 25
UPDATE `server_battlenpc_groups` SET `minLevel` = 20, `maxLevel` = 22 WHERE `groupId` IN (100381, 100387); -- captured monkey/slug 20-43; MB Antelope Doe 20-22
