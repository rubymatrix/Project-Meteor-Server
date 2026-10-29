-- Saved state for long-lived content (campaigns), as JSON written by the script runtime.
CREATE TABLE IF NOT EXISTS `server_content_state` (
  `name` varchar(96) NOT NULL,
  `data` longtext NOT NULL,
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
