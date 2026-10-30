--[[

PopulacePassiveGLPublisher

Operates the Local Levequest selection menus.

Functions:

askOfferPack(player) 
    Desc: Show class selection menu.
    Params: * player		- The player actor.
    Returns: Value dictating which item on the list was selected (1-8 for class, nil if exited/canceled)

askOfferRank(player)
    Desc: Show Level selection menu.
    Params: * player		- The player actor.
    Returns: Value dictating which item on the list was selected (1 = Lv01, 2 = Lv20, 3 = Lv40, nil if exited/canceled)

askOfferQuest(player, ?, questId1, questId2, questId3, questId4, questId5, questId6, questId7, questId8)
    Desc: Show Leve quest selection menu with up to 8 questId entries
    Params: * player		- The player actor.
			* ?				- Unused param. Capture has a 2.
			* questId 1-8	- The local levequests available up to 8 quests.
    Returns: 1 through 8 for an accepted leve in the order sent, -1 for hitting "Return", and Nil for "Cancel"
    
confirmOffer(player, questId)
    Desc: Opens prompt asking whether to activate the leve and begin it.
    Params: * player		- The player actor.
			* questId		- The quest being confirmed.
    Returns: Boolean - True on Yes, false on No or hitting escape.

confirmMaxOffer(player)
    Desc: Opens ask widget stating you'll be capped on leves after accepting.
    Params: * player		- The player actor. Unused.
    Returns: Boolean - True on Accept, false on "Quit" or hitting escape.
    
talkOfferWelcome(player, numAllowance)
    Desc: NPC intro dialog as well as stating your available leve allowances.
    Params: * player		- The player actor.
			* numAllowance	- The number of leve allowances the player still has.

talkOfferDecide()
    Desc: Makes the NPC say dialog following the acceptance of a leve.
    Params: None
 
talkOfferMaxOver()
    Desc: Makes the NPC say dialog stating the player is carrying too many leves currently.
    Params: None
	    
finishTalkTurn()
	Desc: Ends the npc actor's turn towards you. Call this at the end of the script or the 
		  npc will be stuck "facing" the player.
	Params: None
    
selectDiscardGuildleve()
    Desc: Opens the Journal widget to select a leve to discard. This is a follow-up to askDiscardGuildleve().
    Params: None
    Returns: Quest Actor
    
confirmJournal(questId, difficulty, unused, itemsCompleted, remainingMats, hasMaterials, unused)
    Desc: Opens askJournalDetailWidget displaying current status of the leve.
    Params: * questId		- The current quest being confirmed.
			* difficulty	- The difficulty of the quest.
			* unused		- Unused param.
			* itemsComplete	- Sets the number of items crafted.
			* remainingMats	- Sets the remaining materials.
			* hasMaterials	- If set to 1, shows the progress section.
			* unused		- While loaded into widget, it doesn't do anything with this journalType (13).
    Returns: True on "Exchange", Nil on "Return" or hitting Escape key  

askDiscardGuildleve()
    Desc: Opens an ask widget, stating the player cannot accept any more guildleves and if they'd want to return one to make room.
    Params: None
    Returns: Boolean

confirmDiscardGuildleve(?, questId, guildleveId)
    Desc: Opens an ask widget, confirming the returning of the selected guildleve.
    Params: * ?				- Most likely a player actor, but unused.
			* questId		- The dialog is "Returning <quest>. Are you certain?". This is the questId being returned.
			* guildleveId	- This is mostly unused, Japanese localization has a weird switch to use this. Can be nil.
    Returns: Boolean
    
askRetryRegionalleve(questId, numAllowance) 
    Desc: Opens an ask widget to re-attempt leve questId while showing leveAllowances.  If no is selected, a second widget appears to confirm abandoning it. 
    Params: * questId		- The questId being retried.
			* numAllowance	- The number of leve allowances the player still has.
    Returns: Menu1 -  Is 1 if yes is selected, 2 if no.  Nil if Escape is hit (resend function in this case?)
             Menu2 -  Is 1 if yes is selected (leve abandoned), 2 if no.  Nil if Menu1 isn't set to 2
			 
Notes:

50141 - You have <num> leve allowances remaining.
50142 - You have run out of leve allowances. You cannot accept any more levequests at this time.
50143 - You cannot accept any more levequests at this time.

Local Leves:

~~Limsa~~

CRP: Baderon's New Counter (120007)
	 The Mad Fisher (120017)
	 Building Bridges (120039)
	 High Stakes (120047)
	 Training and Trees (120061)

BSM: Baderon's New Sword (120005)
	 Got Ingots (120013)
	 Ship Shape (120014)
	 A Want of Weapons (120015)
	 Skull Valley Delivery (120035)
	 Fruit's of a Vintner's Whinings (120043)
	 Premiums Paid (120051)
	 Training and Trading (120059)
	 Waiting on Weapons (120067)
	 
ARM: Baderon's New Barbuts (120009)
	 Seeing Sallets to the See (120019)
	 A Step Ahead (120020)
	 Mailed Sailors (120021)
	 Running Rings (120036)
	 Watching the Shore (120044)
	 Watching the Knoll (120052)
	 Rings Around the Rock (120063)
	 Dead Ringers (120068)
	 
GSM: Baderon's New Bands (120010)
	 2 x 2 Eyes (120022)
	 Going Brandanas (120041)
	 Brand New Brands (120049)
	 Staves to Fashion (120064)
	 
LTW: Baderon's New Shoes (120008)
	 The Mad Tanner (120018)
	 Under Foot (120040)
	 Shoeing the Shore (120048)
	 Training and Tanning (120062)
	 

WVR: Baderon's New Clothes (120006)
	 The Mad Hatter (120016)
	 Wear and Tear (120038)
	 Outfitting the Shore (120046)
	 Training and Tailoring (120060)
	 
ALC: Baderon's New Soles (120011)
	 A Sticky Situation (120023)
	 Feeding Trainees (120042)
	 Suffering Soldiers (120050)
	 Training and Eating (120065)


CUL: Baderon's New Breakfast (120012)
	 Tall, Cool One (120024)
	 The Captain's Cravings (120025)
	 A Feast Fit for an Admiral (120026)
	 Supper at the Skull (120037)
	 The Last Supper (120045)
	 A Meal to Remember (120053)
	 Just Desserts (120066)
	 A Job Well Done (120069)

~~Gridania~~

CRP: A Mother's Carpentry (120203)
	 Shields for the Masses (120211)
	 Canes for the Citizens (120212)
	 High Tension (120213)
	 Bowing to Pressure (120223)
	 Pole Positioning (120229)
	 Driving up the Wall (120237)
	 Restocking the Stockade (120245)
	 Plinks Aplenty (120247)
	 
BSM: A Mother's Metallurgy (120201)
	 It's All in the File (120209)
	 Training in Bentbranch (120221)
	 Re-crating the Scene (120231)
	 Training in Emerald Moss (120239)
	 
ARM: A Mother's Foundry (120205)
	 Tending to Tendons (120217)
	 A Little Rusty (120225)
	 Springripple Rising (120233)
	 In Sod We Rust (120241)
	 
GSM: A Mother's Jewelry (120206)
	 The Band's Bands (120218)
	 Dusting the Knuckles (120226)
	 In Arm's Reach (120234)
	 Knuckling Down (120242)
	 
LTW: A Mother's Booties (120204)
	 Strapped for Straps (120214)
	 Fire and Hide (120215)
	 Choke Hold (120216)
	 Work of Friction (120224)
	 Hungry Like the Wolves (120230)
	 Back in the Harness (120238)
	 Morbol Measures (120246)
	 Harnessing Help (120248)

WVR: A Mother's Frippery (120202)
	 Quelling Bloody Rumors (120210)
	 Clearing Bentbranch (120222)
 	 Clearing Nine Ivies (120232)
 	 Clearing Emerald Moss (120240)

ALC: A Mother's Delicacies (120207)
	 Mixing It Up (120219)
	 Keeping It Green (120227)
	 Arboreal Alchemy (120235)
	 Growing Strains (120243)

CUL: A Mother's Muselix (120208)
	 Better Baker's Bounty (120220)
	 On a Full Belly (120228)
	 A Well-Deserved Dinner (120236)
	 Seafood Smorgasbord (120244)

~~Uldah~~

CRP: Momodi's Sturdy Supports (120403)
	 The Walk of Death (120413)
	 Pointed Ambitions (120425)
	 Off With Their Heads (120435)
	 Act of Pure Weevil (120443)

BSM: Momodi's Dancing Daggers (120401)
	 Pointy Props (120409)
	 Hammering the Point (120423)
	 Molten Metal (120434)
	 Looking to Horizon (120442)

ARM: Momodi's Sturdy Suits (120405)
	 Battered and Bent (120415)
	 Arming the Unarmed (120427)
	 Provisioning Drybone (120437)
	 Buckling Under (120445)

GSM: Momodi's Radiant Rings (120406)
	 A Scarcity of Scepters (120416)
	 Pleasure and Pain (120417)
	 In the Sultana's Wake (120418)
	 A Shining Example (120428)
	 A Drybone Induction (120432)
	 A Horizon Promotion (120440)
	 A Bluefog Induction (120448)
	 A Broken Water Promotion (120451)

LTW: Momodi's Sashed Shoes (120404)
	 Showing Some Leg (120414)
	 World-weary Souls (120426)
	 Camp Drybone Cares (120436)
	 I Would Walk 500 Malms (120444)

WVR: Momodi's Budget Breeches (120402)
	 Just for Kecks (120410)
	 Pants Make the Man (120411)
	 Holes in Their Defense (120412)
	 Hanging by a Thread (120424)
	 Exposed to the Elements (120433)
	 Busier Than the Blades (120441)
	 A Spot in the Shade (120449)
	 Fire on the Water (120452)

ALC: Momodi's Condiment Conundrum (120407)
	 Exports of Import (120419)
	 Fertile Lies (120420)
	 A Blind Fool (120421)
	 Saint Allene's Fire (120429)
	 Treating Steel (120431)
	 Blue in the Eye (120439)
	 Preserving the Region (120447)
	 Provisioning Broken Water (120450)

CUL: Momodi's Breakfast Bread (120408)
	 Finger Food (120422)
	 Irrational Behavior (120430)
	 Tender Victuals (120438)
	 Some Like It Wet (120446)

--]]

