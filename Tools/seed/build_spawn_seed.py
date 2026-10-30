#!/usr/bin/env python3
"""
build_spawn_seed.py - generate Project Meteor battle-NPC (monster) seed SQL from the
"Eorzea 1.x Bestiary" artifact.

Inputs (all read-only):
  * the bestiary HTML (contains a single-line `const D={...};` JSON blob)
  * repo SQL dumps: Data/sql/gamedata_actor_class.sql, server_zones.sql,
    server_battlenpc_genus.sql  (used instead of the live DB so the output is reproducible)

Outputs (default Data/sql/seed/):
  seed_bnpc_01_genus.sql            new genus rows (ids 1001..1099) for families without one
  seed_bnpc_02_actor_classes.sql    fills classPath/propertyFlags/eventConditions on the
                                    monster actor classes we use that have an empty classPath
  seed_bnpc_03_pools.sql            one pool per monster type (+ pool mods)
  seed_bnpc_04_groups.sql           one group per zone/monster cluster
  seed_bnpc_05_spawn_locations.sql  one row per spawn point
  seed_bnpc_13_navmesh_placement.sql  05's navmesh-placed approximate rows as UPDATEs (+ 16 rollback)
  seed_bnpc_14_rezone.sql           04/05's re-zoned rows as in-place changes (+ 15 rollback)
  seed_bnpc_99_rollback.sql         removes everything above
  seed_bnpc_manifest.csv            per-spawn provenance (source, trust, approx flags, y hint)
and (default Tools/seed/lua_stubs/) base Lua class stubs for every monster classPath used
that has no script under Data/scripts/base.

Usage:
  python Tools/seed/build_spawn_seed.py --bestiary <artifact.html> [--repo .] [--max-per-group 10]

See Tools/seed/README.md for the mapping and trust rules.
"""
import argparse
import collections
import csv
import hashlib
import json
import math
import os
import re
import sys

# --------------------------------------------------------------------------------------
# ID ranges (existing rows at time of writing: genus 1..65, pools 1..4, groups 1..4, bnpc 1..7)
GENUS_BASE = 1001          # 1001..1099
POOL_BASE = 100001         # 100001..199999
GROUP_BASE = 100001        # 100001..199999
BNPC_BASE = 1000001        # 1000001..1999999
GENUS_RANGE = (1001, 1099)
POOL_RANGE = (100001, 199999)
GROUP_RANGE = (100001, 199999)
BNPC_RANGE = (1000001, 1999999)

# Region world<->map offsets from the bestiary "Sources & method" tab:
#   mapX = worldX/100 + offX ; mapY = worldZ/100 + offY   (world Y = height)
REGION_OFF = {
    'La Noscea': (24.8, 30.0),
    'Black Shroud': (30.4, 37.4),
    'Thanalan': (26.4, 30.3),
    'Coerthas': (36.2, 21.0),
    'Mor Dhona': (12.3, 12.6),
}


def region_of(z):
    """Port of the bestiary's R() function."""
    if re.search(r"Noscea|Mistbeard|Cassiopeia|U'Ghamaro|Castrum Novum|Turtleback|Limsa|Locke", z):
        return 'La Noscea'
    if re.search(r"Shroud|Mun-Tuy|Tam-Tara|Toto-Rak|Gridania|Murmur|Hyrstmill|Thornmarch", z):
        return 'Black Shroud'
    if re.search(r"Thanalan|Nanawa|Copperbell|Ul'dah|Zahar|Shposhae|Paglth|Bowl of Embers|Golden Bazaar|Cutter", z):
        return 'Thanalan'
    if re.search(r"Coerthas|Natalan|Dzemael|Aurum|Howling", z):
        return 'Coerthas'
    if re.search(r"Mor Dhona|Rivenroad", z):
        return 'Mor Dhona'
    return 'Other'


# Bestiary zone name -> Meteor server_zones.zoneName (primary, non-"a", non-Battle instance).
# Validated against server_zones.sql at run time. Shposhae (id 235) has zoneName NULL in
# server_zones, so the Map Server never loads it -> not mapped.
ZONE_MAP = {
    'Lower La Noscea': 'sea0Field01', 'Western La Noscea': 'sea0Field02',
    'Eastern La Noscea': 'sea0Field03', 'Upper La Noscea': 'sea0Field04',
    'Mistbeard Cove': 'sea0Dungeon01', 'Cassiopeia Hollow': 'sea0Dungeon03',
    "U'Ghamaro Mines": 'sea0Dungeon06',
    'Coerthas Central Highlands': 'roc0Field01', 'Coerthas Eastern Highlands': 'roc0Field02',
    'Coerthas Eastern Lowlands': 'roc0Field03', 'Coerthas Central Lowlands': 'roc0Field04',
    'Coerthas Western Highlands': 'roc0Field05',
    'Central Shroud': 'fst0Field01', 'East Shroud': 'fst0Field02', 'North Shroud': 'fst0Field03',
    'West Shroud': 'fst0Field04', 'South Shroud': 'fst0Field05',
    'The Mun-Tuy Cellars': 'fst0Dungeon01', 'The Tam-Tara Deepcroft': 'fst0Dungeon02',
    'The Thousand Maws of Toto-Rak': 'fst0Dungeon03',
    'Central Thanalan': 'wil0Field01', 'Eastern Thanalan': 'wil0Field02',
    'Western Thanalan': 'wil0Field03', 'Northern Thanalan': 'wil0Field04',
    'Southern Thanalan': 'wil0Field05',
    'Nanawa Mines': 'wil0Dungeon02', 'Copperbell Mines': 'wil0Dungeon04',
    'Mor Dhona': 'lak0Field01',
}

# Sub-areas the bestiary lists as their own "zone" but that are part of a field zone in Meteor.
# Zahar'ak is the Amalj'aa stronghold in Southern Thanalan and Natalan the Ixal one in Coerthas
# Central Highlands (1.19 notes place Flamefist Ahlygg Roh at "Zahar'ak (50,40)" on the Thanalan
# map, eLeMeN puts Lozol Totoloq at Coerthas (42,21)). Castrum Novum has no position in any
# source; The Battle for the Golden Bazaar / Hyrstmill are instanced behest battles (not seeded).
ZONE_ALIAS = {"Zahar'ak": 'Southern Thanalan', 'Natalan': 'Coerthas Central Highlands'}

# classPath for actor classes whose classPath is empty and whose model family (digits 3-5 of the
# id) has no known classPath in gamedata_actor_class. The directory and class names are the
# client's own monster scripts (1.23b client/script tree, /Chara/Npc/Monster/<Dir>/<Class>.lpb,
# decoded with decomp/tools/decode_lpb.py, 812 files); the family -> directory match is ours
# (by model: Kujata = buffalo, Bird = vulture, Scalelizard = drake, Termite = antling,
# Longlegs = yarzon, Gnole = kobold, Birdman = ixal, Pixie = sylph, Kesaranpasaran = snurble,
# Crowd = swarm, LivingDead = fomor, Skeleton = wight, KillerMachine = magitek). The client
# lower-cases script FILE paths, but the class is bound by its case-sensitive _defineClass name: a
# wrong-case classPath crashed the client in zone 172 (2026-10-03). Every classPath written by
# this generator is checked against data/client_monster_classes.txt (exact client names).
CLIENT_CLASS_BY_CODE = {
    '007': '/Chara/Npc/Monster/Basilisk/BasiliskStandard',
    '008': '/Chara/Npc/Monster/Kujata/KujataHornedStandard',
    '010': '/Chara/Npc/Monster/Morbol/MorbolStandard',
    '012': '/Chara/Npc/Monster/Bird/BirdStandard',
    '013': '/Chara/Npc/Monster/Salamander/SalamanderStandard',
    '017': '/Chara/Npc/Monster/Ahriman/AhrimanStandard',
    '018': '/Chara/Npc/Monster/Livingdead/LivingdeadStandard',
    '019': '/Chara/Npc/Monster/Skeleton/SkeletonStandard',
    '022': '/Chara/Npc/Monster/Scalelizard/ScalelizardStandard',
    '024': '/Chara/Npc/Monster/Killermachine/KillermachineLesserStandard',
    '026': '/Chara/Npc/Monster/Imp/ImpStandard',
    '028': '/Chara/Npc/Monster/Treant/TreantLesserStandard',
    '029': '/Chara/Npc/Monster/Apkallu/ApkalluStandard',
    '030': '/Chara/Npc/Monster/Termite/TermiteStandard',
    '031': '/Chara/Npc/Monster/Gigantoad/GigantoadStandard',
    '032': '/Chara/Npc/Monster/Coeurl/CoeurlLesserStandard',
    '034': '/Chara/Npc/Monster/Flan/FlanLesserStandard',
    '044': '/Chara/Npc/Monster/Kesaranpasaran/KesaranpasaranStandard',
    '053': '/Chara/Npc/Monster/Crowd/CrowdStandard',
    '055': '/Chara/Npc/Monster/Longlegs/LonglegsStandard',
    '060': '/Chara/Npc/Monster/Sheep/SheepStandard',
    '063': '/Chara/Npc/Monster/Qiqirn/QiqirnStandard',
    '064': '/Chara/Npc/Monster/Birdman/BirdmanStandard',
    '066': '/Chara/Npc/Monster/Gnole/GnoleStandard',
    '067': '/Chara/Npc/Monster/Pixie/PixieStandard',
    '090': '/Chara/Npc/Monster/Killermachine/KillermachineLesserStandard',
    '099': '/Chara/Npc/Monster/WillOTheWisp/WillOTheWispStandard',
    '620': '/Chara/Npc/Monster/Lizardman/LizardmanStandard',     # 2162xxx Amalj'aa
}
# Spellings an earlier run of this generator wrote (wrong case); file 02 replaces them.
OLD_WRONG_CASE = {
    '/Chara/Npc/Monster/WillOTheWisp/WillOTheWispStandard': ['/Chara/Npc/Monster/Willothewisp/WillothewispStandard'],
}
# Elementals (codes 046-052) and humanoids (2180xxx, 2280xxx) pick a class by monster name.
CLIENT_CLASS_BY_NAME = [
    (r'fire elemental|firebound', '/Chara/Npc/Monster/Elemental/FireelementalStandard'),
    (r'ice elemental|icebound', '/Chara/Npc/Monster/Elemental/IceelementalStandard'),
    (r'wind elemental|windbound', '/Chara/Npc/Monster/Elemental/WindelementalStandard'),
    (r'earth elemental|earthbound', '/Chara/Npc/Monster/Elemental/EarthelementalStandard'),
    (r'lightning elemental|lightningbound', '/Chara/Npc/Monster/Elemental/LightningelementalStandard'),
    (r'water elemental|waterbound', '/Chara/Npc/Monster/Elemental/WarterelementalStandard'),  # sic (client)
    (r'elemental|wrath', '/Chara/Npc/Monster/Elemental/ElementalStandard'),
    (r'imperial|elite |viith legion|garlean', '/Chara/Npc/Monster/Empire/EmpireStandard'),
    (r'black crow|buccaneer|pirate|corsair', '/Chara/Npc/Monster/Pirate/PirateStandard'),
    (r'.', '/Chara/Npc/Monster/Rebel/RebelStandard'),      # bandits, assassins, other hostile humans
]
CLIENT_CLASS_NAME_CODES = {'046', '047', '048', '049', '050', '051', '052', '070', '800', '801', '802', '803'}

