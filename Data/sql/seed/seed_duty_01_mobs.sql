-- MSQ duty combatants. Pools for DutyEncounter (Map Server/Actors/Director/DutyEncounter.cs);
-- spec and sources: Hand-maintained. Apply after seed_bnpc_* and
-- seed_leve_02_mobs.sql (two classPaths are copied from leve-seeded siblings), then restart the Map
-- Server (actor classes load at boot). Rollback: seed_duty_99_rollback.sql.
--
-- Pool ids = actor class id + 7000000 (9xxxxxx), outside every generated range (leve seed deletes
-- 2200000-2299999 on re-run). No group or spawn rows: duties spawn by pool through
-- Area.SpawnDutyBattleNpc. Levels come from the duty script.
--
-- Actor class -> name: client actorclass col 5 = displayName. Client class paths are real
-- 1.23b classes (tools/seed/data/client_monster_classes.txt); which id binds to which path is
-- inferred from the names (FighterAllyMarauderEmerick for Emerick etc.) except where marked
-- 1.23b has no FighterMarauderEmerick / FighterMarauderMelod: the duelists use the Ally classes.

-- ---- class paths (only rows that are still empty) --------------------------------------------
UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2290001
  SET t.classPath = CASE t.id
        WHEN 2290011 THEN '/Chara/Npc/Monster/Fighter/FighterAllyMarauderEmerick'  -- Emerick
        WHEN 2290012 THEN '/Chara/Npc/Monster/Fighter/FighterAllyMarauderMelod'    -- Merodaulyn
        WHEN 2290013 THEN '/Chara/Npc/Monster/Fighter/FighterAllyGuardedNiellefresne' -- Niellefresne, man2u0 (guarded)
        WHEN 2290014 THEN '/Chara/Npc/Monster/Fighter/FighterAllyGladiatorGreinfarr'  -- Greinfarr, man2u0
        WHEN 2290015 THEN '/Chara/Npc/Monster/Fighter/FighterAllyLancerStandard'   -- Grinnaux, man2g0 (Wood Wailer lancer)
        WHEN 2290016 THEN '/Chara/Npc/Monster/Fighter/FighterAllyArcherStandard'   -- Handeloup, man2g0 (Gods' Quiver archer)
        WHEN 2290017 THEN '/Chara/Npc/Monster/Fighter/FighterAllyArcherStandard'   -- T'kebbe, man2g0 (archer)
        WHEN 2205201 THEN '/Chara/Npc/Monster/Elemental/ElementalScenarioGridaniaLv20' -- spirit of the wood, man2g0
        WHEN 2280008 THEN '/Chara/Npc/Monster/Empire/EmpireLancerStandard'         -- Imperial Speculator, man206 sentinel
        WHEN 2280002 THEN '/Chara/Npc/Monster/Empire/EmpireGladiatorStandard'      -- Imperial Triarius, man206 sentinel
      END,
      t.propertyFlags = IF(t.propertyFlags = 0, s.propertyFlags, t.propertyFlags),
      t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id IN (2290011, 2290012, 2290013, 2290014, 2290015, 2290016, 2290017, 2205201, 2280008, 2280002)
    AND t.classPath = '';

-- A database seeded before the fix holds the class paths 1.23b does not have.
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Monster/Fighter/FighterAllyMarauderEmerick'
  WHERE id = 2290011 AND classPath = '/Chara/Npc/Monster/Fighter/FighterMarauderEmerick';
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Monster/Fighter/FighterAllyMarauderMelod'
  WHERE id = 2290012 AND classPath = '/Chara/Npc/Monster/Fighter/FighterMarauderMelod';

-- minemite (man2u0): the coblyn model class the leve seed gave its coblyn siblings
UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2202101
  SET t.classPath = s.classPath, t.propertyFlags = s.propertyFlags, t.eventConditions = s.eventConditions
  WHERE t.id = 2202106 AND t.classPath = '' AND s.classPath <> '';

-- ---- pools -------------------------------------------------------------------------------------
-- (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId)
-- Story NPCs: genus 29 Person, job by class (MRD 4, GLA 3, LNC 8, ARC 7, THM 22), auto-attack only (no
-- NPC weaponskill lists exist yet) like the upstream Yda/Papalymo pools 3 and 4.
-- Only this seed's pools: other seeds keep theirs in the same 9xxxxxx range (escorts, Ifrit).
DELETE FROM server_battlenpc_pools WHERE poolId IN (9290011, 9290012, 9290013, 9290014, 9290015, 9290016, 9290017, 9205201, 9202106, 9280008, 9280002, 9290001, 9290002, 9205403, 9290003, 9290004, 9203301);
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (9290011, 2290011, 'duty_emerick',          29,  4, 1, 4200, 1, 1, 0, 0, 0,    0),
  (9290012, 2290012, 'duty_merodaulyn',       29,  4, 1, 4200, 1, 1, 0, 0, 0,    0),
  (9290013, 2290013, 'duty_niellefresne',     29, 22, 1, 4200, 1, 0, 0, 0, 0,    0),
  (9290014, 2290014, 'duty_greinfarr',        29,  3, 1, 4200, 1, 0, 0, 0, 0,    0),
  (9290015, 2290015, 'duty_grinnaux',         29,  8, 1, 4200, 1, 0, 0, 0, 0,    0),
  (9290016, 2290016, 'duty_handeloup',        29,  7, 1, 4200, 1, 0, 0, 0, 0,    0),
  (9290017, 2290017, 'duty_tkebbe',           29,  7, 1, 4200, 1, 0, 0, 0, 0,    0),
  -- spirit of the wood: earth elemental leve pool 2204901 copied (genus 56, spells 3008, TP moves 1056)
  (9205201, 2205201, 'duty_spirit_of_the_wood', 56, 0, 1, 4200, 1, 1, 0, 0, 3008, 1056),
  -- minemite: coblyn leve pool 2202101 copied (genus 1002, TP moves 1102)
  (9202106, 2202106, 'duty_minemite',       1002,  0, 1, 4200, 1, 1, 0, 0, 0, 1102),
  (9280008, 2280008, 'duty_imperial_speculator', 29, 8, 1, 4200, 1, 1, 0, 0, 0, 0),
  (9280002, 2280002, 'duty_imperial_triarius',   29, 3, 1, 4200, 1, 1, 0, 0, 0, 0),
  -- Limsa opening, man0l0 SEQ_005 (content/SimpleContent30002.lua): Y'shtola (OpeningHealer, CNJ 23),
  -- Stahlmann (OpeningAttacker, MRD 4), jellyfish (genus 20 Jelly-fish, TP moves 1020)
  (9290001, 2290001, 'opening_yshtola',       29, 23, 1, 4200, 1, 0, 0, 0, 0,    0),
  (9290002, 2290002, 'opening_stahlmann',     29,  4, 1, 4200, 1, 0, 0, 0, 0,    0),
  (9205403, 2205403, 'opening_jellyfish',     20,  0, 1, 4200, 1, 0, 0, 0, 0, 1020),
  -- Ul'dah opening, man0u0 SEQ_005 (content/SimpleContent30079.lua): Niellefresne (OpeningHealer, THM 22),
  -- Thancred (OpeningAttacker, PGL 2), lesser goobbue (genus 6, TP moves 1006 as the goobbue bnpc pools)
  (9290003, 2290003, 'opening_niellefresne',  29, 22, 1, 4200, 1, 0, 0, 0, 0,    0),
  (9290004, 2290004, 'opening_thancred',      29,  2, 1, 4200, 1, 0, 0, 0, 0,    0),
  (9203301, 2203301, 'opening_goobbue',        6,  0, 1, 4200, 1, 0, 0, 0, 0, 1006);
