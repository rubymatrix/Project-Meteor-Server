# RPG systems: sources

Where the numbers for race, stats, attribute points, levels, EXP, physical damage, TP and
monster spacing come from.

## Citing a source

Every row names its exact source, so anyone can retrace it. "Wherever possible" means: if we
have the exact source, it goes in. If we don't, the row says so.

| Kind | Cite |
|---|---|
| Forum post | Link to the post itself (`showpost.php?p=…` or `?p=…#post…`), plus author and date. A thread link alone is not enough. |
| Wiki or fan site | Link to the exact page, plus the section or table. |
| Video | Link with a timestamp (`&t=2m36s`), plus what is on screen. |
| Packet capture | File name, frame number, actor id, and the value seen. Say if the capture is public or private. |
| Game files | File, table or function, and the address or script line. |
| Our code | File path and the constant or function. |

**Capture frames.** `fN` is the 0-based index of the server-to-client game bundle in the
capture's zone stream. It is the same as `frame_index` in the XIVLegacy studies. It is not the
pcap frame number. Public captures are in
[XIVLegacy xivl-captures](https://github.com/XIVLegacy/xivl-captures), folder `pcap-1.23b`.
The private ones (marked *private*) are retail captures held by the project and not published.

**Trust**, best to worst:
- **Capture**: recorded from the real server.
- **Game files**: read from the 1.23b client.
- **Official**: Square Enix patch notes or developer posts.
- **Player test**: a player's own measurement.
- **Fan wiki**: community pages, often unsourced.
- **Our guess**: nothing settles it, so we chose.

**Tests.** `Tests/Map Server Tests/Formulas/` checks the formulas against these sources. Each
expected value names its source id, and a test fails if a cited id has no entry below.

Source ids in the tables ([`[PN119-B]`](#pn119-b), [`[T-36412]`](#t-36412), …) link to their full entry under
[Sources](#sources).

## Race

| What | Source | Trust | Our part |
|---|---|---|---|
| Clan attributes and resistances (table below) | [`[CL-TRIBE]`](#cl-tribe) | Game files | Which row is which tribe id |
| Race only changes starting values | [`[PN119-B]`](#pn119-b): "Race-based differences will be limited to the starting attributes." | Official | That growth is the same for everyone |
| Attributes get (clan value − 15) at every level; resistances are the clan value | — | — | Our guess |

| Tribe id | Clan | STR | VIT | DEX | INT | MND | PIE | Fire | Ice | Wind | Earth | Lightning | Water |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1, 2 | Midlander | 16 | 15 | 14 | 16 | 13 | 16 | 16 | 13 | 15 | 15 | 15 | 16 |
| 3 | Highlander | 18 | 17 | 15 | 13 | 15 | 12 | 15 | 16 | 14 | 14 | 18 | 13 |
| 4, 5 | Wildwood | 14 | 13 | 18 | 17 | 12 | 16 | 12 | 14 | 18 | 17 | 14 | 15 |
| 6, 7 | Duskwight | 15 | 14 | 15 | 18 | 15 | 13 | 14 | 16 | 12 | 17 | 15 | 16 |
| 8, 9 | Plainsfolk | 13 | 13 | 17 | 16 | 15 | 16 | 14 | 13 | 15 | 16 | 17 | 15 |
| 10, 11 | Dunesfolk | 12 | 12 | 15 | 16 | 17 | 18 | 17 | 12 | 16 | 18 | 15 | 12 |
| 12 | Seeker of the Sun | 16 | 15 | 17 | 13 | 14 | 15 | 18 | 15 | 13 | 15 | 12 | 17 |
| 13 | Keeper of the Moon | 13 | 12 | 16 | 14 | 18 | 17 | 13 | 18 | 15 | 14 | 16 | 14 |
| 14 | Sea Wolf | 17 | 18 | 13 | 12 | 16 | 14 | 13 | 17 | 17 | 12 | 13 | 18 |
| 15 | Hellsguard | 15 | 16 | 12 | 15 | 17 | 15 | 18 | 14 | 16 | 13 | 14 | 15 |

## Attributes and HP/MP

| What | Source | Trust | Our part |
|---|---|---|---|
| Lv8 Pugilist STR 35, attack 74; Lv9 STR 37, attack 77 (no gear) | [`[T-37927]`](#t-37927) | Player test | — |
| Lv50 Pugilist STR 246 / INT 263 and STR 267 / INT 242 | [`[BG-171]`](#bg-171) | Player test | That these are near-naked values. The Lv40–50 attribute growth is fit to them |
| Lv50 Lancer STR 255 / PIE 244, attack 532 (no armour) | [`[T-36412]`](#t-36412) | Player test | — |
| Lv50 Paladin MND 232 | Thread 50479 (Paladin stat caps). **Exact post not recorded.** | Player test | — |
| HP and MP at Lv26, 27, 31 and 50 | [`[CAP-HPMP]`](#cap-hpmp) | Capture | They are geared, so naked HP and MP stay at or below them |
| Lv50 Conjurer MP 971 → 2885 after patch 1.20 | [`[T-32893]`](#t-32893) | Player test | That other Lv50 casters are close |
| Which two attributes each class favours | [`[PN120-B]`](#pn120-b), ≪Parameters and Their Effects≫ ("Damage dealt by … arms") | Official | How strongly; Thaumaturge gets INT as its top attribute |
| Growth between those points, class HP/MP factors | — | — | Our guess |

## Stats from attributes

| What | Source | Trust |
|---|---|---|
| 1 VIT = 1 HP, 1 PIE = 1 MP | [`[T-28942]`](#t-28942) (status-menu readings, patch 1.19); [`[DEV-26648]`](#dev-26648) names the stats each attribute drives | Player test |
| 4 INT, MND or PIE = 1 point of a magic stat | [`[T-28942]`](#t-28942) | Player test |
| 3 STR = 2 attack, for STR from points and gear (the naked value is in the attack curve) | [`[KAN-III]`](#kan-iii) (cites earlier 1.18 and 1.20 tests) | Player test |
| 4 VIT = 1 enhancing magic | [`[T-41900]`](#t-41900) | Fan guide. [`[T-39570]`](#t-39570) says every 5th VIT instead |

## Attribute points

| What | Source | Trust | Our part |
|---|---|---|---|
| 5 at level 10, then 1 more per level | [`[PN120-B]`](#pn120-b) [dev1228] | Official | — |
| At most 3 + (level − 9) / 2 in one attribute (3 at Lv10, +1 at each odd level) | [`[PN120-B]`](#pn120-b) [dev1228], level / allotment cap table | Official | — |
| Per class; jobs use their class's points | [`[PN120-B]`](#pn120-b) [dev1228] "handled by class"; [`[PN121-B]`](#pn121-b) [dev1033] "carried over to the associated job" | Official | — |
| Unspent until the player allots them | [`[CL-BONUS]`](#cl-bonus) | Game files | — |

## Gear

| What | Source | Trust | Our part |
|---|---|---|---|
| Broken gear gives nothing | [`[PN119-I]`](#pn119-i): at 0% Condition the item "will become damaged and offer no benefits" | Official | — |
| Gear above your level counts for less | [`[CL-ITEMLVL]`](#cl-itemlvl) | Game files (second-hand) | That it applies to every stat |
| Gear counts by how well it suits the class (100%, 60% for a "Favors" item worn by another class, 0% cannot equip) | [`[CL-COMPAT]`](#cl-compat) | Game files | That it scales every stat; the client's adjust term isn't traced |
| Melded materia add their bonus by grade once you reach the materia's item level | [`[SH-MATERIA]`](#sh-materia) | Community data, not yet checked against the client | That a materia follows its piece's penalties |

## Levels and EXP

| What | Source | Trust | Our part |
|---|---|---|---|
| EXP to next level | [`[CL-EXP]`](#cl-exp) | Game files | — |
| Base EXP per kill by level | [`[CODE-EXP]`](#code-exp) `BASEEXP` only | None | Lv23–26 may be 10 too low |
| Bonus or penalty for level difference | [`[CODE-EXP]`](#code-exp) `GetBaseEXP` only | None | — |
| Cap on the bonus (1.5× to 3×) | [`[PN119-B]`](#pn119-b) §2 says a cap exists; values worked out from [`[EL-EXP]`](#el-exp) | Fan wiki | The values |
| Party share (0.75, 0.67, 0.58) | [`[EL-EXP]`](#el-exp) (party / solo ratios) | Fan wiki | 5+ members: 0.5 |
| Only members within 10 levels share | [`[2N-800]`](#2n-800) | Fan wiki | 50 yalm range |
| Link and chain bonuses, chain timer | [`[PN119-B]`](#pn119-b) §5 Link Bonus, §6 EXP Chain (table) | Official | — |
| Food +3% | [`[PN121-I]`](#pn121-i) [dev1242] "All food items provide experience point bonuses"; 3% from [`[EL-FOOD]`](#el-food) | Official + Fan wiki | — |
| Rested +50%, not used up at level 50 | [`[PN121-E]`](#pn121-e) [dev1301] | Official | Pool size and fill time |
| Inn "Resting" status 223263 | [`[CAP-REST]`](#cap-rest) | Capture | — |

## Monsters

| What | Source | Trust | Our part |
|---|---|---|---|
| HP anchors from Lv1 to Lv88 (table below) | Public and private captures | Capture | — |
| Curve between anchors | Geometric fit through the anchors | — | Our guess |
| Family multipliers for families with no capture, MP | Another server's database: migrations `20260918_000044` and `20260717_000006`, which cite captures we can't open | Second-hand | — |
| Attributes | — | — | Our guess |

HP anchors for `stats.MOB_HP_BASE` (anchor = value seen ÷ family multiplier). The server floors
anchor × multiplier, so an anchor seen under two multipliers is the value that floors to both:
Lv41 1621.7 gives 1621 at 1.0 and 1946 at 1.2; Lv67 9101.1 gives 8373 at 0.92.

| Anchor | Capture | Frame | Mob, multiplier | HP seen |
|---|---|---|---|---|
| Lv1 67 | `gridania_to_coerthas` | f474 | lesser petitghost, 1.0 | 67 |
| | `attack_rat` (*private*, 1.23b) | f25 | bug, 1.0 | 67 |
| Lv5 102 | `gridania_to_coerthas` | f356 | chigoe, 1.0 | 102 |
| Lv10 175 | `gridania_to_coerthas` | f898 | monkey, 1.0 | 175 |
| Lv16 317 | `gridania_to_coerthas` | f1099 | firefly, 0.85 | 269 |
| | `teleport_to_camp_tranquil` | f62 | funguar, 1.2 | 380 |
| Lv26 603 | `combat_autoattack` | f123 | slug, 1.0 | 603 |
| | `login` (*private*, 1.19a) | f23 | jellyfish, 1.0 | 603 |
| Lv32 897 | `party_battle_leve` | f3458 | crab, 1.0 | 897 |
| Lv41 1621.7 | `whole_login` (*private*, 1.20) | f26 | petitghost, 1.0 | 1621 |
| | `teleport_to_camp_nine_ivies` | f86 | glirulus, 1.2 | 1946 |
| Lv47 2356 | `whole_login` (*private*, 1.20) | f25 | gigantoad, 1.0 | 2356 |
| Lv67 9101.1 | `teleport_to_camp_nine_ivies` | f87 | goblin, 0.92 | 8373 |
| Lv76 10693 | `war_quest_update2` | f642 | bomb, 1.0 | 10693 |
| Lv78 11703 | `war_quest_update2` | f641, f643 | bomb, cactus, 1.0 | 11703 |
| Lv88 17918 | `war_quest_update2` | f645 | Amalj'aa pugilist, 1.2 | 21501 |

Lv26 603 also shows in `party_battle_leve` f927, `war_quest_update2` f640 and
`gridania_to_coerthas` f1331.

## Physical damage

`battle/formulas.lua`, called by `battle/actions.lua`. An auto-attack is
`1.6 × weapon Damage × (delay ÷ 3)^0.55 × stat ratio × level factor × (1 − DEF cut)`, ±8%.

| What | Source | Trust | Our part |
|---|---|---|---|
| Auto-attacks follow weapon Damage, weaponskills DPS | Player tests (Mocchi, Kaeko) | Player test | — |
| 1.6 per Damage, the delay exponents, the level factor slopes | Fit to [CAP-AA](#cap-aa) | Capture | The fit is ours |
| DEF cut: a level-typical defender takes 25% less | Kaeko's Lv50 subtraction (about 27% of a hit) | Player test | Ratio form is ours |
| Stat ratio weights 0.8 / 0.68 / 0.38 | Seiken and Kaeko, 1.21 | Player test | — |
| Hit, crit, parry, block rates and crit damage | Captured hit and parry counts, player tests | Mixed | Bases and slopes are ours |
| Monster "weapon" Damage 7 + level at 4.2 s | Fit to [CAP-AA](#cap-aa) | Capture | The fit is ours |

## TP

`Character.OnDamageDealt` and `Character.OnDamageTaken`. Only landed auto-attacks give TP;
weaponskills, spells and abilities give none.

| What | Source | Trust | Our part |
|---|---|---|---|
| A player gains `round(100 × delay × (1 + Store TP ÷ 1000))` per landed swing | Private retail captures: Lv50 Dragoon +326 with a 3.1 s lance and the +5% Store TP trait, Lv50 Warrior +400 with a 4.0 s axe. Frames not listed here | Capture | Split across a fist weapon's two hits, extra hits at half a swing |
| A monster gains 300 per landed auto-attack | Private retail captures, including the Ifrit fight. Frames not listed here | Capture | — |
| A player hit for D gains `ceil(D × 4.5 e^(−0.065 L))` | Fit to private captures: k ≈ 0.83 at Lv26, 0.78 at Lv27, 0.17–0.18 at Lv50 | Capture | The fit is ours |
| A monster hit for D gains `ceil(D × 1600 ÷ max HP)` | Fit to private captures: k 3.135 (Lv30, 550 HP), 1.71–1.91 (Lv30, 770 HP), 2.49 (Lv25, 679 HP), 3.71 (~437 HP); Ifrit 0.048–0.053 at about 32,000 HP | Capture | The fit is ours |

## Monster movement

`MeleeSpread` and `BattleNpcController.Move`.

| What | Source | Trust | Our part |
|---|---|---|---|
| Mobs on one standing player never share a stop: about 2.7 apart at rest, closest 1.2–1.4 | Private retail captures (0x00CF move targets). Frames not listed here | Capture | — |
| A mob arriving beside others stops 13–23° off its approach line | Same captures | Capture | The 25° cap, the 1.5 rank step and the half weight for a standing mob are ours |

## Sources

### Captures

- <a id="cap-mobhp"></a>**CAP-MOBHP**: monster max HP, the captures and frames in the
  [Monsters](#monsters) HP anchor table.
- <a id="cap-aa"></a>**CAP-AA**: auto-attack hits in `party_battle_leve` (public), 0x0139 results
  with command 22104 against Lv30 piranhas (`PiranhaSandyStandard`). Lv26 Marauder 43723073 with a
  Damage 46, 4.2 s axe: normal hits 42–53, mostly 44–51. Lv27 Gladiator 43722707 with a 2.5 s
  sword (Damage about 26): 18–22. The piranhas' command 23005 hits on the Gladiator: 56–63 when
  not blocked. The levels and weapons are from the project's battle research notes; the hit
  values can be read from the capture.
- <a id="cap-hpmp"></a>**CAP-HPMP**: player max HP / MP, all public.

  | Who | Capture | Frame | Actor | hpMax / mpMax |
  |---|---|---|---|---|
  | Lv26 Marauder | `login` | f17 | 43723073 | 758 / 249 |
  | Lv27 Gladiator | `party_battle_leve` | f3453 | 43722707 | 750 / 405 |
  | Lv31 Gladiator | `gridania_to_coerthas` | f184 (also f854, f1328) | 43723073 | 1016 / 548 |
  | Lv50 Pugilist (Monk) | `war_quest_update2` | f639 | 43722707 | 2634 / 1914 |

  Actor 43722707 is a different character in each of the last two captures.
- <a id="cap-rest"></a>**CAP-REST**: inn "Resting" status, public. On the wire it is 23263.
  - Gained: `return_to_inn` f35 (0x0177 slot 0 = 23263), f37 (0x0139 text 30330), f38 (0x0179).
  - Lost: `move_out_of_room` f27 (0x0177 slot 0 = 0), f30 (0x0139 text 30331), f32 (0x0179).
  - Already on when logging in inside the inn: `login` f9 (0x0179).

### Official (forum.square-enix.com)

- <a id="pn119-b"></a>**PN119-B**: Patch 1.19 notes, Battle post, 2011-09-30.
  <https://forum.square-enix.com/ffxiv/showpost.php?p=361386&postcount=2> (thread 24910).
  [dev1072][dev1073] physical levels removed, race line; EXP §1 level-based, §2 level
  difference and its cap, §3 party size, §5 Link Bonus, §6 EXP Chain table.
- <a id="pn119-i"></a>**PN119-I**: Patch 1.19 notes, Items post.
  <https://forum.square-enix.com/ffxiv/showpost.php?p=361387&postcount=3>. Gear Condition at 0%.
- <a id="pn120-b"></a>**PN120-B**: Patch 1.20 notes, Battle post, 2011-12-12.
  <https://forum.square-enix.com/ffxiv/showpost.php?p=476417&postcount=2> (thread 32606).
  [dev1228] attribute points, the level / allotment cap table, ≪Parameters and Their Effects≫.
- <a id="pn121-e"></a>**PN121-E**: Patch 1.21 notes, Event post.
  <https://forum.square-enix.com/ffxiv/showpost.php?p=580985&postcount=2> (thread 39024).
  [dev1301] inn rooms and Rested Bonus.
- <a id="pn121-b"></a>**PN121-B**: Patch 1.21 notes, Battle post.
  <https://forum.square-enix.com/ffxiv/showpost.php?p=580990&postcount=3>. [dev1033] job system.
- <a id="pn121-i"></a>**PN121-I**: Patch 1.21 notes, Items post.
  <https://forum.square-enix.com/ffxiv/showpost.php?p=580991&postcount=4>. [dev1242] food revamp.
- <a id="dev-26648"></a>**DEV-26648**: Bayohne (Community Rep), 2011-10-22, "Stats And You!".
  <https://forum.square-enix.com/ffxiv/threads/26648-Stats-And-You%21?p=408350#post408350>.

### Player tests and guides

- <a id="t-28942"></a>**T-28942**: Deus, 2011-10-26, "Effect of Core Stats on Skills Explained" (patch 1.19).
  <https://forum.square-enix.com/ffxiv/threads/28942>, first post.
- <a id="t-37927"></a>**T-37927**: DecorsWeissmel, 2012-02-23, 「ステータスについて」 (Japanese forum).
  <https://forum.square-enix.com/ffxiv/threads/37927>. Post number not recorded.
- <a id="t-32893"></a>**T-32893**: FineMotion, 2011-12-18, 「ステ振り指南 verパッチ1.20」 (Japanese forum).
  <https://forum.square-enix.com/ffxiv/threads/32893>. Post number not recorded.
- <a id="t-36412"></a>**T-36412**: Seiken, 2012-03-26 (1.21 retest), "STR/PIE/ATK Testing".
  <https://forum.square-enix.com/ffxiv/threads/36412>. Post number not recorded.
- <a id="t-41900"></a>**T-41900**: Sol_Aureus, "White Mage: A Guide", v1.22c, attribute conversions section.
  <https://forum.square-enix.com/ffxiv/threads/41900>, first post.
- <a id="t-39570"></a>**T-39570**: "Enhance Regen & Enhancement Magic Potency", 2012-03-13.
  <https://forum.square-enix.com/ffxiv/threads/39570>.
- <a id="bg-171"></a>**BG-171**: Almalexia, post #171, 2011-12-21, BlueGartr "Stats and how they work".
  <https://www.bluegartr.com/threads/107403>.
- <a id="kan-iii"></a>**KAN-III**: Kaeko Leta, "Stat Testing Part III: Physical Damage Taken", 2012-02-21 (patch 1.20).
  <https://kanican.livejournal.com/55915.html>.

### Fan wikis

- <a id="2n-800"></a>**2N-800**: 2nWIKI 旧データ/パーティ. <https://w.atwiki.jp/eorzea14/pages/800.html>.
  EXP only for members within 10 levels.
- <a id="el-exp"></a>**EL-EXP**: eLeMeN max base EXP per kill, by level and party size (stops at Lv40). The site
  (`www5.plala.or.jp/SQR/ff14/`) is offline. Our copy: Research Notes `07_caps` §C4,
  <https://claude.ai/artifact/MB9cZct47igKuVqH9Z1R5a#doc=07_caps>.
- <a id="el-food"></a>**EL-FOOD**: eLeMeN food data, transcribed by XIVLegacy (study `elemen-consumable-effects`).

### Game files

- <a id="cl-tribe"></a>**CL-TRIBE**: `ffxivgame.exe` 1.23b. A table of 15 tribes × 15 int32 at 0x12be318, read by
  `BootupManager_getTribeStatus` (0x6a97f0) and shown on the character creation TribeStatus
  panel by `TribeStatus_setTribe` (0x863280). Row `i` = tribe id `i + 1`.
- <a id="cl-bonus"></a>**CL-BONUS**: client Lua bonus-point getters (`getBonusPointStockForPhysical`,
  `getBonusPointAtPhysicalParameter`), via
  [ffxivDecomp](https://github.com/Yokimitsuro/ffxivDecomp).
- <a id="cl-itemlvl"></a>**CL-ITEMLVL**: client Lua `NormalItemBaseClass_common.calculateLevelAdjust`, via ffxivDecomp
  `finding_normal_item_level_adjust.md` lines 48–87. That doc's worked example disagrees with
  its own table.
- <a id="cl-compat"></a>**CL-COMPAT**: the client `compatibility` sheet (219 rows, one column per class id),
  read by client Lua `itemBaseClass_common.getItemCompatibilityData` as value / 100. Shipped as
  `Data/sql/gamedata_compatibility.sql` (Shaelou, 2021); its 119 item rows (1001+) match the sheet.
- <a id="cl-exp"></a>**CL-EXP**: client Lua `charabaseclass_battle`, EXP table near line 1892, via ffxivDecomp
  (mislabelled `getMagicAttack` there). Levels 1–49 sum to 1,781,150.

### Community data

- <a id="sh-materia"></a>**SH-MATERIA**: `Data/sql/gamedata_items_materia.sql`, from Shaelou's
  `feature_attribute_point_allotment` branch (Bitbucket, 2021). Catalog ids, icons and names match
  the item sheet for all 65 types; the bonus values still need a check against the client's
  materia sheet.

### Our code

- <a id="code-exp"></a>**CODE-EXP**: `Map Server/Actors/Chara/Ai/Utils/BattleUtils.cs`: `BASEEXP` and `GetBaseEXP`,
  from the original Meteor code. No source is given for either.

## Open issues

- Base EXP per kill and the level-difference rule have no source we can check. Replace them first.
- Base EXP at levels 23–26 is probably 10 too low.
- Post numbers are missing for T-37927, T-32893, T-36412 and the Paladin MND 232 value.
- Two comments in `stats.lua` cite the wrong source, and `Player.CalcPotencial` should be named
  after the client's `getPotencial`.
