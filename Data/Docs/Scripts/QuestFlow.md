# QuestFlow: shared story quest helpers

Script: [`Data/scripts/QuestFlow.lua`](../../scripts/QuestFlow.lua)

A quest script keeps Meteor's callback shape (onStart, onStateChange, onTalk, onPush, onEmote,
onNotice, onNpcLS, getJournalInformation, getJournalMapMarkerList) and uses these helpers for the
parts every quest repeats. Ported examples: `Quest/Man/Man0u0.lua`, `Man0u1.lua`, `Man1u0.lua`,
`Man2u0.lua`. The test QuestPhaseTableTests checks every script that requires this file.

## Phase tables

A quest declares, per sequence, the ENPCs it owns and the journal markers it shows:

```lua
PHASES = {
	[SEQ_000] = {
		enpcs = {
			WARBURTON,                                           -- talk only, no icon
			{ ASCILIA, QFLAG_TALK, when = isAsciliaMarked, push = canPushAscilia },
			{ EXIT_TRIGGER, QFLAG_PUSH, when = areLessonsDone, talk = false, push = true },
			{ crowd = SCENE_CROWD },                             -- a list of talk-only classes
		},
		markers = { MRKR_X, { MRKR_Y, when = isYMarked } },
	},
}

function onStateChange(player, quest, sequence) applyPhase(player, quest, PHASES, sequence) end
function getJournalMapMarkerList(player, quest) return unpack(phaseMarkers(player, quest, PHASES)) end
```

An `enpcs` entry is a class id, `{ crowd = {...} }`, or `{ classId, icon, when=, talk=, push=, emote=, spawn= }`.
`icon` is a QFLAG_* wire value (QFLAG_TALK "!", QFLAG_REWARD turn-in, QFLAG_PUSH for push circles,
QFLAG_OFF none) shown only while `when` holds. `talk` defaults to true, `push`/`emote`/`spawn` to
false. `when`/`talk`/`push`/`emote`/`spawn` may be booleans or predicates `fn(player, quest, data)`.
`enpcs` and `markers` may also be functions returning the list. `spawn = true` is for quest-gated
story actors (server_eventnpc_quest_gated).

## NPC linkshell flows

```lua
NPCLS_FLOW = {
	from = 1, sender = MOMODI_DISPLAY_ID,
	packs = { [SEQ_015] = {301, 302, 303}, [SEQ_045] = {301, 302, 303} },
	advances = { [SEQ_015] = SEQ_045 },
	onFirstRead = function(player, quest, sequence) end,   -- optional
}
function onNpcLS(player, quest, from, msgStep) readNpcLs(player, quest, NPCLS_FLOW, from, msgStep) end
```

A pack is readable at the sequence that armed it and at the one its read advances to, so list it
under both. One message per read (`msgStep`); the advance runs on the read itself because the client
sends nothing after a linkpearl read.

## Turn-in

```lua
turnInQuest(player, quest, "processEvent040", COMPLETION_REWARDS)
```

The closing scene, the reward window (completion rewards come from the client reward sheet), then
completion. A full inventory leaves the quest open so the player can make room and try again. A
rewards table as the first extra argument is the pay for quests the sheet has no row for (see
`payScriptRewards`); it is ignored when the sheet has one. Any further arguments go to the scene.

## Parley

A quest that needs a Parley won declares the board and two callbacks; nothing else:

```lua
PARLEY = { row = 3001, displayNameId = THICKSET_TAILOR_DISPLAY_ID, topics = { 1036, 1034, ... } }
function canParley(player, quest, npc)              -- is a Parley open on this npc now?
	return quest:GetSequence() == SEQ_015 and npc:GetActorClassId() == THICKSET_TAILOR
end                                                 -- (or return a board table to override PARLEY)
function onParleyEnd(player, quest, npc, outcome)   -- "won", "lost" or "abandoned"
	if outcome == "won" then setQuestFlagOn(quest, FLAG_PARLEY_WON) end
end
```

The Parley command (`Command/NegotiationCommand.lua`) hands the target to the held quest that owns
it, which runs `onParley`. The quest's setup scene ("target X and choose Parley") calls
`parleyAfterSetup`. `row` is the client's negotiationTable row; the client shows the Parley entry
only for an npc whose class has property bits 0 and 3 (propertyFlags | 9). The board itself is not
built yet: until it is, a Parley started either way counts as won (`PARLEY_BOARD_READY`).

## Duty content

`startQuestContent(player, def)` creates a SimpleContent area, binds its director and zones the player in.

| Field | Meaning |
|---|---|
| `def.zone` | parent zone id (default: the zone the player is in) |
| `def.content` | content script name, `Content/<content>.lua`, also the area name |
| `def.director` | director script under `Director/` (its `init()` names the client director class) |
| `def.x, y, z, rot` | arrival point |
| `def.spawnType` | 15 by default; 16 only when the director's notice plays a cutscene that drops the client's Now Loading screen |

Call it with the asking event still open; it ends the event. Returns the area and its director (nil
when the area could not be made).
