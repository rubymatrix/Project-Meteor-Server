# Com0g6: Appetite for Destruction

Script: [`Data/scripts/Quest/Com/Com0g6.lua`](../../../../scripts/Quest/Com/Com0g6.lua)

Quest 111606, after Com0g5, level 25.

- Offer, Fulke: `processEventStart` (1 = accepted); repeat `processEventStartAfter`.
- SEQ_000 Lewin at Stillglade Fane: `processEventLewin(0, 0)` (the named greeting), then SEQ_001.
- SEQ_001 push in the clearing west of Nine Ivies (East Shroud): join ask, the beasts
  (QuestDirectorCom0g601). Win: `processEventNq` (Cid finishes the beasts), SEQ_002, back to the
  clearing.
- SEQ_002 Cid at the Fane: `processEventClear(2)`, rewards.
- Ambient at the Fane: Lewin (`processEventLewinAfter` from SEQ_001), Concessa, Kinborow (their
  After versions at SEQ_002). O-App-Pesi, Swethyna, Norbertillon and Suzari Sorezari are not
  spawned for this quest.

Not done: Fulke's hint (`processEventHint`) is not wired.
