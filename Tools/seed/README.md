# Monster spawn seed (bestiary -> Meteor battle NPCs)

`build_spawn_seed.py` turns the "Eorzea 1.x Bestiary" artifact (single-line `const D={...}` JSON
inside the HTML) into Meteor `server_battlenpc_*` seed SQL. It reads the repo SQL dumps
(`Data/sql/gamedata_actor_class.sql`, `server_zones.sql`, `server_battlenpc_genus.sql`) instead of
the live DB, so the output is reproducible offline.

```
python Tools/seed/build_spawn_seed.py --bestiary <artifact.html> [--max-per-group 10]
       [--respawn 90] [--nm-respawn 3600] [--y-mode zero|hint]
```

Output: `Data/sql/seed/seed_bnpc_0[1-5]_*.sql`, `seed_bnpc_99_rollback.sql`,
`seed_bnpc_manifest.csv` (one row per spawn with source/trust/approx/yHint/needsNavSnap), and
`Tools/seed/lua_stubs/base/...` (base class scripts). **Nothing is imported automatically.**
Apply in order 01 -> 05. Every file deletes its own ID range first, so re-running is safe.
Full set on a fresh database: 01 to 08, 10, 11, 12, 14, then 13 (15 to 19 roll back 14, 13, 12, 11, 10).
`seed_bnpc_06_extra_spawns.sql` is hand-maintained (not generated): extra spawn points for
existing groups, bnpcId 2000001-2099999. Apply it after 05.
`seed_bnpc_08_capture_shroud.sql` is hand-maintained too: Central Shroud (zone 150) monsters at
retail capture positions with captured variants/levels (pools/groups/bnpcIds 2100001-2100999). It
deletes the rounded generator copies of those points, so apply it after 05-07 and again after
any re-apply of 05.
`seed_bnpc_10_central_shroud_fixes.sql` (zone 150) and `seed_bnpc_11_black_shroud_fixes.sql` (151-154)
are hand-maintained play-test clean-ups: they drop low-trust high-level spots that land on starter
camps, drop leve-only monsters, and narrow level bands the generator took from the bestiary's all-zone
range (ids 2300001-2300999). Apply after 08 (and after any re-apply of 02/04/05/08); rollbacks 19 and 18.

## Bestiary schema (`D`)
| key | row layout |
|---|---|
| `mon` (1117) | `[name, family, kin, minLv, maxLv, regions, zones('; '), isNM('Y'), aggressive('Y'/'N'/''), spawnType('persistent' / 'leve-or-quest' / 'instanced-dungeon', may be '|'-joined), removedByARR, tier(A/B/C), sources, actorIds(space-sep), aliases, notes]` |
| `zones` (29) | zone names, indexed by `pts[3]` |
| `pts` (6213) | `[mapX, mapY, monIdx(-1 = unnamed), zoneIdx, src(0 retail capture, 1 Navmut, 2 AuroraFlare), label]` - region-map coords at 0.1 precision; retail rows are unnamed and `label` is the model className (e.g. `HareStandard`). Field zones only. |
| `grid` (886) | `[region, mapX, mapY, [monIdx], src(0 Mooglebox, 1 eLeMeN NM, 2 Gamer Escape), levelRange, groupSize, label]` - player-reported map spots, ~1 map unit precision, no zone |
| `per` (573) | `[monIdx, zoneName, pointCount, worldX, worldY, worldZ, mapX, mapY]` - per monster+zone centroid in **world** coords (incl. height); mapX/Y blank for dungeons |
| `field` (20) | the overworld zones that have region maps |

Actor IDs: `21xxxxx/22xxxxx` = `gamedata_actor_class.id` (= pool `actorClassId`); `3xxxxxx` =
`displayNameId` (all 39 rows that list one match the DB). Digits 3-5 of the class id are a model
family code (`21014xx` wolf, `21040xx` lemming/hare, `21027xx` flower...).

