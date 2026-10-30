# Com0u5: Burning Man

Script: [`Data/scripts/Quest/Com/Com0u5.lua`](../../../../scripts/Quest/Com/Com0u5.lua). Quest 111805, after Com0u4, level 25.

- Offer, Aubrey: `processEventAubreyStart` (1 = accepted). Repeat `processEvent000_2`.
- SEQ_000 push at the ferry docks west of Camp Horizon: join ask, the pirates
  (QuestDirectorCom0u501), then SEQ_001.
- SEQ_001 Thancred at the docks: `processEvent010`, then SEQ_002. Urianger: `processEvent010_2`.
- SEQ_002 Aubrey: `processEvent015`, then SEQ_003. Thancred / Urianger repeat `processEvent015_2` / `_3`.
- SEQ_003 push on the Royal Promenade: `processEvent025` (Raubahn's address), then SEQ_004. Aubrey
  repeats `processEvent020`.
- SEQ_004 Thancred after the speech: `processEvent030(0)`, rewards, complete.

Which handler belongs to which NPC follows the handler order and the journal. Not wired:
`processEventAubreyHint` and the dock crowd (`processEvent010_3.._6`, `020_2/_3`, `030_2.._6`).
Thancred and Urianger use unspawned classes that carry their names.
