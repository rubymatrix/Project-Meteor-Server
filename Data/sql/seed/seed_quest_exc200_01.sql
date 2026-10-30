-- Exc200 "Bloody Baptism" (110100): battle pools and class fills for the Swiftperch Tower duty
-- (directors/Quest/QuestDirectorExc20001.lua). Nunuba and Waekbyrt already stand in Limsa Lominsa (230).
-- Apply, then restart the Map Server (actor classes and pools load at boot).
-- Rollback: seed_quest_exc200_99_rollback.sql. Idempotent.
--
-- Class paths are 1.23b client classes: the tower lemming takes the common LemmingStandard, the Lord of
-- Swiftperch his own LemmingScenarioMrdLv20; flags and conditions come from the wharf rat (2104001).
-- Pool id = actor class id + 6000000. Auto-attack only; genus 12 (rodent) as the wharf rat.

UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2104001
  SET t.classPath = CASE t.id
        WHEN 2204003 THEN '/Chara/Npc/Monster/Lemming/LemmingStandard'
        WHEN 2204004 THEN '/Chara/Npc/Monster/Lemming/LemmingScenarioMrdLv20'
      END,
      t.propertyFlags = s.propertyFlags,
      t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id IN (2204003, 2204004) AND t.classPath = '';

DELETE FROM server_battlenpc_pools WHERE poolId IN (8204003, 8204004);
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8204003, 2204003, 'exc200_tower_lemming',      12, 0, 1, 4200, 1, 1, 0, 0, 0, 0),
  (8204004, 2204004, 'exc200_lord_of_swiftperch', 12, 0, 1, 4200, 1, 1, 0, 0, 0, 0);
