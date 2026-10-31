-- --------------------------------------------------------
-- Host:                         127.0.0.1
-- Server version:               5.6.17 - MySQL Community Server (GPL)
-- Server OS:                    Win64
-- HeidiSQL Version:             10.1.0.5464
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;


-- Dumping database structure for ffxiv_server
CREATE DATABASE IF NOT EXISTS `ffxiv_server` /*!40100 DEFAULT CHARACTER SET latin1 */;
USE `ffxiv_server`;

-- Dumping structure for table ffxiv_server.characters_quest_guildleve_local
CREATE TABLE IF NOT EXISTS `characters_quest_guildleve_local` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `characterId` int(10) unsigned NOT NULL,
  `slot` smallint(5) unsigned NOT NULL,
  `questId` int(10) unsigned NOT NULL,
  `questData` longtext,
  `abandoned` tinyint(1) unsigned DEFAULT '0',
  `completed` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Data exporting was unselected.
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IF(@OLD_FOREIGN_KEY_CHECKS IS NULL, 1, @OLD_FOREIGN_KEY_CHECKS) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
