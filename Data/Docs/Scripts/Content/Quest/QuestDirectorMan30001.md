# QuestDirectorMan30001: the excavation mesa (Toll of the Warden)

Script: [`Data/scripts/Content/Quest/QuestDirectorMan30001.lua`](../../../../scripts/Content/Quest/QuestDirectorMan30001.lua)

Toll of the Warden (Man300 SEQ_025/030), director QuestDirectorMan30001.

- Two Ixali swordfighters, an Amalj'aa drubber and an Amalj'aa bowyer stand at the van. They never
  pick a fight and hold at 1 HP. Beaten to the floor, a fighter loses the will to fight and stands
  inert.
- Fighter n is also alone in group `fighter<n>`.
- Counters: `engaged<n>` once it turns on someone, `withdrawn<n>` once it gives up, and `ixal` /
  `amaljaa` for the fighters of that tribe beaten down.
- The quest decides when both tribes are settled and wins the fight. Phase `ixalSettled` or
  `amaljaaSettled` stands a tribe down after a Parley.
