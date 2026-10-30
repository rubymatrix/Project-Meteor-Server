# Com0l5: An Officer and a Wise Man

Script: [`Data/scripts/Quest/Com/Com0l5.lua`](../../../../scripts/Quest/Com/Com0l5.lua)

An Officer and a Wise Man (Com0l5, 111405). After Com0l4. Level 25.

- Offer, Guincum: processEventGUINCUMStart (1 = accepted). Guincum repeats processEvent_000.
- SEQ_000 push in the clearing SW of Camp Bloodshore: join ask, the raiders (QuestDirectorCom0l501).
  Win: processEvent_010 (Merlwyb and Urianger arrive), SEQ_001, back to the spot.
- SEQ_001 Merlwyb and Urianger: processEvent_005_merlwyb / processEvent_005_uri once each, then their
  _01 repeats; both heard -> SEQ_002.
- SEQ_002 Zanthael at the Admiral's Lift: processEvent_elevator_nq1(0); 1 plays the lift and the
  ceremony on the Bridge, then the hall, SEQ_003.
- SEQ_003 Y'shtola in the hall: processEvent_015(0), rewards. The hall's way out (processEventExit)
  rides the lift down on 1 (processEvent_elevator_nq2).

The Bridge is not a server zone; it is staged in the stateroom private area. Not wired:
processEvent_hint, the hall's pirates and Barracudas (processEvent_015_01-04).
