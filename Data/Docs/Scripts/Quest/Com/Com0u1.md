# Com0u1: Career Opportunities

Script: [`Data/scripts/Quest/Com/Com0u1.lua`](../../../../scripts/Quest/Com/Com0u1.lua)

Career Opportunities (Com0u1, 111801). Immortal Flames, first quest; the Ul'dah twin of Com0g1.
Level 22.

- Offer, Flame Lieutenant Aubrey (Hall of Flames): `processEventAUBREYStart` (1 = accepted).
  Repeat `processEvent_000`.
- SEQ_000 Taylor at the Western Thanalan ferry docks: `processEvent_010` -> SEQ_001. Repeat
  `processEvent_010_1`.
- SEQ_001 Urianger SE of the docks: join ask, `processEvent_020(false)`, then the fight with his
  familiar (QuestDirectorCom0u101). Win: `processEvent_030(0)` (Thancred arrives) -> SEQ_002.
- SEQ_002 Taylor: `processEvent_040` (his letter for Aubrey) -> SEQ_003. Repeat
  `processEvent_040_1`.
- SEQ_003 Aubrey: `processEvent_050`, rewards, complete.

Journal: int2 = Taylor's Letter (SEQ_003), int3 = familiar beaten (SEQ_002+).
