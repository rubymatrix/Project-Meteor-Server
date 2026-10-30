# QuestDirectorMan2g001: the spirit of the wood

Script: [`Data/scripts/Content/Quest/QuestDirectorMan2g001.lua`](../../../../scripts/Content/Quest/QuestDirectorMan2g001.lua).

Beckon of the Elementals (Man2g0 SEQ_004), director QuestDirectorMan2g001: the spirit of the wood in
the West Shroud.
Grinnaux, Handeloup and T'kebbe fight the spirit while the player supports. Its aspect turns earth,
wind, water: FIRST_ASPECT_SECONDS after the fight is joined, then every ASPECT_SECONDS. Each turn: its
line and O-App-Pesi's call, repeated every CALL_REPEAT_SECONDS for up to CALL_TIMEOUT_SECONDS. Every
STRIKE_SECONDS while the player's ward is not the aspect: ALLY_STRIKE_DAMAGE to each archer and
PLAYER_STRIKE_DAMAGE to the player, who keeps 1 HP. A fallen archer is replaced once,
REPLACEMENT_SECONDS later. Won when the spirit falls; lost when every seat is gone ("ko").
The quest sets the ward with phase "ward1" (wind), "ward2" (earth) or "ward3" (water).
opts.quest: the quest whose lines the fight shows.
