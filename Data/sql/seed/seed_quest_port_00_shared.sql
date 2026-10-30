-- Shared rows for the story/class quest port, applied before every seed_quest_* file (apply order:
-- apply_quest_port.txt). Idempotent. Apply, then restart the Map Server (classes, gates, pools and status
-- effects load at boot). Rollback: seed_quest_port_99_rollback.sql.

-- ---- quest-gated spawns: a sequence range per owning quest ---------------------------------------
-- One class can stand at several spots for one quest (Min306's Nenekko, Gla306's Yoyobina): the range
-- picks the spot for the step. The default range admits every sequence.
CREATE TABLE IF NOT EXISTS server_eventnpc_quest_gated (
    zoneId      int(10) unsigned     NOT NULL,
    uniqueId    varchar(32)          NOT NULL,
    questId     int(10) unsigned     NOT NULL,
    minSequence smallint(5) unsigned NOT NULL DEFAULT 0,
    maxSequence smallint(5) unsigned NOT NULL DEFAULT 65535,
    PRIMARY KEY (zoneId, uniqueId, questId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
ALTER TABLE server_eventnpc_quest_gated
    ADD COLUMN IF NOT EXISTS minSequence smallint(5) unsigned NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS maxSequence smallint(5) unsigned NOT NULL DEFAULT 65535;

-- Per-spawn event conditions (Fsh300's Barrel points carry their own emotes).
CREATE TABLE IF NOT EXISTS server_eventnpc_spawn_eventconditions (
    zoneId          int(10) unsigned NOT NULL,
    uniqueId        varchar(32)      NOT NULL,
    eventConditions text             NOT NULL,
    PRIMARY KEY (zoneId, uniqueId)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- ---- the shared objective push trigger -----------------------------------------------------------
-- 1090008 is a client push-trigger class with no spawn of its own: PopulaceStandard, property flags 1,
-- push radius 6, the invisible trigger appearance. The class quests' triggers all use it; the server
-- routes a push to the quest that owns the spawn (Player.GetQuestsForNpcEvent). Only fills a blank row.
UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Populace/PopulaceStandard', propertyFlags = 1,
    eventConditions = '{"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"pushWithCircleEventConditions":[{"isEnabled":"false","radius":"6.0","outwards":"false","silent":"false","conditionName":"pushDefault"}]}'
WHERE id = 1090008 AND classPath = '';

-- ---- the Path companion as a duty ally (DutyEncounter.SpawnCompanionAlly) ------------------------
-- Stats only: the spawn takes the player's companion class (1070000 + skin) and name. Pool id = class
-- 1070001 + 7000000 (duty rule). Person genus, gladiator job, auto-attack only.
DELETE FROM server_battlenpc_pools WHERE poolId = 8070001;
INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) VALUES
  (8070001, 1070001, 'duty_path_companion', 29, 3, 1, 4200, 1, 0, 0, 0, 0, 0);

-- ---- status effects the quests apply --------------------------------------------------------------
-- Man206: Intact Podling Toting (statuseffectids.lua). Lost on death and logout: the quest
-- re-checks its own flag.
INSERT IGNORE INTO server_statuseffects (id, name, flags, overwrite, tickMs, hidden, silentOnGain, silentOnLoss, statusGainTextId, statusLossTextId)
VALUES (223993, 'intact_podling_toting', 17, 1, 0, 0, 0, 0, 30328, 30331);
