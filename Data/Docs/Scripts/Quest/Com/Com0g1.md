# Com0g1: Breaking the Seals

Script: [`Data/scripts/Quest/Com/Com0g1.lua`](../../../../scripts/Quest/Com/Com0g1.lua). Quest 111601, Order of the Twin Adder's first quest, level 22.

- Offer, Fulke (Adders' Nest): `processEventStart` (1 = accepted); repeat `processEventStartAfter`.
- SEQ_000 Ailith at Quarrymill: `processEventAilithShiren`, then SEQ_001. Repeat `processEventAilithShirenFree`.
- SEQ_001 push SW of Quarrymill: join ask, `processEventUrianger(false)`, then the fight with
  Urianger's familiar (QuestDirectorCom0g101). Win: `processEventUriangerMore`, SEQ_002, back to Ailith.
- SEQ_002 Ailith: `processEventAilith` (she hands over her oath), then SEQ_003. Repeat `processEventAilithFree`.
- SEQ_003 Fulke: `processEventClear`, rewards, complete.

Journal: int2 = Ailith's Oath (SEQ_003), int3 = familiar beaten (SEQ_002 on).
