# PopulaceRetainerManager: client event functions

Script: [`Data/scripts/Chara/Npc/Populace/PopulaceRetainerManager.lua`](../../../../../scripts/Chara/Npc/Populace/PopulaceRetainerManager.lua).

Client event functions:

- `eventTalkStep1(true)`: Intro tutorial if no retainer
- `newEventTalkStep1(sayIntro)`: Seems to be a post-Tanaka version of the intro????
- `eventTalkStep2()`: Choose retainer yourself (go to race select) or let npc do it
- `eventTaklSelectCutSeane(cutsceneName, actorClassId1, actorClassId2, actorClassId3, actorClassId4, actorClassId5)`: Starts the advance cutscene to choose a retainer. 5 retainer actorClassId's are given.
- `eventTalkStep4(actorClassId)`: Opens up the retainer naming dialog
- `eventTalkStepFinalAnswer(actorClassId)`: Confirm Dialog
- `eventTalkStepError(errorCode)`: Error dialog, 1: No Extra Retainers, 2: Server Busy.
- `eventTalkStepFinish()`
