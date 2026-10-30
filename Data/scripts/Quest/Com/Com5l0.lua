require("Com5Visit")

--[[

Quest Script

Name: 	Imperial Devices (Limsa Lominsa)
Code: 	Com5l0
Id: 	111410
Prereq: Com0l7, the enlistment (seed_msq_limsa_20_com0l.sql). Level 25.

Offer: Guincum (processEventGUINCUMStart).
SEQ_000 Brother Zerig at Stillglade Fane hands over the urn -> SEQ_001.
SEQ_001 Bloisirant at Silent Arbor -> SEQ_002, then the go-in.
SEQ_002 Bloisirant asks to go in. Inside, the moogle (push) -> SEQ_003, back outside.
SEQ_003 Bloisirant -> SEQ_004.
SEQ_004 Guincum, rewards.

The visit is the Thousand Maws of Toto-Rak, parties of 2 to 4. Journal int6 = 1/2/3 shows the quest
items: 1 while the urn is carried, 2 after. The copy is per player and the time limit is on the duty; the
steps, the go-in and the duty are com5visit.lua's. Spawns and gates: seed_msq_limsa_20_com0l.sql; inside
trigger: content/SimpleContentCom5l001.lua.

--]]

local PARTY_MIN				= 2
local PARTY_MAX				= 4
local MIN_LEVEL				= 25
local TIME_LIMIT_MINUTES		= 60	-- The journal prints this value; the client has no default.


local GUINCUM					= 1500199
local ZERIG					= 1000510
local BLOISIRANT				= 1001150
local MOOGLE_TRIGGER			= 1090348	-- inside the copy

local MRKR_ZERIG				= 11154901
local MRKR_BLOISIRANT			= 11154902
local MRKR_GUINCUM			= 11154903

VISIT = {
	giver = GUINCUM,
	offer = {"processEventGUINCUMStart", 0, 0, 0},
	giverRepeat = {"processEvent_000"},
	talks = {
		[0] = {npc = ZERIG, call = {"processEvent_005", 0, 0, 0}, next = 1},
		[1] = {npc = BLOISIRANT, call = {"processEvent_010", PARTY_MAX, MIN_LEVEL, TIME_LIMIT_MINUTES}, next = 2, enter = true},
		[3] = {npc = BLOISIRANT, call = {"processEvent_020", 0, 0}, next = 4},
	},
	enter = {seq = 2, npc = BLOISIRANT, ask = {"processEvent_010_01"}},
	inside = {trigger = MOOGLE_TRIGGER, call = {"processEvent_015", 0}},
	after = 3,
	reward = {seq = 4, npc = GUINCUM, call = {"processEvent_025", 0, 0}},
	repeats = {
		[ZERIG] = {"processEvent_005_01"},
		[BLOISIRANT] = {"processEvent_020_2", 0},
	},
	npcs = {ZERIG, BLOISIRANT},
	public = {[ZERIG] = true},
	party = {min = PARTY_MIN, max = PARTY_MAX, level = MIN_LEVEL},
	partyCall = {"menberCountUnderRange", PARTY_MIN, PARTY_MAX, MIN_LEVEL},
	minutes = TIME_LIMIT_MINUTES,
	duty = {zone = 159, area = "SimpleContentCom5l001", director = "Quest/QuestDirectorCom5l001",
		anchor = {897.4, -28.06, 660.2, 0.74}},						-- inside the entrance door, facing in
	outside = {154, 843.6, -13.33, 640.0, 0.85},					-- Silent Arbor, facing Bloisirant
	markers = {
		[0] = {MRKR_ZERIG}, [1] = {MRKR_BLOISIRANT}, [2] = {MRKR_BLOISIRANT}, [3] = {MRKR_BLOISIRANT},
		[4] = {MRKR_GUINCUM},
	},
	journal = function(seq)
		local item = (seq == 1 or seq == 2) and 1 or ((seq >= 3) and 2 or 0);
		return TIME_LIMIT_MINUTES, 0, 0, 0, item;
	end,
}
