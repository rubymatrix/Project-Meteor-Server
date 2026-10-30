# Com0g5: Their Finest Hour

Script: [`Data/scripts/Quest/Com/Com0g5.lua`](../../../../scripts/Quest/Com/Com0g5.lua). Quest 111605, after Com0g4, level 25.

- Offer, Fulke: `processEventFulkeStart` (1 = accepted; he hands over the invitation, int2).
- SEQ_000 push at Mih Khetto's Amphitheatre: `processEvent005`, then beside Papalymo, SEQ_001.
  Fulke repeats `followEvent005`.
- SEQ_001 Papalymo: `processEvent010` + `processEvent011` (how to use a quest item) +
  `processEvent012`, the Earthbreaker (int3), then SEQ_002.
- SEQ_002 push at the Rootslake (South Shroud): join ask, the clay golem (QuestDirectorCom0g501).
  Win: SEQ_003, back to the lakeside by Urianger. Papalymo repeats `processEvent020(0..2)`.
- SEQ_003 Urianger: `processEvent030(0)` (0 sends you to the other nations), rewards.

Not done: the Earthbreaker can't be used from the menu yet; the golem is beatable without it. The
amphitheatre crowd (`processEvent010_1..5`) and Fulke's hint (`processEventFulkeHint`) are not wired.
