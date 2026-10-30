-- Rollback for seed_bnpc_11_black_shroud_fixes.sql: puts back the removed groups and spawn points, the
-- Screamer group and the level bands as they were in seed_bnpc_04/05, and drops the Mature Funguar
-- pool. Idempotent. The classPath set on actor class 2105916 is left in place (harmless, unused).
INSERT IGNORE INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`) VALUES
(100149,100068,'goblin_freesword',18,63,90,0,0,0,0,0,0,0,'',0,151),
(100276,100134,'sabotender',67,68,90,0,0,0,0,0,0,0,'',0,152),
(100281,100135,'sabotender_del_sol',75,79,90,0,0,0,0,0,0,0,'',0,152);
INSERT IGNORE INTO `server_battlenpc_spawn_locations` (`bnpcId`,`customDisplayName`,`groupId`,`positionX`,`positionY`,`positionZ`,`rotation`) VALUES
(1000881,'',100149,1710,0,-860,1.96),
(1001560,'',100276,-1132,0,-1940,-2.981),
(1001561,'',100276,-1144,0,-1933.1,0.726),
(1001562,'',100276,-1144,0,-1946.9,-3.14),
(1001563,'',100276,-1032,0,-1740,-2.642),
(1001564,'',100276,-1044,0,-1733.1,-2.112),
(1001565,'',100276,-1044,0,-1746.9,-1.14),
(1001589,'',100281,-1032,0,-1740,0.173),
(1001590,'',100281,-1044,0,-1733.1,-1.074),
(1001591,'',100281,-1044,0,-1746.9,-0.805),
(1001592,'',100281,-1032,0,-1940,-1.955),
(1001593,'',100281,-1044,0,-1933.1,0.259),
(1001594,'',100281,-1044,0,-1946.9,-2.227);
UPDATE `server_battlenpc_groups` SET `poolId`=100010,`scriptName`='antelope_doe',`minLevel`=20,`maxLevel`=43 WHERE `groupId`=100027;
UPDATE `server_battlenpc_groups` SET `poolId`=100012,`scriptName`='arbor_squirrel',`minLevel`=20,`maxLevel`=29 WHERE `groupId`=100031;
UPDATE `server_battlenpc_groups` SET `poolId`=100034,`scriptName`='cave_bat',`minLevel`=5,`maxLevel`=23 WHERE `groupId`=100060;
UPDATE `server_battlenpc_groups` SET `poolId`=100051,`scriptName`='dwarf_banemite',`minLevel`=27,`maxLevel`=64 WHERE `groupId`=100106;
UPDATE `server_battlenpc_groups` SET `poolId`=100055,`scriptName`='faerie_funguar',`minLevel`=15,`maxLevel`=32 WHERE `groupId`=100112;
UPDATE `server_battlenpc_groups` SET `poolId`=100056,`scriptName`='fallgourd_funguar',`minLevel`=10,`maxLevel`=26 WHERE `groupId`=100114;
UPDATE `server_battlenpc_groups` SET `poolId`=100056,`scriptName`='fallgourd_funguar',`minLevel`=10,`maxLevel`=26 WHERE `groupId`=100115;
UPDATE `server_battlenpc_groups` SET `poolId`=100066,`scriptName`='goblin_bouncer',`minLevel`=37,`maxLevel`=95 WHERE `groupId`=100136;
UPDATE `server_battlenpc_groups` SET `poolId`=100066,`scriptName`='goblin_bouncer',`minLevel`=37,`maxLevel`=95 WHERE `groupId`=100137;
UPDATE `server_battlenpc_groups` SET `poolId`=100066,`scriptName`='goblin_bouncer',`minLevel`=37,`maxLevel`=95 WHERE `groupId`=100140;
UPDATE `server_battlenpc_groups` SET `poolId`=100066,`scriptName`='goblin_bouncer',`minLevel`=37,`maxLevel`=95 WHERE `groupId`=100141;
UPDATE `server_battlenpc_groups` SET `poolId`=100068,`scriptName`='goblin_freesword',`minLevel`=18,`maxLevel`=63 WHERE `groupId`=100150;
UPDATE `server_battlenpc_groups` SET `poolId`=100068,`scriptName`='goblin_freesword',`minLevel`=18,`maxLevel`=63 WHERE `groupId`=100151;
UPDATE `server_battlenpc_groups` SET `poolId`=100090,`scriptName`='lightning_beetle',`minLevel`=15,`maxLevel`=49 WHERE `groupId`=100193;
UPDATE `server_battlenpc_groups` SET `poolId`=100091,`scriptName`='lone_wolf',`minLevel`=15,`maxLevel`=53 WHERE `groupId`=100196;
UPDATE `server_battlenpc_groups` SET `poolId`=100097,`scriptName`='molting_miteling',`minLevel`=28,`maxLevel`=60 WHERE `groupId`=100209;
UPDATE `server_battlenpc_groups` SET `poolId`=100109,`scriptName`='opo_opo',`minLevel`=21,`maxLevel`=34 WHERE `groupId`=100228;
UPDATE `server_battlenpc_groups` SET `poolId`=100128,`scriptName`='ringtail',`minLevel`=40,`maxLevel`=59 WHERE `groupId`=100267;
UPDATE `server_battlenpc_groups` SET `poolId`=100139,`scriptName`='screamer',`minLevel`=65,`maxLevel`=69 WHERE `groupId`=100292;
UPDATE `server_battlenpc_groups` SET `poolId`=100157,`scriptName`='spiny_dormouse',`minLevel`=34,`maxLevel`=49 WHERE `groupId`=100325;
UPDATE `server_battlenpc_groups` SET `poolId`=100157,`scriptName`='spiny_dormouse',`minLevel`=34,`maxLevel`=49 WHERE `groupId`=100326;
UPDATE `server_battlenpc_groups` SET `poolId`=100157,`scriptName`='spiny_dormouse',`minLevel`=34,`maxLevel`=49 WHERE `groupId`=100327;
UPDATE `server_battlenpc_groups` SET `poolId`=100157,`scriptName`='spiny_dormouse',`minLevel`=34,`maxLevel`=49 WHERE `groupId`=100329;
UPDATE `server_battlenpc_groups` SET `poolId`=100163,`scriptName`='stoneshell',`minLevel`=35,`maxLevel`=65 WHERE `groupId`=100338;
UPDATE `server_battlenpc_groups` SET `poolId`=100163,`scriptName`='stoneshell',`minLevel`=35,`maxLevel`=65 WHERE `groupId`=100339;
UPDATE `server_battlenpc_groups` SET `poolId`=100167,`scriptName`='thistletail_marmot',`minLevel`=10,`maxLevel`=19 WHERE `groupId`=100349;
UPDATE `server_battlenpc_groups` SET `poolId`=100180,`scriptName`='retail_batnormalstandard',`minLevel`=10,`maxLevel`=40 WHERE `groupId`=100371;
UPDATE `server_battlenpc_groups` SET `poolId`=100180,`scriptName`='retail_batnormalstandard',`minLevel`=10,`maxLevel`=40 WHERE `groupId`=100372;
UPDATE `server_battlenpc_groups` SET `poolId`=100186,`scriptName`='retail_monkeylesserstandard',`minLevel`=20,`maxLevel`=43 WHERE `groupId`=100381;
UPDATE `server_battlenpc_groups` SET `poolId`=100192,`scriptName`='retail_sluglesserstandard',`minLevel`=20,`maxLevel`=43 WHERE `groupId`=100387;
UPDATE `server_battlenpc_groups` SET `poolId`=100201,`scriptName`='anole',`minLevel`=29,`maxLevel`=64 WHERE `groupId`=100397;
UPDATE `server_battlenpc_groups` SET `poolId`=100201,`scriptName`='anole',`minLevel`=29,`maxLevel`=64 WHERE `groupId`=100398;
UPDATE `server_battlenpc_groups` SET `poolId`=100208,`scriptName`='banescale_guivre',`minLevel`=43,`maxLevel`=74 WHERE `groupId`=100411;
UPDATE `server_battlenpc_groups` SET `poolId`=100209,`scriptName`='bark_eft',`minLevel`=43,`maxLevel`=54 WHERE `groupId`=100412;
UPDATE `server_battlenpc_groups` SET `poolId`=100221,`scriptName`='buzzard',`minLevel`=24,`maxLevel`=44 WHERE `groupId`=100437;
UPDATE `server_battlenpc_groups` SET `poolId`=100221,`scriptName`='buzzard',`minLevel`=24,`maxLevel`=44 WHERE `groupId`=100438;
UPDATE `server_battlenpc_groups` SET `poolId`=100240,`scriptName`='emerald_bee_swarm',`minLevel`=10,`maxLevel`=49 WHERE `groupId`=100463;
UPDATE `server_battlenpc_groups` SET `poolId`=100244,`scriptName`='fallen_captain',`minLevel`=39,`maxLevel`=79 WHERE `groupId`=100470;
UPDATE `server_battlenpc_groups` SET `poolId`=100246,`scriptName`='fallen_soldier',`minLevel`=38,`maxLevel`=64 WHERE `groupId`=100478;
UPDATE `server_battlenpc_groups` SET `poolId`=100254,`scriptName`='gigantoad',`minLevel`=41,`maxLevel`=64 WHERE `groupId`=100495;
UPDATE `server_battlenpc_groups` SET `poolId`=100260,`scriptName`='guivre',`minLevel`=40,`maxLevel`=69 WHERE `groupId`=100503;
UPDATE `server_battlenpc_groups` SET `poolId`=100262,`scriptName`='hellbender',`minLevel`=40,`maxLevel`=84 WHERE `groupId`=100505;
UPDATE `server_battlenpc_groups` SET `poolId`=100262,`scriptName`='hellbender',`minLevel`=40,`maxLevel`=84 WHERE `groupId`=100506;
UPDATE `server_battlenpc_groups` SET `poolId`=100266,`scriptName`='honeybee_swarm',`minLevel`=5,`maxLevel`=45 WHERE `groupId`=100520;
UPDATE `server_battlenpc_groups` SET `poolId`=100302,`scriptName`='lindwurm',`minLevel`=31,`maxLevel`=74 WHERE `groupId`=100599;
UPDATE `server_battlenpc_groups` SET `poolId`=100302,`scriptName`='lindwurm',`minLevel`=31,`maxLevel`=74 WHERE `groupId`=100600;
UPDATE `server_battlenpc_groups` SET `poolId`=100302,`scriptName`='lindwurm',`minLevel`=31,`maxLevel`=74 WHERE `groupId`=100601;
UPDATE `server_battlenpc_groups` SET `poolId`=100313,`scriptName`='morbol',`minLevel`=63,`maxLevel`=74 WHERE `groupId`=100623;
UPDATE `server_battlenpc_groups` SET `poolId`=100329,`scriptName`='pugot',`minLevel`=43,`maxLevel`=79 WHERE `groupId`=100658;
UPDATE `server_battlenpc_groups` SET `poolId`=100329,`scriptName`='pugot',`minLevel`=43,`maxLevel`=79 WHERE `groupId`=100662;
UPDATE `server_battlenpc_groups` SET `poolId`=100335,`scriptName`='qiqirn_mercenary',`minLevel`=60,`maxLevel`=99 WHERE `groupId`=100676;
UPDATE `server_battlenpc_groups` SET `poolId`=100335,`scriptName`='qiqirn_mercenary',`minLevel`=60,`maxLevel`=99 WHERE `groupId`=100677;
UPDATE `server_battlenpc_groups` SET `poolId`=100341,`scriptName`='redwing_ked',`minLevel`=35,`maxLevel`=74 WHERE `groupId`=100690;
UPDATE `server_battlenpc_groups` SET `poolId`=100351,`scriptName`='smolenkos',`minLevel`=40,`maxLevel`=85 WHERE `groupId`=100731;
UPDATE `server_battlenpc_groups` SET `poolId`=100352,`scriptName`='snurble',`minLevel`=37,`maxLevel`=70 WHERE `groupId`=100737;
UPDATE `server_battlenpc_groups` SET `poolId`=100358,`scriptName`='sylph_susurrus',`minLevel`=40,`maxLevel`=56 WHERE `groupId`=100760;
UPDATE `server_battlenpc_groups` SET `poolId`=100361,`scriptName`='toad_poacher',`minLevel`=34,`maxLevel`=57 WHERE `groupId`=100763;
UPDATE `server_battlenpc_groups` SET `poolId`=100361,`scriptName`='toad_poacher',`minLevel`=34,`maxLevel`=57 WHERE `groupId`=100764;
UPDATE `server_battlenpc_groups` SET `poolId`=100361,`scriptName`='toad_poacher',`minLevel`=34,`maxLevel`=57 WHERE `groupId`=100767;
UPDATE `server_battlenpc_groups` SET `poolId`=100361,`scriptName`='toad_poacher',`minLevel`=34,`maxLevel`=57 WHERE `groupId`=100768;
UPDATE `server_battlenpc_groups` SET `poolId`=100362,`scriptName`='toxic_toad',`minLevel`=8,`maxLevel`=54 WHERE `groupId`=100782;
UPDATE `server_battlenpc_groups` SET `poolId`=100384,`scriptName`='wight_warrior',`minLevel`=30,`maxLevel`=49 WHERE `groupId`=100821;
DELETE FROM `server_battlenpc_pool_mods` WHERE `poolId` = 2300101;
DELETE FROM `server_battlenpc_pools` WHERE `poolId` = 2300101;
