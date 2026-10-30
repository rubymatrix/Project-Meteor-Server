#!/usr/bin/env python3
"""Export spawn points and map objects per zone for navgen (navgen/docs/FORMATS.md section 2).

Writes <out>/<zoneName>.json for every zone that has at least one spawn or map object:

  { "version": 1, "zone": "wil0Town01",
    "spawns":  [ { "id": 1001, "pos": [x, y, z], "kind": "bnpc" } ],
    "mapobjs": [ { "actor": 589, "name": "gridania_shipport", "layoutId": 321, "instanceId": 3294,
                   "pos": [x, y, z], "rot": [0, ry, 0], "prefab": null,
                   "instance": "isgrp_003294", "layout": "fst_f0_twn01", "node": 2461,
                   "tree": "sgrp_bg_airport", "group": null } ] }

Zones are named by zoneName, except where the collision package's zones.json gives that zone id its own
key (several server zones share a zoneName, e.g. sea0Field01a is both 139 The Cieldalaes and 141, a copy
of sea0Field01 that zones.json calls "sea0Field01a#141"); navgen merges a sameAs key's file into its target.

Spawn kinds: bnpc (server_battlenpc_spawn_locations), enpc (server_eventnpc_spawn_locations;
`object` for MapObj/Object classes such as doors and aetheryte gates), border (seamless
crossing boxes from server_seamless_zonechange_bounds, height unknown),
entrance (server_zones_spawnlocations), aetheryte (aetheryteTeleportPositions in
Data/scripts/aetheryte.lua). Spawns inside a private area carry "privateArea"; they share the parent
zone's geometry.

The client binds a map object to the InstanceObject named isgrp_<instanceId, 6 digits> in the
layout with that layout id. That instance is placed in the zone's layout, so its collision is
already in static.xcol (as the dynamic group "<tree>@<node>" when the tree switches collision);
"prefab" stays null and "group" names that group. The lookup table is the collision package's
mapobj_index.json (navgen/tools/dump_collision.py).

The database is only read. The password comes from meteor-server/.dbpass (or MYSQL_PWD) and is
passed to mysql through the environment, never on the command line.

  python3 Tools/seed/export_mapobj.py [--out ../navgen/mapobj] [--zone wil0Town01 ...]
"""
import argparse
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..'))


def find_up(name):
    d = REPO
    while True:
        p = os.path.join(d, name)
        if os.path.exists(p):
            return p
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent


def db(sql, args, password):
    cmd = ['mysql', '-u' + args.user, '-h' + args.host, '-P' + str(args.port), args.database, '--batch', '--raw', '-e', sql]
    env = dict(os.environ, MYSQL_PWD=password)
    out = subprocess.run(cmd, capture_output=True, text=True, env=env)
    if out.returncode != 0:
        raise SystemExit(out.stderr.strip())
    lines = out.stdout.splitlines()
    if not lines:
        return []
    hdr = lines[0].split('\t')
    rows = []
    for line in lines[1:]:
        rows.append({k: (None if v == 'NULL' else v) for k, v in zip(hdr, line.split('\t'))})
    return rows


def f(v):
    return round(float(v), 3) if v is not None else 0.0


