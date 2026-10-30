-- Gla200 "All Bark and No Bite" (110080): event-NPC class fills, quest-gated spawns and battle pools the quest
-- script and its duty director use. Hand-maintained. Apply, then restart the Map Server (classes, spawns and
-- pools load at boot). Rollback: seed_quest_gla200_99_rollback.sql. Idempotent: class fills only touch rows
-- still empty; spawns, gates and pools are deleted and re-inserted by the 'gla200_' prefix / pool id.
--
-- Sources: spawn positions and fight placements are ported scene placements of mixed provenance, several
-- invented (round offsets, rotation 0); none is retail-confirmed. Battle class paths and jobs follow the
-- shipped Fighter/monster classes; pools are auto-attack only.

-- ---- (3) duty battle npcs -------------------------------------------------------------------------
-- Pool id = actor class id + 6000000. Class flags and conditions come from the Tourney Gladiator (2280157).
UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2280157
  SET t.classPath = '/Chara/Npc/Monster/Fighter/FighterEnemyGladiatorStandard', t.propertyFlags = s.propertyFlags,
      t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id = 2289006 AND t.classPath = ''; -- the Ala Mhigan challenger
DELETE FROM server_battlenpc_pools WHERE poolId IN (8289006);
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8289006, 2289006, 'gla200_ala_mhigan_challenger', 29, 3, 1, 4200, 1, 0, 0, 0, 0, 0);
