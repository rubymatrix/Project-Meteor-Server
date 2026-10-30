-- Man402 "Of Men They Sing" (110018): the wounded scout's class and the search duty's bloodhound pool.
-- Hand-maintained. Apply, then restart the Map Server (actor classes and pools load at boot).
-- Rollback: seed_quest_man402_99_rollback.sql. Idempotent: class fills only touch empty rows, the pool is
-- deleted and re-inserted by id.
--
-- The Camp Nine Ivies trigger is m3g_man402_nineivies (seed_msq_gridania_10_man3xx.sql); the companion,
-- the scout and the hounds are placed by the duty's content and director scripts. Their posts are ported
-- calibrations, not retail data.

-- ---- (1) class fills -----------------------------------------------------------------------------
-- Spawning a class with an empty classPath crashes the client.

UPDATE gamedata_actor_class SET
    classPath = '/Chara/Npc/Populace/PopulaceStandard',
    propertyFlags = 19,
    eventConditions = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE id = 1001239 AND classPath = '';  -- wounded rebel warrior (the scout)

-- The bloodhound takes the property flags and conditions of a shipped battle class.
UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 2180011
  SET t.classPath = '/Chara/Npc/Monster/Wolf/HyaenaScenarioMainLv42',
      t.propertyFlags = s.propertyFlags,
      t.eventConditions = IFNULL(t.eventConditions, s.eventConditions)
  WHERE t.id = 2201417 AND t.classPath = '';

-- ---- (2) battle pool -----------------------------------------------------------------------------
-- Pool id = actor class id + 6000000. Auto-attack only; aggro 0: the hounds only spawn inside the duty,
-- which sends them.
DELETE FROM server_battlenpc_pools WHERE poolId = 8201417;
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8201417, 2201417, 'man402_bloodhound', 3, 0, 1, 4200, 1, 0, 0, 0, 0, 0);
