# QuestDirectorMan30001: excavation mesa, quest side (Toll of the Warden)

Script: [`Data/scripts/Director/Quest/QuestDirectorMan30001.lua`](../../../../scripts/Director/Quest/QuestDirectorMan30001.lua)

Toll of the Warden (Man300 SEQ_025/030): the excavation mesa (content SimpleContentMan30001,
zone 171). The fight is
[`Content/Quest/QuestDirectorMan30001.lua`](../../../../scripts/Content/Quest/QuestDirectorMan30001.lua);
the director plays the quest's part:

- On landing at 25, Nananoby's briefing plays (pE40) and the step moves to 30.
- The fighters' lines as they engage and give up. Both fighters of a tribe beaten settles that
  tribe, as does a Parley won with its shaman (Man300 `onParleyEnd`), which stands the tribe down
  in the fight.
- Both tribes settled: `SETTLE_DELAY` seconds later pE50 and out to the mesa (`finishMesaDuty`).
- A knockout or the time running out loses the run (`failMesaDuty`: back to 20).
- The companion (an event actor of the player's class) walks with the player.
