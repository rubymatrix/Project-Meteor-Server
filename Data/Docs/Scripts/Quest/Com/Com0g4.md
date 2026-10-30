# Com0g4: The Mail Must Get Through

Script: [`Data/scripts/Quest/Com/Com0g4.lua`](../../../../scripts/Quest/Com/Com0g4.lua)

The Mail Must Get Through (Com0g4, 111604). After Com0g1. Level 22.

- Offer, Fulke: processEventStart (1 = accepted).
- SEQ_000 push NW of the city (North Shroud): join ask, then the imperials (QuestDirectorCom0g401).
  Win: the letter is on a corpse (int2), SEQ_001, back to the public spot. Fulke repeats
  processEventStartAfter.
- SEQ_001 Fulke: processEventFulke -> SEQ_002. SEQ_002 Fulke repeats processEventFulkeFree.
- SEQ_002 Radulf at Little Ala Mhigo: processEventRadulf, the letter goes, the designs come (int3)
  -> SEQ_003. Repeat processEventRadulfFree.
- SEQ_003 Fulke: processEventClear(0, 0), rewards.
