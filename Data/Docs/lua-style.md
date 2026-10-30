# Lua Style Proposal

## Rules

### Names

- **Functions, methods, locals, parameters, table fields** — style: camelCase; examples: `finishEscort`, `self:pullPack()`, `pickInterval`
- **Constants** — style: UPPER_SNAKE; examples: `SEQ_005`, `TANK_PULL_SECONDS`, `QFLAG_TALK`
- **Enum tables and their members** — style: PascalCase; examples: `Action.Cure`, `StatusEffectId.Sleep`, `CommandType.Weaponskill`
- **Classes and namespaces with behavior** — style: PascalCase; examples: `Profile`, `Encounter`, `Moves`
- **Function libraries** — style: lowercase; examples: `actions`, `formulas`, `stats`, `magic`, `json`

Acronyms are words.

```lua
-- no
function AddGCSeals(player, amount) end
local TEXT_ID = 25018
-- yes
function addGcSeals(player, amount) end
local TEXT_TIME_MINUTES = 25018
```

### Names the server owns

Written exactly as the server spells them, never renamed or wrapped:

- C# members: `player:GetQuest()`, `npc.charaWork`, `GetWorldManager()`.
- Callbacks the server calls by name: `init`, `main`, `onEventStarted`, `onTalk`, `onPush`,
  `onNotice`, `onTrigger`, `onCreate`, `onDestroy`, `onLogin`, `onBeginLogin`, `onGain`, `onLose`,
  `onTick`, `onSkillFinish`, `onSpawn`, `onZoneIn` and the other `on*` hooks.
- `rt_*`: the AI runtime's entry points for C#.

### Client names

Anything the client names keeps the client's name: quest codes (`Man0l0`), directors
(`QuestDirectorMan0l101`), private areas (`SimpleContent30002`), actor classes
(`FighterAllyOpeningHealer`), commands (`ActivateCommand`), zones (`fst0Field05`), statuses
(`Sleep`), battle commands (`cure`). In code it takes the style of what it is: a constant
`QUEST_MAN0L1`, an enum member `Action.Cure`, a key `["Man0l1"]`. Only things the client never
names get our own names.

### File and folder names

Every folder and file uses the client's scheme: PascalCase, spelled exactly as the client spells
it. A script for a client class lives at that class's client path, for example:

- `/Chara/Npc/Populace/PopulaceStandard`
- `/Quest/Man/Man0l0`
- `/Director/Quest/QuestDirectorMan0l001`
- `/Status/StatusBaseClass`

Our own files follow the same scheme. A path is only lowercase where the client's own name is,
like the zone `fst0Town01`.

Today's paths and where they would move:

```text
Today                                          Proposed
base/chara/npc/populace/PopulaceStandard.lua   Chara/Npc/Populace/PopulaceStandard.lua
directors/Quest/QuestDirectorMan0l001.lua      Director/Quest/QuestDirectorMan0l001.lua
quests/man/man0l0.lua                          Quest/Man/Man0l0.lua
commands/ActivateCommand.lua                   Command/ActivateCommand.lua
commands/magic/fire.lua                        Command/Magic/Fire.lua
commands/gm/warp.lua                           Command/Gm/Warp.lua
effects/sleep.lua                              Status/Sleep.lua
content/SimpleContent30002.lua                 Area/PrivateArea/Content/SimpleContent30002.lua
unique/fst0Town01/PopulaceStandard/<id>.lua    Unique/fst0Town01/PopulaceStandard/<id>.lua
global.lua                                     Global.lua
battleutils.lua                                BattleUtils.lua
statuseffectids.lua                            StatusEffectIds.lua
battlenpc_stats.lua                            BattleNpcStats.lua
ai/kinds/battlenpc.lua                         Ai/Kinds/BattleNpc.lua
battle/actions.lua                             Battle/Actions.lua
content/quest/opening.lua                      Content/Quest/Opening.lua
content/profiles/OpeningAlly.lua               Content/Profiles/FighterAllyOpening.lua
routes/caravanguard_fst0Field05.lua            Routes/CaravanGuard/fst0Field05.lua
```

