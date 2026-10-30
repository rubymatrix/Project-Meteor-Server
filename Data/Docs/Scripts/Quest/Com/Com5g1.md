# Com5g1: Into the Dark (Gridania)

Script: [`Data/scripts/Quest/Com/Com5g1.lua`](../../../../scripts/Quest/Com/Com5g1.lua)

Into the Dark (Gridania) (Com5g1, 111611). Prereq: Com5g0 (seed_msq_gridania_21_com0g_side.sql). Level 45.

- Offer: Fulke (processEventFULKEStart).
- SEQ_000 Ser Yuhelmeric at Owl's Nest -> SEQ_001.
- SEQ_001 Dyrstweitz at the Darkhold entrance -> SEQ_002, then the go-in.
- SEQ_002 Dyrstweitz asks to go in. Inside, the imperials in the captain's quarters (push); the win -> SEQ_003.
- SEQ_003 Yuhelmeric -> SEQ_004.
- SEQ_004 Fulke, rewards.

The visit is Dzemael Darkhold, parties of 4 to 8. int2 is the journal objective, as in Com5g0. Not wired:
the knights' side talks. The copy is per player and the time limit is on the duty; the steps, the go-in
and the duty are Com5Visit.lua's. Spawns and gates: seed_msq_gridania_21_com0g_side.sql; inside trigger:
content/SimpleContentCom5g101.lua.
