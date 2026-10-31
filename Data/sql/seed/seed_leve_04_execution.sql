-- Battle leve execution: rewards held for the next aetheryte talk when nobody touched the warp node,
-- faction credits (cap 1000), and the GuildleveSearchPoint class on an unused leve-object id with the
-- same event conditions as GuildleveBonusTreasureBox. Apply after seed_leve_01..03. Re-runnable.
-- Rollback: seed_leve_98_execution_rollback.sql.

CREATE TABLE IF NOT EXISTS `characters_leve_pending_rewards` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `characterId` int(10) unsigned NOT NULL,
  `guildleveId` int(10) unsigned NOT NULL,
  `gil` int(10) unsigned NOT NULL DEFAULT 0,
  `item` int(10) unsigned NOT NULL DEFAULT 0,
  `quantity` int(10) unsigned NOT NULL DEFAULT 0,
  `completedAt` int(10) unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `characterId` (`characterId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `characters_leve_faction` (
  `characterId` int(10) unsigned NOT NULL,
  `faction` tinyint(3) unsigned NOT NULL,
  `credits` smallint(5) unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`characterId`, `faction`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id = 1200161
  SET t.classPath = '/Chara/Npc/Object/GuildleveSearchPoint', t.propertyFlags = s.propertyFlags, t.eventConditions = s.eventConditions
  WHERE t.id = 1200168 AND (t.classPath = '' OR t.classPath = '/Chara/Npc/Object/GuildleveSearchPoint');

-- The Nanawa Mines and Mun-Tuy Cellars aetheryte gates have no zone, so their battle leves could
-- not start. Zones match the aetheryte teleport table and these rows' positions.
UPDATE server_eventnpc_spawn_locations SET zoneId = 176 WHERE actorClassId = 1280052 AND zoneId = 0;
UPDATE server_eventnpc_spawn_locations SET zoneId = 157 WHERE actorClassId = 1280082 AND zoneId = 0;
