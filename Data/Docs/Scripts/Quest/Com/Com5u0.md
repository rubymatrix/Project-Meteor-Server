# Com5u0: Imperial Devices (Ul'dah)

Script: [`Data/scripts/Quest/Com/Com5u0.lua`](../../../../scripts/Quest/Com/Com5u0.lua). Quest 111810, after Com0u7 (the enlistment), level 25.

- Offer: Aubrey (`processEventAUBREYStart`).
- SEQ_000 Nuala at the Wailing Barracks, then SEQ_001.
- SEQ_001 Bloisirant at Silent Arbor, not at the Barracks, then SEQ_002 and the go-in.
- SEQ_002 Bloisirant asks to go in. Inside, the moogle (push) hands over two items: SEQ_003, back outside.
- SEQ_003 Bloisirant, then SEQ_004.
- SEQ_004 Aubrey, rewards.

The visit is the Thousand Maws of Toto-Rak, parties of 2 to 4. Only the minutes (int2) go to the
journal. The copy is per player and the time limit is on the duty; the steps, the go-in and the duty
are `Com5Visit.lua`'s.

Spawns and gates: `seed_msq_uldah_20_com0u.sql`. Inside trigger: `Content/SimpleContentCom5u001.lua`.
