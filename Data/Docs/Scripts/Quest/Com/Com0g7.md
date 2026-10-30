# Com0g7: Serenity, Purity, Sanctity

Script: [`Data/scripts/Quest/Com/Com0g7.lua`](../../../../scripts/Quest/Com/Com0g7.lua)

Serenity, Purity, Sanctity (Com0g7, 111607). Prereq: Com0g6 (`seed_msq_gridania_03_chain.sql`).
Level 25.

The official enlistment in the Order of the Twin Adder. No journal text, no steps.

`processEventFulkeStart` drops recruit status in the other companies, asks to enlist, plays the
join and then the company Q&A. It returns the last Q&A choice after joining, and 0 or nil when
declined. On joining: rank 11 (Serpent Private Third Class), rewards, complete. FulkeStart already
closes the company widget, so `processEventFulkeEnd` is not called.
