# Com0u4: Arms Race

Script: [`Data/scripts/Quest/Com/Com0u4.lua`](../../../../scripts/Quest/Com/Com0u4.lua)

Arms Race (Com0u4, 111804). After Com0u3. Level 22.

- Offer, Aubrey: `processEventAUBREYStart` (1 = accepted). Repeat `processEvent_000`.
- SEQ_000 push at the Hellhounds' blockade of the eastern trade route by the Golden Bazaar: join
  ask, the fight (QuestDirectorCom0u401) -> SEQ_001.
- SEQ_001 Aubrey: `processEvent_010` -> SEQ_002. Repeat `processEvent_010_1`.
- SEQ_002 the three weapon makers in Limsa Lominsa, one contract each: 020 Woolvale Arms
  (Bamponcet), 030 Straight Edge Traders (Raaka Maaka), 040 Gigas Forge (C'ndanya); repeats
  `_020_1` / `_030_1` / `_040_1`. All three -> SEQ_003.
- SEQ_003 Aubrey: `processEvent_050(0)` (plays the cutscene), rewards, complete.

Which line goes to which maker follows each line's speech.
Journal: int2..int4 = the three contracts, held SEQ_002+.
