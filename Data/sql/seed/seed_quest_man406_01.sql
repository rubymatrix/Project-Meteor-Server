-- Man406 "Futures Perfect" (110019): class fills for the Hall's two rebel warriors, the cave's children
-- and the field duty's imperials, and the field duty's battle pools. Hand-maintained.
-- Apply, then restart the Map Server (actor classes and pools load at boot).
-- Rollback: seed_quest_man406_99_rollback.sql. Idempotent: class fills only touch empty rows, pools are
-- deleted and re-inserted by id.
--
-- The Camp Revenant's Toll trigger is m3g_man406_toll (seed_msq_gridania_10_man3xx.sql); the cave's way
-- out reuses the airship trigger class 1090214 there. The Hall, the cave and the aftermath place their
-- actors from their content scripts, the field duty from its director; those posts are ported
-- calibrations, not retail data.

-- ---- (1) class fills -----------------------------------------------------------------------------
-- Spawning a class with an empty classPath crashes the client.

UPDATE gamedata_actor_class SET
    classPath = '/Chara/Npc/Populace/PopulaceStandard',
    propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id IN (
    1000481,  -- hardened rebel warrior (the Hall)
    1000483,  -- careworn rebel warrior (the Hall)
    1000957,  -- shuddering child (the cave)
    1000958,  -- cowering child
    1000959,  -- shivering child
    1000960,  -- cried-out child
    1000961   -- terrified child
) AND classPath = '';

-- The field duty's battle npcs take the property flags and conditions of a shipped imperial class.
UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2180011
  SET t.classPath = CASE t.id
        WHEN 2202401 THEN '/Chara/Npc/Monster/Mysticarmor/MysticarmorStandard'
        ELSE '/Chara/Npc/Monster/Empire/EmpireStandard'
      END,
      t.propertyFlags = s.propertyFlags,
      t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id IN (2207001, 2280003, 2280006, 2202401) AND t.classPath = '';

-- ---- (2) battle pools ----------------------------------------------------------------------------
-- Pool id = actor class id + 6000000. Auto-attack only; the juggernaut's Magitek Cannon is fired by the
-- director. Aggro 0: they only spawn inside the duty, which sends them.
DELETE FROM server_battlenpc_pools WHERE poolId IN (8207001, 8280003, 8280006, 8202401);
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8207001, 2207001, 'man406_imperial_centurion',   29,   3, 1, 4200, 1, 0, 0, 0, 0, 0),
  (8280003, 2280003, 'man406_imperial_hoplomachus', 29,   3, 1, 4200, 1, 0, 0, 0, 0, 0),
  (8280006, 2280006, 'man406_imperial_sagittarius', 29,   7, 1, 4200, 1, 0, 0, 0, 0, 0),
  (8202401, 2202401, 'man406_imperial_juggernaut',  1005, 0, 1, 4200, 1, 0, 0, 0, 0, 0);
