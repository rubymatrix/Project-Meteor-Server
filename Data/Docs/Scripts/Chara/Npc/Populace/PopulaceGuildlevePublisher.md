# PopulaceGuildlevePublisher: guildleve menus

Script: [`Data/scripts/Chara/Npc/Populace/PopulaceGuildlevePublisher.lua`](../../../../../scripts/Chara/Npc/Populace/PopulaceGuildlevePublisher.lua)

Client functions, as worked out so far:

```text
eventTalkType(level (changes factionLeves), sayIntro, brokenBladePoints, shieldsPoints, hornhandPoints, showTutorialLeves, doOmen (!=0), menuId (to Jump), leveAllowances, ?, ?, ?)
eventTalkPack(startGuildlevePack, endGuildlevePack)
eventTalkCard(card1,card2,card3,card4,card5,card6,card7,card8)
eventTalkDetail(guildLeveId, factionEvaluating, rewardType1, rewardQuantity1, rewardType2, rewardQuantity2, boostPoint, previouslyCompleted, completionBonus)
eventTalkAfterOffer()
eventHistoryleveExist(guildLeveId)
eventHistoryleveCannot()
eventGLChangeDetail(?, guildLeveId, boostPoint, rewardType1, rewardQuantity1, rewardType2, rewardQuantity2, factionEvaluating, previouslyCompleted)
eventTalkChangeOne(skipQuestion)
talkOfferMaxOver()
askRetryRegionalleve(guildLeveId, leveAllowances);
```
