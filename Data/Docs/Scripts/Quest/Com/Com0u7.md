# Com0u7: By Fire Reborn

Script: [`Data/scripts/Quest/Com/Com0u7.lua`](../../../../scripts/Quest/Com/Com0u7.lua)

By Fire Reborn (Com0u7, 111807). Prereq: Com0u6 (`seed_msq_uldah_20_com0u.sql`). Level 25.

The official enlistment in the Immortal Flames, Ul'dah twin of Com0g7. No journal steps.

`processEventAubreyStart` drops recruit status in the other companies, asks, plays the join and the
company Q&A; anything but 0 or nil returned counts as joined. On joining: rank 11 (Flame Private
Third Class), rewards, complete. `processEventAubreyEnd` is not called. Aubrey's later pointer to
Flame Lieutenant Lannis is his own guide talk, not a quest step.
