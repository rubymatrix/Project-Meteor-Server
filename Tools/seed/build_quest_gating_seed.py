#!/usr/bin/env python3
"""Quest offer gating seed: which quests a character may be offered.

Inputs (read only):
  * decomp/build/sheets/seed/quests.csv - written by decomp/tools/xivsheet.py seed (gitignored,
    never commit it). Columns used: classScope (xtx/quest 40-41), category (quest 52),
    gcRankReq (quest 53).
  * Data/sql/gamedata_quests.sql - id -> className (the client sheets have no class names).

Rules:
  * The quest level (gamedata_quests.minLevel = quest col 51) is checked against the ACTIVE class or
    job, not the highest level.
  * classScope: 0 All, 1 Disciples of War/Magic, 2 Disciples of the Land, 3 Disciples of the Hand.
    The untranslated scope text on class quests is a placeholder; class quests are gated by
    requiredClass instead (className prefix -> class id).
  * Job quests (Xxx0j1..6): base class at the quest level, second class at 15 (official 1.21; the
    sheet's "& <class>" has no level) and, from step 2 on, the job itself.
  * GC quests (Gc[lgu]*, Com*): membership of that company; Gc* also the sheet's minimum rank.
  * Prerequisites: gamedata_quest_prerequisites lists quests of which ANY ONE completed unlocks the
    quest; when a quest has rows here they replace gamedata_quests.prerequisite. Sources: the
    quest scripts' Prereq headers (Data/scripts/Quest/**), the city MSQ chains, and the class
    quest chains (each step needs the previous one).

Output: Data/sql/seed/seed_quest_gating.sql (drops and recreates both tables). Read by
Map Server/Database.cs GetQuestGamedata; without the tables the server keeps its old gating.
"""
import csv, os, re
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
WORKSPACE = os.path.dirname(REPO)
SHEET = os.path.join(WORKSPACE, 'decomp', 'build', 'sheets', 'seed', 'quests.csv')
QUESTS_SQL = os.path.join(REPO, 'Data', 'sql', 'gamedata_quests.sql')
OUT = os.path.join(REPO, 'Data', 'sql', 'seed', 'seed_quest_gating.sql')

# Class quest prefixes -> class id (Player.CLASSID_*). Acn = Arcanist (24), never playable in 1.23b.
CLASS_PREFIX = {
    'Pgl': 2, 'Gla': 3, 'Exc': 4, 'Arc': 7, 'Lnc': 8, 'Thm': 22, 'Cnj': 23, 'Acn': 24,
    'Wdk': 29, 'Bsm': 30, 'Arm': 31, 'Gld': 32, 'Tan': 33, 'Wvr': 34, 'Alc': 35, 'Cul': 36,
    'Min': 39, 'Hrv': 40, 'Fsh': 41,
}
# Job quest prefixes -> (base class, second class), from the sheet scope text.
JOB_PREFIX = {
    'War': (4, 3), 'Mnk': (2, 8), 'Whm': (23, 3), 'Blm': (22, 2),
    'Pld': (3, 23), 'Brd': (7, 23), 'Drg': (8, 2),
}
JOB_SECOND_CLASS_LEVEL = 15
GC_LETTER = {'l': 1, 'g': 2, 'u': 3}

# Curated any-of prerequisites by className (quest scripts' Prereq headers and MSQ order).
PREREQS = {
    # City MSQs: each step needs the previous one.
    'Man0l1': ['Man0l0'], 'Man1l0': ['Man0l1'], 'Man2l0': ['Man1l0'],
    'Man0g1': ['Man0g0'], 'Man1g0': ['Man0g1'], 'Man2g0': ['Man1g0'],
    'Man0u1': ['Man0u0'], 'Man1u0': ['Man0u1'], 'Man2u0': ['Man1u0'],
    # Path of the Twelve: after any city's level-13 MSQ, then in order. (man200.lua's header names
    # Etc2l0/g0/u0 instead, which are level 25-30 side quests and cannot precede a level-18 MSQ.)
    'Man200': ['Man2l0', 'Man2g0', 'Man2u0'],
    'Man206': ['Man200'], 'Man300': ['Man206'], 'Man304': ['Man300'], 'Man308': ['Man304'],
    'Man402': ['Man308'], 'Man406': ['Man402'], 'Man502': ['Man406'], 'Man504': ['Man502'],
    # Hildibrand: any city's second MSQ, then the shared chain.
    'Etc5g0': ['Man0l1', 'Man0g1', 'Man0u1'],
    'Etc5l0': ['Man0l1', 'Man0g1', 'Man0u1'],
    'Etc5u0': ['Man0l1', 'Man0g1', 'Man0u1'],
    'Etc5u1': ['Etc5g0', 'Etc5l0', 'Etc5u0'],
    'Etc5g1': ['Etc5u1'], 'Etc5l1': ['Etc5g1'], 'Etc5l2': ['Etc5l1'], 'Etc5l3': ['Etc5l2'],
    # Side quest chains named in the script headers.
    'Etc303': ['Etc3l3', 'Etc3g3', 'Etc3u3'],
    'Etc1g6': ['Etc1g4'], 'Etc1g8': ['Etc1l7'], 'Etc2g0': ['Etc1g9'], 'Etc1l6': ['Etc1l5'],
    'Wld0g4': ['Wld0g1'], 'Wld0l4': ['Wld0l2'], 'Wld0u4': ['Wld0u2'],
}


