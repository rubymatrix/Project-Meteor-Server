require("Com5Visit")

--[[
Imperial Devices (Ul'dah) (Com5u0, 111810). Prereq: Com0u7, the enlistment; level 25.
The visit is the Thousand Maws of Toto-Rak, parties of 2 to 4; the steps, the go-in and the duty are
Com5Visit.lua's. Walkthrough: Data/Docs/Scripts/Quest/Com/Com5u0.md.
--]]

local PARTY_MIN				= 2
local PARTY_MAX				= 4
local MIN_LEVEL				= 25
local TIME_LIMIT_MINUTES		= 60	-- The journal prints this value; the client has no default.


local AUBREY					= 1500198
local NUALA					= 1000681
local BLOISIRANT				= 1001150
local MOOGLE_TRIGGER			= 1090357	-- inside the copy

local MRKR_NUALA				= 11174901
local MRKR_BLOISIRANT			= 11174902
local MRKR_AUBREY				= 11174903

VISIT = {
	giver = AUBREY,
	offer = {"processEventAUBREYStart", 0, 0, 0},
	giverRepeat = {"processEvent_000"},
	talks = {
		[0] = {npc = NUALA, call = {"processEvent_005", PARTY_MAX, MIN_LEVEL, TIME_LIMIT_MINUTES, 0}, next = 1},
		[1] = {npc = BLOISIRANT, call = {"processEvent_010", TIME_LIMIT_MINUTES, 0}, next = 2, enter = true},
		[3] = {npc = BLOISIRANT, call = {"processEvent_020", 0, 0}, next = 4},
	},
	enter = {seq = 2, npc = BLOISIRANT, ask = {"processEvent_010_01"}},
	inside = {trigger = MOOGLE_TRIGGER, call = {"processEvent_015", 0}},
	after = 3,
	reward = {seq = 4, npc = AUBREY, call = {"processEvent_025", 0, 0}},
	repeats = {
		[NUALA] = {"processEvent_005_1", PARTY_MAX, MIN_LEVEL, TIME_LIMIT_MINUTES},
		[BLOISIRANT] = {"processEvent_020_1"},
	},
	npcs = {NUALA, BLOISIRANT},
	public = {[NUALA] = true},
	party = {min = PARTY_MIN, max = PARTY_MAX, level = MIN_LEVEL},
	partyCall = {"menberCountUnderRange", PARTY_MAX, MIN_LEVEL},
	minutes = TIME_LIMIT_MINUTES,
	duty = {zone = 159, area = "SimpleContentCom5u001", director = "Quest/QuestDirectorCom5u001",
		anchor = {897.4, -28.06, 660.2, 0.74}},						-- inside the entrance door, facing in
	outside = {154, 843.6, -13.33, 640.0, 0.85},					-- Silent Arbor, facing Bloisirant
	markers = {
		[0] = {MRKR_NUALA}, [1] = {MRKR_BLOISIRANT}, [2] = {MRKR_BLOISIRANT}, [3] = {MRKR_BLOISIRANT},
		[4] = {MRKR_AUBREY},
	},
	journal = function(seq)
		return TIME_LIMIT_MINUTES;
	end,
}
