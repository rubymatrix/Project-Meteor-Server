-- Hand-maintained extra battle NPC spawn points (NOT generated - edit freely).
-- Apply after seed_bnpc_01..05 (needs their groups). Idempotent: deletes its own ID range first.
-- ID range: bnpcId 2000001-2099999 (the generator owns 1000001-1999999 and deletes that range).
-- positionY = 0 means height unknown -> snap to navmesh at load.

DELETE FROM `server_battlenpc_spawn_locations` WHERE `bnpcId` BETWEEN 2000001 AND 2099999;
INSERT INTO `server_battlenpc_spawn_locations` (`bnpcId`,`customDisplayName`,`groupId`,`positionX`,`positionY`,`positionZ`,`rotation`) VALUES
-- Star Marmot (group 100337), Central Shroud: denser lvl 2-3 cluster around retail spot (-510,-900)
(2000001,'',100337,-490.0,0.0,-880.0,0.5),
(2000002,'',100337,-530.0,0.0,-875.0,2.1),
(2000003,'',100337,-485.0,0.0,-915.0,-1.0),
(2000004,'',100337,-540.0,0.0,-910.0,-2.6),
(2000005,'',100337,-505.0,0.0,-860.0,1.4),
(2000006,'',100337,-470.0,0.0,-895.0,0.0),
(2000007,'',100337,-550.0,0.0,-890.0,3.0),
(2000008,'',100337,-515.0,0.0,-930.0,-1.8),
-- second ring (2026-10-02): 2 more around (-500,-895) (12 added, 10 removed 2026-10-03: too dense)
(2000009,'',100337,-452.0,0.0,-882.0,-3.1),
(2000010,'',100337,-482.0,0.0,-877.0,-1.4);
