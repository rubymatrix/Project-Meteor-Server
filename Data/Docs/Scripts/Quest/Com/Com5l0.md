# Com5l0: Imperial Devices (Limsa Lominsa)

Script: [`Data/scripts/Quest/Com/Com5l0.lua`](../../../../scripts/Quest/Com/Com5l0.lua)

Imperial Devices (Limsa Lominsa) (Com5l0, 111410). Prereq: Com0l7, the enlistment
(seed_msq_limsa_20_com0l.sql). Level 25.

- Offer: Guincum (processEventGUINCUMStart).
- SEQ_000 Brother Zerig at Stillglade Fane hands over the urn -> SEQ_001.
- SEQ_001 Bloisirant at Silent Arbor -> SEQ_002, then the go-in.
- SEQ_002 Bloisirant asks to go in. Inside, the moogle (push) -> SEQ_003, back outside.
- SEQ_003 Bloisirant -> SEQ_004.
- SEQ_004 Guincum, rewards.

The visit is the Thousand Maws of Toto-Rak, parties of 2 to 4. Journal int6 = 1/2/3 shows the quest
items: 1 while the urn is carried, 2 after. The copy is per player and the time limit is on the duty;
the steps, the go-in and the duty are Com5Visit.lua's. Spawns and gates: seed_msq_limsa_20_com0l.sql;
inside trigger: Content/SimpleContentCom5l001.lua.
