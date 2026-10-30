require("Global")
--[[
Small Talk (DftRoc, quest 110542). Default lines for talkable npcs in the
Roc region (Coerthas). Active for every player at all times. Maps actor class
id to the client function that plays the line. Entries for npcs that are not
PplStd never fire.
--]]

local defaultTalkRoc = {
	[1500078] = "defaultTalkWithMildthryth_001",
	[1500104] = "defaultTalkWithDeryk_001",
	[1000676] = "defaultTalkWithTarokmagurok_001",
	[1600063] = "defaultTalkWithNcanago_001",
	[1500239] = "defaultTalkWithClaudien_001",
	[1000675] = "defaultTalkWithSidonia_001",
	[1001698] = "defaultTalkWithLiflingulin_001",
	[1001500] = "defaultTalkWithHourlinet_001",
	[1001499] = "defaultTalkWithOrtefauchel_001",
	[1500105] = "defaultTalkWithSkaetlorh_001",
	[1600097] = "defaultTalkWithFawkes_001",
	[1000677] = "defaultTalkWithPaul_001",
	[1500079] = "defaultTalkWithPanhajaab_001",
	[1500260] = "defaultTalkWithFrine_001",
	[1500080] = "defaultTalkWithMomoroto_001",
	[1500106] = "defaultTalkWithJijiri_001",
	[1500246] = "defaultTalkWithSeghuie_001",
	[1600130] = "defaultTalkWithFolcard_001",
	[1500081] = "defaultTalkWithFirmien_001",
	[1500107] = "defaultTalkWithNdhajakkya_001",
	[1500245] = "defaultTalkWithShulolo_001",
	[1600113] = "defaultTalkWithPoponagu_001",
	[1000678] = "defaultTalkWithMhustym_001",
	[1500108] = "defaultTalkWithLycelle_001",
	[1500082] = "defaultTalkWithKleytai_001",
	[1500241] = "defaultTalkWithZwelfhyll_001",
	[1600110] = "defaultTalkWithSynnove_001",
	[1001368] = "defaultTalkWithArmantel_001",
	[1001369] = "defaultTalkWithIliette_001",
	[1001366] = "defaultTalkWithGaetelle_001",
	[1001364] = "defaultTalkWithRickeman_001",
	[1001367] = "defaultTalkWithHubairtien_001",
	[1001365] = "defaultTalkWithQuenburga_001",
	[1001363] = "defaultTalkWithErmiance_001",
	[1001362] = "defaultTalkWithRawawa_001",
	[1500067] = "defaultTalkWithLoloma_001",
	[1001574] = "defaultTalkWithArscelin_001",
	[1001358] = "defaultTalkWithPatrick_001",
	[1000667] = "defaultTalkWithBubudoga_001",
	[1001356] = "defaultTalkWithJanlenoux_001",
	[1001355] = "defaultTalkWithAmianne_001",
	[1001357] = "defaultTalkWithFyrloug_001",
	[1001360] = "defaultTalkWithOdeve_001",
	[1001361] = "defaultTalkWithEmerissel_001",
	[1001359] = "defaultTalkWithElde_001",
	[1001354] = "defaultTalkWithWidigast_001",
	[1001159] = "defaultTalkWithWowotazi_001",
	[1001155] = "defaultTalkWithLadislas_001",
	[1001156] = "defaultTalkWithHersande_001",
	[1001154] = "defaultTalkWithDyrstweitz_001",
	[1001157] = "defaultTalkWithPuroro_001",
}

function onTalk(player, quest, npc, eventName)
	local clientFunc = defaultTalkRoc[npc:GetActorClassId()]
	callClientFunction(player, "delegateEvent", player, quest, clientFunc)
	player:EndEvent()
end

function IsQuestENPC(player, quest, npc)
	return defaultTalkRoc[npc:GetActorClassId()] ~= nil
end