# NM respawn (eLeMeN NM list, wiki): "数分間隔" (every few minutes) for 33 of 39 NMs -> 300 s
# (DESIGN inside "a few minutes"); time-of-day NMs use the same timer and only appear inside
# their Eorzea-time window (MobModifier.SpawnWindowStart/Length, isMobMod 38/39).
NM_RESPAWN_FEW_MINUTES = 300
# Weather-gated NMs: spawn-condition text -> weather id (MobModifier.SpawnWeather = 41; checked by
# BattleNpc against the zone weather cycle, server_zones_weather / Area.UpdateWeatherCycle).
NM_WEATHER = {'妖霧': 8017}   # Gloomy (Dodore) [WIKI eLeMeN NM list]

NM_WINDOWS = {  # spawn-condition text -> (start ET hour, length)
    '8時～20時': (8, 12),
    '20時～8時': (20, 12),
}

# Navmeshes that exist (zone names) per the navmesh agent.
NAVMESH_ZONES = set(
    ['fst0Field0%d' % i for i in range(1, 6)] + ['fst0Town01'] + ['fst0Dungeon0%d' % i for i in range(1, 7)] +
    ['sea0Field0%d' % i for i in range(1, 6)] + ['sea0Town01'] + ['sea0Dungeon0%d' % i for i in range(1, 7)] +
    ['sea1Field0%d' % i for i in range(1, 6)] +
    ['wil0Field0%d' % i for i in range(1, 6)] + ['wil0Town01', 'wil0Town02'] + ['wil0Dungeon0%d' % i for i in range(1, 7)] +
    ['roc0Field0%d' % i for i in range(1, 6)] + ['roc1Field01'] + ['roc0Dungeon0%d' % i for i in range(1, 7)] +
    ['lak0Field01', 'lak0Dungeon01'])

# Bestiary kin -> Meteor KindredType (Map Server/Actors/Chara/Npc/BattleNpc.cs)
KIN_TO_KINDRED = {
    'Beastkin': (1, 'Beast'), 'Seedkin': (2, 'Plantoid'), 'Wavekin': (3, 'Aquan'),
    'Spoken': (4, 'Spoken'), 'Scalekin': (5, 'Reptilian'), 'Vilekin': (6, 'Insect'),
    'Cloudkin': (7, 'Avian'), 'Ashkin': (8, 'Undead'), 'Soulkin': (9, 'Cursed'),
    'Voidsent': (10, 'Voidsent'),
}

# Bestiary family -> existing server_battlenpc_genus.genusId (by name, see server_battlenpc_genus.sql)
FAMILY_TO_GENUS = {
    'Ahriman': 51, 'Aldgoat': 1, "Amalj'aa": 23, 'Antelope': 2, 'Antling': 33, 'Apkallu': 40,
    'Aurelia': 20, 'Basilisk': 31, 'Bat': 43, 'Beetle': 38, 'Boar': 9, 'Bomb': 64, 'Buffalo': 8,
    'Cactuar': 13, 'Chigoe': 36, 'Coblyn': 49, 'Cockatrice': 42, 'Coeurl': 5, 'Crab': 22,
    'Diremite': 35, 'Drake': 30, 'Enemy Humanoid': 29, 'Flan': 63, 'Funguar': 14, 'Ghost': 46,
    'Gnat': 37, 'Goblin': 26, 'Goobbue': 6, 'Hippogryph': 44, 'Imp': 52, 'Ixal': 24, 'Kobold': 27,
    'Landtrap': 15, 'Mole': 11, 'Morbol': 16, 'Ogre': 60, 'Opo-opo': 4, 'Plasmoid': 62, 'Puk': 45,
    'Qiqirn': 25, 'Ram': 7, 'Raptor': 32, 'Rodent': 12, 'Salamander': 19, 'Slug': 21,
    'Snurble': 61, 'Spriggan': 50, 'Swarm': 34, 'Sylph': 28, 'Toad': 18, 'Vulture': 41,
    'Wight': 48, 'Wisp': 53, 'Wolf': 3, 'Yarzon': 39,
    # spelling variants / sub-families used in the bestiary
    'Aldgoats': 1, "Amlaj'aa": 23, 'Couerl': 5, 'Opo-Opo': 4, 'Rat': 12, 'Sheep': 7, 'Sabotender': 13,
    'Gigantoad': 18, 'Jellyfish': 20, 'Hedgemole': 11, 'Weevil': 38, 'Flytrap': 15, 'Hyur': 29,
    'Imperial': 29, 'Wolf/Hyena/Hellhound': 3, 'Phurble': 61, 'Earth Elemental': 56, 'Fire Elemental': 54,
}
ELEMENTAL_GENUS = [('Fire', 54), ('Water', 55), ('Earth', 56), ('Lightning', 57), ('Ice', 58), ('Wind', 59)]
# Families that get a new genus row (kindred guessed where the bestiary has no kin)
NEW_GENUS_KIN = {
    'Angler': 'Wavekin', 'Firefly': 'Vilekin', 'Fomor': 'Ashkin', 'Juggernaut': 'Voidsent',
    'Magitek Armor': 'Spoken', 'Treant': 'Seedkin', 'Elemental': 'Soulkin', 'Ascian': 'Spoken',
    'Primal': 'Voidsent',
}

# Stable ids for seed-created genus rows (drop/skill lists and pools refer to them).
NEW_GENUS_IDS = {'Angler': 1001, 'Firefly': 1002, 'Fomor': 1003, 'Treant': 1004, 'Juggernaut': 1005,
                 'Magitek Armor': 1006, 'Elemental': 1007}

# Detection flags (DetectionType: Sight=1 Scent=2 Sound=4 LowHp=8 Magic=0x20) guessed by kindred
DETECTION_BY_KINDRED = {1: 1 | 2, 2: 4, 3: 4, 4: 1, 5: 1, 6: 4, 7: 1, 8: 8, 9: 0x20, 10: 0x20}

PROPERTY_FLAGS_MONSTER = 23
EVENT_CONDITIONS_MONSTER = ('{\\n  "talkEventConditions": [],\\n  "noticeEventConditions": [\\n    {\\n'
                            '      "unknown1": 0,\\n      "unknown2": 1,\\n      "conditionName": "noticeEvent"\\n'
                            '    }\\n  ],\\n  "emoteEventConditions": [],\\n  "pushWithCircleEventConditions": []\\n}')

LUA_STUB = '''require ("global")
require ("battle/parts")

-- Generated by Tools/seed/build_spawn_seed.py (copied from WolfStandard.lua).
-- Base class script for {classPath}; without it the Map Server binds the actor as
-- /Chara/Npc/Populace/PopulaceStandard (static, non-hostile).

-- The engine calls init(player, npc) when a player is binding the actor, else init(npc).
function init(a, b)
	return parts.initParams(b or a);   -- partsExists from the family (battle/parts.lua)
end

function onDeath(monster, player, killer)
end
'''

SRC_RETAIL, SRC_NAVMUT, SRC_AURORA = 0, 1, 2
GRID_MOOGLEBOX, GRID_ELEMEN, GRID_GE = 0, 1, 2
SRC_NAME = {'retail': 'retail-1.23b-capture', 'navmut': 'navmut', 'aurora': 'auroraflare',
            'spot': 'map-spot', 'centroid': 'zone-centroid'}

CLUSTER_LINK = 250.0    # world units: points closer than this (single-link) share a group
SPOT_CORROB = 250.0     # AuroraFlare point within this of a Mooglebox/eLeMeN/GE spot = corroborated
SPOT_KEEP = 400.0       # when camp spots exist, drop AuroraFlare points farther than this from all spots


# --------------------------------------------------------------------------------------
def sql_str(s):
    return "'" + str(s).replace('\\', '\\\\').replace("'", "''") + "'"


def slug(s, n=40):
    s = re.sub(r"[^a-z0-9]+", '_', s.lower()).strip('_')
    return s[:n] or 'mob'


def stable_rot(key):
    h = int(hashlib.md5(str(key).encode()).hexdigest()[:8], 16)
    return round((h / 0xFFFFFFFF) * 2 * math.pi - math.pi, 3)


def load_bestiary(path):
    with open(path, encoding='utf8') as f:
        for line in f:
            if line.lstrip().startswith('const D='):
                s = line.strip()[len('const D='):].rstrip(';')
                return json.loads(s)
    raise SystemExit('const D= not found in ' + path)


def parse_sql_values(path, table):
    """Yield tuples of python values from `INSERT INTO table VALUES (...);` lines, or from the
    HeidiSQL multi-row form (`REPLACE INTO table (cols) VALUES` then one `\t(...),` row per line)."""
    rx = re.compile(r"^INSERT INTO `%s` VALUES \((.*)\);\s*$" % table)
    rx_multi_head = re.compile(r"^(?:INSERT|REPLACE) INTO `%s` \(.*\) VALUES\s*$" % table)
    rx_multi_row = re.compile(r"^\s*\((.*)\)[,;]\s*$")
    tok = re.compile(r"\s*('(?:[^'\\]|\\.|'')*'|NULL|null|-?[0-9.]+)\s*(,|$)")
    with open(path, encoding='utf8', errors='replace') as f:
        in_multi = False
        for line in f:
            m = None
            if in_multi:
                m = rx_multi_row.match(line)
                if not m:
                    in_multi = False
                    continue
                if line.rstrip().endswith(';'):
                    in_multi = False
            elif rx_multi_head.match(line):
                in_multi = True
                continue
            else:
                m = rx.match(line)
            if not m:
                continue
            body, out, pos = m.group(1), [], 0
            while pos < len(body):
                t = tok.match(body, pos)
                if not t:
                    break
                v = t.group(1)
                if v.lower() == 'null':
                    out.append(None)
                elif v.startswith("'"):
                    out.append(v[1:-1].replace("''", "'").replace("\\'", "'"))
                else:
                    out.append(float(v) if '.' in v else int(v))
                pos = t.end()
            yield out


def hp_guess(level, nm=False):
    # 0 = "derive from the rolled level" (Data/scripts/battlenpc_stats.lua -> battle/stats.lua
    # MOB_HP_CURVE, anchored on retail 1.23b captures). NMs keep an explicit guess: 5x the
    # old level curve (no source; the design value), so they stay much tougher than field mobs.
    if not nm:
        return 0
    return int(round(30 + 12 * level + 1.6 * level * level)) * 5


def nm_window(notes):
    for k, w in NM_WINDOWS.items():
        if k in (notes or ''):
            return w
    return None


def parse_level_range(s):
    nums = [int(x) for x in re.findall(r'\d+', s or '')]
    if not nums:
        return None
    return min(nums), max(nums)


def parse_group_size(s):
    nums = [int(x) for x in re.findall(r'\d+', s or '')]
    if not nums:
        return None
    return max(1, int(round(sum(nums) / len(nums))))


def map_to_world(region, mx, my):
    ox, oy = REGION_OFF[region]
    return round((mx - ox) * 100.0, 1), round((my - oy) * 100.0, 1)


