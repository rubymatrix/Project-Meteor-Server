# Com0u6: Know Your Enemy

Script: [`Data/scripts/Quest/Com/Com0u6.lua`](../../../../scripts/Quest/Com/Com0u6.lua)

Know Your Enemy (Com0u6, 111806). After Com0u5. Level 25.

- Offer, Aubrey: processEventAUBREYStart (1 = accepted). Repeat processEvent_000.
- SEQ_000 the airship landing, the Ironworks staff: E'bolaff processEvent_005 ("who told you that
  name?") -> SEQ_001.
- SEQ_001 push SW of Camp Horizon: join ask, the fight with Charledore (QuestDirectorCom0u601). Win:
  processEvent_005_03(0) (the cliff scene), SEQ_002, back to the spot.
- SEQ_002 Cid at the landing: processEvent_010(0) (the main path), rewards.

Not wired: processEvent_hint, the other engineers processEvent_005_01/_02, the landing staff
_005_05.._07 and _010_01.._07, and the lift scenes processEvent_elevator_nq1F/2F/3F (the Wellhead
Lift's own actors carry the player).
