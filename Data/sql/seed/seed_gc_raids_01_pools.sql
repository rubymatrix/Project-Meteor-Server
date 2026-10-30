-- Battle npc pools the Grand Company story raids spawn (Data/scripts/Content/InstanceRaid/StoryRaid.lua):
-- the stand-in bosses and adds of the Howling Eye, the Castrum Novum transmission tower and Rivenroad.
-- The Map Server skips actor classes with an empty classPath, so these get the family's standard class
-- where theirs is still empty. INSERT IGNORE keeps a genus or pool another seed already made.
-- Restart the map server after applying.

-- ---- genus: the Magitek Vanguard's family, with the table's default stats ----
INSERT IGNORE INTO server_battlenpc_genus (genusId, name, modelSize, speed, kindredId, kindredName, detection) VALUES
  (1006, 'Magitek-Armor', 1, 8, 4, 'Spoken', 1);

-- ---- class paths (only rows that are still empty) ----
-- Ixali Bravewing
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Monster/Birdman/BirdmanStandard', propertyFlags = IF(propertyFlags = 0, 23, propertyFlags), eventConditions = IFNULL(eventConditions, '{\n  "talkEventConditions": [],\n  "noticeEventConditions": [\n    {\n      "unknown1": 0,\n      "unknown2": 1,\n      "conditionName": "noticeEvent"\n    }\n  ],\n  "emoteEventConditions": [],\n  "pushWithCircleEventConditions": []\n}') WHERE id = 2106444 AND classPath = '';
-- Ixali Fearcaller
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Monster/Birdman/BirdmanStandard', propertyFlags = IF(propertyFlags = 0, 23, propertyFlags), eventConditions = IFNULL(eventConditions, '{\n  "talkEventConditions": [],\n  "noticeEventConditions": [\n    {\n      "unknown1": 0,\n      "unknown2": 1,\n      "conditionName": "noticeEvent"\n    }\n  ],\n  "emoteEventConditions": [],\n  "pushWithCircleEventConditions": []\n}') WHERE id = 2106414 AND classPath = '';
-- Ixali Fogcaller
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Monster/Birdman/BirdmanStandard', propertyFlags = IF(propertyFlags = 0, 23, propertyFlags), eventConditions = IFNULL(eventConditions, '{\n  "talkEventConditions": [],\n  "noticeEventConditions": [\n    {\n      "unknown1": 0,\n      "unknown2": 1,\n      "conditionName": "noticeEvent"\n    }\n  ],\n  "emoteEventConditions": [],\n  "pushWithCircleEventConditions": []\n}') WHERE id = 2106417 AND classPath = '';
-- Magitek Vanguard
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Monster/Killermachine/KillermachineLesserStandard', propertyFlags = IF(propertyFlags = 0, 23, propertyFlags), eventConditions = IFNULL(eventConditions, '{\n  "talkEventConditions": [],\n  "noticeEventConditions": [\n    {\n      "unknown1": 0,\n      "unknown2": 1,\n      "conditionName": "noticeEvent"\n    }\n  ],\n  "emoteEventConditions": [],\n  "pushWithCircleEventConditions": []\n}') WHERE id = 2109001 AND classPath = '';
-- Imperial Secutor
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Monster/Empire/EmpireStandard', propertyFlags = IF(propertyFlags = 0, 23, propertyFlags), eventConditions = IFNULL(eventConditions, '{\n  "talkEventConditions": [],\n  "noticeEventConditions": [\n    {\n      "unknown1": 0,\n      "unknown2": 1,\n      "conditionName": "noticeEvent"\n    }\n  ],\n  "emoteEventConditions": [],\n  "pushWithCircleEventConditions": []\n}') WHERE id = 2180009 AND classPath = '';
-- Imperial Signifer
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Monster/Empire/EmpireStandard', propertyFlags = IF(propertyFlags = 0, 23, propertyFlags), eventConditions = IFNULL(eventConditions, '{\n  "talkEventConditions": [],\n  "noticeEventConditions": [\n    {\n      "unknown1": 0,\n      "unknown2": 1,\n      "conditionName": "noticeEvent"\n    }\n  ],\n  "emoteEventConditions": [],\n  "pushWithCircleEventConditions": []\n}') WHERE id = 2180021 AND classPath = '';
-- Elite Secutor
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Monster/Empire/EmpireStandard', propertyFlags = IF(propertyFlags = 0, 23, propertyFlags), eventConditions = IFNULL(eventConditions, '{\n  "talkEventConditions": [],\n  "noticeEventConditions": [\n    {\n      "unknown1": 0,\n      "unknown2": 1,\n      "conditionName": "noticeEvent"\n    }\n  ],\n  "emoteEventConditions": [],\n  "pushWithCircleEventConditions": []\n}') WHERE id = 2180010 AND classPath = '';
-- Elite Signifer
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Monster/Empire/EmpireStandard', propertyFlags = IF(propertyFlags = 0, 23, propertyFlags), eventConditions = IFNULL(eventConditions, '{\n  "talkEventConditions": [],\n  "noticeEventConditions": [\n    {\n      "unknown1": 0,\n      "unknown2": 1,\n      "conditionName": "noticeEvent"\n    }\n  ],\n  "emoteEventConditions": [],\n  "pushWithCircleEventConditions": []\n}') WHERE id = 2180022 AND classPath = '';
-- Elite Laquearius
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Monster/Empire/EmpireStandard', propertyFlags = IF(propertyFlags = 0, 23, propertyFlags), eventConditions = IFNULL(eventConditions, '{\n  "talkEventConditions": [],\n  "noticeEventConditions": [\n    {\n      "unknown1": 0,\n      "unknown2": 1,\n      "conditionName": "noticeEvent"\n    }\n  ],\n  "emoteEventConditions": [],\n  "pushWithCircleEventConditions": []\n}') WHERE id = 2180014 AND classPath = '';

-- ---- pools ----
-- (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType)
INSERT IGNORE INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType) VALUES
  -- InstanceRaidLesserGaruda
  (100277, 2106444, 'ixali_bravewing',   24,   0, 1, 4200, 1, 1, 0, 0),
  (100278, 2106414, 'ixali_fearcaller',  24,   0, 1, 4200, 1, 1, 0, 0),
  (100280, 2106417, 'ixali_fogcaller',   24,   0, 1, 4200, 1, 1, 0, 0),
  -- InstanceRaidBeaconBattle
  (100309, 2109001, 'magitek_vanguard',  1006, 0, 1, 4200, 1, 1, 0, 0),
  (100273, 2180009, 'imperial_secutor',  29,   0, 1, 4200, 1, 1, 0, 0),
  (100274, 2180021, 'imperial_signifer', 29,   0, 1, 4200, 1, 1, 0, 0),
  -- InstanceRaidLesserWhiteGeneral
  (100238, 2180010, 'elite_secutor',     29,   0, 1, 4200, 1, 1, 0, 0),
  (100239, 2180022, 'elite_signifer',    29,   0, 1, 4200, 1, 1, 0, 0),
  (100236, 2180014, 'elite_laquearius',  29,   0, 1, 4200, 1, 1, 0, 0);
