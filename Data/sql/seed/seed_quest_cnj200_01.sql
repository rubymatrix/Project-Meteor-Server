-- Cnj200 "Dendrological Duties" (110260): the coywolf pools of Telent's culling (QuestDirectorCnj20001).
-- Hand-maintained. Apply, then restart the Map Server (classes and pools load at boot). Rollback:
-- seed_quest_cnj200_99_rollback.sql. Idempotent: class fills only touch rows still empty; pools are
-- deleted and re-inserted by id. Soileine and Telent are already placed.
--
-- Battle class paths are the shipped Wolf class; pools copy the bloodthirsty
-- wolf pool (genus 3, TP moves 1003) Apply after
-- seed_bnpc_02_actor_classes.sql and seed_leve_02_mobs.sql (the class flags are copied from there).

UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2201407
  SET t.classPath = '/Chara/Npc/Monster/Wolf/WolfStandard', t.propertyFlags = s.propertyFlags,
      t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id IN (2201408, 2201409) AND t.classPath = '';
DELETE FROM server_battlenpc_pools WHERE poolId IN (8201408, 8201409);
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8201408, 2201408, 'cnj200_rabid_coywolf', 3, 0, 1, 4200, 1, 1, 0, 0, 0, 1003),
  (8201409, 2201409, 'cnj200_alpha_coywolf', 3, 0, 1, 4200, 1, 1, 0, 0, 0, 1003);