require("Global")

local limsaLocalLeves = {
	{120007, 120017, 120039, 120047, 120061},									--CRP
	{120005, 120013, 120014, 120015, 120035, 120043, 120051, 120059, 120067},	--BSM
	{120009, 120019, 120020, 120021, 120036, 120044, 120052, 120063, 120068},	--ARM
	{120010, 120022, 120041, 120049, 120064},									--GSM
	{120008, 120018, 120040, 120048, 120062},									--LTW
	{120006, 120016, 120038, 120046, 120060},									--WVR
	{120011, 120023, 120042, 120050, 120065},									--ALC
	{120012, 120024, 120025, 120026, 120037, 120045, 120053, 120066, 120069}	--CUL
}

local gridaniaLocalLeves = {
	{120203, 120211, 120212, 120213, 120223, 120229, 120237, 120245, 120247},	--CRP
	{120201, 120209, 120221, 120231, 120239},									--BSM
	{120205, 120217, 120225, 120233, 120241},									--ARM
	{120206, 120218, 120226, 120234, 120242},									--GSM
	{120204, 120214, 120215, 120216, 120224, 120230, 120238, 120246, 120248},	--LTW
	{120202, 120210, 120222, 120232, 120240},									--WVR
	{120207, 120219, 120227, 120235, 120243},									--ALC
	{120208, 120220, 120228, 120236, 120244}									--CUL
}

