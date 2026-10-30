require("Global")

--[[
Local levequest (crafting leve) publisher. The offer menus aren't wired yet: talking only shows
confirmJournal for a test leve.
--]]

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

	callClientFunction(player, "finishTalkTurn")
	player:EndEvent()
end

local function getAvailableLeves(class, rank)

end