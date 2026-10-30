require("Com5Visit")

--[[

Quest Script

Name: 	Imperial Devices (Gridania)
Code: 	Com5g0
Id: 	111610
Prereq: Com0g7, the enlistment (seed_msq_gridania_21_com0g_side.sql). Level 25.

Offer: Fulke (processEventFULKEStart).
SEQ_000 Bloisirant at Silent Arbor -> SEQ_001, then the go-in.
SEQ_001 Bloisirant asks to go in. Inside, A-Ruhn-Senna the Padjal (push) -> SEQ_002, back outside.
SEQ_002 Bloisirant -> SEQ_003.
SEQ_003 Fulke, rewards.

The visit is the Thousand Maws of Toto-Rak, parties of 2 to 4. The journal objective sits in int2, the
slot the minutes use in the other visits. Not wired: the moogles' talks. The copy is per player and the
time limit is on the duty; the steps, the go-in and the duty are com5visit.lua's. Spawns and gates:
seed_msq_gridania_21_com0g_side.sql; inside trigger: content/SimpleContentCom5g001.lua.

--]]

local PARTY_MIN				= 2
local PARTY_MAX				= 4
local MIN_LEVEL				= 25
local TIME_LIMIT_MINUTES		= 60	-- The journal prints this value; the client has no default.


local FULKE					= 1500200
local BLOISIRANT				= 1001150
local PADJAL_TRIGGER			= 1090340	-- inside the copy

local MRKR_BLOISIRANT			= 11164901
local MRKR_FULKE				= 11164902

VISIT = {
	giver = FULKE,
	offer = {"processEventFULKEStart", 0, 0, 0},
	giverRepeat = {"followEvent_000", PARTY_MAX, MIN_LEVEL},
	talks = {
		[0] = {npc = BLOISIRANT, call = {"processEvent_010", TIME_LIMIT_MINUTES}, next = 1, enter = true},
		[2] = {npc = BLOISIRANT, call = {"processEvent_050"}, next = 3},
	},
	enter = {seq = 1, npc = BLOISIRANT, ask = {"processEvent_010_1"}},
	inside = {trigger = PADJAL_TRIGGER, call = {"processEvent_020"}},
	after = 2,
	reward = {seq = 3, npc = FULKE, call = {"processEvent_060"}},
	repeats = {
		[BLOISIRANT] = {"followEvent_050"},
	},
	npcs = {BLOISIRANT},
	party = {min = PARTY_MIN, max = PARTY_MAX, level = MIN_LEVEL},
	partyCall = {"menberCountUnderRange", PARTY_MAX, MIN_LEVEL},
	minutes = TIME_LIMIT_MINUTES,
	duty = {zone = 159, area = "SimpleContentCom5g001", director = "Quest/QuestDirectorCom5g001",
		anchor = {897.4, -28.06, 660.2, 0.74}},						-- inside the entrance door, facing in
	outside = {154, 843.6, -13.33, 640.0, 0.85},					-- Silent Arbor, facing Bloisirant
	markers = {
		[0] = {MRKR_BLOISIRANT}, [1] = {MRKR_BLOISIRANT}, [2] = {MRKR_BLOISIRANT}, [3] = {MRKR_FULKE},
	},
	journal = function(seq)
		return (seq >= 2) and 1 or 0;
	end,
}
