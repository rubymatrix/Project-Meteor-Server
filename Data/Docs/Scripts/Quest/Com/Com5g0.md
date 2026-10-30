# Com5g0: Imperial Devices (Gridania)

Script: [`Data/scripts/Quest/Com/Com5g0.lua`](../../../../scripts/Quest/Com/Com5g0.lua)

Imperial Devices (Gridania) (Com5g0, 111610). Prereq: Com0g7, the enlistment (seed_msq_gridania_21_com0g_side.sql). Level 25.

- Offer: Fulke (processEventFULKEStart).
- SEQ_000 Bloisirant at Silent Arbor -> SEQ_001, then the go-in.
- SEQ_001 Bloisirant asks to go in. Inside, A-Ruhn-Senna the Padjal (push) -> SEQ_002, back outside.
- SEQ_002 Bloisirant -> SEQ_003.
- SEQ_003 Fulke, rewards.

The visit is the Thousand Maws of Toto-Rak, parties of 2 to 4. The journal objective sits in int2, the
slot the minutes use in the other visits. Not wired: the moogles' talks. The copy is per player and the
time limit is on the duty; the steps, the go-in and the duty are Com5Visit.lua's. Spawns and gates:
seed_msq_gridania_21_com0g_side.sql; inside trigger: content/SimpleContentCom5g001.lua.