What the server's lookup changes for each:

- `Chara/` actor scripts: built from the actor class path as the client spells it. The lowercased
  copy the server sends the client stays as it is.
- `Director/`, `Command/`, `Unique/`: only the root folder's name changes.
- `Command/` is one folder: commands are found by name, so the client's `Game` and `System`
  split isn't copied.
- `Quest/`: one folder per quest prefix (`Man`, `Etc`, `Dft`), then the quest code exactly as
  `gamedata_quests` has it, no longer lowercased. Only main-story quests have a known client
  folder (`Scenario`), so that level is left out.
- `Command/Magic/` and the other battle command folders: the command's DB name in PascalCase,
  the same name as `Action.Fire`.
- `Command/Gm/`: the typed GM command in PascalCase.
- `Status/`: the status's DB name in PascalCase.
- `Area/PrivateArea/Content/`: content areas sit under the client's private area folder.
- `BattleNpcStats.lua`: its path is written in the server code, so that changes too.
- `Ai/` and `Battle/`: the AI runtime's module names change with the files.
- `Content/` and `Routes/`: the AI runtime finds them by name under those folders.

`require` follows the file: `require("Global")`, `require("Battle/Actions")`.

### Scope

Each script runs in its own globals. `require` runs the other file inside the caller's globals,
so a required file's globals are how its callers reach it (a director calls its quest's
`finishEscort` and reads `SEQ_050`).

- `local` for everything a file uses alone.
- Global only for server callbacks, a GM command's `properties`, and what a shared file exists to
  provide (`Global.lua`'s constants, a quest's functions its director calls).
- AI runtime modules (`Ai/`, `Content/`) build a local table and `return` it.

```lua
-- no: only this file calls it
function getQuestInfo(player, questId)
-- yes
local function getQuestInfo(player, questId)
```

### Quest sequences: maps, not if/else chains

A quest's `onTalk`, `onPush` and the like look their handler up in a table keyed by sequence, then
by NPC class id. One function per sequence and NPC. `runQuestHandler` (in `Quest.lua`) does the
lookup and returns what the handler returned; a handler returns `true` when it has already ended
the event itself.

```lua
-- no
function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()
	if sequence == SEQ_000 then
		if classId == TATARU then
			...
		end
	elseif sequence == SEQ_005 then
		if classId == MINFILIA then
			...
		elseif classId == TATARU then
			...
		end
	elseif ...
	end
	player:EndEvent()
end

-- yes
local talk = {
	[SEQ_000] = {
		[TATARU] = function(player, quest) ... end,
	},
	[SEQ_005] = {
		[MINFILIA] = function(player, quest) ... end,
		[TATARU] = function(player, quest) ... end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
end
```

The helper, added to `Quest.lua`:

```lua
function runQuestHandler(handlers, player, quest, npc, ...)
	local classId = npc:GetActorClassId()
	local byNpc = handlers[quest:GetSequence()] or {}
	local handler = byNpc[classId] or (handlers.always and handlers.always[classId]) or byNpc.other or handlers.other
	return handler ~= nil and handler(player, quest, npc, ...)
end
```

A handler two NPCs or sequences share is a local function named once and used in each entry.

Two more keys cover what a plain lookup can't. `always` holds NPCs answered the same in every
sequence (doors, exits). `other`, inside a sequence or at the top of the table, takes any NPC
without its own entry: chatter, or a class only known at run time such as the player's companion.
A sequence's own entry wins over `always`, and both win over `other`.

```lua
local push = {
	[SEQ_000] = {
		[OFFICE_DOOR] = playOfficeScene,
	},
	always = {
		[OFFICE_DOOR] = enterOffice,
		[EXIT_DOOR] = leaveOffice,
	},
	other = function(player, quest, npc)
		delegateChatter(player, quest, CHATTER, quest:GetSequence(), npc:GetActorClassId())
	end,
}
```

### AI profiles

A battle npc's AI is built from profiles stacked in a fixed order. Each layer is optional, and a
later layer changes what an earlier one set.

