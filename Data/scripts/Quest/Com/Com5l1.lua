require("Com5Visit")

--[[
Into the Dark, Limsa Lominsa (Com5l1, 111411). Prereq: Com5l0; level 45.
A visit to Dzemael Darkhold for parties of 4 to 8; the steps, the go-in and the duty are
Com5Visit.lua's. Spawns and gates: seed_msq_limsa_20_com0l.sql.
--]]

local PARTY_MIN				= 4
local PARTY_MAX				= 8
local MIN_LEVEL				= 45
local TIME_LIMIT_MINUTES		= 90	-- The journal prints this value; the client has no default.


local GUINCUM					= 1500199
local HASTHWAB				= 1001064
local QUILIANE				= 1001635
local DYRSTWEITZ				= 1001154
local SPOT_TRIGGER			= 1090348	-- inside the copy

local MRKR_GUINCUM			= 11155001
local MRKR_HASTHWAB			= 11155002
local MRKR_OWLS_NEST			= 11155003
local MRKR_QUILIANE			= 11155004
local MRKR_DYRSTWEITZ			= 11155005

VISIT = {
	giver = GUINCUM,
	offer = {"processEventGUINCUMStart", PARTY_MAX, MIN_LEVEL, TIME_LIMIT_MINUTES},
	giverRepeat = {"processEvent_000"},
	talks = {
		[0] = {npc = HASTHWAB, call = {"processEvent_010"}, next = 1},
		[1] = {npc = QUILIANE, call = {"processEvent_020", PARTY_MAX, MIN_LEVEL, TIME_LIMIT_MINUTES}, next = 2},
		[2] = {npc = DYRSTWEITZ, call = {"processEvent_030", PARTY_MAX, MIN_LEVEL, TIME_LIMIT_MINUTES}, next = 3, enter = true},
		[4] = {npc = QUILIANE, call = {"processEvent_040"}, next = 5},
	},
	enter = {seq = 3, npc = DYRSTWEITZ, ask = {"processEvent_030_1"}},
	inside = {trigger = SPOT_TRIGGER, level = 46, pos = {65.2, 174.70, 110.2}, enemies = {
		{100273,  0.0, -3.0},	-- imperial_secutor
		{100271, -3.0, -1.0},	-- imperial_laquearius
		{100272,  3.0, -1.0},	-- imperial_medicus
	}},
	after = 4,
	reward = {seq = 5, npc = GUINCUM, call = {"processEvent_050"}},
	repeats = {
		[HASTHWAB] = {"processEvent_010_1"},
		[DYRSTWEITZ] = {"processEvent_030_2"},
	},
	npcs = {HASTHWAB, QUILIANE, DYRSTWEITZ},
	public = {[HASTHWAB] = true, [DYRSTWEITZ] = true},
	party = {min = PARTY_MIN, max = PARTY_MAX, level = MIN_LEVEL},
	partyCall = {"menberCountUnderRange", PARTY_MIN, PARTY_MAX, MIN_LEVEL},
	minutes = TIME_LIMIT_MINUTES,
	duty = {zone = 231, area = "SimpleContentCom5l101", director = "Quest/QuestDirectorCom5l101",
		anchor = {95.8, 179.90, 212.2, 3.14}},						-- the entrance hall, facing in
	outside = {143, -70.35, 248.47, 391.90, -2.0},				-- the Darkhold entrance, facing Dyrstweitz
	markers = {
		[0] = {MRKR_HASTHWAB}, [1] = {MRKR_QUILIANE, MRKR_OWLS_NEST}, [2] = {MRKR_DYRSTWEITZ},
		[3] = {MRKR_DYRSTWEITZ}, [4] = {MRKR_QUILIANE, MRKR_OWLS_NEST}, [5] = {MRKR_GUINCUM},
	},
	journal = function(seq)
		return TIME_LIMIT_MINUTES, 0, 0, 0, (seq == 4) and 1 or 0;
	end,
}
