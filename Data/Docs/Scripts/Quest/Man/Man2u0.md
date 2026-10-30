# Man2u0: Calamity Cometh

Script: [`Data/scripts/Quest/Man/Man2u0.lua`](../../../../scripts/Quest/Man/Man2u0.lua)

Calamity Cometh (Man2u0, quest 110012). Follows Golden Sacrifices (Man1u0); offered by Momodi.

- Seq 0:  Rururaji at the chocobo stables: the coach ride (processEvent005) straight into the fight.
- Seq 5:  Set on boarding; a logout mid-scene lands here, so the stables route stays armed.
- Seq 10: The minemite fight (content SimpleContentMan2u001, QuestDirectorMan2u001); a lost fight keeps 10
  and Rururaji takes the player back (processEvent005_2).
- Seq 15: Nogeloix at the Phrontistery; the ward door leads into the Phrontistery (PA 181/8).
- Seq 20: The sickroom antechamber: the sickroom door (PA 181/9).
- Seq 25: F'lhaminn's sickroom; the corridor (PA 181/10) and the collapse.
- Seq 30: Momodi's linkpearl; the read moves to 35.
- Seq 35: The Camp Black Brush sighting.
- Seq 40: The Arrzaneth Ossuary approach into the crypt echo (PA 209/7).
- Seq 45: The crypt: the closing chain plays and lands at the Quicksand.
- Seq 50: Stepped through on the way to 55.
- Seq 55: Momodi pays out the tale.

Completion: processEventSystemMessage (a3 = level: "travel to Ul'dah" at 18+), then the reward window
(500 EXP, 30000 gil, Parley from the client reward sheet). Spawns, private areas and class fills:
Data/sql/seed/seed_msq_uldah_01_npcs.sql.
