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

`Battle/Formulas.lua`, called by `Battle/Actions.lua`. A player's auto-attack on a monster is
`1.6 × weapon Damage × (delay ÷ 3)^0.55 × stat ratio × level factor × level scale × (1 − DEF cut)`,
±8%, then the level-gap cut. A monster's hit on a player is
`potency × max(raw − k(dLVL) × effective DEF, 0.117 × raw)`, ±8%.

| What | Source | Trust | Our part |
|---|---|---|---|
| Auto-attacks follow weapon Damage, weaponskills DPS | Player tests (Mocchi, Kaeko) | Player test | — |
| 1.6 per Damage, the delay exponents, the level factor slopes | Fit to [CAP-AA](#cap-aa) | Capture | The fit is ours |
| Level scale: flat to Lv27, ×1.68 at Lv50 (+1 Damage = +2.0 per auto-attack at Lv50) | [BG-P24](#bg-p24): +2.2 per Damage, +0.21 per 0.01 DPS at Lv50; [CAP-AA](#cap-aa) / [CAP-WS](#cap-ws) at Lv26-27 | Player test, capture | The linear ramp between them is ours |
| DEF cut on a monster: a level-typical monster takes 25% less | Ours | — | Ratio form is ours |
| Level-gap cut on monsters 5+ levels up: 0.34 × (dLVL − 4) × reference Damage, floor 22% of the hit | [RCAP-IFRIT](#rcap-ifrit): Lv50 DRG autos 14-26, True Thrust 139, ratio 5-6 | Capture | The form is ours |
| Player DEF: a flat cut k per effective DEF point (DEF + 0.67 VIT); k 0.237 at dLVL 0, 0.295 at +2, 0.526 at +8, 0.565 at +9; floor 11.7% of the raw hit (35-42 from a Lv52) | [KAN-III](#kan-iii) | Player test | The floor share and level scaling are ours |
| Below Lv50, k grows with (typical Lv50 DEF ÷ typical DEF)^0.33; typical gear DEF follows the item sheet's best armour (231 at Lv27, 1000 at Lv50) | Item sheet; fit to [CAP-AA](#cap-aa) (Lv30 piranha on Lv27 GLA 56-63) | Client, capture | Exponent fit to one capture |
| Monster raw hit on a player ×2.62 of its hit on a monster (250 at 0 DEF from an even Lv50) | [KAN-III](#kan-iii) worked example | Player test | — |
| Weaponskill potency scales the hit after DEF | Ours, so the [KAN-III](#kan-iii) worked example holds at any potency | — | Ours |
| Stat ratio weights 0.8 / 0.68 / 0.38 | Seiken and Kaeko, 1.21 | Player test | — |
| Weaponskill stat caps: primary 318 + 6(DPS − 34.62); secondary through 280 / 297 / 307 / 311 / 317.5 at DPS 34.62 / 36.74 / 39.7 / 40.0 / 42.06 | [T-50219](#t-50219) and the Battle Data cap tests | Player test | Straight lines between the measured brackets |
| Monster "weapon" Damage 7 + level at 4.2 s | Fit to [CAP-AA](#cap-aa) | Capture | The fit is ours |

### Rates and crits

| What | Source | Trust | Our part |
|---|---|---|---|
| Crit rate 7.5% at dLVL 0, +0.16 per rating, cap 27% | [BG-261](#bg-261), [BG-P17](#bg-p17), [BG-432](#bg-432), [BG-581](#bg-581) (26.4% where the slopes give 31%) | Player test | Cap value is ours |
| Crit damage 1.229 at dLVL 0, −0.0214 per level up (under the 1.15 floor past +4), −0.03 per level down, cap 1.75; +0.00175 per potency point | [KAN-IV](#kan-iv), [KAN-I](#kan-i) (1.237 / 1.3385 with +58), [BG-418](#bg-418) (+50 potency ≈ +7 / +6 pts) | Player test | Slopes are ours |
| Parry 4% − 0.3 per level the attacker is up, +0.04 per Parry, +0.02 per DEX above typical | [BG-521](#bg-521) (5.5-5.7% at −5), [RCAP-IFRIT](#rcap-ifrit) (3% at +8), [T-36877](#t-36877) (3% with +41 Parry at +5) | Player test, capture | Per-point weights are ours |
| Block reduction 56% − 1.25 per level up, +0.1 per VIT, +0.2 per Block, clamp 20-75% | [BG-439](#bg-439) (1.22 rule); [BG-312](#bg-312) at +2 | Player test | Level slope is ours; BG-312's pre-1.22 +8 values are not fit |
| Partial resist 10% + 2 per level up, ±0.5 per MEVA/MACC above typical, 0-100% | [KAN-II](#kan-ii); [RCAP-IFRIT](#rcap-ifrit) (18% at +8) | Player test, capture | Base and level slope are ours |
| Hit rate (unchanged) | [CAP-OUT](#cap-out), [RCAP-IFRIT](#rcap-ifrit) with Comradery | Capture | Bases and slopes are ours |

### Spells and heals

| What | Source | Trust | Our part |
|---|---|---|---|
| Spell unit 2.8 × reference Damage to Lv27, 3.66 at Lv50: level-typical Lv50 Fire 294 | [KAN-IV](#kan-iv) (284-314, geared) | Player test | Typical stats stand for the geared caster |
| Stat ratio `1 + 0.5 (AMP ratio − 1) + 0.85 (stat-pair ratio − 1)`: +1.05 per INT, +32% from INT 198 → 266 | [BG-198](#bg-198), [BG-110](#bg-110) | Player test | AMP weight left at 0.5, see below |
| Spells above the caster −3.5% per level (0.72 at +8) | [RCAP-IFRIT](#rcap-ifrit): Thunder 221-248 | Capture | Linear shape is ours |
| Cure: CNJ 1.15 × HMP + 0.2 × MND, others 1.03 × HMP, +0.05 × VIT | [BG-285](#bg-285) (601-635 / 1222-1275), [CAP-CURE](#cap-cure) (Lv27 GLA 151-166), [KAN-I](#kan-i) slopes within tolerance | Player test, capture | — |
| Heal crit rate 7.5%, THM main class 10.8% | [KAN-I](#kan-i) | Player test | — |

[BG-198](#bg-198)'s +2.2 per attack magic potency is not fit: potency is mostly gear, and a slope
that steep at level-typical stats would roughly double a geared caster's damage.

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

### Battle research

Sources the combat tests cite. Captures, client data, official posts and player tests as collected in
the battle research notes (research/RESEARCH.md, Battle).

- <a id="2n-942"></a>**2N-942**: 2nWIKI 旧データ/FAQ/戦闘, <https://w.atwiki.jp/eorzea14/pages/942.html> (frozen 2015-03-07)
- <a id="bg-107403"></a>**BG-107403**: BlueGartr thread 107403 "Stats and how they work", posts #101 (Kaeko 2011-11-14), #175 (Kaeko 2011-12-25), #201, #288, #324; p.12, p.18
- <a id="bg-110"></a>**BG-110**: BlueGartr 107403 posts by number (authors and dates in Research Notes 03)
- <a id="bg-159"></a>**BG-159**: BlueGartr 107403 posts by number (authors and dates in Research Notes 03)
- <a id="bg-175"></a>**BG-175**: BlueGartr 107403 posts by number (authors and dates in Research Notes 03)
- <a id="bg-198"></a>**BG-198**: BlueGartr 107403 posts by number (authors and dates in Research Notes 03)
- <a id="bg-261"></a>**BG-261**: BlueGartr 107403 posts by number (authors and dates in Research Notes 03)
- <a id="bg-285"></a>**BG-285**: BlueGartr 107403 posts by number (authors and dates in Research Notes 03)
- <a id="bg-312"></a>**BG-312**: BlueGartr 107403 posts by number (authors and dates in Research Notes 03)
- <a id="bg-418"></a>**BG-418**: BlueGartr 107403 posts by number (authors and dates in Research Notes 03)
- <a id="bg-432"></a>**BG-432**: BlueGartr 107403 posts by number (authors and dates in Research Notes 03)
- <a id="bg-439"></a>**BG-439**: BlueGartr 107403 posts by number (authors and dates in Research Notes 03)
- <a id="bg-512"></a>**BG-512**: BlueGartr 107403 posts by number (authors and dates in Research Notes 03)
- <a id="bg-521"></a>**BG-521**: BlueGartr 107403 posts by number (authors and dates in Research Notes 03)
- <a id="bg-549"></a>**BG-549**: BlueGartr 107403 posts by number (authors and dates in Research Notes 03)
- <a id="bg-569"></a>**BG-569**: BlueGartr 107403 posts by number (authors and dates in Research Notes 03)
- <a id="bg-570"></a>**BG-570**: BlueGartr 107403 posts by number (authors and dates in Research Notes 03)
- <a id="bg-581"></a>**BG-581**: BlueGartr 107403 posts by number (authors and dates in Research Notes 03)
- <a id="bg-p17"></a>**BG-P17**: BlueGartr 107403 page 8 (Niiro 1.20 DEX/ACC), page 17 (Kaeko/Seiken crit, 2012-04-05), page 24 (Silvano 1.23 per-point)
- <a id="bg-p24"></a>**BG-P24**: BlueGartr 107403 page 8 (Niiro 1.20 DEX/ACC), page 17 (Kaeko/Seiken crit, 2012-04-05), page 24 (Silvano 1.23 per-point)
- <a id="bg-p8"></a>**BG-P8**: BlueGartr 107403 page 8 (Niiro 1.20 DEX/ACC), page 17 (Kaeko/Seiken crit, 2012-04-05), page 24 (Silvano 1.23 per-point)
- <a id="cap-cs"></a>**CAP-CS**: `combat_skills` (public): f43/f47 (Blood for Blood HP cost), f7/f16 (TP decay in active mode)
- <a id="cap-cure"></a>**CAP-CURE**: Research Notes b6: three retail Cure rows 151/152/166
- <a id="cap-out"></a>**CAP-OUT**: Research Notes 09 §8a outcome rates (miss/block/parry/crit), same captures
- <a id="cap-pbl"></a>**CAP-PBL**: `party_battle_leve` (public, XIVLegacy pcap-1.23b): f671, f2689 (combo TP waiver), f1747–2124 (TP decay), f1834–1880 (active/passive regen gate), f2182→2217 (combo gap 6.25 s), f2399→2406 and f3305→3329 (Bloodbath), f2976 (WS gives no TP)
- <a id="cap-sw"></a>**CAP-SW**: Research Notes 09 §8c: Second Wind level anchors
- <a id="cap-tp"></a>**CAP-TP**: Research Notes 09 §1a–1c: TP per swing, TP from damage taken (k intervals), decay, combo waiver
- <a id="cap-wqu2"></a>**CAP-WQU2**: `war_quest_update2` (public): f228 (WAR KO at 885 TP), f609/f613 (auto-revive 970 HP), f94/95 (Shoulder Tackle TP)
- <a id="cap-open"></a>**CAP-OPEN**: opening battles, pre-1.19, local `caps/`: `limsa_opening_boat_pt2` (1.17; Lv1 MRD, 543 HP, jellyfish), open beta `new character gridania …` (Lv1 PGL, 547 HP, wolves) and `opening_limsa` (Lv1 CNJ, 303 HP). Monster HP was rebalanced in 1.19, so only the swing as a share of the player's max HP carries over: 5–9% at even level, any class.
- <a id="cap-lowlv"></a>**CAP-LOWLV**: low-level field fights, pre-1.19, local `caps/`: `start_and_die_guildleve_beard` (1.17; Lv8 sprites on an MRD of about 584 HP) and beta2 `When Bats Cry` (Lv1–2 lemmings and bats on Lv1–5 players). Same use as CAP-OPEN.
- <a id="cap-mobtp"></a>**CAP-MOBTP**: monster TP moves against the same monster's swings on the same target, public pcap-1.23b: `party_battle_leve` (Head Butt 23091 and 23167 from the leve aldgoats on a Lv27 GLA and a Lv26 MRD), `combat_autoattack` (Hoofkick 23079), `war_quest_update2` (Trap Jaws 23226). A field move hits 1.2–2.1× the swing, 1.8× typical. No field magic move was captured; they follow the same rule.
- <a id="cap-ws"></a>**CAP-WS**: Research Notes 09 §5–§6a: WS vs AA on the same targets, `party_battle_leve`, `combat_skills`, `war_quest_update2` (public pcap-1.23b)
- <a id="cl-cmd"></a>**CL-CMD**: client command sheet (`gameCommand.csv` / XIVLegacy `command_battle_params.csv`): cols 64–67 range, best range, min range, AoE; combo and recast columns
- <a id="cl-cost"></a>**CL-COST**: Client `calculateCommandCost` (charabaseclass_ffxivbattle), Research Notes 01 §3.1
- <a id="cl-itemrange"></a>**CL-ITEMRANGE**: client Lua `ItemBaseClass_common:processCanUseForRange` (proto160, source lines 3193–3215); `client/docs/combat_range_checks.md` §2.3
- <a id="cl-schema"></a>**CL-SCHEMA**: client actor-work schema `statusShownTime[20]` (Research Notes 07_caps A5.10)
- <a id="cl-status"></a>**CL-STATUS**: client `status.csv` col31 (multiplier) and col47 (duration s), 1.23b, `decomp/build/sheets/all/`
- <a id="devjp"></a>**DEVJP**: Japanese community-team replies: Triairy, t-30534, 2011-11-16 (combo ~10 s, provisional); Protect/Shell overwrite (1.20)
- <a id="el-med"></a>**EL-MED**: eLeMeN medicine data, transcribed by XIVLegacy (study `elemen-consumable-effects`), same study as EL-FOOD
- <a id="hf119a"></a>**HF119A**: Patch 1.19a notes, <https://forum.square-enix.com/ffxiv/threads/26963>. [dev1199] TP decay 300 → 90 per 3 s. Post number not recorded
- <a id="jpf-49642"></a>**JPF-49642**: SE JP forum 49642, Mocchi official reply #32, 2012-07-20
- <a id="kan-i"></a>**KAN-I**: kanican Stat Testing Parts I (Cure), II (MEVA, 55370.html), IV (crit damage, 56489.html), 1.20
- <a id="kan-ii"></a>**KAN-II**: kanican Stat Testing Parts I (Cure), II (MEVA, 55370.html), IV (crit damage, 56489.html), 1.20
- <a id="kan-iv"></a>**KAN-IV**: kanican Stat Testing Parts I (Cure), II (MEVA, 55370.html), IV (crit damage, 56489.html), 1.20
- <a id="pn117"></a>**PN117**: Patch 1.17 notes, post 87645, 2011-04-14, <https://forum.square-enix.com/ffxiv/threads/7032>. [dev1020] party size and Comradery / Strength in Numbers
- <a id="pn118"></a>**PN118**: Patch 1.18 notes, <https://forum.square-enix.com/ffxiv/showpost.php?p=241517&postcount=1> (thread 17007). [dev1091] Weakness, Brink of Death, Return; Light Shot recast = bow delay; enmity reset on KO
- <a id="pn118b"></a>**PN118B**: Patch 1.18b notes, <https://forum.square-enix.com/ffxiv/threads/20351>. [dev1129] KO gear-condition penalty by rank. Post number not recorded
- <a id="pn120-l"></a>**PN120-L**: Patch 1.20 notes, List of Actions and Traits, <https://forum.square-enix.com/ffxiv/showpost.php?p=476429> (thread 32606 page 6). Durations, positionals
- <a id="pn120a"></a>**PN120A**: Patch 1.20a notes, <https://forum.square-enix.com/ffxiv/threads/34137>. Shroud of Saints fix; [dev1290] link switch
- <a id="pn121j"></a>**PN121J**: Patch 1.21 job action list, <https://forum.square-enix.com/ffxiv/showpost.php?p=580997> (thread 39024)
- <a id="pn122"></a>**PN122**: Patch 1.22 notes, post 660454, <https://forum.square-enix.com/ffxiv/threads/43599>. [dev1358] +Enmity materia, [dev1374] medicine recasts and durations
- <a id="pn123a"></a>**PN123A**: Patch 1.23a notes, post 783447, <https://forum.square-enix.com/ffxiv/threads/51545>. Multistrike combo fix
- <a id="rcap-ifrit"></a>**RCAP-IFRIT**: `client/docs/battle-captures.md` §2–§8 / Research Notes 11: `caps/1.23b/ifrit_fight.xiv` (private)
- <a id="rcap-rat"></a>**RCAP-RAT**: `caps/1.23b/attack_rat.xiv`, private; Lv50 DRG on a Lv3 wharf rat, no link (battle-linking.md)
- <a id="rcap-time"></a>**RCAP-TIME**: `battle-captures.md` §2: cast, recast and swing timings (1-s clock)
- <a id="rcap-uldah"></a>**RCAP-ULDAH**: `caps/1.23b/npc_pc_capture_uldah*.xiv`, private; other players' passive regen ticks (battle-captures.md §4)
- <a id="sef-34921"></a>**SEF-34921**: "Enmity Testing Round 1", SE forum thread 34921, 2012-01-07 (1.20)
- <a id="sef-37858"></a>**SEF-37858**: Klive, "Max Mana, mana regen, and you!", SE forum thread 37858, 2012-02-20 (1.20)
- <a id="sef-39924"></a>**SEF-39924**: SE forum thread 39924 p.2 (Kikosho; Fiosha_Maureiba; Spider-Dan), 2012-03-18/19 (1.21)
- <a id="sef-40800"></a>**SEF-40800**: Sol_Aureus, "Enhancing Magic", SE forum thread 40800, 2012-03-26 (1.21–1.22c)
- <a id="sef-41900"></a>**SEF-41900**: Sol_Aureus, "White Mage: A Guide" V1.22c, SE forum thread 41900
- <a id="sef-43454"></a>**SEF-43454**: NoctisUmbra, "AF Enhanced Effects", SE forum thread 43454, 2012-04-24 (1.21a/1.22)
- <a id="sef-44650"></a>**SEF-44650**: Gael, Bard song list, SE forum thread 44650 #4, 2012-05-04 (1.22a)
- <a id="sef-47393"></a>**SEF-47393**: Tango, "Tachi's Guide to Paladin", SE forum thread 47393 #1, 2012-06-09 (1.22b)
- <a id="sef-48383"></a>**SEF-48383**: SE forum thread 48383, 2012-06-24 (one song per bard)
- <a id="t-27048"></a>**T-27048**: SE forum 27048 / 33809, shield ⇒ no parry
- <a id="t-36468"></a>**T-36468**: Stanislaw, 2012-01-30, SE forum thread 36468, translating Japanese Lodestone-diary enmity tests (1.20), with 1.21/1.21a follow-ups on BlueGartr 107403 p.11 and p.17. Post numbers not recorded
- <a id="t-36877"></a>**T-36877**: SE forum 36877, Fiosha_Maureiba parry 6/200, 2012-02
- <a id="t-50219"></a>**T-50219**: SE forum 50219, Judge_Xero WS cap rule, 2012-09-11
- <a id="t-50479"></a>**T-50479**: Judge_Xero, Paladin stat caps, SE forum thread 50479 #61, 2012-08-20 (1.23)
- <a id="t-55291"></a>**T-55291**: SE forum 55291 "DPS Testing", Judge_Xero, 2012-09-28
- <a id="vid-q0ho"></a>**VID-Q0HO**: YouTube Q0HOvmIKrbQ, Lv50 BLM leve 11726 vs Lv52 pterocs, read 2026-10-04, timestamps per row
- <a id="w2n"></a>**W2N**: 2nWIKI 旧データ class pages (GLA 613, PGL 627, MRD 436, LNC 462, ARC 624, CNJ 612, THM 601)
- <a id="pn121a"></a>**PN121A**: Patch 1.21a notes, post 607717, 2012-03-26, <https://forum.square-enix.com/ffxiv/threads/40824>. Cover, Divine Regen
- <a id="hf122a"></a>**HF122A**: 1.22a ability-change notice, 2012-05-23 (JP community team, translated on the official forum thread 14967)
- <a id="cl-qreward"></a>**CL-QREWARD**: the client's quest_new_reward sheet (500 rows, 16 slots of 13 values) and the reward window that reads it (QuestRewardWidget.setRewardData): slot type 100 is a completion reward, kind -2 gil, -12/-13/-16 EXP, -10/-8/-3/-14 items, -15 company seals, -4 a command; a negative tier amount shows amount 1. Seeded into gamedata_quest_rewards by tools/seed/build_quest_reward_seed.py.

## Open issues

- Base EXP per kill and the level-difference rule have no source we can check. Replace them first.
- Base EXP at levels 23–26 is probably 10 too low.
- Post numbers are missing for T-37927, T-32893, T-36412 and the Paladin MND 232 value.
- Two comments in `stats.lua` cite the wrong source, and `Player.CalcPotencial` should be named
  after the client's `getPotencial`.