World <-> map: `mapX = worldX/100 + offX`, `mapY = worldZ/100 + offY` with per-region offsets
(La Noscea 24.8/30.0, Black Shroud 30.4/37.4, Thanalan 26.4/30.3, Coerthas 36.2/21.0, Mor Dhona
12.3/12.6). Inverting `pts` against `per` centroids reproduces the world X/Z to <= 5 units for all
451 monster/zone pairs, so `pts` are world positions rounded to 10 units, not hand-placed map pins.

## Meteor side (what the loader needs)
`WorldManager.LoadBattleNpcs` joins `spawn_locations -> groups -> pools -> genus` per loaded zone
(`server_zones.zoneName IS NOT NULL` and matching serverIp/port). Required per row:
* spawn_locations: `bnpcId, groupId, positionX/Y/Z, rotation`
* groups: `poolId, scriptName` (Lua uniqueId: `scripts/unique/<zone>/Monster/<scriptName>.lua`, optional), `minLevel, maxLevel, zoneId, spawnType` (only 0 = Normal is auto-spawned), `allegiance, actorState, animationId`
* pools: `actorClassId` (**must have a non-empty classPath**), `genusId, aggroType` (0 = neutral), `currentJob, combatSkill/combatDelay` (NOT NULL, no default)
* genus: `speed, detection, kindredId`, stat columns (defaults)

## Mapping and trust rules
* Monsters: `spawnType` contains `persistent` and a level is known. Zones are mapped by name to the
  primary `server_zones` row (`ZONE_MAP` in the script). Shposhae is skipped (zoneName NULL).
* Positions per monster+zone, highest trust wins:
  1. **A** retail 1.23b captures, matched to a named monster via className + zone + nearest named point;
     unmatched captures become `retail_<className>` pools.
  2. **B** Navmut points.
  3. Mooglebox / eLeMeN camp spots: AuroraFlare points within 250 u of a spot are kept (**B**,
     corroborated); spots with no nearby point get synthetic points (group size from Mooglebox, else 3;
     NM = 1) in an 8 u ring - **C, approx (+-100 u)**. Uncorroborated AuroraFlare points far from camps are dropped.
  4. AuroraFlare only (Gamer Escape spots only used for corroboration/levels) - **C**.
  5. Dungeons (no map): `per` centroid with its averaged height, up to 3 points - **C, approx (+-200 u)**.
* Points are single-link clustered (250 u) into groups, max `--max-per-group` points (NM: 1).
  Group level = nearest Mooglebox/GE spot level range within 400 u, else the bestiary range.
* Grid spots get a zone from the nearest plotted point in the region (<= 4 map units) and must fall in
  a zone listed for that monster (filters eLeMeN dungeon-map spots).

## Height / navmesh
Field positions have no height: `positionY = 0` is the "snap to navmesh" sentinel (`--y-mode hint`
writes the bestiary centroid height instead). Dungeon centroid rows keep their averaged Y but are
still marked `needsNavSnap=1` in the manifest. Every seeded zone has a navmesh file. The map server
snaps every battle NPC spawn to its zone's navmesh when it loads (`server_zones.loadNavMesh` is no
longer used); 56 seed points lie outside their zone's mesh and keep their raw position (logged at
Debug as "is not near ...'s navmesh"). Those are mostly bestiary points placed on the wrong map.

