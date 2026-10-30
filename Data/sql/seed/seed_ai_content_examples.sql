-- Battle npc pools for the example content (Data/scripts/content/*). Models are stand-ins
-- with class paths the client loads; swap the actor class once the real one (kobold,
-- caravan chocobo, supply cache) has a class path.
-- Restart the map server after applying.

-- (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType)
DELETE FROM server_battlenpc_pools WHERE poolId BETWEEN 9300001 AND 9300099;
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType) VALUES
  -- CaravanGuard
  (9300001, 2102001, 'caravan_chocobo',        42, 0, 1, 4200, 1, 0, 0, 0),
  (9300002, 2110308, 'caravan_raider',         26, 0, 1, 4200, 1, 1, 0, 0),
  -- HamletDefense
  (9300003, 2106501, 'hamlet_raider',          27, 0, 1, 4200, 1, 1, 0, 0),
  (9300004, 2102501, 'hamlet_raider_leader',   27, 0, 1, 4200, 1, 1, 0, 0),
  (9300005, 2290001, 'hamlet_guard',           29, 0, 1, 4200, 1, 0, 0, 0),
  (9300006, 2100901, 'hamlet_supply_cache',    29, 0, 1, 4200, 1, 0, 0, 0),
  -- RaidRoc0Dungeon01 (Dzemael Darkhold)
  (9300010, 2104102, 'darkhold_bat',           43, 0, 1, 4200, 1, 1, 0, 0),
  (9300011, 2101608, 'darkhold_bomb',          64, 0, 1, 4200, 1, 1, 0, 0),
  (9300012, 2110308, 'darkhold_beastmaster',   26, 0, 1, 4200, 1, 1, 0, 0),
  (9300013, 2101424, 'darkhold_hound',          3, 0, 1, 4200, 1, 1, 0, 0),
  (9300014, 2102501, 'darkhold_warden',        60, 0, 1, 4200, 1, 1, 0, 0),
  -- InstanceRaid*Ifrit
  (9300020, 2207303, 'ifrit',                  54, 0, 1, 4200, 1, 1, 0, 0),
  (9300021, 2201601, 'infernal_nail',          64, 0, 1, 4200, 1, 0, 0, 0);
