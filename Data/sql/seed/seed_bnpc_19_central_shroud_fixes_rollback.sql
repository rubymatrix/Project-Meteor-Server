-- Rollback for seed_bnpc_10_central_shroud_fixes.sql: removes the Star Marmot groups and puts back the
-- removed groups, spawn points and level bands as they were in seed_bnpc_04/05/08. Idempotent.
DELETE FROM `server_battlenpc_spawn_locations` WHERE `bnpcId` BETWEEN 2300001 AND 2300006;
DELETE FROM `server_battlenpc_groups` WHERE `groupId` IN (2300001, 2300002);
INSERT IGNORE INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,`privateAreaName`,`privateAreaLevel`,`zoneId`) VALUES
(100275,100134,'sabotender',68,68,90,0,0,0,0,0,0,0,'',0,150),
(100279,100135,'sabotender_del_sol',75,78,90,0,0,0,0,0,0,0,'',0,150),
(100280,100135,'sabotender_del_sol',75,78,90,0,0,0,0,0,0,0,'',0,150),
(100386,100191,'retail_piranhasandystandard',30,39,90,0,0,0,0,0,0,0,'',0,150),
(100388,100193,'retail_yakfemalestandard',30,39,90,0,0,0,0,0,0,0,'',0,150),
(100389,100194,'retail_yakmalestandard',30,39,90,0,0,0,0,0,0,0,'',0,150),
(100597,100301,'lightning_elemental',30,39,90,0,0,0,0,0,0,0,'',0,150),
(100598,100302,'lindwurm',31,74,90,0,0,0,0,0,0,0,'',0,150),
(100621,100313,'morbol',63,74,90,0,0,0,0,0,0,0,'',0,150),
(100813,100379,'water_elemental',30,42,90,0,0,0,0,0,0,0,'',0,150),
(100825,100387,'wild_hog',40,49,90,0,0,0,0,0,0,0,'',0,150);
INSERT IGNORE INTO `server_battlenpc_spawn_locations` (`bnpcId`,`customDisplayName`,`groupId`,`positionX`,`positionY`,`positionZ`,`rotation`) VALUES
(1001557,'',100275,268,0,-540,1.737),
(1001558,'',100275,256,0,-533.1,-0.625),
(1001559,'',100275,256,0,-546.9,1.442),
(1001583,'',100279,568,0,-740,2.645),
(1001584,'',100279,556,0,-733.1,3.094),
(1001585,'',100279,556,0,-746.9,-2.941),
(1001586,'',100280,468,0,-440,-0.65),
(1001587,'',100280,456,0,-433.1,1.228),
(1001588,'',100280,456,0,-446.9,0.438),
(1002098,'',100388,-10,0,-570,0.397),
(1003361,'',100597,168,0,-940,1.745),
(1003362,'',100597,156,0,-933.1,1.45),
(1003363,'',100597,156,0,-946.9,1.452),
(1003364,'',100598,368,0,-40,2.003),
(1003365,'',100598,356,0,-33.1,-1.076),
(1003366,'',100598,356,0,-46.9,-0.301),
(1003500,'',100621,768,0,-1140,-2.582),
(1003501,'',100621,756,0,-1133.1,-1.932),
(1003502,'',100621,756,0,-1146.9,3.051),
(1004497,'',100813,68,0,-840,-1.91),
(1004498,'',100813,56,0,-833.1,-0.851),
(1004499,'',100813,56,0,-846.9,-0.407),
(1004561,'',100825,-332,0,-840,1.818),
(1004562,'',100825,-344,0,-833.1,-1.083),
(1004563,'',100825,-344,0,-846.9,-1.975),
(2100059,'',100386,2.064,4.713,-419.307,0.5612),
(2100065,'',100386,141.027,16.727,-432.133,-0.0788),
(2100071,'',100389,56.387,16.406,-529.096,-0.3116),
(2100075,'',100388,35.114,17.013,-512.333,-1.2308);
INSERT IGNORE INTO `server_battlenpc_spawn_locations` (`bnpcId`,`customDisplayName`,`groupId`,`positionX`,`positionY`,`positionZ`,`rotation`) VALUES
(2100063,'',2100013,138.903,16.545,-520.616,2.8808),
(2100064,'',2100014,194.002,16.793,-419.247,-3.0256),
(2100074,'',2100013,139.308,16.803,-527.039,0.6077);
UPDATE `server_battlenpc_groups` SET `poolId`=100068,`scriptName`='goblin_freesword',`minLevel`=18,`maxLevel`=63 WHERE `groupId`=100145;
UPDATE `server_battlenpc_groups` SET `poolId`=100071,`scriptName`='goblin_thug',`minLevel`=18,`maxLevel`=39 WHERE `groupId`=100157;
UPDATE `server_battlenpc_groups` SET `poolId`=100080,`scriptName`='imptrap',`minLevel`=14,`maxLevel`=59 WHERE `groupId`=100172;
UPDATE `server_battlenpc_groups` SET `poolId`=100266,`scriptName`='honeybee_swarm',`minLevel`=5,`maxLevel`=45 WHERE `groupId`=100519;
UPDATE `server_battlenpc_groups` SET `poolId`=100362,`scriptName`='toxic_toad',`minLevel`=8,`maxLevel`=54 WHERE `groupId`=100769;
UPDATE `server_battlenpc_groups` SET `poolId`=100362,`scriptName`='toxic_toad',`minLevel`=8,`maxLevel`=54 WHERE `groupId`=100770;