def aetherytes(path):
    """class id -> (zoneId, x, y, z) from aetheryteTeleportPositions."""
    if not path or not os.path.exists(path):
        return {}
    text = open(path, encoding='utf-8', errors='replace').read()
    m = re.search(r'aetheryteTeleportPositions\s*=\s*\{(.*?)\n\}', text, re.S)
    if not m:
        return {}
    out = {}
    for line in m.group(1).splitlines():
        line = line.split('--', 1)[0]
        e = re.match(r'\s*\[(\d+)\]\s*=\s*\{\s*(\d+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\}', line)
        if e:
            out[int(e.group(1))] = (int(e.group(2)), float(e.group(3)), float(e.group(4)), float(e.group(5)))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--out', default=None, help='output folder (default: the workspace navgen/mapobj)')
    ap.add_argument('--zone', action='append', help='only these zone names (repeatable)')
    ap.add_argument('--host', default='127.0.0.1')
    ap.add_argument('--port', type=int, default=3306)
    ap.add_argument('--user', default='meteor')
    ap.add_argument('--database', default='ffxiv_server')
    ap.add_argument('--mapobj-index', default=None,
                    help='collision package mapobj_index.json (default: the workspace collision/)')
    ap.add_argument('--zones-json', default=None,
                    help='collision package zones.json (default: the workspace collision/)')
    ap.add_argument('--aetheryte-lua', default=os.path.join(REPO, 'Data', 'scripts', 'aetheryte.lua'))
    args = ap.parse_args()

    password = os.environ.get('MYSQL_PWD')
    if password is None:
        dbpass = find_up('.dbpass')
        if dbpass is None:
            raise SystemExit('no .dbpass found and MYSQL_PWD not set')
        password = open(dbpass).read().strip()

    out_dir = args.out
    if out_dir is None:
        navgen = find_up('navgen')
        if navgen is None:
            raise SystemExit('navgen folder not found; pass --out')
        out_dir = os.path.join(navgen, 'mapobj')
    os.makedirs(out_dir, exist_ok=True)

    index_path = args.mapobj_index
    if index_path is None:
        col = find_up('collision')
        index_path = os.path.join(col, 'mapobj_index.json') if col else None
    binding = {}
    if index_path and os.path.exists(index_path):
        binding = json.load(open(index_path))['layouts']
    else:
        print('warning: no mapobj_index.json; map objects keep no binding', file=sys.stderr)

    zones = {int(r['id']): r['zoneName'] for r in db('SELECT id, zoneName FROM server_zones', args, password) if r['zoneName']}
    zones_json = args.zones_json
    if zones_json is None:
        col = find_up('collision')
        zones_json = os.path.join(col, 'zones.json') if col else None
    if zones_json and os.path.exists(zones_json):
        keys = {}
        for key, z in json.load(open(zones_json))['zones'].items():
            for zid in {z.get('zoneId')} | set(z.get('zoneIds', [])):
                if zid is not None:
                    keys.setdefault(zid, []).append(key)
        for zid, name in list(zones.items()):
            if len(keys.get(zid, [])) == 1 and keys[zid][0] != name:
                zones[zid] = keys[zid][0]
    else:
        print('warning: no zones.json; zones that share a zoneName share a file', file=sys.stderr)
    data = {}

    def zone_entry(zone_id):
        name = zones.get(zone_id)
        if name is None:
            return None
        return data.setdefault(name, {'version': 1, 'zone': name, 'spawns': [], 'mapobjs': []})

    def add_spawn(zone_id, sid, x, y, z, kind, private_area=None):
        e = zone_entry(zone_id)
        if e is None:
            return
        s = {'id': sid, 'pos': [f(x), f(y), f(z)], 'kind': kind}
        if private_area:
            s['privateArea'] = private_area
        e['spawns'].append(s)

    for r in db('''SELECT s.bnpcId, s.positionX, s.positionY, s.positionZ, g.zoneId, g.privateAreaName
                   FROM server_battlenpc_spawn_locations s JOIN server_battlenpc_groups g ON g.groupId = s.groupId''', args, password):
        add_spawn(int(r['zoneId']), int(r['bnpcId']), r['positionX'], r['positionY'], r['positionZ'], 'bnpc', r['privateAreaName'])

    for r in db('''SELECT e.id, e.uniqueId, e.zoneId, e.privateAreaName, e.positionX, e.positionY, e.positionZ, e.rotation,
                          m.layoutId, m.instanceId, c.classPath
                   FROM server_eventnpc_spawn_locations e LEFT JOIN server_eventnpc_mapobj m ON m.id = e.id
                   LEFT JOIN gamedata_actor_class c ON c.id = e.actorClassId''', args, password):
        zone_id = int(r['zoneId'])
        # Map objects and objects (doors, ferry routes, aetheryte gates) are placed by their model's
        # origin, not standing on the floor, so navgen counts them apart from npcs that walk.
        cls = r['classPath'] or ''
        kind = 'object' if cls.startswith(('/Chara/Npc/MapObj/', '/Chara/Npc/Object/')) else 'enpc'
        add_spawn(zone_id, int(r['id']), r['positionX'], r['positionY'], r['positionZ'], kind, r['privateAreaName'])
        if r['layoutId'] is not None and r['instanceId'] is not None:
            e = zone_entry(zone_id)
            if e is not None:
                e['mapobjs'].append({
                    'actor': int(r['id']), 'name': r['uniqueId'] or '',
                    'layoutId': int(r['layoutId']), 'instanceId': int(r['instanceId']),
                    'pos': [f(r['positionX']), f(r['positionY']), f(r['positionZ'])],
                    'rot': [0.0, f(r['rotation']), 0.0],
                    'prefab': None,
                })
                b = binding.get(r['layoutId'], {}).get(r['instanceId'])
                if b:
                    e['mapobjs'][-1].update({k: b[k] for k in ('instance', 'layout', 'node', 'tree', 'group')})

    for r in db('SELECT id, zoneId, privateAreaName, spawnX, spawnY, spawnZ FROM server_zones_spawnlocations', args, password):
        add_spawn(int(r['zoneId']), int(r['id']), r['spawnX'], r['spawnY'], r['spawnZ'], 'entrance', r['privateAreaName'])

    for class_id, (zone_id, x, y, z) in sorted(aetherytes(args.aetheryte_lua).items()):
        add_spawn(zone_id, class_id, x, y, z, 'aetheryte')

    # Seamless crossings: players walk into a zone through these boxes from its neighbour, so each
    # box centre is an arrival point (kind border). The table stores the zone2 box as x1, x2, y1, y2;
    # "y" is world Z and the height is unknown (0).
    for r in db('''SELECT id, zoneId1, zoneId2,
                          zone1_boundingbox_x1 AS ax1, zone1_boundingbox_y1 AS az1,
                          zone1_boundingbox_x2 AS ax2, zone1_boundingbox_y2 AS az2,
                          zone2_boundingbox_x1 AS bx1, zone2_boundingbox_x2 AS bx2,
                          zone2_boundingbox_y1 AS bz1, zone2_boundingbox_y2 AS bz2
                   FROM server_seamless_zonechange_bounds''', args, password):
        rid = int(r['id'])
        add_spawn(int(r['zoneId1']), rid * 10 + 1, (float(r['ax1']) + float(r['ax2'])) / 2, 0,
                  (float(r['az1']) + float(r['az2'])) / 2, 'border')
        add_spawn(int(r['zoneId2']), rid * 10 + 2, (float(r['bx1']) + float(r['bx2'])) / 2, 0,
                  (float(r['bz1']) + float(r['bz2'])) / 2, 'border')

    wanted = set(args.zone) if args.zone else None
    written = 0
    for name in sorted(data):
        if wanted is not None and name not in wanted:
            continue
        e = data[name]
        e['spawns'].sort(key=lambda s: (s['kind'], s['id']))
        e['mapobjs'].sort(key=lambda m: m['actor'])
        with open(os.path.join(out_dir, name + '.json'), 'w') as fh:
            json.dump(e, fh, indent=1)
            fh.write('\n')
        written += 1
        print('%-16s %5d spawns %4d mapobjs' % (name, len(e['spawns']), len(e['mapobjs'])))
    print('wrote %d zone files to %s' % (written, out_dir), file=sys.stderr)


if __name__ == '__main__':
    main()
