# DummyCommand: HarvestJudge client functions

Script: [`Data/scripts/Command/DummyCommand.lua`](../../../scripts/Command/DummyCommand.lua).

```text
Operates the harvesting system for mining, logging, and fishing.

Functions:

loadTextData()
    Desc: Loads all gamesheets needed and instantiates a HarvestJudge.
	Params: None

targetCancel()
    Desc: Cancels the player's target.
    Params: None

turnToTarget()
    Desc: Turns to a direction
    Params: * harvestType           - Harvest command used.  Client script has a _waitForTurning() for Quarry/Harvest/Spearfishing
            * direction             - The pi radian to turn the character towards, server has to calculate the vector between the actors.

openInputWidget()
    Desc: Inits the widget system (call first).
    Params: * harvestType           - Determines which text strings to load based on the harvestType
            * nodeGrade             - The grade of the node.  Retail went up to grade 5.

orderInputWidget()
    Desc: Updates the node HP.
    Params: * nodeRemainder         - Range goes from 0-100
            * unk1                  -
            * harvestType           - Doesn't appear to visually do anything? Script checks against harvest command id

textInputWidget()
    Desc: Sets the result text after a minigame is performed.
    Params: * harvestType           - The harvest command
            * unk1                  - Actor to grab text from?  Set to the harvestJudge so the rest of params function, otherwise widget prints whatever is set here.
            * textId                - Id from the harvestJudge sheet.
            * textIdParam1          - Used to fill in textId details if the sheet requires it, Eg. textId #25 requires an itemId, HQ quality, and yield filled in.
            * textIdParam2
            * textIdParam3
            * commandId             - If textId = nil, client script sets it to 64 and this parameter is assigned to Param1
                                    - Why does this exist?  Setting textId to 64 and using commandId as textIdParam1 does the same job.

askInputWidget()
    Desc: Gets user input after opening a ask widget.  Returns two values, one being the id of the chosen command, and the "currentPower" of the minigame.
    Params: * harvestType           - The harvest command
            * phase                 - The current minigame window to show.  Valid ids 1 & 2.
            * showTutorial          - Shows Tutorial menu option in the window if not = 0.
            * showFishWait          -
            * showFishWaitAndJig    -
            * updateFishHP          -
            * showRareCatalystEffect-

closeInputWidget()
    Desc: Closes the widget system (call last).
    Params: * harvestType           - The harvest command

rangeInputWidget()
    Desc: Unknown, currently errors the client...
    Params: * harvestType
            * phase
            * goodMin
            * goodMax
            * bool
```

## Mooglebox scales

```text
Aim
+5 = 0
+4 = 10
+3 = 20
+2 = 30
+1 = 40
 0 = 50
-1 = 60
-2 = 70 
-3 = 80
-4 = 90
-5 = 100  

Sweetspots   1=10  2=30  3=70  4=100 for Mining
remainder    A=40  B=60  C=70  D=80
```
