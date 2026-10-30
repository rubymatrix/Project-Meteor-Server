# AetheryteParent: client event functions

Script: [`Data/scripts/Chara/Npc/Object/Aetheryte/AetheryteParent.lua`](../../../../../../scripts/Chara/Npc/Object/Aetheryte/AetheryteParent.lua)

Client functions the aetheryte (crystal) event calls. `?` marks an argument whose meaning is unknown.

- `eventAetheryteParentSelect(showTeleportMenu, animaAmount, gate1, gate2, gate3, gate4, gate5)`: open the menu.
- `eventAetheryteParentDesion(sheetId)`: show the home point set message.
- `eventGLSelect(?)`: open the guildleve selector.
- `eventGLSelectDetail(glid, ?, reward, rewardQuantity, subreward, subrewardQuantity, faction, ?, completed)`: show guildleve details.
- `eventGLDifficulty()`: open the difficulty selector.
- `eventGLStart(glId, difficulty, evaluatingFaction, areaFactionStanding, factionReward, warningBoundByDuty, warningTooFar, warningYouCannotRecieve, warningChangingClass)`: confirmation dialog.
- `eventGLBoost(currentFavor, minNeeded)`: ask the player for the Guardian Aspect.
- `eventGLPlay(glId, showLeveLink, leveLinkFaction, leveLinkFactionStanding, leveLinkReward, guardianFavorAmount, guardianFavorNeeded, currentDifficulty, jobNameForChange)`: open the menu (guildleve active version).
- `eventGLReward(glId, clearTime, missionBonus, difficultyBonus, factionNumber, factionBonus, factionCredit, reward, rewardQuantity, subreward, subrewardQuantity, difficulty)`: open the reward window.
- `eventGLJoin()`: ask to join the party leader's leve.

Sample calls:

```lua
callClientFunction(player, "eventGLBoost", 0xc8, 0xb)
callClientFunction(player, "eventGLReward", 0x2a48, 120, 123, 125, 1, 111, 0, 0xf4241, 5, 0, 0, 3)
```
