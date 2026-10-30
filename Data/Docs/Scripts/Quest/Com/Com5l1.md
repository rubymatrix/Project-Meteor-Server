# Com5l1: Into the Dark (Limsa Lominsa)

Script: [`Data/scripts/Quest/Com/Com5l1.lua`](../../../../scripts/Quest/Com/Com5l1.lua)

Into the Dark (Limsa Lominsa) (Com5l1, 111411). Prereq: Com5l0 (`seed_msq_limsa_20_com0l.sql`).
Level 45.

- Offer: Guincum (`processEventGUINCUMStart`; worldMaster 33 prints the minutes).
- SEQ_000 Hasthwab on the Astalicia -> SEQ_001.
- SEQ_001 Quiliane at Owl's Nest -> SEQ_002.
- SEQ_002 Dyrstweitz at the Darkhold entrance -> SEQ_003, then the go-in.
- SEQ_003 Dyrstweitz asks to go in. Inside, the imperials at the spot (push); the win is the item
  in int6 -> SEQ_004.
- SEQ_004 Quiliane -> SEQ_005.
- SEQ_005 Guincum, rewards.

The visit is Dzemael Darkhold, parties of 4 to 8. The copy is per player and the time limit is on
the duty; the steps, the go-in and the duty are `Com5Visit.lua`'s. Spawns and gates:
`seed_msq_limsa_20_com0l.sql`; inside trigger: `SimpleContentCom5l101.lua`.
