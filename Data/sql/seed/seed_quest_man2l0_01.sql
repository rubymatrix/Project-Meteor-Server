-- Man2l0 "Never the Twain Shall Meet" (110004): the chain prerequisite. Apply, then restart the Map
-- Server (quest prerequisites load at boot). Rollback: seed_quest_man2l0_99_rollback.sql. Idempotent.
--
-- Spawns, triggers and private areas are already in server_eventnpc_spawn_locations.sql /
-- server_zones_privateareas.sql; the duel pools (Emerick 9290011, Merodaulyn 9290012) are
-- seed_duty_01_mobs.sql's.

-- Man2l0 needs Man1l0 (otherwise it is offered on level alone).
UPDATE gamedata_quests SET prerequisite = 110003 WHERE id = 110004 AND prerequisite = 0;
