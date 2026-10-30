#!/usr/bin/env python3
"""
probe_navmesh.py - helper for build_spawn_seed.py's navmesh probe.

  python Tools/seed/probe_navmesh.py lua   [--chunk N]   -> prints Lua chunk(s) for the map server
  python Tools/seed/probe_navmesh.py merge <result.txt>   -> merges the printed results into
                                                            Tools/seed/data/navmesh_probe.json

Run each printed chunk with the meteor MCP (meteor_lua) against a running Map Server; it prints one
line per query: "zone|x|z|ok|sx|sy|sz|reason" (Area.ProjectToGround, the map server's spawn-load
check, on .nav worlds and old meshes alike; ok = reason "Ok"). Save the lines to a file and
merge. Zones are resolved by zoneName through the world's zone list.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TODO = os.path.join(HERE, 'data', 'navmesh_probe_todo.json')
OUT = os.path.join(HERE, 'data', 'navmesh_probe.json')

LUA_HEAD = '''local wm = GetWorldManager()
local byName = {}
for _, id in ipairs(%s) do local z = GetZone(id); if z ~= nil then byName[z.zoneName] = z end end
local q = {%s}
local out = {}
for _, k in ipairs(q) do
  local zn, x, zz = k:match("([^|]+)|([^|]+)|([^|]+)")
  local zone = byName[zn]
  if zone == nil then table.insert(out, k .. "|0|0|0|0|NoZone")
  else
    local reason, p = zone:ProjectToGround(tonumber(x), 0, tonumber(zz))
    if reason == "Ok" then table.insert(out, k .. "|1|" .. p.X .. "|" .. p.Y .. "|" .. p.Z .. "|Ok")
    elseif p ~= nil then table.insert(out, k .. "|0|" .. p.X .. "|" .. p.Y .. "|" .. p.Z .. "|" .. reason)
    else table.insert(out, k .. "|0|0|0|0|" .. reason) end
  end
end
return table.concat(out, "\\n")'''

ZONE_IDS = [128, 129, 130, 131, 132, 135, 137, 143, 144, 145, 147, 148, 150, 151, 152, 153, 154, 157, 158,
            159, 170, 171, 172, 173, 174, 176, 178, 190]


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == 'lua':
        todo = json.load(open(TODO))
        n = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[2] == '--chunk' else 400
        for i in range(0, len(todo), n):
            q = ','.join('"%s"' % k.replace('"', '\\"') for k in todo[i:i + n])
            print(LUA_HEAD % ('{' + ','.join(map(str, ZONE_IDS)) + '}', q))
            print('-- ----8<----')
    elif len(sys.argv) == 3 and sys.argv[1] == 'merge':
        res = json.load(open(OUT)) if os.path.exists(OUT) else {}
        for line in open(sys.argv[2], encoding='utf8'):
            parts = line.strip().split('|')
            if len(parts) not in (7, 8):
                continue
            zn, x, z, ok, sx, sy, sz = parts[:7]
            res['%s|%s|%s' % (zn, x, z)] = [int(ok), round(float(sx), 1), round(float(sy), 1), round(float(sz), 1)]
        with open(OUT, 'w', encoding='utf8', newline='\n') as f:
            json.dump(res, f, indent=0, sort_keys=True)
        print('%d probe results in %s' % (len(res), OUT))
    else:
        print(__doc__)


if __name__ == '__main__':
    main()
