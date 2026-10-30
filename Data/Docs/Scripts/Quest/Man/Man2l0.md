# Man2l0: Never the Twain Shall Meet

Script: [`Data/scripts/Quest/Man/Man2l0.lua`](../../../../scripts/Quest/Man/Man2l0.lua). Quest 110004, after Legends Adrift (Man1l0, 110003).

- Offer: Baderon.
- SEQ_000: Hob at the Limsa docks. The docks push leads into the docks echo (PA 230/8), where Hob sails.
- SEQ_010: the dromond echo (PA 192/0): the door into the hold.
- SEQ_015: the hold (PA 192/1): the stairs or the deck trigger ask to start the duel.
- SEQ_020: the deck duel (content SimpleContentMan2l001, QuestDirectorMan2l001). A lost duel keeps 20
  and every boarding route stays armed for a retry.
- SEQ_035: Baderon's briefing.
- SEQ_037: the sea-field outcrop (public 128) lights Baderon's linkpearl.
- SEQ_040: linkpearl pending; the read moves to 42. Nothing else is armed.
- SEQ_042: the Marauders' Guild doors (public 230).
- SEQ_045: Isaudorel at the Coral Tower.
- SEQ_050: the Gods' Grip push into the shoreline echo (PA 128/3).
- SEQ_055: the shoreline echo with Y'shtola: the far push plays the ending and lands at the Wench.
- SEQ_070: turn in to Baderon.

The duel: Emerick and Merodaulyn square off on the deck. The one the player attacks fights the
other, and the survivor picks the cutscene (`processEvent020` a3: 1 Emerick, 2 Merodaulyn).

Completion: `processEvent081_2` (a3 = level: "travel to Ul'dah" at 18+), then the reward window
(500 EXP, 30000 gil, Parley from the client reward sheet).
