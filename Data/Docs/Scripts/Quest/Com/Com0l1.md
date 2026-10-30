# Com0l1: The Price of Integrity

Script: [`Data/scripts/Quest/Com/Com0l1.lua`](../../../../scripts/Quest/Com/Com0l1.lua)

Quest 111401, the Maelstrom's first quest and the Limsa twin of Com0g1. Level 22.

- Offer, Storm Lieutenant Guincum (Maelstrom Command): `processEventGUINCUMStart` (1 = accepted).
  Guincum repeats `processEvent_000`.
- SEQ_000 Walcher at Wineport: `processEvent_010`, then SEQ_001. Repeat `processEvent_010_1`.
- SEQ_001 Urianger east of Wineport: join ask, `processEvent_020(false)`, then the fight with his
  familiar (QuestDirectorCom0l101). Win: `processEvent_030(0)`, SEQ_002.
- SEQ_002 Walcher: `processEvent_040` (the signed agreement), then SEQ_003. Repeat
  `processEvent_040_1`.
- SEQ_003 Guincum: `processEvent_050`, rewards, complete.

Who runs which function, and the step order, follow the function names and Com0g1.

Journal: int2 = the agreement (SEQ_003), int3 = familiar beaten (SEQ_002 on). Markers use the
111500nn block; the 1114nn ones are filler.
