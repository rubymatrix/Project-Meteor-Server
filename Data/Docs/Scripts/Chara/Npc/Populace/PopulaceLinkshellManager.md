# PopulaceLinkshellManager: client event functions

Script: [`Data/scripts/Chara/Npc/Populace/PopulaceLinkshellManager.lua`](../../../../../scripts/Chara/Npc/Populace/PopulaceLinkshellManager.lua)

- `eventTalkStep1(noLinkshellActive)`: intro. With `noLinkshellActive` true, adds the newcomer lines.
- `eventTalkStep2(noLinkshellActive)`: the menu. With `noLinkshellActive` true, only offers creating a linkshell.
- `eventTalkStepMakeupDone()`: confirm after creating a linkshell.
- `eventTalkStepModifyDone()`: confirm after changing a linkshell.
- `eventTalkStepBreakDone()`: confirm after disbanding a linkshell.

Text ids:

- 25121: That [linkshell/company] name is already being used.
- 25122: That [linkshell/company] name cannot be used.
- 25123: The [linkshell/company] "[name]" has been [created/founded].
