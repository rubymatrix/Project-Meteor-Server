#!/usr/bin/env python3
"""Battle leve execution seed: leve monster pools and one plan per playable battle leve.

Inputs (read only):
  * the live DB (after seed_bnpc_* and seed_drop_* are applied): gamedata_guildleves,
    gamedata_actor_class, server_battlenpc_pools/groups, server_eventnpc_spawn_locations.
  * $DECOMP/build/sheets/en/xtx__displayName.csv (client text, never commit it): English monster
    names used to match eLeMeN family names. $DECOMP defaults to decomp/ beside the repo.
  * Tools/seed/data/elemen_battle_leves.csv: eLeMeN battlecraft leve objectives, by client leve id.
  * Tools/seed/data/leve_class_fixes.json: leve classes an earlier run gave a classPath (kept so the
    rollback still resets them).

Output:
  * Data/sql/seed/seed_leve_02_mobs.sql: classPath for leve actor classes (22xxxxx), one pool and one
    never auto-spawned group per leve class.
  * Data/sql/seed/seed_leve_03_scripts.sql: server_guildleve_scripts, read by GuildleveDirector.
  * Data/sql/seed/seed_leve_98_execution_rollback.sql.

Rules:
  * Display name -> class: gamedata_actor_class.displayNameId, preferring the 22xxxxx leve class.
  * A leve pool copies a family sibling's pool (an existing pool whose actor class shares digits 3-5,
    nearest id) inside the SQL, so the output follows the target database's pools. poolId = groupId =
    actorClassId; groups have zoneId 0, spawnType 1, respawn 0 and the sibling group's drop list.
  * An empty leve class takes the sibling class's classPath (a client class from
    data/client_monster_classes.txt), propertyFlags and eventConditions.
  * Choreography is parsed from the eLeMeN text; anything unparsed falls back to the director's
    default waves.
"""
import argparse, collections, csv, json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
WORKSPACE = os.path.dirname(REPO)
SHEETS = os.path.join(os.environ.get('DECOMP', os.path.join(WORKSPACE, 'decomp')), 'build', 'sheets', 'en')

# eLeMeN family names (katakana) -> English keywords matched against client display names / pool names.
JP = {
    'ドードー': ['dodo'], 'インプ': ['imp'], 'チグレット': ['chigoe', 'chiglet'], 'アルドゴート・ビリー': ['billy'],
    'ナット': ['gnat'], 'ペイスト': ['peiste'], 'ボム': ['bomb'], 'デビレット': ['devilet'], 'モール': ['mole'],
    'アルドゴート・ナニー': ['nanny'], 'エフト': ['eft'], 'スプリガン': ['spriggan'], 'ファイアフライ': ['firefly', 'glowfly'],
    'ガラゴ': ['galago'], 'スラッグ': ['slug'], 'メガロクラブ': ['crab'], 'モングレル': ['mongrel'], 'テロック': ['pteroc'],
    'ローズリング': ['roseling'], 'コブラン': ['coblyn'], 'ヘッジモール': ['hedgemole'], 'ファンガー': ['funguar'],
    'アンテロープ・ドゥ': ['doe'], 'ファハン': ['fachan'], 'ギガントード': ['toad'], 'ラット': ['rat'], 'ラム': ['ram'],
    'バット': ['bat'], 'ボッグヤーゾン': ['bog yarzon', 'yarzon'], 'サーフィド・クラウド': ['syrphid'],
    'マーモット': ['marmot'], 'カクター': ['cactuar'], 'ビー・クラウド': ['bee'], 'アースエレメンタル': ['earth elemental'],
    'ジャッカル': ['jackal', 'mongrel'], 'ゾンビー': ['zombie', 'corpse'], 'ウィーヴィル': ['weevil'], 'レディバグ': ['ladybug'],
    'プーク': ['puk'], 'フライトラップ': ['flytrap', 'trap'], 'ラセットヤーゾン': ['sand yarzon', 'yarzon'],
    'スクウィレル': ['squirrel'], 'アングラー': ['angler'], 'ヂッガ': ['djigga'], 'オロボン': ['orobon'],
    'ウルフポーチャー': ['wolf poacher'], 'ボギー': ['bogy'], 'ミッヂ・クラウド': ['midge'], 'フットパッド': ['footpad'],
    'レイダー': ['raider'], 'コカトリス': ['cockatrice'], 'ドーマウス': ['dormouse'], 'ヒッポセルフ': ['hippocerf'],
    'デスストローク・アサシン': ['deathstroke'], 'ナイトブレード・アサシン': ['nightblade'], 'ベノムタン・アサシン': ['venomtongue'],
    'ウィル・オ・ザ・ウィスプ': ['wisp'], 'ライトニングエレメンタル': ['lightning elemental'], 'ラプトルポーチャー': ['raptor poacher'],
    'ボアポーチャー': ['boar poacher'], 'ホッグ': ['hog'], 'アイスエレメンタル': ['ice elemental'],
    'ウィンドエレメンタル': ['wind elemental'], 'ハイウェイマン': ['highwayman'], 'ビートル': ['beetle'], 'ウルフ': ['wolf'],
    'ブルータルカラクール': ['karakul'], 'ウォータエレメンタル': ['water elemental'], 'ウォーターエレメンタル': ['water elemental'],
    'ファイアエレメンタル': ['fire elemental'], 'ワイト': ['wight'], 'カラクールユー': ['karakul'], 'アリオン': ['arion'],
    'レミュー': ['lemur'], 'アネモネ': ['anemone'], 'オーレリア': ['aurelia'],
}

