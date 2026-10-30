-- Body-part drop gates (2026-10-03). Run after seed_drop_01.
-- requiredPart 1..8: the row only drops if that part of the monster was incapacitated at least once
-- before it died (PartBreak.BrokenMask). 0 = always.
-- Evidence: part damage "is mainly for drops", e.g. horn break on billy goats / Ifrit [CLAIM JP forum
-- t-40616, 1.21]. Which items, and that the gate is all-or-nothing: DESIGN. Horns sit on the head (5)
-- for horned families in battle/parts.lua, reachable by Concussive Blow, Skull Sunder, Bloodletter,
-- Spirits Within [OFF 1.20/1.21].
ALTER TABLE `server_battlenpc_drop_list` ADD COLUMN IF NOT EXISTS `requiredPart` tinyint(3) unsigned NOT NULL DEFAULT 0;

UPDATE `server_battlenpc_drop_list` d JOIN `gamedata_items` i ON i.catalogID = d.itemId
SET d.requiredPart = 5
WHERE i.name IN ('Aldgoat Horn', 'Buffalo Horn', 'Ram Horn', 'Mossy Horn');
