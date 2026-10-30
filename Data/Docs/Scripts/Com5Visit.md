# Com5Visit: shared Com5 dungeon visit quests

Script: [`Data/scripts/Com5Visit.lua`](../../scripts/Com5Visit.lua)

The Com5 dungeon visits (Com5l0/g0/u0 Toto-Rak, Com5l1/g1/u1 Dzemael Darkhold) share one shape: the
officer's offer, NPC visits, an entrance NPC who briefs and asks to go in, one objective inside under
a time limit, NPC visits back, the officer's reward. A quest script sets `VISIT` and requires this file.
The content runs on QuestBattle variant `Com5Visit`; `questBattleOptions` passes it the time limit and
the fight a push brings in.

## VISIT fields

| Field | Meaning |
|---|---|
| `giver` | Officer class; `offer = {fn, args...}`; `giverRepeat = {fn, args...}` |
| `talks` | `[seq] = {npc, call = {fn, args...}, next = seq [, enter = true]}`; `enter` asks to go in right after |
| `enter` | `{seq, npc, ask = {fn, args...}}`: the go-in talk; reply 1 = in. Inside is `enter.seq`. |
| `inside` | `{trigger, call = {fn, args...}}`: the push inside that wins the objective. Or with `enemies = {{poolId, dx, dz}...}`, `level`, `pos`: the push brings in the fight and the win completes it; `won = {fn, args...}` plays after that win. |
| `after` | Sequence after the objective |
| `reward` | `{seq, npc, call = {fn, args...}}` |
| `repeats` | `[npc] = {fn, args...}`: that NPC's line when it is not their step |
| `npcs` | Every story NPC class; `public = {[class] = true}` for the ones with a public spawn (the others are quest-gated, so `isSpawned` is set) |
| `party` | `{min, max, level}`; `partyCall = {fn, args...}`: shown when the party is bigger than max |
| `minutes` | Time limit |
| `duty` | `{zone, area, director, anchor = {x, y, z, rot}}` |
| `outside` | `{zone, x, y, z, rot}`: where the player comes out |
| `markers` | `[seq] = {marker ids}` |
| `journal` | `function(seq)` returning int2, int3, ... (int1 is the sequence) |

The copy is per player: party members are not taken along, so only the upper party bound is checked.
The lower bound would lock solo players out of a copy they enter alone.