OBJ_KIND = {10011: 'sweep', 10012: 'sweep', 10021: 'gather', 10031: 'chase', 10041: 'detect', 10042: 'detect',
            10043: 'detect', 10051: 'orb', 10061: 'survive', 10071: 'hunt', 10081: 'round',
            10801: 'tutorial', 11601: 'tutorial', 12401: 'tutorial',
            12001: 'sweep', 12002: 'sweep', 12007: 'sweep', 12011: 'sweep', 12012: 'sweep',
            12006: 'chase', 12008: 'chase', 12009: 'chase', 12010: 'gather'}
TUTORIAL_IDS = {10801, 11601, 12401}


def db(sql, args):
    cmd = ['mysql', '-u' + args.user, '-p' + args.password, '-h' + args.host, '-P' + str(args.port), args.database,
           '--batch', '-e', sql]
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0:
        raise SystemExit(out.stderr)
    lines = out.stdout.splitlines()
    hdr = lines[0].split('\t')
    return [dict(zip(hdr, l.split('\t'))) for l in lines[1:]]


def sq(s):
    return "'" + str(s).replace('\\', '\\\\').replace("'", "''") + "'"


def slug(s):
    return re.sub(r'[^a-z0-9]+', '_', s.lower()).strip('_')[:50]


def parse_brackets(text):
    """[(composition [(jpName, minCount, maxCount)], multiplier, tailText)] for every 【...】."""
    out = []
    for m in re.finditer(r'【([^】]*)】(?:\s*[×x](\d+))?', text):
        comp = []
        for n, cnt in re.findall(r'\s*([^\s0-9～]+?)\s*((?:\d+～)?\d+体|単体)', m.group(1)):
            if cnt == '単体':
                lo = hi = 1
            else:
                nums = [int(x) for x in re.findall(r'\d+', cnt)]
                lo, hi = nums[0], nums[-1]
            comp.append((n.strip(), lo, hi))
        out.append((comp, int(m.group(2)) if m.group(2) else 1, text[m.end():]))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--host', default='127.0.0.1')
    ap.add_argument('--port', default=3306, type=int)
    ap.add_argument('--user', default='meteor')
    ap.add_argument('--password', default=os.environ.get('METEOR_DB_PASSWORD', ''))
    ap.add_argument('--database', default=None)
    ap.add_argument('--report', help='write a JSON coverage report here')
    args = ap.parse_args()
    if not args.password:
        ini = os.path.join(REPO, 'Map Server', 'bin', 'Debug', 'map_config.ini')
        for line in open(ini):
            if line.startswith('password='):
                args.password = line.strip().split('=', 1)[1]
            elif line.startswith('database=') and args.database is None:
                args.database = line.strip().split('=', 1)[1]
    if args.database is None:
        args.database = 'ffxiv_server'

    leves = db('SELECT * FROM gamedata_guildleves', args)
    classes = {int(r['id']): r for r in db('SELECT id, classPath, displayNameId FROM gamedata_actor_class', args)}
    pools = db('SELECT * FROM server_battlenpc_pools', args)
    groups = db('SELECT * FROM server_battlenpc_groups', args)
    aeth = {int(r['actorClassId']): r for r in db('SELECT actorClassId, zoneId FROM server_eventnpc_spawn_locations WHERE actorClassId BETWEEN 1280000 AND 1280199', args)}
    client_classes = set(l.strip() for l in open(os.path.join(HERE, 'data', 'client_monster_classes.txt')) if l.strip())
    names = {}
    for r in csv.DictReader(open(os.path.join(SHEETS, 'xtx__displayName.csv'), encoding='utf8')):
        names[int(r['id'])] = r['1:str']
    elemen = {int(r['client_leve_id']): r['objective_text']
              for r in csv.DictReader(open(os.path.join(HERE, 'data', 'elemen_battle_leves.csv'), encoding='utf8'))
              if r['client_leve_id'].isdigit()}

    by_display = collections.defaultdict(list)
    for cid, c in classes.items():
        if 2100000 <= cid < 2300000:
            by_display[int(c['displayNameId'])].append(cid)
    # pools this generator made on an earlier run are rebuilt, not reused
    pools = [p for p in pools if not 2200000 <= int(p['poolId']) <= 2299999]
    # classes an earlier run gave a classPath: keep them in file 02 / the rollback (ledger)
    ledger_path = os.path.join(HERE, 'data', 'leve_class_fixes.json')
    ledger = {int(k): v for k, v in json.load(open(ledger_path)).items()} if os.path.exists(ledger_path) else {}
    for cid in ledger:
        if cid in classes:
            classes[cid]['classPath'] = ''
    pool_by_class = {}
    for p in pools:
        pool_by_class.setdefault(int(p['actorClassId']), p)
    pool_by_id = {int(p['poolId']): p for p in pools}
    group_by_pool = {}
    for g in groups:
        group_by_pool.setdefault(int(g['poolId']), g)
    family_pools = collections.defaultdict(list)   # family code -> [(classId, pool)]
    for p in pools:
        cid = int(p['actorClassId'])
        cp = classes.get(cid, {}).get('classPath', '')
        if len(str(cid)) == 7 and cp in client_classes:
            family_pools[str(cid)[2:5]].append((cid, p))

    def name_of(cid):
        return names.get(int(classes[cid]['displayNameId']), '') if cid in classes else ''

    new_pools = {}      # classId -> dict
    class_fixes = {}    # classId -> (classPath, propertyFlags, eventConditions)

    def pool_for_class(cid):
        """poolId for an actor class, generating a leve pool from a family sibling; None if impossible."""
        if cid in pool_by_class and classes.get(cid, {}).get('classPath', '') in client_classes:
            return int(pool_by_class[cid]['poolId'])
        if cid in new_pools:
            return cid
        sibs = family_pools.get(str(cid)[2:5])
        if not sibs:
            return None
        sib_cid, sib = min(sibs, key=lambda t: (str(t[0])[:2] != '21', abs(t[0] - cid)))
        cp = classes.get(cid, {}).get('classPath', '')
        if cp not in client_classes:
            class_fixes[cid] = sib_cid
        g = group_by_pool.get(int(sib['poolId']))
        new_pools[cid] = dict(sib=sib, drop=int(g['dropListId']) if g else 0,
                              name=slug(name_of(cid) or ('leve_%d' % cid)))
        return cid

    def target_class(display_id):
        cls = sorted(by_display.get(display_id, []))
        leve = [c for c in cls if str(c).startswith('22')]
        return (leve or cls or [None])[0]

    def resolve_jp(jp, own):
        """eLeMeN family name -> poolId: the leve's own mob classes first, then any field pool."""
        kws = JP.get(jp)
        if not kws:
            return None
        for kw in kws:
            for cid in own:
                if kw in name_of(cid).lower():
                    return pool_for_class(cid)
        for kw in kws:
            kslug = kw.replace(' ', '_')
            cands = [p for p in pools if kslug in p['name'] and classes.get(int(p['actorClassId']), {}).get('classPath', '') in client_classes]
            if cands:
                return int(min(cands, key=lambda p: int(p['poolId']))['poolId'])
        return None

    plans, report = {}, collections.Counter()
    unresolved = collections.Counter()
    for r in leves:
        lid = int(r['id'])
        if r['classType'] != '1':
            continue
        obj = int(r['objective'])
        kind = OBJ_KIND.get(obj)
        if kind is None:
            continue
        lvl = int(r['level'])
        if lvl in (0, 100):
            continue
        aims = [int(r['aimNum%d' % i]) for i in range(1, 5)]
        mob_disp = [int(r['mob%d' % i]) for i in range(1, 5)]
        items = [int(r['item%d' % i]) for i in range(1, 5)]
        if 3000009 in mob_disp:
            report[(kind, 'placeholder')] += 1
            continue
        a = aeth.get(int(r['aetheryte']))
        if not a or a['zoneId'] in ('0', 'NULL'):
            report[(kind, 'no-zone')] += 1
            continue
        own_cls = [target_class(d) if d else None for d in mob_disp]
        own = [c for c in own_cls if c]
        text = elemen.get(lid, '')
        ok = True
        slot_pool = [None] * 4
        for i in range(4):
            if mob_disp[i]:
                slot_pool[i] = pool_for_class(own_cls[i]) if own_cls[i] else None
                if aims[i] > 0 and slot_pool[i] is None and kind not in ('gather',):
                    ok = False
        if not ok:
            report[(kind, 'no-family')] += 1
            continue

        def comp_pools(comp, use_max=True):
            res = []
            for jp, lo, hi in comp:
                p = resolve_jp(jp, own)
                if p is None:
                    unresolved[jp] += 1
                    return None
                res += [p] * (hi if use_max else lo)
            return res

        plan = dict(kind=kind, level=lvl)
        br = parse_brackets(text)
        slots = [i for i in range(4) if aims[i] > 0]
        if kind in ('sweep', 'tutorial', 'chase'):
            # eLeMeN "【X N体PT】×k ..." -> per slot group size and concurrency; brackets in slot order.
            sl = []
            for k, i in enumerate(slots):
                size, conc = None, None
                if k < len(br) and br[k][0]:
                    size = sum(c[2] for c in br[k][0])
                    conc = br[k][1]
                sl.append(dict(slot=i, pool=slot_pool[i], size=size, concurrent=conc))
            if kind == 'tutorial':
                for s in sl:
                    s.update(size=1, concurrent=3)
            plan['slots'] = sl
            if any(s['pool'] is None for s in sl):
                report[(kind, 'unresolved')] += 1
                continue
        elif kind == 'detect':
            m_decoy = re.search(r'【([^】]*)】の中から当たり探し(?:[×x](\d+))?', text)
            m_hit = re.search(r'当たりの場合【([^】]*)】', text)
            extra = [slot_pool[i] for i in range(4) if mob_disp[i] and aims[i] == 0 and slot_pool[i]]
            if not text and slots and extra:
                # No eLeMeN row: decoys = the first non-target sheet mob in pairs; the
                # true form = the slot-0 target, 2 per hit (1 if the slot needs 1).
                size = 2 if aims[slots[0]] >= 2 else 1
                plan.update(decoy=[extra[0]] * 2, hit=[slot_pool[slots[0]]] * size,
                            hits=-(-aims[slots[0]] // size), slots=[dict(slot=i, pool=slot_pool[i]) for i in slots])
                plan['source'] = 'default'
                plans[lid] = plan
                report[(kind, 'ok-default')] += 1
                continue
            if not (m_decoy and m_hit):
                report[(kind, 'unparsed')] += 1
                continue
            decoy = comp_pools(parse_brackets('【' + m_decoy.group(1) + '】')[0][0])
            hit = comp_pools(parse_brackets('【' + m_hit.group(1) + '】')[0][0])
            if not decoy or not hit:
                report[(kind, 'unresolved')] += 1
                continue
            plan.update(decoy=decoy, hit=hit, hits=int(m_decoy.group(2) or 1),
                        slots=[dict(slot=i, pool=slot_pool[i]) for i in slots])
        elif kind == 'gather':
            carriers = []
            parts = re.findall(r'【([^】]*)】(?:と【([^】]*)】)?から\s*\S+\s*(\d+)個', text)
            for k, i in enumerate(slots):
                pl = None
                if k < len(parts):
                    pl = []
                    for b in parts[k][:2]:
                        if b:
                            c = comp_pools(parse_brackets('【' + b + '】')[0][0])
                            if c is None:
                                pl = None
                                break
                            pl.append(c)
                if not pl and slot_pool[i]:
                    pl = [[slot_pool[i]] * (2 if aims[i] >= 4 else 1)]
                if not pl:
                    carriers = None
                    break
                if not items[i]:
                    carriers = None
                    break
                carriers.append(dict(slot=i, item=items[i], groups=pl))
            if not carriers:
                report[(kind, 'unresolved')] += 1
                continue
            plan['carriers'] = carriers
        elif kind in ('orb', 'hunt'):
            m_pts = re.search(r'当たり探し[×x](\d+)', text)
            m_miss = re.search(r'ハズレの場合【([^】]*)】', text)
            miss = comp_pools(parse_brackets('【' + m_miss.group(1) + '】')[0][0]) if m_miss else []
            if miss is None:
                report[(kind, 'unresolved')] += 1
                continue
            plan['miss'] = miss
            if kind == 'orb':
                pages = []
                book = [it for it in items if it == 12000004]
                summons = re.findall(r'(\d+)個を集めると【([^】]*)】', text)
                carrier = re.match(r'\s*【([^】]*)】から', text)
                for k, i in enumerate(slots):
                    if k >= len(summons):
                        break
                    sp = comp_pools(parse_brackets('【' + summons[k][1] + '】')[0][0])
                    if sp is None:
                        pages = None
                        break
                    pages.append(dict(slot=i, item=items[i], summon=sp))
                if not pages:
                    report[(kind, 'unresolved')] += 1
                    continue
                plan['pages'] = pages
                plan['hits'] = sum(aims[i] for i in slots)
                if carrier:
                    cp = comp_pools(parse_brackets('【' + carrier.group(1) + '】')[0][0])
                    if cp is None:
                        report[(kind, 'unresolved')] += 1
                        continue
                    plan['carrier'] = cp
                plan['points'] = 0 if carrier else plan['hits'] + 2 + len(pages)
            else:
                m_hit = re.search(r'当たりの場合【([^】]*)】', text)
                hit = comp_pools(parse_brackets('【' + m_hit.group(1) + '】')[0][0]) if m_hit else None
                if not hit:
                    report[(kind, 'unresolved')] += 1
                    continue
                plan.update(hit=hit, hits=int(m_pts.group(1)) if m_pts else 3,
                            slots=[dict(slot=i, pool=slot_pool[i]) for i in slots])
                plan['points'] = plan['hits'] + 2
        elif kind == 'round':
            # "1,2箇所目で【X】が出現 / / 3箇所目で【Y】が出現 倒すと/戦闘中に【Z】追加"
            stops = []
            for m in re.finditer(r'([\d,]+)箇所目で【([^】]*)】(?:か【[^】]*】)?が出現([^/]*)', text):
                wave = comp_pools(parse_brackets('【' + m.group(2) + '】')[0][0])
                add = None
                ma = re.search(r'【([^】]*)】追加', m.group(3))
                if ma:
                    add = comp_pools(parse_brackets('【' + ma.group(1) + '】')[0][0])
                if wave is None or (ma and add is None):
                    stops = None
                    break
                for n in m.group(1).split(','):
                    stops.append(dict(wave=wave, add=add or []))
            if not stops:
                report[(kind, 'unresolved')] += 1
                continue
            plan.update(stops=stops, slots=[dict(slot=i, pool=slot_pool[i]) for i in slots])
        elif kind == 'survive':
            m_t = re.search(r'防衛時間(\d+):(\d+)', text)
            horde = []
            for comp, mult, tail in parse_brackets(text.split('防衛時間00:00')[0]):
                c = comp_pools(comp, use_max=True)
                if c is None:
                    horde = None
                    break
                lo = sum(x[1] for x in comp)
                horde.append(dict(pools=c, min=lo))
            boss = []
            m_b = re.search(r'防衛時間00:00で【([^】]*)】', text)
            if m_b:
                boss = comp_pools(parse_brackets('【' + m_b.group(1) + '】')[0][0])
            if not horde or boss is None:
                report[(kind, 'unresolved')] += 1
                continue
            plan.update(defense=(int(m_t.group(1)) * 60 + int(m_t.group(2))) if m_t else 300, horde=horde,
                        boss=boss, slots=[dict(slot=i, pool=slot_pool[i]) for i in slots])
        plan['source'] = 'elemen' if text else 'default'
        plans[lid] = plan
        report[(kind, 'ok-' + plan['source'])] += 1

    for cid, sib in ledger.items():
        class_fixes.setdefault(cid, sib)
    json.dump({str(k): v for k, v in sorted(class_fixes.items())}, open(ledger_path, 'w'), indent=0)

    # ---- SQL
    out1 = [
        '-- Generated by Tools/seed/build_leve_seed.py. Leve monster classes, pools and groups.',
        "-- Each leve pool copies a family sibling's pool; groups are never auto-spawned (spawnType 1, zoneId 0)",
        '-- because GuildleveDirector spawns them. Apply after seed_bnpc_* and seed_drop_*.',
        '-- Rollback: seed_leve_98_execution_rollback.sql.',
        'DELETE FROM server_battlenpc_groups WHERE groupId BETWEEN 2200000 AND 2299999;',
        'DELETE FROM server_battlenpc_pools WHERE poolId BETWEEN 2200000 AND 2299999;',
    ]
    for cid, sib_cid in sorted(class_fixes.items()):
        out1.append("UPDATE gamedata_actor_class t JOIN gamedata_actor_class s ON s.id=%d SET t.classPath=IF(t.classPath='',s.classPath,t.classPath), "
                    "t.propertyFlags=s.propertyFlags, t.eventConditions=s.eventConditions WHERE t.id=%d AND (t.classPath='' OR t.propertyFlags=0);"
                    % (sib_cid, cid))
    for cid, np in sorted(new_pools.items()):
        out1.append('INSERT INTO server_battlenpc_pools (poolId, actorClassId, name, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId) '
                    'SELECT %d, %d, %s, genusId, currentJob, combatSkill, combatDelay, combatDmgMult, aggroType, immunity, linkType, spellListId, skillListId '
                    'FROM server_battlenpc_pools WHERE poolId = %s;' % (cid, cid, sq(np['name']), np['sib']['poolId']))
        out1.append('INSERT INTO server_battlenpc_groups (groupId, poolId, scriptName, minLevel, maxLevel, respawnTime, hp, mp, dropListId, allegiance, spawnType, animationId, actorState, privateAreaName, privateAreaLevel, zoneId) '
                    "VALUES (%d, %d, %s, 1, 1, 0, 0, 0, %d, 0, 1, 0, 0, '', 0, 0);" % (cid, cid, sq(np['name']), np['drop']))
    open(os.path.join(REPO, 'Data', 'sql', 'seed', 'seed_leve_02_mobs.sql'), 'w').write('\n'.join(out1) + '\n')

    out2 = [
        '-- Generated by Tools/seed/build_leve_seed.py. One JSON plan per playable battle leve, read by',
        '-- GuildleveDirector at leve start.',
        'CREATE TABLE IF NOT EXISTS server_guildleve_scripts (',
        '  leveId int(10) unsigned NOT NULL,',
        '  kind varchar(16) NOT NULL,',
        '  source varchar(16) NOT NULL,',
        '  script text NOT NULL,',
        '  PRIMARY KEY (leveId)',
        ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;',
        'DELETE FROM server_guildleve_scripts;',
    ]
    for lid, p in sorted(plans.items()):
        out2.append('INSERT INTO server_guildleve_scripts (leveId, kind, source, script) VALUES (%d, %s, %s, %s);'
                    % (lid, sq(p['kind']), sq(p['source']), sq(json.dumps(p, separators=(',', ':')))))
    open(os.path.join(REPO, 'Data', 'sql', 'seed', 'seed_leve_03_scripts.sql'), 'w').write('\n'.join(out2) + '\n')

    rb = [
        '-- Generated by Tools/seed/build_leve_seed.py. Rollback for seed_leve_02_mobs.sql,',
        '-- seed_leve_03_scripts.sql and seed_leve_04_execution.sql. Leve actor classes that file 02 gave a',
        "-- classPath had none before and are reset to ''.",
        'DELETE FROM server_battlenpc_groups WHERE groupId BETWEEN 2200000 AND 2299999;',
        'DELETE FROM server_battlenpc_pools WHERE poolId BETWEEN 2200000 AND 2299999;',
        'DROP TABLE IF EXISTS server_guildleve_scripts;',
        'DROP TABLE IF EXISTS characters_leve_pending_rewards;',
        'DROP TABLE IF EXISTS characters_leve_faction;',
        "UPDATE gamedata_actor_class SET classPath = '', propertyFlags = 0, eventConditions = NULL WHERE id = 1200168;",
        'UPDATE server_eventnpc_spawn_locations SET zoneId = 0 WHERE actorClassId IN (1280052, 1280082);',
    ]
    ids = sorted(class_fixes)
    for i in range(0, len(ids), 40):
        rb.append("UPDATE gamedata_actor_class SET classPath = '', propertyFlags = 0, eventConditions = NULL WHERE id IN (%s);"
                  % ', '.join(str(x) for x in ids[i:i + 40]))
    open(os.path.join(REPO, 'Data', 'sql', 'seed', 'seed_leve_98_execution_rollback.sql'), 'w').write('\n'.join(rb) + '\n')

    for k, v in sorted(report.items()):
        print('%-10s %-14s %d' % (k[0], k[1], v))
    print('plans', len(plans), 'new pools', len(new_pools), 'class fixes', len(class_fixes))
    if unresolved:
        print('unresolved eLeMeN names:', dict(unresolved))
    if args.report:
        json.dump(dict(plans=plans), open(args.report, 'w'), ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()