1. Kind, from the npc's server class: `Ai/Kinds/BattleNpc.lua` for everything that fights.
   `Ally.lua` builds on it for npcs on the players' side. `Structure.lua` and `Ambient.lua` stand
   alone, for things that never fight.
2. Pool flags: `Detect` when the pool is aggressive (`aggroType`), `Link` when it links
   (`linkType`).
3. Family, by genus: `Ai/Families/Wolf.lua`. `Ai/Families/Index.lua` maps genus ids to family
   names.
4. Pool: `Ai/Pools/<poolId>.lua`, one kind of mob.
5. Spawn: `Ai/Zones/<zone>/<spawnId>.lua`, one placed mob in one zone.
6. Content profile: `Content/Profiles/<Name>.lua`, a role a fight gives its npcs
   (`FighterAllyOpening`, `HamletGuard`).
7. Override: the table a spawn passes as `override`, for this one npc.

Naming:

- Kinds are named after the server class and families after the client's family folder
  (`Monster/Wolf`), in PascalCase like every other file. The server's `Kind` strings change to
  match (`BattleNpc`, `Ally`).
- Behaviors are PascalCase because each is a server class (`Follow`, `Ready`, `Combat`) or a Lua
  behavior made with `Behavior.define("Harass")`. Their settings are camelCase (`pickInterval`,
  `onlyWhenAttacked`).
- Actions are named through the generated `Action` table (`Action.Cure`). Family TP moves live in
  `Moves.Genus`, and boss move sets in `Moves.Sets` (`Moves.Sets.Ifrit`).

Only kinds use `Profile.extend`, and only from `BattleNpc`. Families, pools, spawns and content
profiles use `Profile.define`: the kind is already first in the stack, and extending it again
would undo every layer between.

How a later layer changes an earlier one:

- `behaviors`: settings merge into the earlier ones; `Name = false` removes the behavior;
  `replace = true` swaps the whole table.
- `rules`: a plain list replaces the earlier rules; `{ append = {...} }` and
  `{ prepend = {...} }` add to them.
- `on*` hooks stack: every layer's runs, the latest layer's first.
- `tags` add up; anything else is replaced.

```lua
--[[
Hamlet militia: hold a post, fight anything hostile that comes close, never follow or wander.
--]]
return Profile.define {
	behaviors = {
		Follow = false,
		Assist = { group = "guards", range = 20 },
		Guard = { radius = 14, pace = "run" },
		Combat = {},
	},
	rules = {
		{ tier = 1, use = Action.HeavySwing, on = "target", when = "self:tp() >= 1000" },
	},
}
```

```lua
self:spawn("guards", {
	pool = POOL_GUARD, kind = "ally", at = post,
	profile = "Content/Profiles/HamletGuard",
	override = { behaviors = { Guard = { point = post } } },
})
```

### Encounters

A fight's script is named after the client director that runs it: `Encounter.define("QuestDirectorMan0l101")`
in `Content/Quest/QuestDirectorMan0l101.lua`, `ContentArea.define("RaidRoc0Dungeon01")` for a
whole instanced area. Fights that share their rules keep them in one file named for what they
are (`Content/Quest/Opening.lua`, `Content/InstanceRaid/Ifrit.lua`), with a variant per director:

```lua
local Opening = Encounter.define("Opening")
Opening:variant("g", { allies = { ... }, enemyPool = 2 })
```

and each director's file is one line: `return require("Content/Quest/Opening"):as("g")`.

### Layout

- Indent with tabs, like the original Meteor scripts.
- No semicolons at the ends of lines, and `end` rather than `end;`.
- No parentheses around a whole `if` or `while` condition.
- `~=` for not-equal, never `!=`.
- No space between `require` and its parenthesis: `require("Global")`.
- Double quotes for strings.
- Server methods called with `:`, never `.` with the object passed by hand.

The same function before and after (the second one is indented with tabs):

```lua
-- no
require ("global")

function onEventStarted(player, command, argc)
    if (argc != 4) then
        player.EndEvent(player);
        return;
    end;
    if (type(command) == 'table') then
        player:EndEvent();
    end
end;

-- yes
require("Global")

function onEventStarted(player, command, argc)
	if argc ~= 4 then
		player:EndEvent()
		return
	end
	if type(command) == "table" then
		player:EndEvent()
	end
end
```