local uldahLocalLeves = {
	{120403, 120413, 120425, 120435, 120443},									--CRP
	{120401, 120409, 120423, 120434, 120442},									--BSM
	{120405, 120415, 120427, 120437, 120445},									--ARM
	{120406, 120416, 120417, 120418, 120428, 120432, 120440, 120448, 120451},	--GSM
	{120404, 120414, 120426, 120436, 120444},									--LTW
	{120402, 120410, 120411, 120412, 120424, 120433, 120441, 120449, 120452},	--WVR
	{120407, 120419, 120420, 120421, 120429, 120431, 120439, 120447, 120450},	--ALC
	{120408, 120422, 120430, 120438, 120446}									--CUL
}

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)

	local leveAllowances = 16
	local quest = 120438

	callClientFunction(player, "confirmJournal", quest, 1)
	callClientFunction(player, "confirmJournal", quest, 2)
	callClientFunction(player, "confirmJournal", quest, 3)
	callClientFunction(player, "confirmJournal", quest, 4)
	--[[callClientFunction(player, "talkOfferWelcome", player, leveAllowances);
    
    while (true) do        
        -- Class Menu
        local classChoice = callClientFunction(player, "askOfferPack");
     
        if (classChoice != nil) then            
            while (true) do
                -- Level Difficulty Menu
                local levelChoice = callClientFunction(player, "askOfferRank");
                
                if levelChoice != nil then
                    if levelChoice == 1 then
                        local levequest = callClientFunction(player, "askOfferQuest", player, 1, 120438, 120025);
                        if (levequest != nil and levequest > 0) then
                            player:SendMessage(0x20, "", "[DEBUG] Leve : " .. tostring(pickedLeve));
                            player:SendGameMessage(GetWorldMaster(), 50141, 0x20, leveAllowances);
                        end
                        
                    elseif levelChoice == 2 then
                        pickedLeve = callClientFunction(player, "askOfferQuest", player, 1, 120026, 120027);
                        if (pickedLeve != nil) or (pickedLeve != -1) then
                            player:SendMessage(0x20, "", "[DEBUG] Leve : " .. tostring(pickedLeve));
                            player:SendGameMessage(GetWorldMaster(), 50141, 0x20, leveAllowances);
                        end
                        
                    elseif levelChoice == 3 then
                        pickedLeve = callClientFunction(player, "askOfferQuest", player, 1, 120028, 120029);
                        if (pickedLeve != nil) or (pickedLeve != -1) then
                            player:SendMessage(0x20, "", "[DEBUG] Leve : " .. tostring(pickedLeve));
                            player:SendGameMessage(GetWorldMaster(), 50141, 0x20, leveAllowances)
                        end
                        
                    end
                else    
                    break
                end
            end            
        else
            break;
        end
    end]]--

	callClientFunction(player, "finishTalkTurn")
	player:EndEvent()
end

local function getAvailableLeves(class, rank)

end