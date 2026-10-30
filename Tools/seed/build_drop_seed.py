#!/usr/bin/env python3
"""
build_drop_seed.py - generate Project Meteor monster drop lists from the "Eorzea 1.x Loot Ledger"
artifact (https://claude.ai/artifact/2iokZyUfqL9GbFAWtLJKGf).

Inputs (read-only):
  * the loot ledger HTML (single-line `const D={...}` JSON blob), or a JSON extract of it
  * Data/sql/gamedata_items.sql                (item names -> catalogID)
  * Data/sql/seed/seed_bnpc_manifest.csv       (spawn groups -> monster name, zone, level)
  * Data/sql/seed/seed_bnpc_04_groups.sql      (group level ranges)

Output: Data/sql/seed/seed_drop_01_lists.sql
  * (re)creates server_battlenpc_drop_list
  * one drop list per seeded spawn group (dropListId = groupId), so per-zone tables and the
    group's level (crystal tier, gil amount) are resolved here and the runtime only rolls rows
  * sets server_battlenpc_groups.dropListId for those groups

Rules are the 1.23b loot spec; every number not backed by a
source is a design choice and is marked as such there.

Row semantics (Map Server/Actors/Chara/Npc/DropList.cs):
  groupId 0  -> independent roll: chance rate/10000
  groupId N  -> one roll per group at groupRate/10000; on success one row is picked, weighted by rate
  quantity uniform in [minQty, maxQty]; hqRate/10000 chance of +1 (quality 2)

Usage:
  python Tools/seed/build_drop_seed.py --ledger <artifact.html|loot.json> [--repo .]
"""
import argparse
import collections
import csv
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from build_spawn_seed import parse_sql_values, sql_str  # noqa: E402

GIL = 1000001
SHARD = {'Fire': 1000003, 'Ice': 1000004, 'Wind': 1000005, 'Earth': 1000006, 'Lightning': 1000007, 'Water': 1000008}
CRYSTAL = {k: v + 6 for k, v in SHARD.items()}

MAX_P, MIN_P = 0.60, 0.01
PRIOR_WEIGHT = 20           # GE counts blend: (a + 20*p0) / (b + 20)
HQ_RATE = 0.12              # materials/consumables, emitted as +1
CRYSTAL_RATE = 0.40
GIL_RATE = 0.50

MATERIAL, AMMO, CONSUMABLE, GEAR = 0.20, 0.40, 0.10, 0.03
COIN_GRADE = (0.20, 0.08, 0.03)
COFFER_KEY, KEYSTONE = 0.15, 0.10
NM_RARE, NM_UNCOMMON, NM_GEAR = 0.15, 0.25, 0.08
OVERRIDE = {'Karakul Fleece': 0.04}   # 37/1040 kills (Thend, 2011-11)

AMMO_CATS = {'Arrow', 'Throwing Stone', 'Throwing Axe'}
CONSUMABLE_CATS = {'Potion', 'Ether', 'Panacea', 'Foodstuff', 'Drink', 'Seasoning', 'Medicine', 'Meal', 'Grain Dish'}
GEAR_CATS = {'Armor', 'Necklace', 'Pants', 'Attire', 'Ring', 'Earrings', 'Bracelets', 'Belt', 'Gloves',
             'Footwear', 'Headgear', 'Body', 'Legs', 'Hands', 'Feet', 'Head', 'Waist', 'Shield',
             "Gladiator's Arm", "Pugilist's Arm", "Marauder's Arm", "Lancer's Arm", "Archer's Arm",
             "Conjurer's Arm", "Thaumaturge's Arm", 'Sword', 'Axe', 'Polearm', 'Bow', 'Staff', 'Wand',
             'Dagger', 'Knuckles', 'Cesti', 'Armlets', 'Choker', 'Wristlet', 'War Garb', 'Shoes',
             'Eyewear', 'Hat', 'Helm', 'Gauntlets', 'Headwear', 'Greaves', 'Mask', 'Hooded Attire',
             'Cloth Sleeve', 'Armor Leather'}
