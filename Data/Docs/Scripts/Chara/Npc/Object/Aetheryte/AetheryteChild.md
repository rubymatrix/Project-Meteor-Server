# AetheryteChild: client event functions

Script: [`Data/scripts/Chara/Npc/Object/Aetheryte/AetheryteChild.lua`](../../../../../../scripts/Chara/Npc/Object/Aetheryte/AetheryteChild.lua).

Client event functions:

- `eventAetheryteChildSelect(showTeleport, parentAetheryteID, animaAmount, animaCost(always 1))`: Opens menu
- `eventAetheryteChildDesion(aetheryteId)`: "Your homepoint is now X"

- `eventGLSelect(?)`: Open GL selector
- `eventGLSelectDetail(glid, ?, reward, rewardQuantity, subreward, subrewardQuantity, faction, ?, completed)`: Show GL details
- `eventGLDifficulty()`: Open difficulty selector
- `eventGLStart(glId, difficulty, evaluatingFaction, areaFactionStanding, factionReward, warningBoundByDuty, warningTooFar, warningYouCannotRecieve, warningChangingClass)`: Confirmation dialog

- `eventGLBoost(currentFavor, minNeeded)`: Ask player for Guardian Aspect
- `eventGLPlay(??)`: Open Menu (GL active version)
- `eventGLReward(glId, clearTime, missionBonus, difficultyBonus, factionNumber, factionBonus, factionCredit, reward, rewardQuantity, subreward, subrewardQuantity, difficulty)`: Open reward window
- `eventGLJoin()`: Ask to join party leader's leve
