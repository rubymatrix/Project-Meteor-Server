# TaskBoard: client event functions

Script: [`Data/scripts/Chara/Npc/Object/TaskBoard.lua`](../../../../../scripts/Chara/Npc/Object/TaskBoard.lua).

The Task Board in each Adventurers' Guild. Its calls come from the Noc000 static actor, which also
serves some guild NPCs. Only the Noc000 functions the Task Board uses are listed.

```text
pETaskBoardAskLimsa()
    Desc: Show guild menu with valid options for Limsa Lominsa.
    Params: None
    Returns: Value dictating which item on the list was selected.

pETaskBoardAskUldah()
    Desc: Show guild menu with valid options for Ul'dah.
    Params: None
    Returns: Value dictating which item on the list was selected.

pETaskBoardAskGridania()
    Desc: Show guild menu with valid options for Gridania.
    Params: None
    Returns: Value dictating which item on the list was selected.

pETaskBoardGuild(guildId)
    Desc: Plays back a message "The following tasks are available:".
    Params: * guildId 			- Class Id from xtx_text_jobName.  EN doesn't make use of it, but JP/DE/FR do.
    
pETaskBoardOrder(recommendedLvl itemId, hq, amount)
    Desc: Takes the params and tells the player what the guild still needs turned in.
    Params: * recommendedLvl 	- Recommended level the player be at
            * itemId  			- Id of the item from xtx_itemName
            * hq     			- Quality of item (1 = NQ, 2 = +1, 3 = +2 4 = +3)
            * amount 			- Amount needed (The amount the player needs to turn-in, not the amount guild needs overall)
```
