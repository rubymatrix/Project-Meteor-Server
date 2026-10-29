# AI and content scripting

How battle npcs think and how scripted content (quest battles, dungeons, trials, caravan escorts,
hamlet defense) runs on the map server.

## Pieces

| Piece | Where | What it does |
|---|---|---|
| Brain | `Map Server/AI/Brain.cs` | Drives one npc: a set of behaviors competing for channels, a blackboard, the npc's script object. Replaces the old per-class controllers. |
| Behaviors | `Map Server/AI/Behaviors/` | Stock conduct in C#: Idle, Roam, Patrol, Detect, Link, Combat, Leash, Follow, Assist, Guard, Escort, Command, Flee, Avoid, Mechanic, Hold, Walk, Fear, Charm, Confuse. Lua behaviors live in `scripts/ai/behaviors/`. |
| Perception | `Map Server/AI/Perception.cs` | Senses (sight, sound, magic, low HP, proximity), level gap, target filters. |
| Factions | `Map Server/AI/Factions.cs`, `scripts/ai/factions.lua` | Who is hostile, neutral, friendly or ignored. Content can override relations for its own actors. |
| Hate | `Map Server/Actors/Chara/Ai/HateContainer.cs` | Enmity with modes: normal, locked (only listed tags), weighted (tag weights), fixed. |
| Events | `Map Server/AI/ActorEvents.cs` | Typed events queued during a tick step and drained after it. |
| Content | `Map Server/Content/` | Encounters (roster, phases, objectives, arena, hazards, scores), the content manager. |
| Script runtime | `scripts/ai/runtime/`, `Map Server/Scripting/` | Loads profiles and content once, keeps their objects, runs their tasks. |

## Tick order

The zone loop holds the world lock and, each tick: advances the game clock, drains events, updates
every zone (actors, then the encounters in that zone), resumes Lua tasks that are due, and drains
events again. `GameClock` is the only clock AI and content code reads; tests step it by hand.

## Channels and priority

A behavior asks for channels each tick: Move, Face, Target, Act, Sense, Speak. The brain gives each
channel to the highest-priority behavior that wants it; behaviors that lost a channel still tick
with what they hold. Bands: Control 950 (status effects), Script 850, Mechanic 700, Survival 500,
Combat 400, Role 300, Ambient 100. The brain does nothing while the npc's action state cannot change
(mid-cast, dead).

## Profiles

A profile is a Lua table: faction, tags, senses, hate mode, behaviors with parameters, action rules,
think rate and hooks. An npc's profile resolves at spawn from layers, later ones winning:

1. kind: `ai/kinds/<battlenpc|ally|pet|structure|ambient>`
2. family: `ai/families/<name>` (genus id to name in `ai/families/index.lua`)
3. pool: `ai/pools/<poolId>`
4. placement: `ai/zones/<zone>/<spawnId>`
5. content: the spawn spec's `profile` and `override`
6. runtime: `actor:add`, `remove`, `set`, `push`

Merge rules: tables merge key by key and other values replace. `behaviors.X = false` removes X;
`behaviors.X = { replace = true, ... }` drops what lower layers set. `rules` replace unless given as
`{ append = {...} }` or `{ prepend = {...} }`. Hooks (`on<Event>`, `think`) chain: the most
specific layer runs first, and returning `"stop"` skips the layers below it.

```lua
return Profile.extend("ai/kinds/battlenpc") {
    senses = { sound = { range = 12 } },
    behaviors = { Link = { radius = 14, by = "family" }, Roam = false },
    rules = { { use = 27110, on = "target", when = "self:tp() >= 1000" } },
    onHp = { [25] = function(self) self:push("Hold", { channels = { "Move" } }) end },
}
```

## Action rules

`Combat` asks the profile what to use whenever the npc is free. Rules:
`{ use = actionId, on = selector, when = condition, tier = n, weight = w, cooldown = s, max = n, phase = name }`.
Tiers are tried lowest first; in a tier the passing rules are picked by weight. `when` is a function
`(self, target, enc)` or a string such as `"self:tp() >= 1000"`.

Selectors: `self`, `target`, `leader`, `owner`, `lowestAlly`, `lowestAllyBelow(pct)`, `allyWith(id)`,
`allyWithout(id)`, `enemyWith(id)`, `enemyWithout(id)`, `random`, `randomPlayer`, `nearest`,
`farthest`, `mostHated`, `tag(name)`, or a function.

