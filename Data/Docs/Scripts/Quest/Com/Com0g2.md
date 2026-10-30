# Com0g2: Why Did It Have to Be Snakes

Script: [`Data/scripts/Quest/Com/Com0g2.lua`](../../../../scripts/Quest/Com/Com0g2.lua)

Quest 111602, after Com0g1 (seed_msq_gridania_21_com0g_side.sql), level 22.

- One talk with Fulke accepts and turns the quest in. No cutscenes, no journal steps.
- `processEventFulkeStart` asks (1 = yes); on yes it runs the seal tutorial.
- `processEventFulkeEnd` only counts the company widget up to 250. The seals themselves are the
  completion reward.
