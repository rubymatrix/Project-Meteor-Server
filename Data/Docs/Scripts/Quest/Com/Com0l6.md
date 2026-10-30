# Com0l6: Ceruleum Shock

Script: [`Data/scripts/Quest/Com/Com0l6.lua`](../../../../scripts/Quest/Com/Com0l6.lua)

Ceruleum Shock (Com0l6, 111406). After Com0l5. Level 25.

- Offer, Guincum: processEventGUINCUMStart(0, 0, 0) (1 = accepted). Guincum repeats processEvent_000.
- SEQ_000 push at the Vesper Bay ferry docks: join ask, the Immortal Flames (QuestDirectorCom0l601).
  Win: SEQ_001, back to the spot.
- SEQ_001 Storm Private Aisborgsyn: processEvent_005 -> SEQ_002. Repeat processEvent_005_1.
- SEQ_002 push at the ceruleum fields, northern Thanalan: processEvent_010 (Cid appears) -> SEQ_003.
- SEQ_003 Cid at the Limsa Lominsa Landing: processEvent_015(0, 0) (the main path), rewards.

Not wired: processEventGUINCUMHint, the dock bystanders processEvent_005_2-4, the landing staff
processEvent_015_1-7 and the landing lift processEvent_elevator_nq1/nq2.