def load_quests():
    quests = {}
    row = re.compile(r"\((\d+), '((?:[^'\\]|\\.|'')*)', '([^']*)', (\d+), (\d+), (\d+)\)")
    with open(QUESTS_SQL, encoding='utf-8') as f:
        for m in row.finditer(f.read()):
            quests[int(m.group(1))] = {'className': m.group(3), 'prereq': int(m.group(4)),
                                       'minLevel': int(m.group(5)), 'template': int(m.group(6))}
    return quests


def scope_code(text):
    if text == 'All':
        return 0
    if text.startswith('Disciples of the Land'):
        return 2
    if text.startswith('Disciples of the Hand'):
        return 3
    return 1


def main():
    quests = load_quests()
    by_class = {q['className']: qid for qid, q in quests.items()}
    sheet = {}
    with open(SHEET, encoding='utf-8') as f:
        for r in csv.DictReader(f):
            sheet[int(r['id'])] = r

    gating = []
    prereqs = defaultdict(set)
    chains = defaultdict(list)
    for qid in sorted(quests):
        q = quests[qid]
        name = q['className']
        prefix = name[:3]
        s = sheet.get(qid, {})
        scope = scope_code(s.get('classScope', 'All'))
        required = second = second_lv = require_job = gc = gc_rank = 0
        if prefix in CLASS_PREFIX:
            required, scope = CLASS_PREFIX[prefix], 0
            chains[prefix].append(qid)
        elif prefix in JOB_PREFIX and name[3:5] == '0j':
            required, second = JOB_PREFIX[prefix]
            second_lv, scope = JOB_SECOND_CLASS_LEVEL, 0
            require_job = 0 if name.endswith('1') else 1
            chains[prefix].append(qid)
        if prefix in ('Gcl', 'Gcg', 'Gcu'):
            gc, gc_rank = GC_LETTER[prefix[2]], int(s.get('gcRankReq') or 0)
        elif prefix == 'Com' and len(name) > 4 and name[4] in GC_LETTER:
            gc = GC_LETTER[name[4]]
        gating.append((qid, scope, required, second, second_lv, require_job, gc, gc_rank))

    for prefix, ids in chains.items():
        ids.sort()
        for prev, cur in zip(ids, ids[1:]):
            prereqs[cur].add(prev)
    for name, reqs in PREREQS.items():
        qid = by_class[name]
        prereqs[qid] = {by_class[r] for r in reqs}

    out = ['-- Generated by tools/seed/build_quest_gating_seed.py; do not edit by hand.',
           '-- Quest offer gating (class scope / class / job / GC) and any-of prerequisites.',
           'DROP TABLE IF EXISTS `gamedata_quest_gating`;',
           'CREATE TABLE `gamedata_quest_gating` (',
           '  `questId` int(10) unsigned NOT NULL,',
           '  `classScope` tinyint(3) unsigned NOT NULL DEFAULT 0 COMMENT \'0 all, 1 DoW/DoM, 2 DoL, 3 DoH\',',
           '  `requiredClass` tinyint(3) unsigned NOT NULL DEFAULT 0,',
           '  `secondClass` tinyint(3) unsigned NOT NULL DEFAULT 0,',
           '  `secondClassLevel` tinyint(3) unsigned NOT NULL DEFAULT 0,',
           '  `requireJob` tinyint(1) unsigned NOT NULL DEFAULT 0,',
           '  `grandCompany` tinyint(3) unsigned NOT NULL DEFAULT 0 COMMENT \'1 Maelstrom, 2 Twin Adder, 3 Immortal Flames\',',
           '  `minGCRank` tinyint(3) unsigned NOT NULL DEFAULT 0,',
           '  PRIMARY KEY (`questId`)',
           ') ENGINE=InnoDB DEFAULT CHARSET=latin1;',
           'INSERT INTO `gamedata_quest_gating` VALUES']
    out.append(',\n'.join('  (%d, %d, %d, %d, %d, %d, %d, %d)' % g for g in gating) + ';')
    out += ['',
            'DROP TABLE IF EXISTS `gamedata_quest_prerequisites`;',
            'CREATE TABLE `gamedata_quest_prerequisites` (',
            '  `questId` int(10) unsigned NOT NULL,',
            '  `prerequisite` int(10) unsigned NOT NULL COMMENT \'any one completed unlocks questId\',',
            '  PRIMARY KEY (`questId`, `prerequisite`)',
            ') ENGINE=InnoDB DEFAULT CHARSET=latin1;',
            'INSERT INTO `gamedata_quest_prerequisites` VALUES']
    rows = ['  (%d, %d)' % (q, p) for q in sorted(prereqs) for p in sorted(prereqs[q])]
    out.append(',\n'.join(rows) + ';')
    with open(OUT, 'w') as f:
        f.write('\n'.join(out) + '\n')
    print('wrote %s: %d gating rows, %d prerequisite rows' % (OUT, len(gating), len(rows)))


if __name__ == '__main__':
    main()
