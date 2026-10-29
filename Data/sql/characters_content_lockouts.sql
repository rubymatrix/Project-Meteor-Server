-- Per-character content lockouts: until is a unix time.
CREATE TABLE IF NOT EXISTS `characters_content_lockouts` (
  `characterId` int(10) unsigned NOT NULL,
  `name` varchar(96) NOT NULL,
  `until` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`characterId`, `name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
