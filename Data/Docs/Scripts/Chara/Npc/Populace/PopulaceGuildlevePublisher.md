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

Returns:

- `eventTalkType`: 1 Battlecraft, 21/22/23 Fieldcraft MIN/BTN/FSH (24 quit), 41-59 faction leves,
  5 history evaluation, 6 tutorial, 7 back from the info menu, 8 or nil nothing. `level` gates the
  faction options (25/35/45); `sayIntro` says the remaining allowances first.
- `eventTalkPack`: the chosen guildlevePack id, or nil.
- `eventTalkCard`: the card index 1-8 (0 = empty card); nil when every card is 0.
- `eventTalkDetail`: non-nil to accept. The 2nd argument is the card's "Evaluation" faction (1-3, 0 hides it).

The NPC's lines around the cards are game messages from the publisher's text sheet, sent as the NPC
(log 0x23): 13 before the first card list and 14 before the first detail of a visit, 21 once the
last card is taken, 20 on leaving. The first accept of a visit calls `eventTalkAfterOffer` at once.

Game messages: 50142 "You have run out of leve
allowances...", 50143 "You cannot accept any more levequests at this time."