### Placing approximate rows (`--place`)
Approximate rows (map spot or zone centroid x/z, `approx=1`) are put on the zone's `.nav` walkable mesh
at build time by `Tools/seed/navplace` (a small dotnet tool on the server's own navigation library, Mob
agent, no water). Only ground a player can walk to from the zone's arrival points counts: aetherytes,
entrances and seamless crossings from the workspace `navgen/mapobj` (`--arrivals`, written by
`export_mapobj.py`), Player agent, every gate open, as navgen validate judges it (navgen/docs/FORMATS.md
"Arrival points"). A row whose frozen spot is still such ground keeps it. For the rest, each group's
anchor goes on the largest island within the row's error radius (100 for spots, 200 for centroids;
islands at least half that size count too, the nearest wins), and each row keeps its offset from the
anchor while that ground is on the same island and reachable, else moves in towards it. No row moves
further than its error radius; rows with no reachable dry ground in reach stay where they were and are
listed as unplaced, unless `data/navmesh_place_fallback.txt` lists them: those go to the nearest
reachable ground at any distance (the group's anchor there, rows at their offsets where the ground
allows) and are marked `fallback` with the distance moved. A row added to that list has no result
until the next `--place-missing`. Re-export `navgen/mapobj` before `--place` when spawns or seamless boxes changed. Every `.nav` the manifest lists is used, whether or not navgen validate
passed it. Results are frozen in `data/navmesh_place.json` (keyed by each row's input position, so a
changed row needs a new `--place`); the generator applies them without dotnet. Placed rows get `placed`
in the SQL comment, `yKnown=3` and `navPlacedMoved` (yalms moved) in the manifest.
`seed_bnpc_13_navmesh_placement.sql` holds the same positions as UPDATEs of the rows that still exist,
for a DB that already has 05 and the hand-made 08/10/11 (re-applying 05 would bring back rows those
deleted); `seed_bnpc_16_navmesh_placement_rollback.sql` undoes it.
A frozen result belongs to the row's zone: a row that has since moved zone has no result until
`--place-missing` runs navplace for just the groups without one and merges them in (new results record
their `zone`), so the other rows keep their placements.

### Re-zoned rows
The sources label field points by region-map area, which does not always match the server zone whose
geometry is under them (Navmut's "Lower La Noscea" points 300-600 y east and west of sea0Field01's mesh
are on sea0Field03's and sea0Field02's). A retail/Navmut/AuroraFlare point whose labelled zone has no
ground under it (navmesh probe, `PROBE_MAX_SHIFT`) but exactly one other field zone of the region does,
goes to that zone; so does a map spot, when its labelled zone has no Navmut points of that monster (so
the spot was in use). Re-zoned points cluster apart from the new zone's own points, their group keeps its
id (the ledger also matches the old zone), and the labelled zone does not fall back to map spots when all
its Navmut points moved away. The generator prints the counts. `bnpc_ids.json` `rezone` keeps what each
re-zoned row was before (group -> old zone, spawn -> old group, null = new) and the rows groups that gave
rows away got back from thinning; `seed_bnpc_14_rezone.sql` is written from it as in-place changes for a
DB that already has 04/05 (apply before 13), `seed_bnpc_15_rezone_rollback.sql` undoes it. A kept spawn
keeps the rotation the previous 05 gave it (rotations come from creation order).

## Client class names are case-sensitive (2026-10-03)
The client binds a monster by its `_defineClass` name, case-sensitively; a wrong-case classPath crashed
the client in zone 172. `data/client_monster_classes.txt` (812 exact paths from the 1.23b client script
tree) is the reference: every classPath the generator writes must be in it (asserted), upstream
`gamedata_actor_class` monster rows that are not are fixed in file 02 (Bug/LadyBugStandard ->
LadybugStandard x6, Hyaena/HyaenaStandard -> Wolf/HyaenaStandard), and base stubs are named with the
exact class name (dirs lower-case). The stub check is exact-case, so a wrong-case stub file is replaced.

## Zone resolution additions (2026-10-03)
* `ZONE_ALIAS`: Zahar'ak -> Southern Thanalan, Natalan -> Coerthas Central Highlands (sub-areas of a field zone).
* Grid spots with no plotted point within 4 map units (Coerthas Eastern Highlands has none at all) take
  the monster's listed zones in that region (all field zones when it is listed only by region, e.g.
  "Coerthas") and keep the spot if exactly one zone's navmesh has ground within 40 units of it.
  The probe results are frozen in `data/navmesh_probe.json`; missing queries go to
  `data/navmesh_probe_todo.json`. Run `python Tools/seed/probe_navmesh.py lua`, execute the chunk with
  the meteor MCP (`meteor_lua`) against a running Map Server, save the printed lines, then
  `python Tools/seed/probe_navmesh.py merge <file>` and re-run the generator.
