# CraftCommand: CraftJudge client functions

Script: [`Data/scripts/Command/CraftCommand.lua`](../../../scripts/Command/CraftCommand.lua)

Client functions of the CraftJudge widget, which runs crafting. Kept as written in the script.

```text
Functions:

loadTextData()  
    Desc: Loads all gamesheets needed and instantiates a CraftJudge.
    Params: None

start(facility, requestsMode, material1, material2, material3, material4, material5, material6, material7, material8)
    Desc: Opens the Craft Start widget, with any preloaded materials. Widget has two modes; one for normal synthesis and another
          for local leve "requested items" mode.
    Params:    * facility        - The current facility id buff the player may have.
            * requestMode     - If true, switches the UI to Requested Items mode otherwise it opens Normal Synthesis mode.
            * material1-8    - ItemID for each of the 8 material slots. If empty, they must be set to 0 or the client will crash.
        
closeCraftStartWidget()
    Desc: Closes the Craft Start widget.
    Params: None

selectRcp(itemId)
    Desc:     Selects the recipe to be crafted. May be a legacy function but still required to properly initialize the UI. Requires start() to have
            been called.
    Params:    * itemId         - The itemID of the item to be crafted.
    
confirmRcp(craftedItem, quantity, crystalItem1, crystalQuantity1, crystalQuantity1, crystalItem2, crystalQuantity2, recommendedSkill, recommendedFacility)
    Desc: Opens the confirmation window, detailing what is needed and the item that will be created. Requires a selectRcp() call first.
    Params:    * craftedItem            - The itemID of the item to be crafted.
            * quantity                - Quantity of crafted items.
            * crystalItem1             - The first required crystal itemID for crafting.
            * crystalQuantity1        - Quantity of the first crystal.
            * crystalItem2            - The second required crystal itemID for crafting.
            * crystalQuantity2        - Quantity of the second crystal.
            * recommendedSkill        - Which itemID to display under the "Recommended Skill" panel.
            * recommendedFacility    - Which facility to display under the "Recommended Facility" panel.

selectCraftQuest()
    Desc: Opens the journal to select the local leve that the player would like to do.
    Params: None

askContinueLocalLeve(localLeveID, craftedItem, itemsCompleted, craftTotal, attempts)
    Desc: Opens the dialog to continue crafting for a local leve after an item was completed.
    Params: * localLeveID            - The id of the current leve in progress.
            * craftedItem            - The current crafted item id.
            * itemsCompleted        - Number of items crafted so far.
            * craftTotal            - Number of items to be crafted in total.
            * attempts                - The number of attempts left.

askRetryLocalleve(localLeveID, allowanceCount)
    Desc: Opens the dialog to retry the local leve (at the expense of an allowance) if the player had failed it.
    Params: * localLeveID            - The failed level id.
            * allowanceCount        - How many allowances the player has.

openCraftProgressWidget(durability, quality, hqChance)
    Desc: Opens the crafting minigame, sets starting values.
    Params: * durability            - Durability of the current item.
            * quality                - Starting quality of the current item.
            * hqChance                - Starting chance to get a HQ item.

craftCommandUI(classID, hasWait, command1, command2, command3, command4, command5)
    Desc: Sets the available command list and waits for the player to select a command.
    Params:
            * classID                - The current crafting class. Must be set properly to show the three synthesis commands.
            * hasWait                - If true, adds the wait command.
            * command1-5            - Five possible crafting commands (crafting skills).

craftTuningUI(command1, command2, command3, command4, command5, command6, command7, command8)
    Desc: Displays a full list of commands for the legacy "Tuning" phase that happens after crafting. Deprecated in 1.23b.
    Params: * command1-8            - The list of commands available.

updateInfo(progress, durability, quality, tuningItem, tuningItemQuality, tuningItemQuantity, hqChance)
    Desc: Updates the progress UI components and text boxes.
    Params: * progress                - The current crafting progress percentage. Value is from 0 to 100.
            * durability            - The current durability of the crafted item.
            * quality                - The current quality of the crafted item.
            * tuningItem            - The crafted item to show in the Tuning UI. Nil if crafting. Deprecated in 1.23b.
            * tuningItemQuality     - The quality of the item to show in the Tuning UI. Nil if crafting. Deprecated in 1.23b.
            * tuningItemQuantity    - The amount of the item to show in the Tuning UI. Nil if crafting. Deprecated in 1.23b.
            * hqChance                - The current chance of an HQ craft.

closeCraftProgressWidget()
    Desc: Closes the crafting minigame widget.
    Params: None
    
cfmQst()
    Desc: Quest confirmation window for when starting a crafting quest from the journal.
    Params:

confirmLeve()
    Desc: Opens the summery page for the local leve.
    Params: * localLeveID            - The quest id of the leve you are confirming.
            * difficulty            - Changes the objective.
            * craftedItem?            -
            * ?                        -
            * numSuccess            - The number of successful crafts you did.
            * remainingMaterials    - The number of materials you have left.
            * hasMaterials            - Shows the in-progress panel of successes and attempts left.
            * ?                        -

startRepair(craftMode, item, quality, durability, hasMateria, spiritbind)
    Desc: Opens the repair item widget.
    Params: * craftMode                - Either 0 or 1. Anything else crashes.
            * item                    - ItemID of the item to be repaired.
            * quality                - Quality of the item to be repaired.
            * durability            - Durability of the item to be repaired.
            * hasMateria            - Shows an icon if the item to be repaired has materia attached.
            * spiritbind            - Spiritbind of the item to be repaired.

askJoinMateria()
displayRate()

askJoinResult(isSuccess, item, itemQuality, materia, materiaNumber, isSpiritBound)
    Desc: Opens the result widget after materia melding is done.
    Params: * isSuccess                - True if the meld was successful.
            * item                    - Item ID of the melded item.
            * quality                - Quality of the melded item.
            * materia                - Item ID of the materia being melded.
            * materiaNumber            - Total count of materia on the item.
            * isSpiritBound            - True if the item is spiritbound. Causes icon to appear.
    
Notes:

Class ID + Starting skill
 29 CRP = 22550
 30 BSM = 22556
 31 ARM = 22562
 32 GSM = 22568
 33 LTW = 22574
 34 WVR = 22580
 35 ALC = 22586
 36 CUL = 22592

Leve objectives/rewards are in passiveGL_craft.

* Index 1: 
* Index 2: Recommended Class
* Index 3: Issuing Authority
* Index 7: Levequest Location
* Index 8: Deliver Display Name
* Starts at index 14. Four sections for the four difficulties.
* Required Item, Amount, ?, Recommended Level, , Reward Item, Reward Amount, |
```