# 1.20 [dev1259] / 1.20a: these drop everywhere the mob lives
ZONE_FREE = {('Boar Hide', m) for m in ('Wild Hog', 'Buata', 'Hog', 'Tusked Hog', 'Swinging Swine', 'Truffle Hog')}
REMOVED_121 = {'Highland Parsley', 'Poisoning Potion', 'Jerked Beef', 'Potion', 'Ether'}
SKIP_FAMILIES = {'Primal'}
# bestiary family -> eLeMeN crystal genus
CRYS_ALIAS = {'Ram': 'Sheep', 'Crab': 'Megalocrab', 'Angler': 'Orobon', 'Aurelia': 'Jellyfish',
              'Toad': 'Gigantoad', 'Cockatrice': 'Dodo', 'Landtrap': 'Flying Trap', 'Flytrap': 'Flying Trap',
              'Swarm': 'Sworm', 'Ixal': 'Ixali', 'Wisp': "Will-o'-the-Wisp", 'Snurble': 'Phurble',
              'Fomor': 'The Damned', 'Enemy Humanoid': 'Human', 'Opo-Opo': 'Opo-opo',
              'Wolf/Hyena/Hellhound': 'Wolf', 'Aldgoats': 'Aldgoat', "Amlaj'aa": "Amalj'aa",
              'Couerl': 'Coeurl', 'Cyclopes': 'Cyclops', 'Hedgemole': 'Mole', 'Rat': 'Rodent',
              'Sabotender': 'Cactuar', 'Earth Elemental': 'Elemental', 'Fire Elemental': 'Elemental'}
ELEMENTS = ('Fire', 'Ice', 'Wind', 'Earth', 'Lightning', 'Water')


def load_ledger(path):
    with open(path, encoding='utf8') as f:
        if path.endswith('.json'):
            return json.load(f)
        for line in f:
            if line.lstrip().startswith('const D='):
                return json.loads(line.strip()[len('const D='):].rstrip(';'))
    raise SystemExit('const D= not found in ' + path)


def item_index(repo):
    by_name = collections.defaultdict(list)
    info = {}
    for r in parse_sql_values(os.path.join(repo, 'Data/sql/gamedata_items.sql'), 'gamedata_items'):
        cid, name, cat, max_stack, is_rare = r[0], r[1], r[2], r[3], r[4]
        if cat == 'Normal/DummyItem':
            continue
        by_name[name.lower()].append(cid)
        info[cid] = (name, cat, max_stack, is_rare)
    return by_name, info


def resolve(name, by_name):
    """-> (catalogID, quality) or None. Ledger names predate the 1.21 'Dated' rename and
    sometimes carry a +N quality suffix."""
    q = 1
    m = re.match(r'^(.*?)\s*\+(\d)$', name)
    if m:
        name, q = m.group(1), 1 + int(m.group(2))
    cands = (name, 'Dated ' + name, name + 's', 'Dated ' + name + 's', re.sub(r' (Belt|Staff)$', '', name))
    for cand in cands:
        ids = by_name.get(cand.lower())
        if ids:
            return min(ids), q
    # undyed piece missing: take the first dye variant ("Dated Leather Harness (Black)")
    for cand in cands[:2]:
        ids = [i for n, l in by_name.items() if n.startswith(cand.lower() + ' (') for i in l]
        if ids:
            return min(ids), q
    return None


def ge_counts(pair):
    best = None
    for s in pair[6]:
        m = re.match(r'GE params (\d+)\|(\d+)', s[2])
        if m:
            a, b = int(m.group(1)), int(m.group(2))
            if a <= b and (best is None or b > best[1]):
                best = (a, b)
    return best


