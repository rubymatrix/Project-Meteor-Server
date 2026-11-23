#!/usr/bin/env python3
"""Build actions.csv, the reference for the action data parity tests.

Reads the FFXIV 1.23b Battle Data page (an HTML file whose <script id="data"> holds the action
records). Numbers come from the 1.23b client command sheet as XIVLegacy decoded it
(command_battle_params.csv); see CL-COMMAND in Data/Docs/RPG-Systems.md.

    build_action_reference.py <battle-data.html> > actions.csv
"""
import csv
import json
import re
import sys


def main(path):
    html = open(path, encoding='utf-8').read()
    data = json.loads(re.search(r'<script type="application/json" id="data">(.*?)</script>', html, re.S).group(1))
    out = csv.writer(sys.stdout, lineterminator='\n')
    out.writerow(['id', 'name', 'classId', 'level', 'tp', 'mpPermille', 'castSeconds', 'recastSeconds', 'sources'])
    for a in sorted(data['actions'], key=lambda a: int(a['action_id'])):
        out.writerow([a['action_id'], a['name_en'], a['class_job_id'], a['level'], a['tp_cost'] or 0,
                      a['mp_base_permille'] or 0, a['cast_s'] or 0, a['recast_s'] or 0, a['sources']])


if __name__ == '__main__':
    main(sys.argv[1])
