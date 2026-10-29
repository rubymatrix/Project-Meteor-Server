-- Man0u0 "Flowers for All": the skirmish pools SimpleContent30079 spawns (Niellefresne, Thancred and
-- the escaped goobbue). Restart the map server after applying.
DELETE FROM server_battlenpc_pools WHERE poolId IN (8290003, 8290004, 8203301);
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8290003, 2290003, 'man0u0_niellefresne',    29, 23, 1, 4200, 1, 0, 0, 0, 0, 0),
  (8290004, 2290004, 'man0u0_thancred',        29,  2, 1, 4200, 1, 0, 0, 0, 0, 0),
  (8203301, 2203301, 'man0u0_escaped_goobbue',  6,  0, 1, 4200, 1, 0, 0, 0, 0, 0);