def tags(pair):
    return ' '.join(s[2] for s in pair[6])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ledger', required=True)
    ap.add_argument('--repo', default='.')
    args = ap.parse_args()
    D = load_ledger(args.ledger)
    repo = args.repo
    by_name, info = item_index(repo)

    coin_grade = {}
    for c in D['coins']:
        for g, n in enumerate(c[1:4]):
            coin_grade[n] = g
    crys = {c[0]: [e.strip() for e in c[1].split('>') if e.strip()] for c in D['crys']}

    # spawn groups from the bestiary seed
    man = list(csv.DictReader(open(os.path.join(repo, 'Data/sql/seed/seed_bnpc_manifest.csv'), encoding='utf8')))
    groups = {}
    for r in man:
        groups.setdefault(int(r['groupId']), (r['monster'], r['bestiaryZone'], r['nm'] == '1'))
    levels = {}
    for r in parse_sql_values(os.path.join(repo, 'Data/sql/seed/seed_bnpc_04_groups.sql'), 'server_battlenpc_groups'):
        levels[r[0]] = (r[3], r[4])

    log = collections.Counter()
    unresolved = collections.Counter()
    by_mon = collections.defaultdict(list)
    for p in D['pairs']:
        mon, item, zones, cat, note, in123 = p[:6]
        fam = (D['mon'].get(mon) or [''])[0]
        if in123 == 'no':
            log['excluded: gone by 1.23b'] += 1; continue
        if re.search(r'\+3$', item):
            log['excluded: +3 row (HQ roll replaces it)'] += 1; continue
        if 'Quest Item' in item or cat == 'Quest Item':
            log['excluded: quest item'] += 1; continue
        if fam in SKIP_FAMILIES or item == 'Voidstone':
            log['excluded: primal/instance'] += 1; continue
        if item in REMOVED_121:
            log['excluded: removed 1.21'] += 1; continue
        nm = (D['mon'].get(mon) or ['', '', '', '', ''])[4] == 'Y'
        if item in ("Iron Amalj'ok", "Darksteel Amalj'ok") and not nm:
            log["excluded: Amalj'ok (1.23 change)"] += 1; continue
        r = resolve(item, by_name)
        if not r:
            unresolved[item] += 1; continue
        by_mon[mon].append((p, r, nm))

    def chance(p, nm):
        mon, item, _, cat = p[:4]
        t = tags(p)
        if item in OVERRIDE:
            return OVERRIDE[item]
        if item in coin_grade:
            p0 = COIN_GRADE[coin_grade[item]]
        elif 'Coffer Key' in item:
            p0 = COFFER_KEY
        elif item == 'Unmarked Keystone':
            p0 = KEYSTONE
        elif cat in AMMO_CATS:
            p0 = AMMO
        elif cat in CONSUMABLE_CATS:
            p0 = CONSUMABLE
        elif cat in GEAR_CATS or cat.endswith("'s Arm") or cat.endswith("'s Tool"):
            if nm:
                p0 = NM_RARE if ('◆◆' in t or 'notable' in t) else NM_UNCOMMON if '◆' in t else NM_GEAR
            else:
                p0 = GEAR
        else:
            p0 = MATERIAL
            if nm and ('◆◆' in t or 'notable' in t):
                p0 = NM_RARE
        c = ge_counts(p)
        v = (c[0] + PRIOR_WEIGHT * p0) / (c[1] + PRIOR_WEIGHT) if c else p0
        return max(MIN_P, min(MAX_P, v))

    def hq_ok(p, cid):
        cat = p[3]
        return (cat not in GEAR_CATS and cat not in AMMO_CATS and p[1] not in coin_grade
                and 'Key' not in p[1] and not info[cid][1].startswith('Money/') and info[cid][2] > 1)

    def crystal_rows(fam, mon, lvl):
        if 'Elemental' in fam or mon.endswith('Elemental') or 'Wrath' in mon:
            el = next((e for e in ELEMENTS if e in mon), None)
            elems = [el] if el else []
        else:
            elems = crys.get(CRYS_ALIAS.get(fam, fam), [])
        if not elems:
            return []
        weights = {1: [10000], 2: [7000, 3000], 3: [6000, 3000, 1000]}[min(len(elems), 3)]
        rows = []
        for e, w in zip(elems[:3], weights):
            if lvl < 20:
                rows.append((SHARD[e], w, 1, 3))
            elif lvl < 40:
                rows.append((SHARD[e], w // 2, 1, 3))
                rows.append((CRYSTAL[e], w - w // 2, 1, 1))
            else:
                rows.append((CRYSTAL[e], w, 1, 3))
        return rows

    out = []
    stats = collections.Counter()
    for gid in sorted(groups):
        mon, zone, nm_flag = groups[gid]
        lo, hi = levels.get(gid, (1, 1))
        lvl = (lo + hi) // 2
        fam = (D['mon'].get(mon) or [''])[0]
        pairs = by_mon.get(mon, [])
        nm = nm_flag or any(x[2] for x in pairs)
        sel = [x for x in pairs if not x[0][2] or zone in x[0][2].split('; ')
               or (x[0][1], mon) in ZONE_FREE or x[0][1] == 'Unmarked Keystone']
        if pairs and not sel:
            sel = pairs
            stats['groups using zone fallback'] += 1
        rows = []
        seen = set()
        for p, (cid, q), _ in sel:
            if (cid, q) in seen:
                continue
            seen.add((cid, q))
            rate = round(chance(p, nm) * 10000)
            mx = 3 if p[3] in AMMO_CATS else 1
            hq = round(HQ_RATE * 10000) if q == 1 and hq_ok(p, cid) else 0
            stale = ' stale' if any(s[3] and s[3] < '2012-03-08' for s in p[6] if s[0].startswith('Gamer')) else ''
            rows.append((0, 0, cid, rate, 1, mx, hq, q, '%s%s' % (p[1], stale)))
        for cid, w, mn, mx in crystal_rows(fam, mon, lvl):
            rows.append((1, round(CRYSTAL_RATE * 10000), cid, w, mn, mx, 0, 1, 'crystal'))
        if fam == 'Enemy Humanoid':
            mult = 10 if nm else 1
            rows.append((0, 0, GIL, 10000 if nm else round(GIL_RATE * 10000), lvl * mult, 2 * lvl * mult, 0, 1, 'gil'))
        if rows:
            out.append((gid, mon, zone, rows))
            stats['groups with drops'] += 1
            stats['rows'] += len(rows)
        else:
            stats['groups without drops'] += 1

    path = os.path.join(repo, 'Data/sql/seed/seed_drop_01_lists.sql')
    with open(path, 'w', encoding='utf8') as f:
        f.write('-- Generated by Tools/seed/build_drop_seed.py from the "Eorzea 1.x Loot Ledger" artifact.\n'
                '-- DO NOT EDIT BY HAND - re-run the generator. Rules:\n'
                '-- Rates are per 10000. groupId 0 = independent roll; groupId N = one roll at groupRate,\n'
                '-- then one row picked weighted by rate. dropListId = spawn groupId.\n\n')
        f.write('CREATE TABLE IF NOT EXISTS `server_battlenpc_drop_list` (\n'
                '  `dropListId` int(10) unsigned NOT NULL,\n'
                '  `groupId` tinyint(3) unsigned NOT NULL DEFAULT 0,\n'
                '  `groupRate` smallint(5) unsigned NOT NULL DEFAULT 0,\n'
                '  `itemId` int(10) unsigned NOT NULL,\n'
                '  `rate` smallint(5) unsigned NOT NULL,\n'
                '  `minQty` int(10) unsigned NOT NULL DEFAULT 1,\n'
                '  `maxQty` int(10) unsigned NOT NULL DEFAULT 1,\n'
                '  `hqRate` smallint(5) unsigned NOT NULL DEFAULT 0,\n'
                '  `quality` tinyint(3) unsigned NOT NULL DEFAULT 1,\n'
                '  PRIMARY KEY (`dropListId`,`groupId`,`itemId`,`quality`)\n'
                ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;\n\n')
        f.write('DELETE FROM `server_battlenpc_drop_list` WHERE `dropListId` BETWEEN 100001 AND 199999;\n')
        f.write('UPDATE `server_battlenpc_groups` SET `dropListId` = 0 WHERE `groupId` BETWEEN 100001 AND 199999;\n\n')
        cols = '(`dropListId`,`groupId`,`groupRate`,`itemId`,`rate`,`minQty`,`maxQty`,`hqRate`,`quality`)'
        for gid, mon, zone, rows in out:
            f.write('-- %d %s / %s\n' % (gid, mon, zone))
            f.write('INSERT INTO `server_battlenpc_drop_list` %s VALUES\n' % cols)
            f.write(',\n'.join('(%d,%d,%d,%d,%d,%d,%d,%d,%d) /* %s */' % ((gid,) + r[:8] + (r[8].replace('*/', ''),))
                               for r in rows) + ';\n')
        f.write('\nUPDATE `server_battlenpc_groups` SET `dropListId` = `groupId` WHERE `groupId` IN (%s);\n'
                % ','.join(str(g) for g, _, _, _ in out))

    rb = os.path.join(repo, 'Data/sql/seed/seed_drop_99_rollback.sql')
    with open(rb, 'w', encoding='utf8') as f:
        f.write('-- Removes everything seed_drop_01_lists.sql added.\n'
                'DELETE FROM `server_battlenpc_drop_list` WHERE `dropListId` BETWEEN 100001 AND 199999;\n'
                'UPDATE `server_battlenpc_groups` SET `dropListId` = 0 WHERE `groupId` BETWEEN 100001 AND 199999;\n')

    for k, v in sorted(log.items()):
        print('%5d %s' % (v, k))
    for k, v in sorted(stats.items()):
        print('%5d %s' % (v, k))
    if unresolved:
        print('unresolved item names (%d): %s' % (len(unresolved), ', '.join(sorted(unresolved))))
    print('wrote', path)


if __name__ == '__main__':
    main()
