# PopulaceCompanyOfficer: client event functions

Script: [`Data/scripts/Chara/Npc/Populace/PopulaceCompanyOfficer.lua`](../../../../../scripts/Chara/Npc/Populace/PopulaceCompanyOfficer.lua)

Rank values come from `xtx_gcRank`.

- `eventTalkWelcome()`: welcome dialog.
- `eventTalkWelcomeQuest()`: same as the welcome dialog?
- `eventTalkPreJoin()`: dialog for the starting GC rank?
- `eventTalkExclusive()`: dialog when you're not of that GC?
- `eventTalkJoinedOnly()`: reads like the chat-end dialog for your GC.
- `eventTalkJoined(gcRank, gcRank, isCanAfford, isShowPromotion)`: menu to ask about or for promotion.
- `eventDoRankUp(gcRank, gcRank)`: plays the rank-up animation and opens the GC window.
- `eventRankUpDone(?, ?)`: your character does the GC salute? The values seem to do nothing.
- `eventRankCategoryUpBefore(gcRank)`: at 11/21/31, names the GC quest you need to clear to continue promotion.
- `eventRankCategoryUpAfter()`: follow-up dialog after ranking up.
- `eventTalkQuestUncomplete()`: quest prerequisite dialog for Second Lieutenant (the 1.23b rank cap).
- `eventTalkFestival()`: Foundation Day 2011 dialog. The server must give 1000 GC seals after it.
- `eventTalkFestival2()`: Foundation Day 2011 dialog. Seems to give more seals; amount unknown.
- `eventTalkFestival2012(value)`: Foundation Day 2012 dialog. Gives `value` seals; retail used 5000.
- `eventTalkStepBreak()`: resets the NPC's target and facing.
