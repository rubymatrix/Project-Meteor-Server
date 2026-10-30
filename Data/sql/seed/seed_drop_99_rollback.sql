-- Removes everything seed_drop_01_lists.sql added.
DELETE FROM `server_battlenpc_drop_list` WHERE `dropListId` BETWEEN 100001 AND 199999;
UPDATE `server_battlenpc_groups` SET `dropListId` = 0 WHERE `groupId` BETWEEN 100001 AND 199999;
