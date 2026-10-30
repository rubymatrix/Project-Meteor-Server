# QuestDirectorMan40201 (quest side): the East Shroud search

Script: [`Data/scripts/Director/Quest/QuestDirectorMan40201.lua`](../../../../scripts/Director/Quest/QuestDirectorMan40201.lua)

Of Men They Sing (Man402) Seq 5: the search (content SimpleContentMan40201, East Shroud 151).
The fight is Content/Quest/QuestDirectorMan40201.lua; this side plays the quest's part:
 - The companion's lines: "guard her" on arrival, then at the first and the second kill. The second
   kill sets FLAG_HOUNDS_DEFEATED, and a talk to the scout after it wins at once.
 - A knockout, the clock or leaving fails; the quest stays at 5.
Win: finishSearch (pE20, Seq 15). Loss: failSearch.
Her lines are man402 text rows by personality position (Say, the client fills in her name).
