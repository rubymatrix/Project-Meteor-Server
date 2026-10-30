# PopulaceCompanyGLPublisher: client event functions

Script: [`Data/scripts/Chara/Npc/Populace/PopulaceCompanyGLPublisher.lua`](../../../../../scripts/Chara/Npc/Populace/PopulaceCompanyGLPublisher.lua).

Grand Company rank values are in the client sheet xtx_gcRank.

```text
talkOutsider()                              - Dialog for no affiliated with GC.  Seems to always read Maelstrom?
talkOfferWelcome(unk1)                      - Errors
askCompanyLeve()                            - Errors
askLeveDetail(unk1, unk2, unk3, unk4, unk5, unk6, unk7, unk8)                             - Errors

eventGLDifficulty()                         - Difficulty window, returns player choice
eventGLStart(leveName, difficulty, unk1)    - leveName from xtx_guildleve

talkAfterOffer()
talkOfferLimit()

finishTalkTurn()                                            - Resets NPC target/facing

eventGLPlay(leveName, guardianFavor, favorCost, difficulty) - Menu for active levequest
eventGLShinpu(guardianFavor, favorCost)                     - Menu to accept favor buff.  evenGLPlay() calls it
eventGLThanks()                                             - Errors

eventGLReward(                      -- Leve reward screen
    guildleveId, 
    clearTime, 
    missionBonus, 
    difficultyBonus, 
    factionNumber, 
    factionBonus, 
    factionCredit, 
    glRewardItem, 
    glRewardNumber, 
    glRewardSubItem, 
    glRewardSubNumber, 
    difficulty
)
```
