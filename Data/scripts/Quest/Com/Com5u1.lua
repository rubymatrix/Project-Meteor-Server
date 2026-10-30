require("Com5Visit")

--[[

Quest Script

Name: 	Into the Dark (Ul'dah)
Code: 	Com5u1
Id: 	111811
Prereq: Com5u0 (seed_msq_uldah_20_com0u.sql). Level 45.

Offer: Aubrey (processEventAUBREYStart).
SEQ_000 Ser Vairemont at Owl's Nest -> SEQ_001.
SEQ_001 the Darkhold entrance, with Dyrstweitz as the marked NPC -> SEQ_002, then the go-in.
SEQ_002 Dyrstweitz asks to go in. Inside, the primus ordinarius and his men (push); the win -> SEQ_003.
SEQ_003 Vairemont -> SEQ_004.
SEQ_004 Aubrey, rewards.

The visit is Dzemael Darkhold, parties of 4 to 8. The copy is per player and the time limit is on the
duty; the steps, the go-in and the duty are com5visit.lua's. Spawns and gates:
seed_msq_uldah_20_com0u.sql; inside trigger: content/SimpleContentCom5u101.lua.

--]]

local PARTY_MIN				= 4
local PARTY_MAX				= 8
local MIN_LEVEL				= 45
local TIME_LIMIT_MINUTES		= 60	-- The journal prints this value; the client has no default.


local AUBREY					= 1500198
local VAIREMONT				= 1000586
local DYRSTWEITZ				= 1001154
local SPOT_TRIGGER			= 1090358	-- inside the copy

local MRKR_AUBREY				= 11175001
local MRKR_OWLS_NEST			= 11175002
local MRKR_VAIREMONT			= 11175003
local MRKR_DYRSTWEITZ			= 11175004

VISIT = {
	giver = AUBREY,
	offer = {"processEventAUBREYStart", PARTY_MAX, MIN_LEVEL, TIME_LIMIT_MINUTES},
	giverRepeat = {"processEvent_000"},
	talks = {
		[0] = {npc = VAIREMONT, call = {"processEvent_010", PARTY_MAX, MIN_LEVEL, TIME_LIMIT_MINUTES}, next = 1},
		[1] = {npc = DYRSTWEITZ, call = {"processEvent_020", PARTY_MAX, MIN_LEVEL, TIME_LIMIT_MINUTES}, next = 2, enter = true},
		[3] = {npc = VAIREMONT, call = {"processEvent_030"}, next = 4},
	},
	enter = {seq = 2, npc = DYRSTWEITZ, ask = {"processEvent_020_1"}},
	inside = {trigger = SPOT_TRIGGER, level = 46, pos = {65.2, 174.70, 110.2}, enemies = {
		{9280002,  0.0, -3.0},	-- duty_imperial_triarius: the primus ordinarius
		{100273,  -3.0, -1.0},	-- imperial_secutor
		{100274,   3.0, -1.0},	-- imperial_signifer
	}},
	after = 3,
	reward = {seq = 4, npc = AUBREY, call = {"processEvent_040"}},
	repeats = {
		[DYRSTWEITZ] = {"processEvent_020_2"},
	},
	npcs = {VAIREMONT, DYRSTWEITZ},
	public = {[DYRSTWEITZ] = true},
	party = {min = PARTY_MIN, max = PARTY_MAX, level = MIN_LEVEL},
	partyCall = {"menberCountUnderRange", PARTY_MAX, MIN_LEVEL},
	minutes = TIME_LIMIT_MINUTES,
	duty = {zone = 231, area = "SimpleContentCom5u101", director = "Quest/QuestDirectorCom5u101",
		anchor = {95.8, 179.90, 212.2, 3.14}},						-- the entrance hall, facing in
	outside = {143, -70.35, 248.47, 391.90, -2.0},				-- the Darkhold entrance, facing Dyrstweitz
	markers = {
		[0] = {MRKR_VAIREMONT, MRKR_OWLS_NEST}, [1] = {MRKR_DYRSTWEITZ}, [2] = {MRKR_DYRSTWEITZ},
		[3] = {MRKR_VAIREMONT, MRKR_OWLS_NEST}, [4] = {MRKR_AUBREY},
	},
	journal = function(seq)
		return TIME_LIMIT_MINUTES, 0, 0, 0, (seq == 3) and 1 or 0;
	end,
}
