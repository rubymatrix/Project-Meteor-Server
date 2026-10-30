# QuestDirectorMan40201: the East Shroud search

Script: [`Data/scripts/Content/Quest/QuestDirectorMan40201.lua`](../../../../scripts/Content/Quest/QuestDirectorMan40201.lua)

Of Men They Sing (Man402 SEQ_005), director QuestDirectorMan40201: the search in the East Shroud.
WALK_START_SECONDS in, the Path companion (the area's event actor) sets off down the gullies toward the
scout, waiting while the player trails her by more than HOLD_DISTANCE. The player LEASH_DISTANCE from
her for LEASH_SECONDS fails ("left"); the warning comes on the first second.
Arrival (she reaches the end, a hound engages, or the player comes within ARRIVAL_RANGE of the scout):
she is swapped in place for a fighting ally of the same class and name, and the two bloodhounds charge
ENGAGE_DELAY later, or at once within ENGAGE_RANGE of the scout. WIN_SETTLE_SECONDS after the second
kill wins; the quest may win it sooner.
Counters for the quest: "arrived", "kills". The fighting companion is group "companion".
