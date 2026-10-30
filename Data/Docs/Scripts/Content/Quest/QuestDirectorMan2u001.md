# QuestDirectorMan2u001: Calamity Cometh minemite fight

Script: [`Data/scripts/Content/Quest/QuestDirectorMan2u001.lua`](../../../../scripts/Content/Quest/QuestDirectorMan2u001.lua)

Calamity Cometh (Man2u0 SEQ_010): Greinfarr holds the line over the wounded at the Nanawa Mines road
while minemites come one or two at a time.

- Niellefresne stands passive, Greinfarr fights. Either falling loses ("guarded").
- Twelve minemites, at most two up (`LIVE_CAP`). The first comes `FIRST_WAVE_SECONDS` in, then one
  every `WAVE_INTERVAL_SECONDS`. Each is sent at the player, Greinfarr or Niellefresne in turn.
- A minemite next to an ally chips it for `ALLY_STRIKE_DAMAGE` every `ALLY_STRIKE_SECONDS`.
- The last minemite down wins. The player keeps 1 HP.
- `opts.quest`: the quest whose lines the fight shows.
