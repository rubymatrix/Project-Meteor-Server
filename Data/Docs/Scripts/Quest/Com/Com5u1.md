# Com5u1: Into the Dark (Ul'dah)

Script: [`Data/scripts/Quest/Com/Com5u1.lua`](../../../../scripts/Quest/Com/Com5u1.lua). Quest 111811, after Com5u0, level 45.

- Offer: Aubrey (`processEventAUBREYStart`).
- SEQ_000 Ser Vairemont at Owl's Nest, then SEQ_001.
- SEQ_001 the Darkhold entrance, with Dyrstweitz as the marked NPC, then SEQ_002 and the go-in.
- SEQ_002 Dyrstweitz asks to go in. Inside, the primus ordinarius and his men (push); the win: SEQ_003.
- SEQ_003 Vairemont, then SEQ_004.
- SEQ_004 Aubrey, rewards.

The visit is Dzemael Darkhold, parties of 4 to 8. The copy is per player and the time limit is on
the duty; the steps, the go-in and the duty are `Com5Visit.lua`'s.

Spawns and gates: `seed_msq_uldah_20_com0u.sql`. Inside trigger: `Content/SimpleContentCom5u101.lua`.