* Not seeded: Shposhae (zoneName NULL, no navmesh), Castrum Novum (no position in any source),
  The Battle for the Golden Bazaar / Hyrstmill (instanced behests), Toto-Rak (instanced-dungeon only),
  dungeon NMs whose spot is on a dungeon map (Alux, Bomb Baron, Prince of Pestilence, Unknown Soldier,
  Third Order Patriarch Zu Ga).

## Stable ids
`data/bnpc_ids.json` keeps every pool/group/spawn id ever issued (pool by name; group by pool + zone +
nearest centroid within 400; spawn by group + point within 1 unit). Re-running the generator keeps
existing ids, so skill-list pool updates, file 06 and unique
scripts stay valid; retired ids are never reused. Seed-created genus ids are fixed in `NEW_GENUS_IDS`.
The first run bootstraps the ledger from the seed files already in `Data/sql/seed`.

## Family elements (file 07)
`seed_bnpc_07_family.sql` writes `server_battlenpc_genus.fire..water` (damage-taken multiplier),
`element`, and `server_battlenpc_genus_mods` rows modId 30-35 (`MobModifier.AffinityFire..Water`,
isMobMod 1, % change). Data: `data/family_elements.csv`; model and sources in
`` §11.3.

## ID ranges
genus 1001-1099, pools 100001-199999, groups 100001-199999, bnpcId 1000001-1999999 (generated), 2000001-2099999 (hand-maintained, file 06)
(existing: genus 1-65, pools/groups 1-4, bnpc 1-7). Inserting bnpcIds pushes the table's AUTO_INCREMENT past 1000001.

## Guessed columns (all evidence tier "guess", not from any source)
| column | value |
|---|---|
| `gamedata_actor_class.classPath` (file 02) | nearest known `*Standard` classPath with the same family code; else (2026-10-03) the client's own `/Chara/Npc/Monster/<Dir>/<Dir>Standard` script for the model family (`CLIENT_CLASS_BY_CODE`; dir names from the 1.23b client script tree, family match ours), elementals/humanoids by name (`CLIENT_CLASS_BY_NAME`); propertyFlags 23 + WolfStandard eventConditions. Pools are inserted with an `INSERT...SELECT ... WHERE classPath<>''` guard, so skipping file 02 drops those pools rather than crashing the loader. |
| base Lua (`lua_stubs`, 30 files) | copy of WolfStandard `init`. Not used on this server: classes without a script fall back to `Chara/Npc/Monster/Monster.lua`. |
| groups.hp / mp | `0` = derived at spawn from the rolled level by `Data/scripts/battlenpc_stats.lua` (`battle/stats.lua` MOB_HP_BASE x family multiplier and MOB_MP_BASE, x5 MP for casters, fit to retail 1.23b captures); NMs keep hp `5 x (30 + 12L + 1.6L^2)` as an explicit override (guess) |
| groups.respawnTime | 90 s; NMs 300 s when eLeMeN says "数分間隔" (every few minutes) or gives an Eorzea-time window, else 3600 s (Dodore: also weather-gated, pool mod 41 = 8017 Gloomy) |
| groups.spawnType | 0 for all (NMs auto-spawn since 2026-10-03; one group/one spawn per NM). Time-window NMs carry pool mods 38/39 (`MobModifier.SpawnWindowStart/Length`, Eorzea hours), checked by `BattleNpc.InSpawnWindow` |
| pools.aggroType | 1 if bestiary `aggressive = Y` (sourced), else 0 |
| pools combatSkill/combatDelay/combatDmgMult | 1 / 4200 / 1 (copied from existing pools) |
| pool_mods | Roams=1, RoamDelay=20 for non-NM pools |
| genus 1001+ | table defaults, detection by kindred |
| rotation | deterministic pseudo-random from bnpcId |

## Loader
`LoadBattleNpcs` applies pool, genus and spawn mods, the group's respawn time and the derived stats
(`ApplyBattleNpcSetup`), and rolls the level from `minLevel` to `maxLevel` inclusive. A monster class
with no class script of its own binds through `Data/scripts/Chara/Npc/Monster/Monster.lua`, so the
generator's `lua_stubs` aren't needed here.
