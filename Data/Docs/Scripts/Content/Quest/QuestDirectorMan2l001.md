# QuestDirectorMan2l001: the deck duel (Never the Twain Shall Meet)

Script: [`Data/scripts/Content/Quest/QuestDirectorMan2l001.lua`](../../../../scripts/Content/Quest/QuestDirectorMan2l001.lua)

Never the Twain Shall Meet (Man2l0 SEQ_020), director QuestDirectorMan2l001.

- Emerick and Merodaulyn square off on the deck and stand idle until the player attacks one of
  them. Then the two fight each other while the player fights the one attacked.
- After `IDLE_START_SECONDS` without a choice they start fighting on their own. A duelist that
  drops out of the fight is set on the other again each second.
- One duelist down: the survivor stands down, the player is healed and the fight is won, with
  counter `winner` 1 (Emerick) or 2 (Merodaulyn). Both down: lost.
- The player keeps 1 HP throughout.