## Events

`Spawned`, `Despawned`, `Died`, `Raised`, `Aggro`, `Engaged`, `Disengaged`, `TargetChanged`,
`Damaged`, `Healed`, `HpCrossed`, `CastStarted`, `CastInterrupted`, `ActionDone`, `StatusGained`,
`StatusLost`, `WaypointReached`, `PathFailed`, `EnteredRegion`, `LeftRegion`, `Talked`, `ItemGiven`,
`Emoted`, `BehaviorEnded`, `Fled`, `Recovered`, `PhaseChanged`, `ObjectiveChanged`, `EncounterEnded`,
`HazardResolved`, `Signal`.

An actor's event goes to its behaviors, its profile hooks, the content that owns it (and that
content's parents), then the zone script. A handler that returns `"handled"` stops default handling.
`HpCrossed` fires for each threshold someone registered, once per crossing.

## Content

Content is named after the client director it runs under where there is one, and lives in
`scripts/content/<client folder>/<name>.lua`:

| Folder | Kind | Example |
|---|---|---|
| `content/quest` | quest battles | `QuestDirectorMan0g001`, `QuestDirectorMan0g101` |
| `content/occupancy` | dungeons (`/Director/Occupancy/Raid*`) | `RaidRoc0Dungeon01` (Dzemael Darkhold) |
| `content/instanceraid` | trials (`/Director/InstanceRaid/*`) | `InstanceRaidLesserIfrit`, `InstanceRaidNormalIfrit`, `InstanceRaidHyperIfrit` |
| `content/caravanguard` | caravan escorts (client `ChocoboCaravanGuard`) | `CaravanGuardTranquil` |
| `content/hamletdefense` | hamlet battles (client `HamletGuard`, `HamletDefenseScore`) | `HamletDefenseAleport` |
| `content/campaigns` | long cycles that survive restarts | `HamletAleport` |
| `content/zones` | zone scripts | `fst0Field05` |
| `content/profiles` | profiles content spawns with | `OpeningAlly`, `ChocoboCaravanGuard`, `HamletGuard` |

Three definers: `Encounter.define(name)` (a fight in an area someone gives it),
`ContentArea.define(name)` (creates its own private content area from `area = { zone, classPath,
name, script, director }` and warps the starter to `entry`), `WorldEvent.define(name)` (open world;
participants who wander off stay in it).

A content object has: participants, a roster in named groups, phases (`phase_<name>` runs as a task
on entry; tasks and triggers made in a phase end with it), tasks (`run`, `after`, `every`, and inside
them `wait`, `waitUntil`, `waitEvent`), triggers (`on`, `once`, `onHp`, `onRegion`), objectives,
an arena with regions, doors and hazards, scores and counters, a seeded random generator, and
variants (`Encounter:variant(name, cfg)`; `:as(name)` makes a copy whose default variant is name, so
each client director can be its own file over one mechanics module).

Objectives: `kill(group)`, `protect(group, min)`, `reach(group, point, min, radius)`,
`survive(seconds)`, `hold(region, seconds)`, `count(counter, n)`, `custom(fn)`. Roles: `wins`,
`required`, `fails`, `score`. Built-in failures: time limit, every participant KO'd, every
participant gone.

Lifecycle: Created, Ready (`setup` ran), Running (`onStart`), Ending (`onEnd`; hostiles hold,
rewards), Closed (roster despawned, objects freed).

Starting content: from Lua, `StartContent(name, variant, area, player, opts)`; from C#,
`ContentManager.Start`. Dev: `!content start <name> [variant]`, `!content list|win|fail|phase`,
and `!ai show|add|remove|reset` on a targeted npc.

## Data

Example pools: `Data/sql/seed/seed_ai_content_examples.sql` (stand-in models). Saved campaign state:
`server_content_state`. Lockouts: `characters_content_lockouts`.

## Limits

- Hit points are 16-bit in the client's character work; spawn specs clamp `hp` to 32767.
- The client director class for hamlet battles is not known; `HamletDefenseAleport` borrows an
  occupancy director and sends no score widget.
- Caravan and hamlet routes, waves and numbers are placeholders until checked against captures.