Two exceptions: a semicolon stays where the next line starts with `(`, which Lua would otherwise
read as a call, and single quotes stay where the string holds a double quote.

### Comments

- A file explains itself in one `--[[ ... --]]` block at the top, after its `require` lines.
- No explanation inside the code; a line comment is a rare note the code can't say.
- No comment that repeats a name, key or parameter list.
- Generated files: two header lines, what it is and what generated it.

## What changes if adopted

Counts are from the 655 scripts on `feature/ai-redesign`.

### Automatic fixes

A tool rewrites these, and each pass is checked token by token, so no script behaves differently.

- Semicolons removed from 11,380 lines in 517 files (commands, effects, quests, base, directors).
- `end;` becomes `end` in 747 places (effects, commands, quests).
- Parentheses removed from 1,419 conditions (everywhere except `Ai/` and `Battle/`).
- `require (` becomes `require(` on 357 lines (quests, base, directors).
- `!=` becomes `~=` in 19 places (commands, quests, populace, effects).
- About 540 single-quoted strings become double-quoted, mostly in `ai/runtime`.
- 4-space indents become tabs in 323 files (`Ai/`, `Battle/`, `Content/`, statuses, many commands).

### Renames

- Every file and folder takes the client's capitalization: 655 files in 12 folders, 868 `require`
  lines, about 30 module paths in the AI runtime and content, and the server lookups listed under
  File and folder names.
- `modifiersGlobal` becomes `Modifier` and `mobModifiersGlobal` becomes `MobModifier`: 155 uses in
  74 files.
- 9 PascalCase functions become camelCase, with 1 to 6 uses each: `AddGCSeals`, `GetGCSeals`,
  `CalculateDamage`, `HandleAttackSkill`, `HandleHealingSkill`, `HandleStoneskin`, `SendTutorial`,
  `Vec` and `onTalk_shipSequences`. None is called by name from C#. `IsQuestENPC` keeps its name:
  the server calls it by name.
- The `OpeningAlly` profile becomes `FighterAllyOpening`: 1 file, 3 spawns.
- The server's `Kind` strings `battlenpc` and `ally` become `BattleNpc` and `Ally`, and the
  family names in `Ai/Families/Index.lua` become PascalCase.
- The shared encounters `opening` and `ifrit` become `Opening` and `Ifrit`.

### Checked one at a time

- About 1,030 globals only their own file can reach become `local`. A file's globals stay global
  when the server names them, a file that requires it uses them, or a library it requires reads
  them. Where a function is used above its definition, a `local a, b` line after the `require`s
  declares it first. `EquipCommand.lua` keeps its slot constants global: as locals they pass
  LuaJIT's limit of 60 upvalues per function.
- 41 quests' `onTalk` or `onPush` become maps. A script compares each against its original: every
  sequence, every number in the file as the NPC, and four client replies, with the calls each makes
  recorded and matched. Every quest file was also compared against its version before any of
  these changes.
- Two dead branches were dropped along the way: `Man2g0`'s `SEQ_15` and `Pgl200`'s
  `ENPC_PUSH_PGL` name constants that don't exist, so they never matched. Both were empty.

### Rewritten by hand

- About 30 quest handlers keep their if/else chains for now: they test sequence ranges, flags or
  quest state alongside the NPC (`Man0g0`, `Man0l0`, `Man0u0`, `Man200`, the `Dft` and `Trl`
  quests), so a map needs judgment per quest and a playthrough.

### Before and after

`commands/AttackWeaponSkill.lua`, which mixes tabs and spaces in one function:

