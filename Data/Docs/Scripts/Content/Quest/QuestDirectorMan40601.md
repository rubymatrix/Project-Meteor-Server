# QuestDirectorMan40601: Futures Perfect field duty

Script: [`Data/scripts/Content/Quest/QuestDirectorMan40601.lua`](../../../../scripts/Content/Quest/QuestDirectorMan40601.lua). Quest: [Man406](../../Quest/Man/Man406.md), SEQ_015, in Mor Dhona.

- `WALK_START_SECONDS` in, the centurion walks the track to the juggernaut with his sagittarius and
  hoplomachus behind. They never fight back while they walk, and hold at 1 HP.
- At the track's end the counter "ambush" goes up and the fight waits for the quest's scene, which
  moves it to phase "fight".
- The fight: the player at full HP and MP, all three on the player (only the centurion still held at
  1 HP), the juggernaut in place to fire its Magitek Cannon.
- A warning marker drops on the player `CANNON_FIRST_IMPACT - CANNON_WINDUP` seconds in and every
  `CANNON_CADENCE` after; `CANNON_WINDUP` later it fires if the player is still within
  `CANNON_RADIUS` of it.
- Both escorts down: at the next impact (at most `FLEE_CAP_SECONDS` later) the centurion flees. He
  reaches the end with the player within `LEASH_DISTANCE`: won.
- The player `LEASH_DISTANCE` from the action for `LEASH_SECONDS` fails ("left").
