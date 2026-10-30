require("Com5Visit")

--[[
Into the Dark (Gridania) (Com5g1, 111611). Prereq: Com5g0; level 45.
A visit to Dzemael Darkhold; the steps, the go-in and the duty are Com5Visit.lua's. The journal
objective sits in int2. Walkthrough: Data/Docs/Scripts/Quest/Com/Com5g1.md.
--]]

local PARTY_MIN				= 4
local PARTY_MAX				= 8
local MIN_LEVEL				= 45
local TIME_LIMIT_MINUTES		= 60	-- The journal prints this value; the client has no default.


local FULKE					= 1500200
local YUHELMERIC				= 1000370
local DYRSTWEITZ				= 1001154
local SPOT_TRIGGER			= 1090342	-- inside the copy

local MRKR_FULKE				= 11165001
local MRKR_OWLS_NEST			= 11165002
local MRKR_YUHELMERIC			= 11165003
local MRKR_DYRSTWEITZ			= 11165004

VISIT = {
	giver = FULKE,
	offer = {"processEventFULKEStart", PARTY_MAX, MIN_LEVEL, TIME_LIMIT_MINUTES, 0},
	giverRepeat = {"processEvent_000", PARTY_MAX, MIN_LEVEL, TIME_LIMIT_MINUTES},
	talks = {
		[0] = {npc = YUHELMERIC, call = {"processEvent_010", PARTY_MAX, MIN_LEVEL, TIME_LIMIT_MINUTES}, next = 1},
		[1] = {npc = DYRSTWEITZ, call = {"processEvent_020", PARTY_MAX, MIN_LEVEL, TIME_LIMIT_MINUTES}, next = 2, enter = true},
		[3] = {npc = YUHELMERIC, call = {"processEvent_040"}, next = 4},
	},
	enter = {seq = 2, npc = DYRSTWEITZ, ask = {"processEvent_020_1"}},
	inside = {trigger = SPOT_TRIGGER, level = 46, pos = {65.2, 174.70, 110.2}, enemies = {
		{100273,  0.0, -3.0},	-- imperial_secutor
		{100269, -3.0, -1.0},	-- imperial_eques
		{100274,  3.0, -1.0},	-- imperial_signifer
	}},
	after = 3,
	reward = {seq = 4, npc = FULKE, call = {"processEvent_050"}},
	repeats = {
		[DYRSTWEITZ] = {"processEvent_030_1"},
	},
	npcs = {YUHELMERIC, DYRSTWEITZ},
	public = {[DYRSTWEITZ] = true},
	party = {min = PARTY_MIN, max = PARTY_MAX, level = MIN_LEVEL},
	partyCall = {"menberCountUnderRange", PARTY_MAX, MIN_LEVEL},
	minutes = TIME_LIMIT_MINUTES,
	duty = {zone = 231, area = "SimpleContentCom5g101", director = "Quest/QuestDirectorCom5g101",
		anchor = {95.8, 179.90, 212.2, 3.14}},						-- the entrance hall, facing in
	outside = {143, -70.35, 248.47, 391.90, -2.0},				-- the Darkhold entrance, facing Dyrstweitz
	markers = {
		[0] = {MRKR_YUHELMERIC, MRKR_OWLS_NEST}, [1] = {MRKR_DYRSTWEITZ}, [2] = {MRKR_DYRSTWEITZ},
		[3] = {MRKR_YUHELMERIC, MRKR_OWLS_NEST}, [4] = {MRKR_FULKE},
	},
	journal = function(seq)
		return (seq >= 3) and 1 or 0;
	end,
}
