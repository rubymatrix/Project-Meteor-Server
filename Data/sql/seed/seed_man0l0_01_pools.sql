-- Man0l0 "Shapeless Melody": the deck battle pools SimpleContent30002 spawns (Y'shtola, Sthalmann and
-- the frenzied aurelia). Restart the map server after applying.
DELETE FROM server_battlenpc_pools WHERE poolId IN (8290001, 8290002, 8205403);
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8290001, 2290001, 'man0l0_yshtola',          29, 23, 1, 4200, 1, 0, 0, 0, 0, 0),
  (8290002, 2290002, 'man0l0_sthalmann',        29,  2, 1, 4200, 1, 0, 0, 0, 0, 0),
  (8205403, 2205403, 'man0l0_frenzied_aurelia', 20,  0, 1, 4200, 1, 0, 0, 0, 0, 0);
