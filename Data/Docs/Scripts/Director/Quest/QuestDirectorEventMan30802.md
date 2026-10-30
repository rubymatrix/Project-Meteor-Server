# QuestDirectorEventMan30802: Lord Errant, the Bowl of Embers

Script: [`Data/scripts/Director/Quest/QuestDirectorEventMan30802.lua`](../../../../scripts/Director/Quest/QuestDirectorEventMan30802.lua). Quest Man308, SEQ_015 (content SimpleContentMan30803, zone 240).

The fight is `Content/Quest/QuestDirectorEventMan30802.lua`; this side plays the quest's part:

- On landing, with the notice still open: pE50 (HQ man40640 + man30850) and pE60 (man30860), once
  per run of the quest (journal int3).
- Each captive the fight stands down sets its flag and the subdued count; the war party coming out
  sets `FLAG_CAPTIVES_STOPPED`.
- A knockout, the clock or leaving fails; the quest stays at 15 and the approach relaunches the duty.

Win: `finishBowl` (pE80, SEQ_020, the gates). Loss: `failBowl`.

Not ported: Parley with the three named captives.