```lua
-- before
function onEventStarted(player, command, eventType, eventName, arg1, arg2, arg3, arg4, targetActor, arg5, arg6, arg7, arg8)
	--Are they in active mode?
	if (player:GetState() != 2) then
		player:SendGameMessage(GetWorldMaster(), 32503, 0x20);
		player:EndEvent();
		return;
	end
    if not player.aiContainer:IsEngaged() then
        player:Engage(targetActor);

-- after
function onEventStarted(player, command, eventType, eventName, arg1, arg2, arg3, arg4, targetActor, arg5, arg6, arg7, arg8)
	if player:GetState() ~= 2 then
		player:SendGameMessage(GetWorldMaster(), 32503, 0x20)
		player:EndEvent()
		return
	end
	if not player.aiContainer:IsEngaged() then
		player:Engage(targetActor)
```

`quests/man/man200.lua`, `onTalk` (first three sequences):

```lua
-- before
function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_000) then
		if (classId == TATARU) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2");
		end
	elseif (sequence == SEQ_005) then
		if (classId == MINFILIA) then
			callClientFunction(player, "delegateEvent", player, quest, "pE20", "???", 1, 1, 1, player:GetInitialTown());
			quest:StartSequence(SEQ_010);
		elseif (classId == TATARU) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2");
		end
	elseif (sequence == SEQ_010) then
		if (classId == MINFILIA) then
			local didJoinPoT = callClientFunction(player, "delegateEvent", player, quest, "pE25", "???", 1, 1, 1, player:GetInitialTown());
			if (didJoinPoT == 1) then
				player:EndEvent();
				GetWorldManager():WarpToPosition(player, -142.75, 1, -160, -1.6);
				quest:StartSequence(SEQ_020);
				return;
			end
		elseif (classId == TATARU) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_2");
		end
	elseif ...
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

-- after
local function tataruIdle(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2")
end

local talk = {
	[SEQ_000] = {
		[TATARU] = tataruIdle,
	},
	[SEQ_005] = {
		[MINFILIA] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "pE20", "???", 1, 1, 1, player:GetInitialTown())
			quest:StartSequence(SEQ_010)
		end,
		[TATARU] = tataruIdle,
	},
	[SEQ_010] = {
		[MINFILIA] = function(player, quest)
			local didJoinPoT = callClientFunction(player, "delegateEvent", player, quest, "pE25", "???", 1, 1, 1, player:GetInitialTown())
			if didJoinPoT == 1 then
				player:EndEvent()
				GetWorldManager():WarpToPosition(player, -142.75, 1, -160, -1.6)
				quest:StartSequence(SEQ_020)
				return true
			end
		end,
		[TATARU] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_2")
		end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end
```

`effects/sleep.lua` (the old comment is copied from another effect and wrong, so it goes):

```lua
-- before
require("modifiers")

--Set magnitude to milliseconds that HF will reduce delay by
function onGain(owner, effect, actionContainer)
end;

-- after
require("modifiers")

function onGain(owner, effect, actionContainer)
end
```

`commands/gm/quest.lua`, helpers nothing else calls:

```lua
-- before
function addQuest(player, questId)
function removeQuest(player, questId)

-- after
local function addQuest(player, questId)
local function removeQuest(player, questId)
```

Renames:

```lua
-- before
player:SetMod(modifiersGlobal.MinimumHpLock, 0);
SendTutorial(player, harvestJudge, 2)

-- after
player:SetMod(Modifier.MinimumHpLock, 0)
sendTutorial(player, harvestJudge, 2)
```

`ai/runtime/actor.lua`:

```lua
-- before
if type(t) ~= 'table' or getmetatable(t) ~= nil then return t end
-- after
if type(t) ~= "table" or getmetatable(t) ~= nil then return t end
```


## How it would be applied

1. `Tools/LuaApi` gets a lint rule and a fix for each layout rule, and a check that a fixed file
   lexes to the same tokens as before (apart from the removed semicolons and parentheses).
2. One commit per layout rule across all scripts, each passing that check and the test that loads
   every script.
3. File-only globals made `local`, from a cross-file scan of who requires whom and which names
   the server calls.
4. The renames. The file move goes with its server change: script paths in `LuaEngine` (quest
   lookup without lowercasing, the actor class path as the client spells it, PascalCase status,
   battle command and GM command names, the new root folders), `BattleNpcStats`, the runtime's
   module paths, and the test that requires lowercase quest names.
5. The style rules become lint errors, run in tests.