def dist2(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def cluster(points, link):
    """single-linkage clustering of dicts with 'x','z'."""
    n = len(points)
    parent = list(range(n))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for i in range(n):
        for j in range(i + 1, n):
            if math.hypot(points[i]['x'] - points[j]['x'], points[i]['z'] - points[j]['z']) <= link:
                parent[find(i)] = find(j)
    groups = collections.OrderedDict()
    for i in range(n):
        groups.setdefault(find(i), []).append(points[i])
    return list(groups.values())


def thin(points, k):
    """keep at most k points, farthest-point sampling (deterministic)."""
    if len(points) <= k:
        return points
    pts = sorted(points, key=lambda p: (p['x'], p['z']))
    chosen = [pts[0]]
    rest = pts[1:]
    while len(chosen) < k and rest:
        best = max(rest, key=lambda p: min(math.hypot(p['x'] - c['x'], p['z'] - c['z']) for c in chosen))
        chosen.append(best)
        rest.remove(best)
    return chosen


# --------------------------------------------------------------------------------------
# Elemental affinity (file 07). Element model: 1.17-era TESTED multipliers (Research Notes
# 05_community_jp D6, forum thread 12985, 113 samples vs an Earth target): the target's own element
# 70%, the element that beats it 120%, the element it beats 100%, the other three by polarity -
# same polarity 90%, opposite 110%. Affinities still existed in 1.21/1.22 [CLAIM, threads 42219/
# 46320]. Family element/weakness: Tools/seed/data/family_elements.csv (Loot Ledger family table
# [WIKI], else the eLeMeN crystal-drop element [INFERENCE]).
ELEMENTS = ['Fire', 'Ice', 'Wind', 'Earth', 'Lightning', 'Water']
ELEMENT_ID = {'Fire': 5, 'Ice': 6, 'Wind': 7, 'Earth': 8, 'Lightning': 9, 'Water': 10}   # actionProperty ids
AFFINITY_MOBMOD = {'Fire': 30, 'Ice': 31, 'Wind': 32, 'Earth': 33, 'Lightning': 34, 'Water': 35}
ASTRAL = {'Fire', 'Wind', 'Lightning'}
BEATS = {'Water': 'Earth', 'Earth': 'Lightning', 'Lightning': 'Water', 'Wind': 'Fire', 'Fire': 'Ice', 'Ice': 'Wind'}
BEATS_INV = {v: k for k, v in BEATS.items()}
ELEMENTAL_GENUS_ELEMENT = {54: 'Fire', 55: 'Water', 56: 'Earth', 57: 'Lightning', 58: 'Ice', 59: 'Wind'}


def affinity_deltas(element, weakness):
    """% damage-taken change per element for a target of `element` (D6 model)."""
    out = {e: 0 for e in ELEMENTS}
    if element:
        for e in ELEMENTS:
            if e == element:
                out[e] = -30
            elif BEATS.get(e) == element:
                out[e] = +20
            elif BEATS.get(element) == e:
                out[e] = 0
            else:
                out[e] = -10 if ((e in ASTRAL) == (element in ASTRAL)) else +10
    if weakness and weakness != element:
        out[weakness] = +20
    return out


# --------------------------------------------------------------------------------------
# Stable id ledger (Tools/seed/data/bnpc_ids.json)
#   pools:  {pool name: id}
#   groups: [[id, pool name, zoneId, centroidX, centroidZ], ...]
#   spawns: [[id, groupId, x, z], ...]
#   next:   {pool, group, bnpc}: next free id (never decreases)
GROUP_MATCH = 400.0     # a regenerated group keeps an old id if same pool+zone and centroid within this
SPAWN_MATCH = 1.0


def bootstrap_ledger(seed_dir):
    """First run: read the ids out of the seed files that are already applied."""
    L = dict(pools={}, groups=[], spawns=[], next=dict(pool=POOL_BASE, group=GROUP_BASE, bnpc=BNPC_BASE))
    pth = os.path.join(seed_dir, 'seed_bnpc_03_pools.sql')
    if not os.path.exists(pth):
        return L
    for m in re.finditer(r"SELECT (\d+),\d+,'((?:[^']|'')*)'", open(pth, encoding='utf8').read()):
        L['pools'][m.group(2).replace("''", "'")] = int(m.group(1))
    pool_name = {v: k for k, v in L['pools'].items()}
    gz = {}
    for line in open(os.path.join(seed_dir, 'seed_bnpc_04_groups.sql'), encoding='utf8'):
        m = re.match(r"^\((\d+),(\d+),'.*,(\d+)\) /\*", line)
        if m:
            gz[int(m.group(1))] = (int(m.group(2)), int(m.group(3)))
    pts = collections.defaultdict(list)
    for line in open(os.path.join(seed_dir, 'seed_bnpc_05_spawn_locations.sql'), encoding='utf8'):
        m = re.match(r"^\((\d+),'',(\d+),(-?[\d.]+),(-?[\d.]+),(-?[\d.]+),", line)
        if m:
            sid, gid, x, z = int(m.group(1)), int(m.group(2)), float(m.group(3)), float(m.group(5))
            pts[gid].append((x, z))
            L['spawns'].append([sid, gid, x, z])
    for gid, (pid, zid) in sorted(gz.items()):
        pp = pts.get(gid) or [(0.0, 0.0)]
        L['groups'].append([gid, pool_name.get(pid, '#%d' % pid), zid,
                            round(sum(p[0] for p in pp) / len(pp), 1), round(sum(p[1] for p in pp) / len(pp), 1)])
    L['next'] = dict(pool=max(list(L['pools'].values()) + [POOL_BASE - 1]) + 1,
                     group=max([g[0] for g in L['groups']] + [GROUP_BASE - 1]) + 1,
                     bnpc=max([s[0] for s in L['spawns']] + [BNPC_BASE - 1]) + 1)
    return L


def assign_stable_ids(L, pools, groups, spawns):
    st = collections.Counter()
    for p in pools.values():
        name = slug(p['name'], 50)
        if name in L['pools']:
            p['id'] = L['pools'][name]
            st['pool_kept'] += 1
        else:
            p['id'] = L['pools'][name] = L['next']['pool']
            L['next']['pool'] += 1
            st['pool_new'] += 1
    # groups: greedy nearest match per (pool, zone)
    old = collections.defaultdict(list)
    for g in L['groups']:
        old[(g[1], g[2])].append(g)
    cand = []
    for k, g in enumerate(groups):
        g['cx'] = sum(s['x'] for s in spawns if s['group'] is g)
        n = sum(1 for s in spawns if s['group'] is g) or 1
        g['cx'] /= n
        g['cz'] = sum(s['z'] for s in spawns if s['group'] is g) / n
        for o in old.get((slug(g['pool']['name'], 50), g['zone']), []) + \
                (old.get((slug(g['pool']['name'], 50), g['rz']), []) if g.get('rz') else []):
            d = math.hypot(o[3] - g['cx'], o[4] - g['cz'])
            if d <= GROUP_MATCH:
                cand.append((d, k, o[0]))
    used_new, used_old = set(), set()
    for d, k, oid in sorted(cand):
        if k in used_new or oid in used_old:
            continue
        groups[k]['id'] = oid
        used_new.add(k)
        used_old.add(oid)
        st['group_kept'] += 1
    gmap = {g[0]: g for g in L['groups']}
    for k, g in enumerate(groups):
        if k not in used_new:
            g['id'] = L['next']['group']
            L['next']['group'] += 1
            st['group_new'] += 1
        gmap[g['id']] = [g['id'], slug(g['pool']['name'], 50), g['zone'], round(g['cx'], 1), round(g['cz'], 1)]
    L['groups'] = [gmap[k] for k in sorted(gmap)]
    # spawns: same group and (almost) the same point
    olds = collections.defaultdict(list)
    for s in L['spawns']:
        olds[s[1]].append(s)
    taken = set()
    smap = {s[0]: s for s in L['spawns']}
    old_group_key = {g[0]: (g[1], g[2]) for g in L['groups']}
    olds_pz = collections.defaultdict(list)
    for o in L['spawns']:
        if o[1] in old_group_key:
            olds_pz[old_group_key[o[1]]].append(o)
    for s in spawns:
        gid = s['group']['id']
        best = None
        pool_zone = (slug(s['group']['pool']['name'], 50), s['rz']) if s.get('rz') else None
        for o in olds.get(gid, []) + (olds_pz.get(pool_zone, []) if pool_zone else []):
            if o[0] in taken:
                continue
            d = math.hypot(o[2] - s['x'], o[3] - s['z'])
            if d <= SPAWN_MATCH and (best is None or d < best[0]):
                best = (d, o[0])
        if best:
            s['id'] = best[1]
            taken.add(best[1])
            st['spawn_kept'] += 1
        else:
            s['id'] = L['next']['bnpc']
            L['next']['bnpc'] += 1
            st['spawn_new'] += 1
        smap[s['id']] = [s['id'], gid, s['x'], s['z']]
    L['spawns'] = [smap[k] for k in sorted(smap)]
    live_g = {g['id'] for g in groups}
    live_s = {s['id'] for s in spawns}
    st['group_retired'] = sum(1 for g in L['groups'] if g[0] not in live_g)
    st['spawn_retired'] = sum(1 for s in L['spawns'] if s[0] not in live_s)
    return st


def place_approx_rows(args, repo, groups, spawns):
    """Approximate rows (map spot / zone centroid x/z, unknown height) onto the zone's walkable .nav mesh,
    from the frozen placements file; --place recomputes it with Tools/seed/navplace (the server's own
    navigation library, Mob agent). A result only applies while the row's input x/y/z are unchanged.
    Returns counts for the report, or None when there is nothing to place."""
    path = args.placements or os.path.join(repo, 'Tools', 'seed', 'data', 'navmesh_place.json')
    by_group = collections.OrderedDict()
    for s in spawns:
        if s['approx']:
            by_group.setdefault(s['group']['id'], []).append(s)
    if not by_group:
        return None
    gmap = {g['id']: g for g in groups}

    def key(s):
        return '%.1f|%.1f|%.1f' % (s['x'], s['y'], s['z'])

    old = json.load(open(path, encoding='utf8')) if os.path.exists(path) else {'meshes': {}, 'rows': {}, 'unplaced': []}
    # rows allowed to go to the nearest reachable ground when none is within their error radius
    fallback = set()
    fpath = os.path.join(repo, 'Tools', 'seed', 'data', 'navmesh_place_fallback.txt')
    if os.path.exists(fpath):
        for line in open(fpath, encoding='utf8'):
            line = line.split('#', 1)[0].strip()
            if line:
                fallback.add(int(line))

    def has_result(s):
        # a result is for the row's input position in the row's zone (rows re-zoned since need a new one)
        r = old['rows'].get(str(s['id']))
        if r is not None:
            return r.get('input') == key(s) and r.get('zone', s['group']['zname']) == s['group']['zname']
        # an unplaced row added to the fallback list since needs a new one
        return any(u['id'] == s['id'] and u['zone'] == s['group']['zname'] and (s['id'] not in fallback or u.get('fallback'))
                   for u in old['unplaced'])

    def current(s):
        # the row's frozen spot: navplace keeps it while a player can still reach it
        r = old['rows'].get(str(s['id']))
        if r is not None and has_result(s):
            return {'current': [r['x'], r['y'], r['z']]}
        return {}

    if args.place or args.place_missing:
        import subprocess
        import tempfile
        # arrival points (aetherytes, entrances, seamless crossings) per zone, as navgen validate reads them
        arrivals = args.arrivals or os.path.join(repo, '..', 'navgen', 'mapobj')
        if not os.path.isdir(arrivals):
            sys.exit('arrival points not found: %s (Tools/seed/export_mapobj.py writes them; pass --arrivals)' % arrivals)
        req = {'navDir': os.path.join(repo, 'Data', 'navmesh'), 'arrivalDir': os.path.abspath(arrivals), 'groups': []}
        for gid, rows in by_group.items():
            if not args.place and all(has_result(s) for s in rows):
                continue
            g = gmap[gid]
            placed = [[s['x'], s['y'], s['z']] for s in spawns if s['group']['id'] == gid and not s['approx']]
            req['groups'].append({'group': gid, 'zone': g['zname'], 'radius': max(s['xz_err'] for s in rows),
                                  'placed': placed,
                                  'rows': [dict({'id': s['id'], 'x': s['x'], 'y': s['y'], 'z': s['z']}, **current(s),
                                                **({'fallback': True} if s['id'] in fallback else {})) for s in rows]})
        with tempfile.TemporaryDirectory() as tmp:
            fin, fout = os.path.join(tmp, 'in.json'), os.path.join(tmp, 'out.json')
            with open(fin, 'w', encoding='utf8') as f:
                json.dump(req, f)
            subprocess.check_call(['dotnet', 'run', '-c', 'Release', '--project',
                                   os.path.join(repo, 'Tools', 'seed', 'navplace'), '--', fin, fout])
            res = json.load(open(fout, encoding='utf8'))
        if res.get('noArrivals'):
            print('navplace: no arrival points, placed without the arrival rule: ' + ', '.join(res['noArrivals']))
        inputs = {str(s['id']): key(s) for rows in by_group.values() for s in rows}
        zname = {str(s['id']): s['group']['zname'] for rows in by_group.values() for s in rows}
        # a kept row keeps its frozen result as it was
        new_rows = {k: old['rows'][k] if v['how'] == 'kept' else dict(v, input=inputs[k]) for k, v in res['rows'].items()}
        if args.place_missing:
            # merged into the frozen results; the zone is recorded so a later re-zone is noticed
            for k in new_rows:
                new_rows[k]['zone'] = zname[k]
            redone = {g['rows'][i]['id'] for g in req['groups'] for i in range(len(g['rows']))}
            rows_all = {k: v for k, v in old['rows'].items() if int(k) not in redone}
            rows_all.update(new_rows)
            unpl = [u for u in old['unplaced'] if u['id'] not in redone] + res['unplaced']
            meshes = dict(old.get('meshes', {}), **res['meshes'])
        else:
            rows_all, unpl, meshes = new_rows, res['unplaced'], res['meshes']
        frozen = {'meshes': meshes,
                  'rows': dict(sorted(rows_all.items(), key=lambda kv: int(kv[0]))),
                  'unplaced': sorted(unpl, key=lambda u: u['id'])}
        with open(path, 'w', encoding='utf8', newline='\n') as f:
            json.dump(frozen, f, indent=1, sort_keys=True)
    frozen = json.load(open(path, encoding='utf8')) if os.path.exists(path) else {'rows': {}, 'unplaced': []}

    st = dict(rows=0, placed=0, moved=0, max=0.0, max_id='-', unplaced=len(frozen.get('unplaced', [])), stale=0)
    unplaced_ids = {(u['id'], u['zone']) for u in frozen.get('unplaced', [])}
    for rows in by_group.values():
        for s in rows:
            st['rows'] += 1
            r = frozen['rows'].get(str(s['id']))
            if r is None or r.get('input') != key(s) or r.get('zone', s['group']['zname']) != s['group']['zname']:
                if (s['id'], s['group']['zname']) not in unplaced_ids:
                    st['stale'] += 1
                continue
            s['orig'] = (s['x'], s['y'], s['z'])
            s['x'], s['y'], s['z'] = r['x'], r['y'], r['z']
            s['placed'] = r['moved']
            s['fallback'] = r.get('fallback', False)
            s['y_known'] = 3   # ground height from the placement
            st['placed'] += 1
            if r['moved'] > 1.0:
                st['moved'] += 1
            if r['moved'] > st['max']:
                st['max'], st['max_id'] = r['moved'], s['id']
    return st


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--bestiary', required=True, help='bestiary artifact .html')
    ap.add_argument('--repo', default=os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
    ap.add_argument('--out', default=None, help='SQL output dir (default <repo>/Data/sql/seed)')
    ap.add_argument('--lua-out', default=None, help='Lua stub dir (default <repo>/Tools/seed/lua_stubs)')
    ap.add_argument('--max-per-group', type=int, default=10, help='cap on spawn points per group')
    ap.add_argument('--respawn', type=int, default=90, help='respawnTime (s) for normal groups (guess)')
    ap.add_argument('--nm-respawn', type=int, default=3600, help='respawnTime (s) for NM groups (guess)')
    ap.add_argument('--probe', default=None,
                    help='navmesh probe results JSON (default Tools/seed/data/navmesh_probe.json); queries it '
                         'lacks are written to navmesh_probe_todo.json for Tools/seed/probe_navmesh.lua')
    ap.add_argument('--ids', default=None, help='stable id ledger (default Tools/seed/data/bnpc_ids.json)')
    ap.add_argument('--placements', default=None,
                    help='navmesh placements of approximate rows (default Tools/seed/data/navmesh_place.json)')
    ap.add_argument('--place', action='store_true',
                    help='re-run Tools/seed/navplace (dotnet) against Data/navmesh and rewrite --placements')
    ap.add_argument('--arrivals', default=None,
                    help='arrival points per zone for --place (default: the workspace navgen/mapobj, written by '
                         'Tools/seed/export_mapobj.py)')
    ap.add_argument('--place-missing', action='store_true',
                    help='like --place, but only for groups with a row that has no result yet (merged in)')
    ap.add_argument('--y-mode', choices=['zero', 'hint'], default='zero',
                    help="unknown height: 'zero' writes Y=0 (navmesh-snap sentinel); 'hint' writes the "
                         "bestiary's per-zone centroid height when available")
    args = ap.parse_args()

    repo = os.path.abspath(args.repo)
    out = args.out or os.path.join(repo, 'Data', 'sql', 'seed')
    lua_out = args.lua_out or os.path.join(repo, 'Tools', 'seed', 'lua_stubs')
    os.makedirs(out, exist_ok=True)

    D = load_bestiary(args.bestiary)
    MON, ZN, PTS, GRID, PER, FIELD = D['mon'], D['zones'], D['pts'], D['grid'], D['per'], set(D['field'])

    # ---- Meteor reference data from repo SQL dumps
    sqldir = os.path.join(repo, 'Data', 'sql')
    actor_class = {}  # id -> (classPath, displayNameId, propertyFlags, eventConditions)
    for r in parse_sql_values(os.path.join(sqldir, 'gamedata_actor_class.sql'), 'gamedata_actor_class'):
        actor_class[int(r[0])] = (r[1] or '', r[2], r[3], r[4])
    zones = {}  # zoneName -> (id, placeName)
    for r in parse_sql_values(os.path.join(sqldir, 'server_zones.sql'), 'server_zones'):
        if r[2]:
            zones.setdefault(r[2], (int(r[0]), r[3]))
    genus_rows = {int(r[0]): r[1] for r in parse_sql_values(os.path.join(sqldir, 'server_battlenpc_genus.sql'),
                                                           'server_battlenpc_genus')}
    base_scripts = set()
    bdir = os.path.join(repo, 'Data', 'scripts', 'base')
    for root, _, files in os.walk(bdir):
        for fn in files:
            if fn.endswith('.lua'):
                rel = os.path.relpath(os.path.join(root, fn), bdir).replace('\\', '/')[:-4]
                d, _, f = rel.rpartition('/')
                base_scripts.add(d.lower() + '/' + f)   # dirs lower-case, class file name exact

    # exact-case client monster class names (1.23b client script tree, _defineClass names)
    client_cls = [l.strip() for l in open(os.path.join(repo, 'Tools', 'seed', 'data', 'client_monster_classes.txt'),
                                          encoding='utf8') if l.strip()]
    client_exact = set(client_cls)
    client_lower = {c.lower(): c for c in client_cls}
    client_by_class = collections.defaultdict(list)
    for c in client_cls:
        client_by_class[c.rsplit('/', 1)[1].lower()].append(c)
    for cp in list(CLIENT_CLASS_BY_CODE.values()) + [cp for _rx, cp in CLIENT_CLASS_BY_NAME]:
        assert cp in client_exact, 'not a client class: ' + cp

    def client_path(cp):
        """Exact client spelling of a monster classPath (case fix; class name in another dir as a
        fallback, e.g. upstream /Hyaena/HyaenaStandard -> /Wolf/HyaenaStandard), or None."""
        if cp in client_exact:
            return cp
        if cp.lower() in client_lower:
            return client_lower[cp.lower()]
        alt = client_by_class.get(cp.rsplit('/', 1)[-1].lower(), [])
        return alt[0] if len(alt) == 1 else None

    # upstream gamedata_actor_class monster rows whose classPath is not an exact client class
    case_fixes = {}   # actorClassId -> (old, new)
    for cid, (cp, *_r) in actor_class.items():
        if cp.startswith('/Chara/Npc/Monster/') and cp not in client_exact:
            fixed = client_path(cp)
            if fixed:
                case_fixes[cid] = (cp, fixed)
                actor_class[cid] = (fixed,) + tuple(_r)

    for bz, mz in ZONE_MAP.items():
        if mz not in zones:
            raise SystemExit('zone %s (%s) missing from server_zones.sql' % (mz, bz))

    # known monster class paths, indexed by actor-class "family code" (digits 3..5 of the id)
    known_by_code = collections.defaultdict(list)   # code -> [(id, classPath)]
    known_by_classname = {}                          # lower className -> lowest id
    for cid, (cp, *_r) in sorted(actor_class.items()):
        if 2100000 <= cid < 2300000 and cp.startswith('/Chara/Npc/Monster/'):
            # only generic *Standard classes are used as guesses (skip NM/Scenario/Raid/Ally variants)
            if cp.endswith('Standard'):
                known_by_code[str(cid)[2:5]].append((cid, cp))
            known_by_classname.setdefault(cp.rsplit('/', 1)[1].lower(), cid)

    def resolve_class(ids, name=''):
        """pick (actorClassId, classPath, guessed) for a monster's actor ids."""
        mids = [int(t) for t in ids if t.startswith('2') and int(t) in actor_class]
        for cid in mids:
            if actor_class[cid][0]:
                return cid, actor_class[cid][0], False
        for cid in mids:
            cands = known_by_code.get(str(cid)[2:5])
            if cands:
                same_prefix = [c for c in cands if str(c[0])[:2] == str(cid)[:2]] or cands
                near = min(same_prefix, key=lambda c: abs(c[0] - cid))
                return cid, near[1], True
        for cid in mids:
            code = str(cid)[2:5]
            if code in CLIENT_CLASS_BY_CODE:
                return cid, CLIENT_CLASS_BY_CODE[code], True
            if code in CLIENT_CLASS_NAME_CODES and name:
                for rx, cp in CLIENT_CLASS_BY_NAME:
                    if re.search(rx, name.lower()):
                        return cid, cp, True
        return None

    # ---- genus resolution
    new_genus = collections.OrderedDict()  # family -> (id, kindredId, kindredName)

    def genus_for(m):
        fam, kin = m[1], m[2]
        if fam == 'Elemental':
            for kw, gid in ELEMENTAL_GENUS:
                if kw.lower() in m[0].lower():
                    return gid
        if fam in FAMILY_TO_GENUS:
            gid = FAMILY_TO_GENUS[fam]
            assert gid in genus_rows, gid
            return gid
        if fam not in new_genus:
            k = kin or NEW_GENUS_KIN.get(fam, '')
            kid, kname = KIN_TO_KINDRED.get(k, (0, 'Unknown'))
            gid = NEW_GENUS_IDS.get(fam) or max([GENUS_BASE - 1] + list(NEW_GENUS_IDS.values()) +
                                                [g[0] for g in new_genus.values()]) + 1
            new_genus[fam] = (gid, kid, kname)
        return new_genus[fam][0]

    # ---- navmesh probe (zone, x, z) -> on that zone's walkable mesh? Filled offline by running
    # Tools/seed/probe_navmesh.lua through the map server admin API (meteor_lua); see README.
    probe_path = args.probe or os.path.join(repo, 'Tools', 'seed', 'data', 'navmesh_probe.json')
    probe = json.load(open(probe_path)) if os.path.exists(probe_path) else {}
    probe_todo = set()
    PROBE_MAX_SHIFT = 40.0   # snapped XZ farther than this from the asked point = not on this mesh

    def on_mesh(zname, x, z):
        """True/False from the probe file, None if not probed yet (queued in probe_todo)."""
        key = '%s|%.0f|%.0f' % (zname, x, z)
        r = probe.get(key)
        if r is None:
            probe_todo.add(key)
            return None
        return bool(r[0]) and math.hypot(r[1] - x, r[3] - z) <= PROBE_MAX_SHIFT

    # Field points whose labelled zone has no ground under them but exactly one other field zone of
    # the region does go to that zone (the sources label by region-map area, e.g. Navmut's "Lower
    # La Noscea" points 300-600 y east of sea0Field01's geometry lie on sea0Field03's).
    rezoned = collections.Counter()   # (from, to) -> points

    def point_zone(p):
        z = ZN[p[3]]
        if z not in FIELD or z not in ZONE_MAP:
            return z
        region = region_of(z)
        wx, wz = map_to_world(region, p[0], p[1])
        if on_mesh(ZONE_MAP[z], wx, wz) is not False:
            return z
        sib = [zz for zz in sorted(FIELD) if zz != z and zz in ZONE_MAP and region_of(zz) == region]
        hits = [zz for zz in sib if on_mesh(ZONE_MAP[zz], wx, wz)]
        if len(hits) != 1:
            return z
        rezoned[(z, hits[0])] += 1
        return hits[0]

    # ---- index bestiary
    pts_by = collections.defaultdict(list)      # (mon, zoneName) -> [pts]
    lab_by = collections.defaultdict(list)      # the same by the sources' zone label (spot/retail matching)
    zone_pts = collections.defaultdict(list)    # zoneName -> [pts] (for spot -> zone resolution)
    pt_zone = {}                                # id(point) -> zone after re-zoning
    rezoned_out = collections.Counter()         # (mon, labelled zone) -> Navmut points moved away
    for p in PTS:
        z = ZN[p[3]]
        zone_pts[z].append(p)
        pt_zone[id(p)] = point_zone(p)
        pts_by[(p[2], pt_zone[id(p)])].append(p)
        lab_by[(p[2], z)].append(p)
        if pt_zone[id(p)] != z:
            rezoned_out[(p[2], z)] += 1 if p[4] == SRC_NAVMUT else 0

    def rz(p):
        """Marks a re-zoned point with its labelled zone id: it clusters apart from the new zone's own
        points (merging would thin them out) and its group keeps the id it had in the old zone."""
        z = ZN[p[3]]
        return {'rz': zones[ZONE_MAP[z]][0]} if pt_zone[id(p)] != z else {}

    def clusters(pts):
        return cluster([p for p in pts if 'rz' not in p], CLUSTER_LINK) + \
            cluster([p for p in pts if 'rz' in p], CLUSTER_LINK)
    per_by = {(q[0], q[1]): q for q in PER}

    def mon_zones(m):
        zs = set(z.strip() for z in m[6].split(';') if z.strip()) if m[6] else set()
        return {ZONE_ALIAS.get(z, z) for z in zs}

    def eligible(i):
        m = MON[i]
        return 'persistent' in m[9] and m[3] != ''

    # grid spots -> (mon, zone) via nearest plotted point in the same region (field zones only);
    # when the region has no plotted point near the spot (e.g. Coerthas Eastern Highlands has no
    # positional data at all), the monster's own listed zones in that region are tried against the
    # zone navmeshes and the spot is kept only if exactly one of them has walkable ground there.
    spots_by = collections.defaultdict(list)    # (mon, zone) -> [dict]
    spot_unresolved = 0
    spot_by_probe = 0
    for g in GRID:
        region, gx, gy, mons, src, lvl, gsize, label = g
        if region not in REGION_OFF:
            continue
        best, bd = None, 4.0
        for z in sorted(FIELD):   # sorted: ties between zones must not depend on the hash seed
            if region_of(z) != region:
                continue
            for p in zone_pts.get(z, ()):
                d = math.hypot(p[0] - gx, p[1] - gy)
                if d < bd:
                    best, bd = z, d
        wx, wz = map_to_world(region, gx, gy)
        for mi in mons:
            if mi < 0:
                continue
            mz = {zz.lower() for zz in mon_zones(MON[mi])}
            # the spot must fall in a zone the bestiary lists for this monster (or where it has points);
            # this also rejects eLeMeN dungeon-map spots that are labelled with the parent region.
            zone = best
            if zone is None or (zone.lower() not in mz and not lab_by.get((mi, zone))):
                zone = None
                mzs = mon_zones(MON[mi])
                if region in mzs:
                    # listed only by region ("Coerthas"): any field zone of that region
                    mzs = mzs | {zz for zz in FIELD if region_of(zz) == region}
                cands = [zz for zz in mzs if zz in FIELD and region_of(zz) == region and zz in ZONE_MAP]
                hits = [zz for zz in cands if on_mesh(ZONE_MAP[zz], wx, wz)]
                if len(hits) == 1:
                    zone = hits[0]
                    spot_by_probe += 1
            if zone is None:
                spot_unresolved += 1
                continue
            # as with points: no ground in that zone but in exactly one other zone of the region. Only
            # spots that zone would use (no Navmut points there) move, so other zones' sources stay put.
            rz_from = {}
            if zone in ZONE_MAP and not any(q[4] == SRC_NAVMUT for q in lab_by.get((mi, zone), ())) \
                    and on_mesh(ZONE_MAP[zone], wx, wz) is False:
                sib = [zz for zz in sorted(FIELD) if zz != zone and zz in ZONE_MAP and region_of(zz) == region]
                hits = [zz for zz in sib if on_mesh(ZONE_MAP[zz], wx, wz)]
                if len(hits) == 1:
                    rezoned[(zone + ' (spot)', hits[0])] += 1
                    rz_from = {'rz': zones[ZONE_MAP[zone]][0]}
                    zone = hits[0]
            spots_by[(mi, zone)].append(dict(x=wx, z=wz, src=src, lvl=parse_level_range(lvl),
                                             size=parse_group_size(gsize), label=label, **rz_from))

    # ---- retail captures: assign unnamed model-class points to a named monster
    mon_class = {}
    for i, m in enumerate(MON):
        rc = resolve_class(m[13].split(), m[0])
        if rc:
            mon_class[i] = rc
    retail_assigned = collections.defaultdict(list)
    retail_unnamed = collections.defaultdict(list)   # (className, zone) -> [pts]
    retail_stats = collections.Counter()
    for p in PTS:
        if p[4] != SRC_RETAIL:
            continue
        z, label = pt_zone[id(p)], p[5].lower()
        known = known_by_classname.get(label)
        code = str(known)[2:5] if known else None
        cands = []
        for i in range(len(MON)):
            if not eligible(i) or i not in mon_class:
                continue
            if z not in mon_zones(MON[i]) and not lab_by.get((i, z)):
                continue
            cid, cp, _g = mon_class[i]
            exact = cp.rsplit('/', 1)[1].lower() == label
            if exact or (code and str(cid)[2:5] == code):
                others = [q for q in lab_by.get((i, z), []) if q[4] != SRC_RETAIL]
                d = min((math.hypot(q[0] - p[0], q[1] - p[1]) for q in others), default=99.0)
                cands.append((0 if exact else 1, d, i))
        if cands:
            cands.sort()
            if cands[0][1] <= 3.0 or len(cands) == 1:
                retail_assigned[(cands[0][2], z)].append(p)
                retail_stats['assigned'] += 1
                continue
        retail_unnamed[(p[5], z)].append(p)
        retail_stats['unnamed'] += 1

    # ---- build pools / groups / spawns
    pools = collections.OrderedDict()   # key -> dict
    groups = []
    spawns = []
    skipped = collections.Counter()
    lua_needed = {}
    classpath_updates = {}              # actorClassId -> classPath

    def get_pool(key, name, cid, cp, guessed, gid, aggressive, nm, fam):
        if key not in pools:
            assert cp in client_exact, 'classPath %s (pool %s) is not an exact client class' % (cp, name)
            pools[key] = dict(id=POOL_BASE + len(pools), name=name, cid=cid, cp=cp, guessed=guessed,
                              genus=gid, aggro=1 if aggressive else 0, nm=nm, fam=fam)
            if guessed:
                classpath_updates[cid] = cp
            rel = cp.lstrip('/').lower()
            rel = rel.rsplit('/', 1)[0] + '/' + cp.rsplit('/', 1)[1]
            if rel not in base_scripts:
                lua_needed[cp] = True
        return pools[key]

    def add_group(pool, zname, pts, lv, nm, note):
        zid = zones[zname][0]
        respawn = args.respawn
        if nm:
            notes = pool.get('notes', '')
            respawn = NM_RESPAWN_FEW_MINUTES if ('数分間隔' in notes or nm_window(notes)) else args.nm_respawn
        grp = dict(id=GROUP_BASE + len(groups), pool=pool, zone=zid, zname=zname, minlv=lv[0], maxlv=lv[1],
                   respawn=respawn, nm=nm, note=note, rz=pts[0].get('rz') if pts else None)
        avg = (lv[0] + lv[1]) / 2.0
        grp['hp'] = hp_guess(avg, nm)
        # 0 = derived at spawn (battle/stats.lua MOB_MP_BASE, captured; x5 for casters).
        grp['mp'] = 0
        groups.append(grp)
        for p in pts:
            sid = BNPC_BASE + len(spawns)
            p = dict(p)
            p['id'] = sid
            p['group'] = grp
            p['rot'] = stable_rot(sid)
            spawns.append(p)
        return grp

    mon_ok = collections.Counter()
    for i, m in enumerate(MON):
        if not eligible(i):
            continue
        name, fam, minlv, maxlv = m[0], m[1], int(m[3]), int(m[4] or m[3])
        nm = m[7] == 'Y'
        zset = set(mon_zones(m)) | {z for (mi, z) in list(pts_by) if mi == i} | \
            {z for (mi, z) in list(spots_by) if mi == i} | {q[1] for q in PER if q[0] == i}
        zset = {z for z in zset if z in ZONE_MAP}
        if not zset:
            skipped['no meteor zone'] += 1
            continue
        rc = mon_class.get(i)
        if not rc:
            skipped['no usable actor class'] += 1
            continue
        cid, cp, guessed = rc
        gid = genus_for(m)
        made = False
        for z in sorted(zset):
            zname = ZONE_MAP[z]
            region = region_of(z)
            # points re-zoned into z are added as they are; z's own points pick the source as before
            moved = [p for p in retail_assigned.get((i, z), []) + pts_by.get((i, z), []) if ZN[p[3]] != z
                     and p[4] in (SRC_RETAIL, SRC_NAVMUT, SRC_AURORA)]
            moved = list({id(p): p for p in moved}.values())
            exact = [p for p in retail_assigned.get((i, z), []) if ZN[p[3]] == z]
            nav = [p for p in pts_by.get((i, z), []) if p[4] == SRC_NAVMUT and ZN[p[3]] == z]
            af = [p for p in pts_by.get((i, z), []) if p[4] == SRC_AURORA and ZN[p[3]] == z]
            spots = spots_by.get((i, z), [])
            pts = []
            # a zone whose Navmut points all moved away does not fall back to map spots
            if z in FIELD and (exact or nav or rezoned_out[(i, z)]):
                for p in exact + nav:
                    wx, wz = map_to_world(region, p[0], p[1])
                    src = 'retail' if p[4] == SRC_RETAIL else 'navmut'
                    pts.append(dict(x=wx, z=wz, src=src, trust='A' if src == 'retail' else 'B',
                                    xz_err=5, approx=0, **rz(p)))
            elif z in FIELD and spots:
                camp = [s for s in spots if s['src'] in (GRID_MOOGLEBOX, GRID_ELEMEN)]
                anchor = camp or spots
                used = set()
                for s in anchor:
                    near = []
                    for k, p in enumerate(af):
                        wx, wz = map_to_world(region, p[0], p[1])
                        if math.hypot(wx - s['x'], wz - s['z']) <= SPOT_CORROB:
                            near.append(k)
                    if near:
                        used.update(near)
                    else:
                        n = s['size'] or (1 if nm else 3)
                        n = min(n, args.max_per_group)
                        for k in range(n):
                            ang = 2 * math.pi * k / max(n, 1)
                            r = 0 if n == 1 else 8.0
                            pts.append(dict(x=round(s['x'] + r * math.cos(ang), 1),
                                            z=round(s['z'] + r * math.sin(ang), 1), src='spot',
                                            trust='C', xz_err=100, approx=1,
                                            spot=['mooglebox', 'elemen', 'gamerescape'][s['src']],
                                            **({'rz': s['rz']} if 'rz' in s else {})))
                for k, p in enumerate(af):
                    wx, wz = map_to_world(region, p[0], p[1])
                    if k in used:
                        pts.append(dict(x=wx, z=wz, src='aurora', trust='B', xz_err=5, approx=0,
                                        corroborated=1, **rz(af[k])))
                    elif not camp and min(math.hypot(wx - s['x'], wz - s['z']) for s in spots) <= SPOT_KEEP:
                        pts.append(dict(x=wx, z=wz, src='aurora', trust='C', xz_err=5, approx=0, **rz(p)))
                    elif not camp:
                        pts.append(dict(x=wx, z=wz, src='aurora', trust='C', xz_err=5, approx=0, **rz(p)))
                    # camp spots exist and this AF point is far from all -> dropped (lower trust)
            elif z in FIELD and af:
                for p in af:
                    wx, wz = map_to_world(region, p[0], p[1])
                    pts.append(dict(x=wx, z=wz, src='aurora', trust='C', xz_err=5, approx=0, **rz(p)))
            elif z not in FIELD and (i, z) in per_by:
                q = per_by[(i, z)]
                n = min(max(1, q[2]), 3)
                for k in range(n):
                    ang = 2 * math.pi * k / n
                    r = 0 if n == 1 else 5.0
                    pts.append(dict(x=round(q[3] + r * math.cos(ang), 1), z=round(q[5] + r * math.sin(ang), 1),
                                    y=q[4], src='centroid', trust='C', xz_err=200, approx=1))
            for p in moved:
                wx, wz = map_to_world(region, p[0], p[1])
                src = {SRC_RETAIL: 'retail', SRC_NAVMUT: 'navmut', SRC_AURORA: 'aurora'}[p[4]]
                pts.append(dict(x=wx, z=wz, src=src, trust={'retail': 'A', 'navmut': 'B'}.get(src, 'C'),
                                xz_err=5, approx=0, **rz(p)))
            if not pts:
                continue
            yhint = per_by.get((i, z), [None] * 6)[4]
            pool = get_pool(('mon', i), name, cid, cp, guessed, gid, m[8] == 'Y', nm, fam)
            pool['notes'] = m[15]
            for cl in clusters(pts):
                if nm and made:
                    break   # one placeholder per NM: a single live instance, at its first (best) spot
                cl = thin(cl, 1 if nm else args.max_per_group)
                cx = sum(p['x'] for p in cl) / len(cl)
                cz = sum(p['z'] for p in cl) / len(cl)
                lv = (minlv, maxlv)
                cands = [s for s in spots if s['lvl'] and math.hypot(s['x'] - cx, s['z'] - cz) <= 400]
                if cands:
                    s = min(cands, key=lambda s: math.hypot(s['x'] - cx, s['z'] - cz))
                    lv = s['lvl']
                for p in cl:
                    if 'y' not in p:
                        p['y'] = yhint if (args.y_mode == 'hint' and yhint is not None) else 0.0
                        p['y_known'] = 0
                    else:
                        p['y_known'] = 2   # averaged (centroid) height
                    p['y_hint'] = yhint
                    p['monster'] = name
                    p['zone_name'] = z
                add_group(pool, zname, cl, lv, nm, '%s / %s' % (name, z))
                made = True
        if made:
            mon_ok['nm' if nm else 'normal'] += 1
        else:
            skipped['no positions in mapped zones'] += 1

    # unnamed retail captures -> their own pools keyed by className
    for (label, z), pl in sorted(retail_unnamed.items()):
        cid = known_by_classname.get(label.lower())
        if not cid or z not in ZONE_MAP:
            skipped['retail unnamed unresolvable'] += len(pl)
            continue
        cp = actor_class[cid][0]
        # level: nearest named point in the same zone
        region = region_of(z)
        best = None
        for p in zone_pts[z]:
            if p[2] >= 0 and MON[p[2]][3] != '':
                d = min(math.hypot(p[0] - q[0], p[1] - q[1]) for q in pl)
                if best is None or d < best[0]:
                    best = (d, p[2])
        lv = (int(MON[best[1]][3]), int(MON[best[1]][4] or MON[best[1]][3])) if best else (1, 5)
        # genus: family of any bestiary monster sharing the actor-class family code
        same = [mi for mi, rc in mon_class.items() if str(rc[0])[2:5] == str(cid)[2:5] and MON[mi][1]]
        gid = genus_for(MON[same[0]]) if same else 29
        pool = get_pool(('retail', label), 'retail_' + label, cid, cp, False, gid, False, False, '')
        pts = []
        for p in pl:
            wx, wz = map_to_world(region, p[0], p[1])
            pts.append(dict(x=wx, z=wz, y=0.0, y_known=0, y_hint=None, src='retail', trust='A', xz_err=5,
                            approx=0, monster='(unnamed %s)' % label, zone_name=z, **rz(p)))
        for cl in clusters(pts):
            add_group(pool, ZONE_MAP[z], thin(cl, args.max_per_group), lv, False,
                      'retail capture %s / %s' % (label, z))

    # ---- stable ids: keep every pool/group/spawn id that already exists (drop lists, skill-list pool
    # updates, the hand-made file 06 and live NM scripts refer to them); new rows get ids above the
    # highest ever issued, retired ids are never reused.
    ids_path = args.ids or os.path.join(repo, 'Tools', 'seed', 'data', 'bnpc_ids.json')
    ledger = json.load(open(ids_path)) if os.path.exists(ids_path) else bootstrap_ledger(os.path.join(repo, 'Data', 'sql', 'seed'))
    old_group_zone = {g[0]: g[2] for g in ledger['groups']}
    old_spawn_group = {o[0]: o[1] for o in ledger['spawns']}
    id_stats = assign_stable_ids(ledger, pools, groups, spawns)
    # what each re-zoned row was before its first re-zone (file 14 is written from this, so it does not
    # change on later runs): group -> old zone, spawn -> old group (null = the row is new), and the new
    # rows of groups that gave rows away
    rzl = ledger.setdefault('rezone', {'groups': {}, 'spawns': {}, 'added': []})
    for g in groups:
        if g.get('rz') and str(g['id']) not in rzl['groups']:
            rzl['groups'][str(g['id'])] = old_group_zone.get(g['id'])
    for sp in spawns:
        if sp.get('rz') and str(sp['id']) not in rzl['spawns']:
            rzl['spawns'][str(sp['id'])] = old_spawn_group.get(sp['id'])
    gave = {v for v in rzl['spawns'].values() if v}
    for sp in spawns:
        if sp['group']['id'] in gave and sp['id'] not in old_spawn_group and sp['id'] not in rzl['added']:
            rzl['added'].append(sp['id'])
    rzl['added'].sort()
    with open(ids_path, 'w', encoding='utf8', newline='\n') as f:
        json.dump(ledger, f, indent=0, sort_keys=True)
    groups.sort(key=lambda g: g['id'])
    spawns.sort(key=lambda s: s['id'])
    # a kept spawn keeps the rotation the previous 05 gave it (rotations come from creation order, which
    # shifts when rows are added or re-zoned)
    prev05 = os.path.join(out, 'seed_bnpc_05_spawn_locations.sql')
    if os.path.exists(prev05):
        prev_rot = {}
        for line in open(prev05, encoding='utf8'):
            m = re.match(r"^\((\d+),'',\d+,-?[\d.]+,-?[\d.]+,-?[\d.]+,(-?[\d.]+)\)", line)
            if m:
                prev_rot[int(m.group(1))] = float(m.group(2))
        for s in spawns:
            s['rot'] = prev_rot.get(s['id'], s['rot'])

    # ---- sanity: ranges
    assert all(GENUS_RANGE[0] <= g[0] <= GENUS_RANGE[1] for g in new_genus.values())
    assert all(POOL_RANGE[0] <= p['id'] <= POOL_RANGE[1] for p in pools.values())
    assert all(GROUP_RANGE[0] <= g['id'] <= GROUP_RANGE[1] for g in groups)
    assert all(BNPC_RANGE[0] <= s['id'] <= BNPC_RANGE[1] for s in spawns)

    place_stats = place_approx_rows(args, repo, groups, spawns)

    hdr = ('-- Generated by Tools/seed/build_spawn_seed.py from the "Eorzea 1.x Bestiary" artifact.\n'
           '-- DO NOT EDIT BY HAND - re-run the generator. Idempotent: deletes its own ID range first.\n'
           '-- See Tools/seed/README.md for provenance, trust tiers and guessed columns.\n\n')

    def w(name, body):
        with open(os.path.join(out, name), 'w', encoding='utf8', newline='\n') as f:
            f.write(hdr + body)

    # 01 genus
    b = ['-- New genus rows for bestiary families with no existing genus (ids %d..%d).' % GENUS_RANGE,
         '-- Stats are the table defaults (same as every existing genus row); detection guessed by kindred.',
         'DELETE FROM `server_battlenpc_genus` WHERE `genusId` BETWEEN %d AND %d;' % GENUS_RANGE]
    for fam, (gid, kid, kname) in new_genus.items():
        b.append("INSERT INTO `server_battlenpc_genus` (`genusId`,`name`,`modelSize`,`speed`,`kindredId`,"
                 "`kindredName`,`detection`) VALUES (%d,%s,1,8,%d,%s,%d);"
                 % (gid, sql_str(fam.replace(' ', '-')), kid, sql_str(kname), DETECTION_BY_KINDRED.get(kid, 0)))
    w('seed_bnpc_01_genus.sql', '\n'.join(b) + '\n')

    # 02 actor class paths
    flag_updates = sorted({p['cid'] for p in pools.values()
                           if not p['guessed'] and str(actor_class[p['cid']][2]) == '0'})
    b = ['-- Monster actor classes used by the seed whose classPath is empty in gamedata_actor_class.',
         '-- The Map Server skips classes with classPath = \'\' (WorldManager.LoadActorClasses), and a pool',
         '-- pointing at a skipped class throws NullReferenceException inside LoadBattleNpcs (only',
         '-- MySqlException is caught) which aborts the whole monster load.',
         '-- classPath here is GUESSED: the known classPath of the numerically nearest actor class with the',
         '-- same family code (digits 3-5 of the id, e.g. 21014xx = Wolf). Only rows that are still empty',
         '-- are touched, so re-running is safe. propertyFlags/eventConditions copy WolfStandard (2201407).',
         '-- Pools in seed_bnpc_03 are inserted only when their class has a classPath, so skipping this',
         '-- file simply drops those pools instead of crashing the server.']
    for cid, cp in sorted(classpath_updates.items()):
        b.append("UPDATE `gamedata_actor_class` SET `classPath`=%s, `propertyFlags`=IF(`propertyFlags`=0,%d,"
                 "`propertyFlags`), `eventConditions`=IFNULL(`eventConditions`,%s) WHERE `id`=%d AND "
                 "(`classPath`='' OR LOWER(`classPath`)=LOWER(%s) OR `classPath` IN (%s));"
                 % (sql_str(cp), PROPERTY_FLAGS_MONSTER, "'" + EVENT_CONDITIONS_MONSTER + "'", cid, sql_str(cp),
                    ','.join(sql_str(x) for x in OLD_WRONG_CASE.get(cp, [])) or "''"))
    b.append('-- Upstream monster classPaths that are not the client\'s exact _defineClass name (case-sensitive;')
    b.append('-- a mismatch crashes the client). Fixed to data/client_monster_classes.txt.')
    for cid, (old, new) in sorted(case_fixes.items()):
        b.append("UPDATE `gamedata_actor_class` SET `classPath`=%s WHERE `id`=%d AND `classPath`=%s;"
                 % (sql_str(new), cid, sql_str(old)))
    # Classes that already had a classPath but propertyFlags 0: charaWork.property[] is built from these
    # bits (Npc.cs), and with all of them clear the client shows no nameplate and won't target the mob.
    b.append('-- Monster classes used by the seed that already have a classPath but propertyFlags = 0')
    b.append('-- (no nameplate, not targetable): same flags/eventConditions as above.')
    for cid in flag_updates:
        b.append("UPDATE `gamedata_actor_class` SET `propertyFlags`=%d, `eventConditions`=IFNULL(`eventConditions`,%s) "
                 "WHERE `id`=%d AND `propertyFlags`=0;" % (PROPERTY_FLAGS_MONSTER, "'" + EVENT_CONDITIONS_MONSTER + "'", cid))
    w('seed_bnpc_02_actor_classes.sql', '\n'.join(b) + '\n')

    # 03 pools
    b = ['DELETE FROM `server_battlenpc_pool_mods` WHERE `poolId` BETWEEN %d AND %d;' % POOL_RANGE,
         'DELETE FROM `server_battlenpc_pools` WHERE `poolId` BETWEEN %d AND %d;' % POOL_RANGE,
         '-- INSERT ... SELECT guard: a pool is only created if its actor class is loadable (classPath <> \'\').']
    for key, p in sorted(pools.items(), key=lambda kv: kv[1]['id']):
        b.append("-- %s | genus %d | actorClass %d%s" % (p['name'], p['genus'], p['cid'],
                                                       ' (classPath guessed: %s)' % p['cp'] if p['guessed'] else ''))
        b.append("INSERT INTO `server_battlenpc_pools` (`poolId`,`actorClassId`,`name`,`genusId`,`currentJob`,"
                 "`combatSkill`,`combatDelay`,`combatDmgMult`,`aggroType`,`immunity`,`linkType`,`spellListId`,"
                 "`skillListId`) SELECT %d,%d,%s,%d,0,1,4200,1,%d,0,0,0,0 FROM `gamedata_actor_class` "
                 "WHERE `id`=%d AND `classPath`<>'';"
                 % (p['id'], p['cid'], sql_str(slug(p['name'], 50)), p['genus'], p['aggro'], p['cid']))
        if not p['nm']:
            # MobModifier.Roams=24, RoamDelay=25 (isMobMod=1).
            b.append("INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`) VALUES "
                     "(%d,24,1,1),(%d,25,20,1);" % (p['id'], p['id']))
        wx = [w for k, w in NM_WEATHER.items() if k in p.get('notes', '')] if p['nm'] else []
        if wx:
            b.append("INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`) VALUES "
                     "(%d,41,%d,1); -- SpawnWeather" % (p['id'], wx[0]))
        win = nm_window(p.get('notes', '')) if p['nm'] else None
        if win:
            # MobModifier.SpawnWindowStart=38 / SpawnWindowLength=39: Eorzea-time window [WIKI eLeMeN]
            b.append("INSERT INTO `server_battlenpc_pool_mods` (`poolId`,`modId`,`modVal`,`isMobMod`) VALUES "
                     "(%d,38,%d,1),(%d,39,%d,1); -- ET %02d-%02d" % (p['id'], win[0], p['id'], win[1], win[0],
                                                                 (win[0] + win[1]) % 24))
    w('seed_bnpc_03_pools.sql', '\n'.join(b) + '\n')

    # 04 groups
    b = ['DELETE FROM `server_battlenpc_groups` WHERE `groupId` BETWEEN %d AND %d;' % GROUP_RANGE,
         '-- hp/mp are guesses (see README). NMs are auto-spawned (spawnType 0) since 2026-10-03: respawn 300 s',
         '-- for the eLeMeN "every few minutes" NMs and the Eorzea-time-window NMs, --nm-respawn for the rest.']
    rows = []
    for g in groups:
        rows.append("(%d,%d,%s,%d,%d,%d,%d,%d,0,0,%d,0,0,'',0,%d) /* %s */"
                    % (g['id'], g['pool']['id'], sql_str(slug(g['pool']['name'], 50)), g['minlv'], g['maxlv'],
                       g['respawn'], g['hp'], g['mp'], 0, g['zone'],
                       g['note'].replace('*/', '')))
    for k in range(0, len(rows), 200):
        b.append("INSERT INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,"
                 "`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,"
                 "`privateAreaName`,`privateAreaLevel`,`zoneId`) VALUES\n" + ',\n'.join(rows[k:k + 200]) + ';')
    w('seed_bnpc_04_groups.sql', '\n'.join(b) + '\n')

    # 05 spawn locations
    b = ['DELETE FROM `server_battlenpc_spawn_locations` WHERE `bnpcId` BETWEEN %d AND %d;' % BNPC_RANGE,
         '-- positionY = 0 means height unknown -> snap to navmesh at load (see seed_bnpc_manifest.csv).',
         '-- comment: src/trust/approx  (approx=1: x/z from a map spot or zone centroid, +-100..200 units;',
         '-- "placed": put on the zone\'s walkable mesh offline by Tools/seed/navplace, see README)']
    rows = []
    for s in spawns:
        rows.append("(%d,'',%d,%.1f,%.1f,%.1f,%.3f) /* %s %s%s */"
                    % (s['id'], s['group']['id'], s['x'], s['y'], s['z'], s['rot'], s['src'], s['trust'],
                       (' approx' if s['approx'] else '') + (' placed' if s.get('placed') is not None else '')
                       + (' fallback' if s.get('fallback') else '')))
    for k in range(0, len(rows), 500):
        b.append("INSERT INTO `server_battlenpc_spawn_locations` (`bnpcId`,`customDisplayName`,`groupId`,"
                 "`positionX`,`positionY`,`positionZ`,`rotation`) VALUES\n" + ',\n'.join(rows[k:k + 500]) + ';')
    w('seed_bnpc_05_spawn_locations.sql', '\n'.join(b) + '\n')

    # 13 navmesh placement as in-place updates, for a DB that already has 05 and the hand-made 08/10/11
    # applied (re-applying 05 would bring back rows those deleted); 16 puts the old positions back
    placed = [s for s in spawns if s.get('placed') is not None]
    b = ['-- The approximate rows of seed_bnpc_05 moved onto the walkable navmesh (Tools/seed/navplace),',
         '-- as UPDATEs of the rows that still exist. Same positions as 05; apply this instead of re-applying 05',
         '-- when 08/10/11 are already in. Idempotent. Rollback: seed_bnpc_16_navmesh_placement_rollback.sql.']
    for s in placed:
        b.append("UPDATE `server_battlenpc_spawn_locations` SET `positionX`=%.1f,`positionY`=%.1f,`positionZ`=%.1f "
                 "WHERE `bnpcId`=%d AND `groupId`=%d;" % (s['x'], s['y'], s['z'], s['id'], s['group']['id']))
    w('seed_bnpc_13_navmesh_placement.sql', '\n'.join(b) + '\n')
    b = ['-- Undoes seed_bnpc_13_navmesh_placement.sql: rows still at their placed position go back to the',
         '-- approximate map-spot / centroid position.']
    for s in placed:
        b.append("UPDATE `server_battlenpc_spawn_locations` SET `positionX`=%.1f,`positionY`=%.1f,`positionZ`=%.1f "
                 "WHERE `bnpcId`=%d AND `groupId`=%d AND `positionX`=%.1f AND `positionZ`=%.1f;"
                 % (s['orig'][0], s['orig'][1], s['orig'][2], s['id'], s['group']['id'], s['x'], s['z']))
    w('seed_bnpc_16_navmesh_placement_rollback.sql', '\n'.join(b) + '\n')

    # 14 re-zoned rows as in-place changes, for a DB that already has 04/05: re-zoned groups move zone,
    # re-zoned rows move group, and groups that gained or lost re-zoned rows get their new rows; 15 undoes it
    rzl = ledger['rezone']
    live_rz_g = {g['id'] for g in groups if g.get('rz')}
    live_rz_s = {s['id'] for s in spawns if s.get('rz')}
    gnew = [g for g in groups if g['id'] in live_rz_g and rzl['groups'].get(str(g['id'])) is None]
    gmoved = [g for g in groups if g['id'] in live_rz_g and rzl['groups'].get(str(g['id'])) not in (None, g['zone'])]
    old_group_zone = {int(k): v for k, v in rzl['groups'].items() if v is not None}
    old_spawn_group = {int(k): v for k, v in rzl['spawns'].items() if v is not None}
    added = set(rzl['added'])
    snew = [s for s in spawns if (s['id'] in live_rz_s and rzl['spawns'].get(str(s['id'])) is None) or s['id'] in added]
    smoved = [s for s in spawns if s['id'] in live_rz_s and old_spawn_group.get(s['id'], s['group']['id']) != s['group']['id']]
    b = ['-- Field rows that had no ground in their labelled zone, moved to the one zone of the region that has',
         '-- ground there (see README, "Re-zoned rows"), as in-place changes for a DB that already has 04/05.',
         '-- Same result as 04/05; apply before 13. Idempotent. Rollback: seed_bnpc_15_rezone_rollback.sql.']
    for g in gnew:
        b.append("INSERT IGNORE INTO `server_battlenpc_groups` (`groupId`,`poolId`,`scriptName`,`minLevel`,`maxLevel`,"
                 "`respawnTime`,`hp`,`mp`,`dropListId`,`allegiance`,`spawnType`,`animationId`,`actorState`,"
                 "`privateAreaName`,`privateAreaLevel`,`zoneId`) VALUES (%d,%d,%s,%d,%d,%d,%d,%d,0,0,0,0,0,'',0,%d);"
                 " -- %s" % (g['id'], g['pool']['id'], sql_str(slug(g['pool']['name'], 50)), g['minlv'], g['maxlv'],
                             g['respawn'], g['hp'], g['mp'], g['zone'], g['note']))
    for g in gmoved:
        b.append("UPDATE `server_battlenpc_groups` SET `zoneId`=%d WHERE `groupId`=%d; -- %s, was zone %d"
                 % (g['zone'], g['id'], g['note'], old_group_zone[g['id']]))
    for s in smoved:
        b.append("UPDATE `server_battlenpc_spawn_locations` SET `groupId`=%d WHERE `bnpcId`=%d AND `groupId`=%d;"
                 % (s['group']['id'], s['id'], old_spawn_group[s['id']]))
    for s in snew:
        b.append("INSERT IGNORE INTO `server_battlenpc_spawn_locations` (`bnpcId`,`customDisplayName`,`groupId`,"
                 "`positionX`,`positionY`,`positionZ`,`rotation`) VALUES (%d,'',%d,%.1f,%.1f,%.1f,%.3f);"
                 % (s['id'], s['group']['id'], s['x'], s['y'], s['z'], s['rot']))
    w('seed_bnpc_14_rezone.sql', '\n'.join(b) + '\n')
    b = ['-- Undoes seed_bnpc_14_rezone.sql.']
    for s in snew:
        b.append("DELETE FROM `server_battlenpc_spawn_locations` WHERE `bnpcId`=%d;" % s['id'])
    for s in smoved:
        b.append("UPDATE `server_battlenpc_spawn_locations` SET `groupId`=%d WHERE `bnpcId`=%d AND `groupId`=%d;"
                 % (old_spawn_group[s['id']], s['id'], s['group']['id']))
    for g in gmoved:
        b.append("UPDATE `server_battlenpc_groups` SET `zoneId`=%d WHERE `groupId`=%d;" % (old_group_zone[g['id']], g['id']))
    for g in gnew:
        b.append("DELETE FROM `server_battlenpc_groups` WHERE `groupId`=%d;" % g['id'])
    w('seed_bnpc_15_rezone_rollback.sql', '\n'.join(b) + '\n')

    # 07 family elemental affinity (genus columns + genus_mods read by battle/formulas.lua)
    fam_el = {}
    with open(os.path.join(repo, 'Tools', 'seed', 'data', 'family_elements.csv'), encoding='utf8') as f:
        for r in csv.DictReader(f):
            fam_el[r['family']] = (r['element'], r['weakness'], r['source'])
    genus_el = collections.OrderedDict()
    for gid, el in ELEMENTAL_GENUS_ELEMENT.items():
        genus_el[gid] = (el, BEATS_INV[el], 'elemental by name')
    all_fams = dict(FAMILY_TO_GENUS)
    all_fams.update({fam: v[0] for fam, v in new_genus.items()})
    for fam, (el, wk, src) in sorted(fam_el.items()):
        gid = all_fams.get(fam)
        if gid is None or gid in genus_el:
            continue
        genus_el[gid] = (el, wk, '%s: %s' % (fam, src))
    b = ['-- Elemental affinity per genus (Research Notes 05 D6 model, see build_spawn_seed.py ELEMENTS).',
         '-- genus fire..water = damage-taken multiplier, element = actionProperty id (5 Fire .. 10 Water).',
         '-- genus_mods isMobMod=1, modId 30-35 = MobModifier.AffinityFire..Water (% change, applied by the',
         '-- loader for every spawn; read by battle/formulas.lua). Neutral families get nothing.',
         "UPDATE `server_battlenpc_genus` SET `fire`=1,`ice`=1,`wind`=1,`lightning`=1,`earth`=1,`water`=1,`element`=0;",
         'DELETE FROM `server_battlenpc_genus_mods` WHERE `isMobMod`=1 AND `modId` BETWEEN 30 AND 35;']
    for gid, (el, wk, src) in sorted(genus_el.items()):
        d = affinity_deltas(el, wk)
        b.append('-- genus %d: element %s, weak %s (%s)' % (gid, el or '-', wk or '-', src))
        b.append("UPDATE `server_battlenpc_genus` SET %s,`element`=%d WHERE `genusId`=%d;" % (
            ','.join('`%s`=%.2f' % (e.lower(), 1 + d[e] / 100.0) for e in ELEMENTS), ELEMENT_ID.get(el, 0), gid))
        vals = ','.join('(%d,%d,%d,1)' % (gid, AFFINITY_MOBMOD[e], d[e]) for e in ELEMENTS if d[e])
        if vals:
            b.append("INSERT INTO `server_battlenpc_genus_mods` (`genusId`,`modId`,`modVal`,`isMobMod`) VALUES %s;" % vals)
    w('seed_bnpc_07_family.sql', '\n'.join(b) + '\n')

    # 99 rollback
    b = ['DELETE FROM `server_battlenpc_spawn_locations` WHERE `bnpcId` BETWEEN %d AND %d;' % BNPC_RANGE,
         'DELETE FROM `server_battlenpc_groups` WHERE `groupId` BETWEEN %d AND %d;' % GROUP_RANGE,
         'DELETE FROM `server_battlenpc_pool_mods` WHERE `poolId` BETWEEN %d AND %d;' % POOL_RANGE,
         'DELETE FROM `server_battlenpc_pools` WHERE `poolId` BETWEEN %d AND %d;' % POOL_RANGE,
         'DELETE FROM `server_battlenpc_genus` WHERE `genusId` BETWEEN %d AND %d;' % GENUS_RANGE]
    for cid, cp in sorted(classpath_updates.items()):
        b.append("UPDATE `gamedata_actor_class` SET `classPath`='', `propertyFlags`=0, `eventConditions`=NULL "
                 "WHERE `id`=%d AND `classPath`=%s;" % (cid, sql_str(cp)))
    for cid in flag_updates:
        b.append("UPDATE `gamedata_actor_class` SET `propertyFlags`=0, `eventConditions`=NULL "
                 "WHERE `id`=%d AND `propertyFlags`=%d;" % (cid, PROPERTY_FLAGS_MONSTER))
    for cid, (old, new) in sorted(case_fixes.items()):
        b.append("UPDATE `gamedata_actor_class` SET `classPath`=%s WHERE `id`=%d AND `classPath`=%s;"
                 % (sql_str(old), cid, sql_str(new)))
    b.append("UPDATE `server_battlenpc_genus` SET `fire`=1,`ice`=1,`wind`=1,`lightning`=1,`earth`=1,`water`=1,`element`=0;")
    b.append('DELETE FROM `server_battlenpc_genus_mods` WHERE `isMobMod`=1 AND `modId` BETWEEN 30 AND 35;')
    w('seed_bnpc_99_rollback.sql', '\n'.join(b) + '\n')

    # manifest
    with open(os.path.join(out, 'seed_bnpc_manifest.csv'), 'w', encoding='utf8', newline='') as f:
        cw = csv.writer(f)
        cw.writerow(['bnpcId', 'groupId', 'poolId', 'zoneId', 'zoneName', 'bestiaryZone', 'monster',
                     'actorClassId', 'classPathGuessed', 'x', 'y', 'z', 'rot', 'source', 'trust', 'xzErr',
                     'approxXZ', 'yKnown', 'yHint', 'needsNavSnap', 'zoneHasNavmesh', 'nm', 'navPlacedMoved'])
        for s in spawns:
            g = s['group']
            p = g['pool']
            cw.writerow([s['id'], g['id'], p['id'], g['zone'], g['zname'], s['zone_name'], s['monster'],
                         p['cid'], int(p['guessed']), s['x'], s['y'], s['z'], s['rot'], SRC_NAME[s['src']],
                         s['trust'], s['xz_err'], s['approx'], s['y_known'],
                         '' if s.get('y_hint') is None else s['y_hint'],
                         int(s['y_known'] != 1), int(g['zname'] in NAVMESH_ZONES), int(g['nm']),
                         '' if s.get('placed') is None else s['placed']])

    # Lua stubs
    for cp in sorted(lua_needed):
        d, cls = cp.rsplit('/', 1)
        rel = os.path.join('base', *d.lstrip('/').lower().split('/'), cls + '.lua')
        pth = os.path.join(lua_out, rel)
        os.makedirs(os.path.dirname(pth), exist_ok=True)
        with open(pth, 'w', encoding='utf8', newline='\n') as f:
            f.write(LUA_STUB.format(classPath=cp))

    # ---- report
    zc = collections.OrderedDict()
    for s in spawns:
        k = s['group']['zname']
        c = zc.setdefault(k, collections.Counter())
        c['spawns'] += 1
        c['nm' if s['group']['nm'] else 'normal'] += 1
        c['approx'] += s['approx']
        c['src_' + s['src']] += 1
        c['y_known'] += 1 if s['y_known'] else 0
    gz = collections.Counter(g['zname'] for g in groups)
    print('monsters seeded: %s  skipped: %s' % (dict(mon_ok), dict(skipped)))
    print('retail captures: %s  grid spots unresolved: %d  resolved by navmesh probe: %d'
          % (dict(retail_stats), spot_unresolved, spot_by_probe))
    print('ids: %s' % dict(id_stats))
    if rezoned:
        print('re-zoned field points (no ground in the labelled zone): %s'
              % ', '.join('%s -> %s %d' % (a, b, n) for (a, b), n in sorted(rezoned.items())))
    todo_path = os.path.join(os.path.dirname(probe_path), 'navmesh_probe_todo.json')
    if probe_todo:
        with open(todo_path, 'w', encoding='utf8') as f:
            json.dump(sorted(probe_todo), f, indent=0)
        print('navmesh probe: %d queries missing -> %s (run Tools/seed/probe_navmesh.lua, re-run)'
              % (len(probe_todo), todo_path))
    elif os.path.exists(todo_path):
        os.remove(todo_path)
    if place_stats:
        print('navmesh placement: %(rows)d approximate rows, %(placed)d placed (%(moved)d moved > 1y, max %(max).1fy '
              'by spawn %(max_id)s), %(unplaced)d unplaceable, %(stale)d without a result' % place_stats)
    print('genus new: %d  pools: %d (guessed classPath: %d)  groups: %d  spawns: %d  lua stubs: %d'
          % (len(new_genus), len(pools), sum(p['guessed'] for p in pools.values()), len(groups), len(spawns),
             len(lua_needed)))
    print('zone\tid\tnavmesh\tgroups\tspawns\tnormal\tnm\tretail\tnavmut\taurora\tspot\tcentroid\tapproxXZ\tyKnown')
    for k in sorted(zc, key=lambda k: zones[k][0]):
        c = zc[k]
        print('%s\t%d\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d' % (
            k, zones[k][0], 'Y' if k in NAVMESH_ZONES else 'N', gz[k], c['spawns'], c['normal'], c['nm'],
            c['src_retail'], c['src_navmut'], c['src_aurora'], c['src_spot'], c['src_centroid'], c['approx'],
            c['y_known']))


if __name__ == '__main__':
    main()
