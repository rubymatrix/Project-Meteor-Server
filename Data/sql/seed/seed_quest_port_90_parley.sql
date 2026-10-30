-- Parley targets of the ported quests. Apply after the seed_quest_* files (they fill these classes).
-- Idempotent. Rollback: seed_quest_port_99_rollback.sql. Restart the Map Server afterwards.
--
-- The client offers Parley on an npc only when its charaWork.property[0] and [3] are set
-- (DesktopWidget.canTargetNegotiation via isNegotiatable); the server sets property bits from the
-- class's propertyFlags. Whether a Parley is open is the quest's answer (questflow.lua canParley).
-- 1700010 coach driver (Min300), 1000292 thickset tailor (Cul300),
-- 1001095 loyal Ixal and 1001098 able-bodied Amalj'aa (Man300).
UPDATE gamedata_actor_class SET propertyFlags = propertyFlags | 9
WHERE id IN (1700010, 1000292, 1001095, 1001098) AND classPath <> '';
