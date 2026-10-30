# Com0l7: Till Sea Swallows All

Script: [`Data/scripts/Quest/Com/Com0l7.lua`](../../../../scripts/Quest/Com/Com0l7.lua)

Till Sea Swallows All (Com0l7, 111407). Prereq: Com0l6 (seed_msq_limsa_20_com0l.sql). Level 25.

The official enlistment in the Maelstrom, twin of Com0g7. No journal text, no steps.
processEventGuincamStart shows the company widget, the join ask, the join and the company Q&A; anything
but 0 or nil returned counts as joined. On joining: rank 11 (Storm Private Third Class), rewards (1000 Storm
Seals), complete. GuincamStart already closes the widget, so processEventGuincamEnd is not called.
