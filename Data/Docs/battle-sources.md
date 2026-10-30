# Battle Script Sources

Where the numbers and rules in the battle scripts come from. The scripts carry no sources in their
comments; this page does. Tags: CL client data, CLT client text, OFF official notes, RCAP/CAP
retail captures, WIKI fan wikis, TEST player tests, DESIGN our own choice.

## Actions params

`Battle/Actions.lua` does the work for every battle command script. Per-action scripts in
`Command/{WeaponSkill,Magic,Ability,AutoAttack}/` build a params table and call one of these
from `onSkillFinish`.

```text
  actions.autoAttack(caster, target, skill, action, container)
  actions.physicalWeaponskill(caster, target, skill, action, container, params)
  actions.attackSpell(caster, target, skill, action, container, params)
  actions.healSpell(caster, target, skill, action, container, params)
  actions.statusAbility(caster, target, skill, action, container, params)
  actions.healAbility(caster, target, skill, action, container, params)

params (all optional):
  potency          damage multiplier vs the reference opener (Fast Blade / Heavy Swing = 1.0)
  comboPotency     extra multiplier when the action continues a combo
  positionalPotency extra multiplier when the positional requirement is met
  positionalAcc    hit-rate points added when the positional is met (Heavy Swing front)
  positionalCrit   crit-rate points added when the positional is met (Vorpal Thrust rear)
  comboCrit        crit-rate points added on combo (Impulse Drive)
  critDamage       extra critical-damage multiplier (+0.2 = crits do 0.2x more; Chaos Thrust)
  acc              hit-rate points always added (Feint col96 "high accuracy")
  enmityMult       enmity per damage (combo enmity bonuses, e.g. Skull Sunder; spells: Freeze 0)
  comboEnmityMult  enmity multiplier when comboed
  status           "always" | "positional" | "combo" | "notCombo" | "targetingCaster" | "noEnmity" | "none"
                   when the skill's statusId may land (default "always" if statusId set)
  statusChance     0-1 override for the landing roll
  magnitude        spells/heals: client command-sheet magnitude (col 84)
  stats            spells: {[modId] = weight} from the client stat pairs (col 87-94)
  enmity           statusAbility: fixed enmity at Lv50 as a number (550); scaled by
                   formulas.fixedEnmity(enmity, caster level) and applied to a BattleNpc target
  kind             physicalWeaponskill: "ws" (weapon DPS, default) or "aa" (weapon Damage: Jump)
  scale(c,t,s,combo,pos)  extra damage multiplier (weaponskill potency / spell magnitude)
  accScale(...)    extra hit-rate points (weaponskills)
  after(c,t,s,action,container,combo,pos)  runs after the hit (MP restore, dispel, ...)
  comboAcc         spells: resist-rate points removed when comboed (Aerora)
  comboCritUncapped spells: crit-damage bonus added past the 175% cap when comboed (Thundaga)
  statsOnly        spells: magic stat ratio from the stat pairs only (Dragonfire Dive)
  statusKind       "rider" (default) or "enfeeble" (75% landing cap)
  enmityFlat       weaponskills: fixed enmity at Lv50 added on top of the damage enmity
  flatDamage(c,t,s) physicalWeaponskill: damage added after the formula (Jump's flat term)

  actions.spreadEnmity(caster, who, amount)  fixed enmity split over the enemies hating `who`
```

## Battle modules

- Battle/Buffs.lua: Fists of Fire 223209 Attack +20% / +25% traited (tier 2) — [CLAIM W2NC; CL trait 27124 "+5%"]
- Battle/Buffs.lua: Fists of Earth 223210 Defense +20% / +25% traited (tier 2) — [CLAIM W2NC; CL trait 27125 "+5%"]
- Battle/Buffs.lua: HP Boost 223029 max HP +25% (Battle Voice) — [CLAIM SEF-44650 1.22a]
- Battle/Consumables.lua: consumable buff = min(stat x %, cap) per effect, or a flat value — [OFF 1.21 dev1242; Battle Data artifact, eLeMeN]
- Battle/Partybonus.lua: Comradery 223193 "Granted when in a light party (4 to 7 members)" — [CL xtx/status 223193]
- Battle/Partybonus.lua: Strength in Numbers 223194 "Granted when in a full party (8 members)" — [CL xtx/status 223194]
- Battle/Partybonus.lua: max HP / max MP Comradery +5%, SiN +10% — [OFF 1.17 dev1020] = client status.csv col31 105.0 / 110.0 [CL]; sizes at 1.23b decision 2026-10-03
- Battle/Partybonus.lua: physical accuracy Comradery +10%, SiN +20% official ("increased from 5 to 10 percent" / "10 to 20") — [OFF 1.21 dev1317]
- Battle/Partybonus.lua: magic accuracy Comradery +5%, SiN +10%; 1.21 raised "accuracy" only, magic stayed — [OFF 1.17]; 2nWIKI p800 [WIKI]
- Battle/Partybonus.lua: client's single col31 value matches the HP/MP part (no patch changed it); accuracy doubling is a later official change; earlier code gave +5/+10 to all four — decision 2026-10-03
- Battle/Partybonus.lua: SiN accuracy +12% not official +20%: accuracy adds 0.25 hit-% per point, +20% of a Lv50's ~370 ACC = +18 hit-%; relic/AF trust party hit Lv58 Ifrit ~100% where retail Lv50 party with Comradery missed 12-13%; at +12% party lands 81-93% (BRD higher); revert to 0.20 if a capture of a full 8-member party vs higher-level monster shows high-90s hit rates — DESIGN 2026-10-06; [RCAP ifrit_fight]
- Battle/Partybonus.lua: only members within +5/-10 levels count — 2nWIKI p800 [WIKI]
- Battle/Partybonus.lua: party-size rule "All members of a light party ... will receive a status enhancement ... When in a full party (eight members), this bonus is further increased." — [CL aetheryteParent.csv help text]
- Battle/Partybonus.lua: gain/loss lines are the status's own texts — worldMaster 30330/30331
- Battle/Crossclass.lua: slot cap by class level "a cap will be imposed upon the number of actions from other classes that can be set. The cap is determined by the level of your current class." 1 at Lv1-9, 2 at Lv10, +1 per 5 levels -> 10 at Lv50 — [OFF 1.20 dev notes]; Research Notes 04_official, off_patch_1-20
- Battle/Crossclass.lua: jobs 3 at Lv30-39, 4 at 40-49, 5 at 50 ("a level 35 paladin can only equip three"); base-class actions don't count — [OFF 1.21]
- Battle/Crossclass.lua: job class pairs PLD MRD/CNJ, MNK LNC/ARC, WAR GLA/PGL, DRG PGL/ARC, BRD CNJ/THM, WHM GLA/PGL, BLM PGL/ARC — [OFF 1.21]
- Battle/Crossclass.lua: client command sheet compatibility key: 6 any class; 113 "Exclusive" (own class and its job); 87 "Requires: Discipline of War" (not THM/CNJ/BLM/WHM); 88-94 job actions (own job only) — [CL, Battle Data client_compat]
- Battle/Crossclass.lua: "no longer bound by level restrictions when setting actions from other classes ... a level 1 pugilist will be able to set a level 30 gladiator action. However, the effectiveness of that action will be scaled down accordingly." Action must still be learned on its own class; no extra multiplier, formulas already use caster level — [OFF 1.20]; DESIGN
- Battle/Ko.lua: Weakness 223165 max HP and MP -25% ("Maximum HP and MP are reduced 25%"; status.csv col31 = 0.75), 180 s (col47 = 180.0) — [CL xtx/status 223165; OFF 1.18 dev1091; OFF manual "Weakness 3 min"]
- Battle/Ko.lua: Brink of Death 223197 max HP, max MP and all battle stats -50% (col31 = 0.5), 180 s; CHS client text and OFF 1.18 name attack, magic potency, defense, magic defense — [CL xtx/status 223197; OFF 1.18 dev1091]
- Battle/Ko.lua: raised while Weak -> Brink of Death; escalates only once, time does not add up — [OFF 1.18 dev1091; WIKI 2nWIKI FAQ/戦闘 p942]
- Battle/Ko.lua: Enhanced Raise (trait 27363, CNJ48) "Causes Raise to no longer inflict enfeebling effects" — [CL]
- Battle/Ko.lua: Return also gives Weakness plus gear-durability loss — [OFF manual "Return (Weakness 3 min, durability loss)"; OFF 1.18 dev1091; WIKI p942]
- Battle/Ko.lua: no command input for 7 s after being raised (C# AcceptRaise) — [OFF 1.19 dev1150]
- Battle/Ko.lua: Raise revives at 100% HP: two Raises by Lv50 WHMs set HP to exactly hpMax (2774/2774, 2206/2206), MP left as at KO; both raisers probably had Enhanced Raise so non-traited Raise unmeasured; Raise command row magnitude 0 — [CAP 1.23b caps/ ifrit_fight; CL 27349]
- Battle/Ko.lua: Return HP 100% and MP refill; escalation tested at revival; statuses run while KO'd; Brink-on-Brink restarts timer at 180 s; Enhanced Raise blocks both, running Weakness stays; Brink stats mapped to Attack, Defense, four magic potencies (1.19 split the 1.18 stat) and elemental resistances; accuracy/evasion untouched; lost on logout, kept on zoning — DESIGN
- Battle/Items.lua: "Recovery items are no longer usable on other characters"; scripted items are not recovery items — [OFF 1.21]
- Battle/Items.lua: sources for item sizes: Battle Data medicine rows; every size not quoted from a row is DESIGN — eLeMeN [WIKI] + 1.21 notes [OFF PN121F]; statuses [CLS/ROSTER]
- Battle/Items.lua: enfeebling potions durations 10 s (Poisoning 20 s), recast 2:00 — [WIKI eLeMeN; OFF PN121F]
- Battle/Items.lua: potion landing "the odds of success are no longer affected by the player's status (magic accuracy, etc.)" — [OFF 1.21]; flat 75% = enfeeble landing cap [TEST Kaeko #101]; DESIGN; CC diminishing returns apply [OFF CC121]
- Battle/Items.lua: enfeeble potion range 15 y (no client row for item range found) — DESIGN
- Battle/Items.lua: potion poison tick: CNJ Poison fixed 14/tick at 1.20 "regardless of resist", scaled by level/50, min 3 — [TEST kanican Part II, weak]; DESIGN
- Battle/Items.lua: Company-issue raise items "raise from KO" / "chance-based raise from KO", recast 5 s; Expectorant 50% (no rate published) — [WIKI eLeMeN]; DESIGN
- Battle/Items.lua: Unguents Protect/Shell 5:00; Protect +1 DEF per 4.5 Enhancing Magic Potency; Shell +1 each elemental resistance per 6.7 (Enhanced Protect "magic defense" rate) — [WIKI eLeMeN]; [TEST SEF-40800]; DESIGN
- Battle/Items.lua: Protect and Shell overwrite each other — [OFF DEVJP 1.20]
- Battle/Items.lua: Lunar Curtain 223273 "magic barrier (absorbs aetherial waves)", 0:15, recast 30:00; nullifying magic damage is DESIGN — [WIKI]
- Battle/Items.lua: Maddening Potion 190 enmity at Lv50, level-scaled; per enemy not split is DESIGN — [TEST JPENM 1.20/1.21: "Maddening Potion 190"]
- Battle/Items.lua: potion on a monster adds base hate only — DESIGN
- Battle/Parts.lua: parts 1..8 = body, right arm, left arm, legs, head, special right, special left, special rear; generic names xtx/text_partsName 1-5; family names in blocks (body 11+, right arm 18+, left arm 25+, legs 32+, head 41+, special R 56+, special L 69+, rear 81+) — [CL]
- Battle/Parts.lua: incapacitation = status 223019 + part (223021 right arm .. 223027 special rear), 30 s (status.csv col47), text "<part> is incapacitated" / "no longer incapacitated" — [CL]
- Battle/Parts.lua: 0x0144 sub-state byte 0: part 1..8 = bit 7..0 — [CL]
- Battle/Parts.lua: weaponskill -> part table — [OFF 1.20 dev1206 table; 1.21 dev1314 Spirits Within, Dragon Kick; ELP]
- Battle/Parts.lua: family part sets, BREAK_SHARE 0.25 of max HP, counter restart, TP moves gated, drops gated by requiredPart — DESIGN (§11.4)
- Battle/Actions.lua: Antagonize 223251 enmity x1.5, x1.65 with AF head (tier 2) — [TEST BG 1.21a #324; JPENM]
- Battle/Actions.lua: Sentinel 223062 enmity x1.2 on damage and Flash; Tachi's "+100 per WS" is a 1.22b CLAIM, JP test wins — [TEST JPENM 1.20]
- Battle/Actions.lua: these multipliers were formerly skill.enmityModifier in effect scripts (only C# physical path read it) and Antagonize added 1.5 (x2.5) — history
- Battle/Actions.lua: Fists of Fire/Wind/Earth turn auto-attacks into that element — [CLT 1.23b]
- Battle/Actions.lua: spell accuracyModifier lowers resist a quarter point per point; spell rows all carry 0 — DESIGN
- Battle/Actions.lua: hostile status riders roll through enfeebling potency vs target — [OFF PN122c; formulas.lua]
- Battle/Actions.lua: crit rating 0.16 % per point after the 1.22a hotfix — [TEST BG]
- Battle/Actions.lua: Light Shot damage keyed to weapon base damage; recast = bow delay — [OFF 1.18/1.22]
- Battle/Actions.lua: basePotency clamp exists for the emulator-era mob rows — history
- Battle/Actions.lua: accuracyModifier quarter point each: Feint DB 100 -> +25 hit-rate points; reading of client col96 = 1.0 — DESIGN
- Battle/Actions.lua: part-targeting weaponskills wear down body parts — §12.14
- Battle/Actions.lua: spell magnitude = client command sheet col 84; spell stat pairs col 87-94 — [CL]
- Battle/Actions.lua: Cleric Stance attack spells +20%, heals -20% — [OFF 1.20 list]
- Battle/Actions.lua: Lunar Curtain (223273, item 3020538) nullifies magic damage — DESIGN
- Battle/Actions.lua: heal crits — [TEST KAN]; 0.6 enmity per HP actually restored, 0 on a full-HP target since 1.21 — [TEST JP; OFF 1.21]
- Battle/Actions.lua: self-targeted fixed enmity split across hating enemies like cure/support enmity — [TEST JP 1.20]
- Battle/Actions.lua: Sleep family landing uses magic accuracy; enfeeble 75% cap — [CLAIM SEF-41900]
- Battle/Actions.lua: Feint col96 "high accuracy" — params doc; full original params header saved at scratchpad/port/notes/actions-params-header.txt
- Battle/Formulas.lua: dlvl = target level - actor level, as kanican/BG use it — convention
- Battle/Formulas.lua: variance uniform: physical ~+-8% (Seiken, kanican), magic +-5%, cures +-3% (kanican "DEV thresholds"; Cure +-3% uniform) — [TEST]
- Battle/Formulas.lua: levelFactor: Lv26 MRD hit Lv30 mobs for 44-51 and a lower field mob for 81 with same axe (ratio ~0.58) — [CAP 09_gap_fill §5]; 20-30% swings over 3-4 levels — [CLAIM t-42506]; linear fit 1-0.07*dlvl (floor 0.3) above, 1-0.05*dlvl (cap 1.5) below and clamps — DESIGN
- Battle/Formulas.lua: hitRate: players vs +3/+4 mobs hit 92%/89%; +3/+4 mobs hit shielded GLA 93% — [CAP §8a]; DEX +35 ~ +5%, ACC +34 ~ +8.5% at dLVL+4 — [TEST 1.20]; never 100% (cap ~99.9) — [TEST]; base 95 and -1.5/level — DESIGN fit
- Battle/Formulas.lua: MOB_HIT_BASE 87: mobs 3-4 levels above hit shielded GLA 41/44 and unshielded MRD 10/13, pooled 89.5% at dLVL -3.2 (n=57); quest mobs hit Lv50 MNK 7/14 (MNK evasion gear) — [CAP 09_gap_fill §8a]; DESIGN fit
- Battle/Formulas.lua: Blind etc. land on RawHitRate so they work on monsters (monster Accuracy not modelled) — effects/blind.lua
- Battle/Formulas.lua: HIT_GAP_KNEE 4 / HIT_GAP_STEEP 4.5: Lv50 party (Comradery, Lv50 gear) missed Ifrit (Lv58, +8) 13% (DRG, n=45) and 12% (WAR, n=52); 1.5/level would give 83% before gear (~95% after); 4.5/level past +4 gives base 71 at +8: Lv50 DRG with Garuda's Beak + Comradery hits Ifrit 86%, relic/AF trust party with SiN 81-93% (BRD ~99) — [RCAP ifrit_fight]; DESIGN fit to one fight; kanican damage-taken slope also steepens with dLVL — [TEST KAN III]
- Battle/Formulas.lua: hitRate per point: 0.25 per ACC above level baseline, 0.14 per DEX above expected — (from code; source as hitRate block)
- Battle/Formulas.lua: critRate: base ~7.5% at dLVL 0, ~11.2% at -5, ~6% at +5 — [TEST 1.21, BG]; +0.16% per crit rating after 1.22a hotfix — [TEST]; CRIT_RATE_CAP 27: +102 rating 24.3% at dLVL 0 and 26.4% at -10 where the slopes give 31% (n=5213), Eagleheart ~30% (n=200) — [TEST BG-581, BG-570]; 27 DESIGN (was 30)
- Battle/Formulas.lua: monster crits keep the player curve; Ifrit L58 landed 0 crits in 70 swings on Lv50s vs Lv30 mobs 6/44 on a Lv27 GLA — [RCAP ifrit_fight; CAP §8a]; no level rule fits both, so a boss's no-crit belongs on its own RawCritRate — DESIGN
- Battle/Formulas.lua: critical evasion (trait 27206 MRD / 27247 ARC "+10") 0.16% per point on defender — [CL; PN120]; scale DESIGN (no test)
- Battle/Formulas.lua: CRIT_POTENCY_PER_POINT 0.00175: +58 magic crit potency lifts a Cure crit 1.237 -> 1.3385 (0.00175/pt) — [TEST KAN I]; +50 potency +7 pts at dLVL 0, +6 at +5 — [TEST BG-418]; resilience lowers it; Thundaga combo "a rough +175 magic critical potency" breaks 175% cap — [TEST KAN IV]; was 0.002 DESIGN
- Battle/Formulas.lua: critMultiplier 1.229 at dLVL 0 (damage 1.20-1.23 [TEST KAN IV]; Cure crit +22-23%, 1.237 [TEST KAN I]), -0.0214/level above so the floor holds from ~+4 and sits 0.028 under it at +5, where +15 potency shows nothing and +16 is needed — [TEST KAN IV]; -0.03/level below, cap 1.75 — [TEST KAN IV / BG]; slopes DESIGN fit. Retail MRD crit/normal 1.27x at +4 is one pair whose ±8% spread covers 1.15 (up to 1.35) — [CAP §5]; not fit, the KAN IV floor wins
- Battle/Formulas.lua: Magic Critical Potency trait 27329 THM "+10" (potency, not rate) — [CL; DEVJP]; Critical Attack Power trait 27130 PGL "+10" — [CL]; resilience trait 27166 GLA "+10" — [CL]; Thundaga combo "can exceed the 175% cap" — [TEST KAN IV]
- Battle/Formulas.lua: "the 115% floor is applied after potency is factored in" — [TEST KAN IV]
- Battle/Formulas.lua: parry 4% - 0.3/level attacker above, +0.04 per Parry, +0.02 per DEX above typical: PGL vs R45 5.5-5.7% (1.23) — [TEST BG-521]; Ifrit (+8) 3% (2/70) — [RCAP ifrit_fight]; +41 Parry / 301 DEX vs +5 doblyn 3% (6/200) — [TEST T-36877 1.20]; mobs +4 on MRD 15.4% (2/13), quest mobs on MNK 14.3% (2/14) — [CAP §8a, wide CIs, still covered]; per-point weights DESIGN (were base 13, 0.1/Parry, 0.07/DEX); parried hits still land and give TP — [CAP]; monsters: no parries/blocks in 81 player swings at Lv30 mobs — [CAP §8a]
- Battle/Formulas.lua: PARRY_REDUCTION 0.5: parried hits on MRD 23/33/59 vs ~60 normal — [CAP §8a]; DESIGN
- Battle/Formulas.lua: block 1.22+: rate = base(dLVL) + 0.1%/DEX + 0.2%/Block Rate, cap 75% — [TEST Kaeko]; Lv27 GLA blocked 29.5% from +3 mobs — [CAP §8a]; base 20 - 1/level DESIGN; attribute weight shrinks with level — Kaeko
- Battle/Formulas.lua: block reduction 56 - 1.25/level + 0.1%/VIT + 0.2%/Block, clamp 20-75% — [TEST Kaeko BG-439, 1.22]; 1.21a Block 28/71/120 vs +2: 63.6/68.8/72.7% — [TEST BG-312] fit within ±5; BG-312's +8 values (19.5/15.2%) are pre-1.22, below the 1.22 floor, and not fit; base 56 keeps +100 Block under the 75% cap at dLVL 0; level slope DESIGN (was 45 - 2/level)
- Battle/Formulas.lua: resist: each tier -25%; RESIST_PER_POINT 0.5 per MEVA (or MACC) above typical, clamp 0-100: CNJ vs R35 Cursed Eyes went 0% -> 100% over ~200 MEVA, 100% at 425, no cap — [TEST KAN II]; was 0.1 and cap 90; base 10% and +2/level DESIGN; typical MACC/MEVA = 4.8 x level + MND/4 or PIE/4 (Stats.lua); retail resisted 10 of 57 party spells (~18%) on Ifrit at +8; 10 + 2x8 = 26% — [RCAP ifrit_fight]
- Battle/Formulas.lua: effective defense DEF + 0.67 VIT — [TEST kanican III, R^2~1]; monster Defense mods default 1 (pool rows); old max(0, Defense-1) dropped negative deltas so Defense Down did nothing — history
- Battle/Formulas.lua: defenseReduction (monster defenders only): DEF/(DEF+3*expected) = 25% for a typical monster — DESIGN
- Battle/Formulas.lua: defendedHit (player defenders): taken = raw - k(dLVL) x (DEF + 0.67 VIT); DEF_SLOPE k 0.237 at dLVL 0, 0.290-0.300 at +2 (Mongrels and Peistes alike), 0.526 at +8, 0.56-0.57 at +9; same k for autos and weaponskills; worked example 250 at 0 DEF -> 155 at +400 DEF -> 60 at +800 — [TEST KAN III, Lv50 only]
- Battle/Formulas.lua: DEF_FLOOR_SHARE 0.117: R52 Mongrels floored at 35-42 regardless of DEF/VIT, floor rises with mob level (Ifrit ~68.5) — [TEST KAN III]; share form DESIGN
- Battle/Formulas.lua: MOB_HIT_ON_PLAYER 2.62: puts an even Lv50 monster's raw auto-attack at 287, 250 on a Lv50 GLA with 0 DEF — [TEST KAN III worked example]; weaponskill potency multiplies the hit after DEF so the worked example holds at any potency — DESIGN
- Battle/Formulas.lua: DEF_LEVEL_EXP 0.33: k measured at Lv50 only; below it k x (typical Lv50 DEF / typical DEF)^0.33 so the Lv30 piranha hits a level-typical Lv27 GLA for 56-63 — [CAP-AA]; exponent DESIGN fit to one capture; an absolute k would leave Lv1-10 hits at 1-3
- Battle/Formulas.lua: consequence: a level-typical Lv50 tank (1000 gear DEF) takes the floor (~33) from even mobs; a 550-DEF caster ~120 — [TEST KAN III: 1000-DEF GLA at the floor vs +2]; live gear decides the rest
- Battle/Stats.lua: GEAR_DEF_CURVE 30/65/130/275/490/1000 at Lv1/10/20/30/40/50: best armour DEF per slot on the 1.23b item sheet (gamedata_items_armor, head/body/legs/hands/feet/waist/neck) sums ~63/128/275/487 at Lv10/20/30/40 — [CL]; 1000 at Lv50 is the KAN III tank — [TEST KAN III]; was linear 30 -> 1000, which gave a Lv27 player 545 DEF the item sheet cannot reach; only typical-player DEF and Rampart's size read it
- Battle/Formulas.lua: levelGapDefense (monster defenders): Lv50 DRG (Garuda's Beak 127/3.1) on Ifrit Lv58: autos 14-26 vs True Thrust 139, Feint 144-163, Vorpal Thrust 157-249 (WS/AA 5-6x) — [RCAP ifrit_fight]; with the Lv50 level scale True Thrust is 279 before the cut, so D = 140
- Battle/Formulas.lua: no subtraction needed at +3/+4: Lv27 GLA AA 18-22 / Fast Blade 56-65, Lv26 MRD 44-51 / Heavy Swing 77-106 on Lv30 mobs — [CAP §5]; D = 0.34 x (dLVL-4) x referenceWeaponDamage x DEF ratio — DESIGN fit [RCAP ifrit_fight: D ~140 at +8]; GAP_DEF_FREE_LEVELS 4 — DESIGN [CAP §5]; GAP_DEF_PER_LEVEL was 0.14 before the level scale
- Battle/Formulas.lua: GAP_DEF_MIN_SHARE 0.22: retail DRG autos 14-26 with True Thrust/AA 5-6 put the floor at 0.20-0.24 of the pre-cut hit (DRG 25 of 115) — [RCAP ifrit_fight]; flat D left Lv50 PLD autos on Ifrit at 1 (live 2026-10-06); BRD autos 5-8 on Extreme Ifrit — [video hz_MYagvuMI]; DESIGN floor
- Battle/Formulas.lua: physical stat weights at Lv50: primary 0.80-0.90, secondary 0.67-0.70, ATK 0.35-0.42 — [TEST Seiken 1.21, Kaeko 1.21]; class stat pairs — [OFF 1.20 notes]
- Battle/Formulas.lua: stat caps set by weapon, not level/target — [TEST, 07_caps §B; Lv50 data]; WS primary 318 + 6(DPS - 34.62), DPS = (Damage + bow ammo)/Delay — [TEST T-50219]; WS_SECONDARY_CAP through the measured brackets 275-280 @34.62 (Cobalt Winglet), 295-300 @36.74 (Ifrit's Bow, C20/C25), 305-310 @39.7 (Ifrit melee), 310-312 @40.0 (Garuda's Gaze, C47), 317-318 @42.06 (Sphairai): the tests win over Judge_Xero's line 280 + 5(DPS - 34.62) (290.6 / 306.9 at 36.74 / 40.0) and the C45 claim 290 — [TEST; conflict #8]; below 34.62 the line's 5/DPS — DESIGN; before 1.21 secondary was AA-only — [OFF dev1316]
- Battle/Formulas.lua: AA_STAT_CAP 280: auto-attack class ~280 for both stats with Lv50 Ifrit-tier weapons (272-290 observed), "keyed to Damage" — [TEST BG/SEF t-35795, t-36412; CLAIM JP t-49642 "ステ280CAP"]; min(280, WS cap) DESIGN; below Lv50 nothing measured, linear rule used as is (~110 + 6 DPS) — DESIGN; past the cap STR still adds attack at 3:2, ATK has no cap
- Battle/Formulas.lua: AA_PER_DAMAGE 1.6: AA keys off weapon Damage — [OFF-JP Mocchi 2012-07-20]; Lv27 GLA 2.5 s sword hit +3 mobs 18-22, Lv26 MRD D46 axe hit +4 mobs 44-51 — [CAP §5]; DESIGN fit
- Battle/Formulas.lua: PLAYER_LEVEL_SCALE flat to Lv27, x1.68 at Lv50: +1 Damage = +2.2 per AA at Lv50 ("1 base damage ≈ 2.225"), WS +0.21 per 0.01 DPS — [TEST BG-P24 Silvano 1.23; T-55291 ~0.85%/Damage]; the Lv26-27 captures pin 1.0 — [CAP §5]; gives 2.0 per Damage, 0.25 per 0.01 DPS (cap shift included); linear ramp DESIGN
- Battle/Formulas.lua: WS_PER_DPS 12.0: WS key off DPS = Damage/delay — [OFF-JP Mocchi 2012-07-20; TEST Kaeko 2012-05-04: WS ~ DPS, intercept ~0]; WS/AA ~3x for 2.5 s sword, ~2x for 4.2 s axe — [CAP §5]; Fast Blade ~64, Heavy Swing ~90 — DESIGN fit
- Battle/Formulas.lua: AA_DELAY_EXP 0.55 / WS_DELAY_EXP 0.72 (normalised at 3.0 s): 4.2 s axe out-hits 2.5 s sword 2.35x per swing on 1.77x Damage ratio; Heavy Swing out-hits Fast Blade 1.5x at equal DPS — [CAP §5]; DESIGN fit on two classes, refit with PGL/LNC/ARC captures
- Battle/Formulas.lua: SPELL_UNIT_PER_DAMAGE 2.8 to Lv27, 3.66 at Lv50: client magnitude (command sheet col 84) scales damage/heal; how client turns 1050 into HP not known — [CL]; 2.8 by 2026-10-03 playtest (Lv10 THM short); 3.66 puts a level-typical Lv50 Fire at 294 against the geared 284-314 — [TEST KAN IV]; level-typical stats stand for the geared caster, as in every damage test; ramp DESIGN
- Battle/Formulas.lua: Lv50 geared 1.20 THM Fire (950) did 284-314 to even-level target — [TEST kanican Part IV, via Emulation Reference "Spell damage"]
- Battle/Formulas.lua: low level: level-matched nuke ~ one level-matched WS; Fast Blade / Heavy Swing took ~9-13% of Lv25-30 mob HP — [CAP 09_gap_fill §1b, §5]; Lv50 Fire ~300 vs ~3000-HP Lv50 mobs ~10% — [TEST + SPEC]; 3.6 put Thunder ~1.4x Fast Blade, 2.6 ~1.0x
- Battle/Formulas.lua: attack magic potency = level base + INT/4 + gear — [TEST]; INT and potency "multiply each other" — [TEST BG]; per-spell stat pairs (col 87-94, Thunder INT x0.5) role unknown — [CL]; Dragonfire Dive PIE-keyed "magical" jump — [CL]; statsOnly DESIGN
- Battle/Formulas.lua: SPELL_STAT_WEIGHT 0.85 / SPELL_AMP_WEIGHT 0.5: Fire +1.17 per INT (±20%) — [TEST BG-198 1.20]; INT 198 -> 266 +30-37% — [TEST BG-110 1.19]; gives +1.05 per INT, +32.7%; BG-198's +2.2 per attack magic potency not fit: potency is mostly gear (Lv50 THM gear sums to ~+130-220 AMP on the item sheet), and that slope at level-typical stats would make a geared Fire ~2x retail — DESIGN; a magic-defense subtraction model would fit it, not adopted
- Battle/Formulas.lua: magic defense removed in 1.19 — [OFF]; elemental resistances reduce damage — [OFF 1.19]; modelled as resist/(resist+3*typical) — DESIGN
- Battle/Formulas.lua: SPELL_LEVEL_BELOW: same Lv50 THM Fire 284-314 vs Lv50, 1164-1284 vs Lv35 (x4.1 at -15), 1893-2092 vs Lv1 (x6.7 at -49) — [TEST kanican Part IV]; 0 to -15 shape DESIGN (first 5 levels physical slope +5%/level)
- Battle/Formulas.lua: SPELL_ABOVE_PER_LEVEL 0.035 (0.72 at +8, floor 0.3): Lv50 BLMs' unresisted non-crit Thunder on Ifrit (Lv58) 221-248 (also Thundaga 539-553, Freeze 352, Burst ~532) — [RCAP ifrit_fight]; with the Lv50 Fire fit, 0.72 lands Thunder at 234; linear shape DESIGN (was 0.025)
- Battle/Formulas.lua: MagicResistance % less attack-spell damage (Magic Resistance Up 223047, man2g0 ward) — DESIGN
- Battle/Formulas.lua: heals: CNJ 1.15 x HMP + 0.2 x MND, others 1.03 x HMP, +0.05 x VIT, ±3%: Lv50 WHM 484 HMP / 303 MND / 186 VIT Cure 601-635, Cura 1222-1275 (avg 1264) — [TEST BG-285 1.21]; Lv27 GLA cross-class Cure 151-166 — [CAP-CURE]; kanican 1.20 slopes CNJ +1.25/HMP, +0.25/MND, others +1.10/HMP, VIT ~0.1 — [TEST KAN I]: the newer test and the capture win (conflict #1), every slope stays inside KAN I's ±0.1; Cure 1000, Cura 2000, Curaga 4000 magnitude — [CL]; Cleric Stance -20% heals — [OFF 1.20]
- Battle/Formulas.lua: heal crits: THM main class cure crit 10.8%, others 7.71% (HEAL_CRIT_THM_BONUS 3.3) — [TEST KAN I 1.20]; size CRIT_MULT_BASE 1.229 + 0.00175/potency (1.237, 1.3385 with +58) — [TEST KAN I]; Curaga crit 1378 vs 1046-1110 (x1.24-1.32) — [TEST BG-285]
- Battle/Formulas.lua: affinity: own element -30, element that beats it +20, the one it beats 0, other three -10 same polarity / +10 opposite — [TEST 05_community_jp D6, 1.17, 113 samples, pre-1.19; family elements WIKI/INFERENCE]; mob mods 30..35 = Fire..Water (25 + element id)
- Battle/Formulas.lua: directional weakness "Only certain monsters" — [OFF 1.19]; which/how much unknown, no rows set it
- Battle/Formulas.lua: Exposed statuses 223017-223020 (front/right/rear/left): "<target>'s rear side is exposed", 30 s, param1 50 — [CL status sheet]; +50% damage from that side is DESIGN reading of param1; nothing applies them
- Battle/Formulas.lua: status resist mods per status id — [modifiers.lua 73-83]; "+1 status resist = +1 MEVA against that ailment" — [TEST BG 107403]
- Battle/Formulas.lua: status landing uses Enfeebling Magic Potency vs target magic evasion — [OFF DEVJP 2011-12-16; OFF PN122c "additional effects ... increase Enfeebling Magic Potency ... more likely to succeed"]; Sleep/Repose magic accuracy only — [CLAIM SEF-41900]
- Battle/Formulas.lua: pure enfeebles cap near 75%, riders higher — [TEST Kaeko BG #101/#162, pre-1.20 eyeball]; 1.23b Shield Bash stunned 8/8 — [CAP]; shape base x (1 + 0.004 x (potency-typical - MEVA-typical)) - 0.03/level above, floor 0.05, rider cap base+0.15 — DESIGN; ENFEEBLE_CAP 0.75 — [TEST Kaeko BG #101]
- Battle/Formulas.lua: HEAL_ENMITY 0.6: 1 damage = 1 enmity; 1 HP healed = 0.6 (split over engaged mobs); overcure on full-HP target 0 since 1.21 — [TEST JP 1.20/1.21a; OFF 1.21 fix]
- Battle/Formulas.lua: fixed enmity at Lv50: Provoke ~550 (EN test 571), Flash ~380, Rampart 190 per target, Hallowed Ground 1140 — [TEST JP 1.20/1.21a]; ~15 per level ("30 per 2 levels" on Provoke) — [TEST]; linear by level DESIGN
- Battle/Formulas.lua: MP cost base = client calculateCommandCost — [CL 01_client_re §3.1]

## Statuses

- Status/AegisBoon.lua: Lv27 GLA took 0 damage and recovered 136/161/148/144 HP while the mob's normal hits were 56-63 (~2.4x the blocked hit); status ended on that hit and the mob gained no TP — CAP 09_gap_fill §6a
- Status/AegisBoon.lua: heal cap ~703 at Lv39, "only character level affects the cap" — TEST BG p.12
- Status/AegisBoon.lua: 2.5x the blocked amount, capped at 703 — DESIGN fit
- Status/Antagonize.lua: status 223251 from 27187 WAR35, 15 s — W2N; "Increases enmity generated by all actions." — CLT
- Status/Antagonize.lua: x1.5, x1.65 with the AF head (tier 2) — TEST BG 1.21a #324; JPENM
- Status/AttackDown.lua: status 223034 — ROSTER name-match; from Provoke (27180) once Enhanced Provoke (trait 27200, MRD28) is learned — CLT 1.23b; PN120
- Status/AttackDown.lua: duration 30 s — PN120 1.20 (official Enhanced Provoke row)
- Status/AttackDown.lua: owner's physical damage x0.9 — DESIGN (no source gives the size)
- Status/BattleVoice.lua: Battle Voice (223253) on the bard, 30 s — CLAIM SEF-44650
- Status/Berserk2.lua: stacks reset when the owner takes damage — Battle Data 223207: CLT; HF122a
- Status/Blind.lua: status 223007 "accuracy down" — CLS; sources Concussive Blow flank 30 s, Gloom Arrow combo 30 s, Flash with Enhanced Flash, Blinding Potion 10 s — PN120; EL
- Status/Blind.lua: CC diminishing-returns group Blind, 180 s — OFF CC121
- Status/Blind.lua: default -20 hit-rate points — DESIGN
- Status/Bloodbath.lua: Skull Sunder 97 -> +73 HP, Heavy Swing 87 -> +65 HP, i.e. round(0.75 x damage); status consumed by that weaponskill — CAP 09_gap_fill §6a, n=2
- Status/Bloodbath.lua: 1.21 absorb amount no longer scales with VIT — OFF PN121
- Status/BrinkOfDeath.lua: max HP, max MP and battle stats -50% for 180 s when raised while still Weak — CL xtx/status 223197 + status.csv; OFF 1.18 dev1091
- Status/BrinkOfDeath.lua: which modifiers count as "battle stats" (Battle/Ko.lua BRINK_STATS) — DESIGN mapping
- Status/Collusion.lua: status 223097 — ROSTER name-match; ability 27188 WAR40, recast 90 s — CL; duration 30 s — W2N (command row: 15 s)
- Status/Collusion.lua: target must be within 8 yalms, a condition for the effect to fire, not the cast range (client range 15) — CLT 1.23b
- Status/Collusion.lua: 1.21 100% of enmity transferred — BG 1.21a #288/#324; 1.22a hotfix "all" -> "a portion" — HF122a; 1.23b keeps "a portion" — CLT
- Status/Collusion.lua: 50% of the attack's enmity moves to the WAR — DESIGN ("a portion" [CLT; HF122a])
- Status/Comradery.lua: light party (4 to 7): max HP/MP +5%, physical accuracy +10%, magic accuracy +5% — sources in battle/partybonus.lua
- Status/DarkSeal2.lua: status 223229 from ability 27300 THM, "Increases magic accuracy of next spell." — CLT 1.23b; +50 accuracyModifier -> -12.5 resist-rate points — DESIGN (size unpublished)
- Status/DefenseDown.lua: status 223038 from Riot Blade from behind, 30 s — PN120 1.20
- Status/DefenseDown.lua: -20% of effective DEF — DESIGN
- Status/Excruciate.lua: status 223231 — ROSTER name-match; ability 27302 THM38, recast 90 s — CL; 30 s or until a magic critical — PN120 1.20; EL 1.23b
- Status/Excruciate.lua: "Gradually increases critical rate of spells. Effect ends upon landing a critical hit." — CLT 1.23b; Enhanced Excruciate (trait 27321, THM48) increases the bonus, no size — CLT; PN120; "only spell that can aid in forcing magic criticals" — KAN 1.20
- Status/Excruciate.lua: +4 crit-rate points per 3 s tick (+8 traited), +40 after 30 s untraited; emulator's 25/50 crit rating x 0.16 %/point — DESIGN (Research Notes gap)
- Status/Featherfoot.lua: status 223075 — ROSTER name-match; ability 27103; 30 s or until one evasion — PN120 1.20; EL 1.23b
- Status/Featherfoot.lua: flat 140 MP per evade (two evaded pteroc auto-attacks of different sizes, cross-class BLM) — VID-Q0HO @3:19, @5:51
- Status/Featherfoot.lua: Enhanced Featherfoot (trait 27123, PGL28) +25% -> 175 MP — CL; PN120
- Status/Featherfoot.lua: evasion +15 raw — DESIGN (emulator value, kept)
- Status/FistsOfEarth.lua: physical defense +20%, +25% with Enhanced Fists of Earth (PGL36) — CLAIM W2NC "ともに特性有りで+25%"; CL trait "+5%"
- Status/FistsOfFire.lua: attack +20%, +25% with Enhanced Fists of Fire (PGL44) — CLAIM W2NC 1.20+; CL trait "+5%"
- Status/FistsOfEarth.lua, FistsOfFire.lua, FistsOfWind.lua: stance ends on reuse, MP consumed while active, exclusive with the other two — CLT 1.23b
- Status/FistsOfEarth.lua, FistsOfFire.lua, FistsOfWind.lua: MP upkeep 28 per 3 s tick, 25 with AF body Temple Cyclas (8032702) — TEST SEF-43454 1.21a
- Status/FistsOfEarth.lua, FistsOfFire.lua, FistsOfWind.lua: target's elemental affinity applies to the owner's attacks — CLAIM JPF-42219
- Status/FistsOfWind.lua: weaponskill recast -20% (-30% with AF, AF piece unidentified, not applied) — TEST SEF-43454 1.21a; movement speed has no published size
- Status/Flare2.lua: status 223262 — ROSTER "Flare 2" name-match; Flare 27318 BLM40, "Chance to inflict damage over time effect." — CLT 1.23b; PN121J
- Status/Flare2.lua: chance 0.75 and 30 s are the command row's values; tick 20 set by Command/Magic/Flare.lua — DESIGN (DoT ticks at 1.23b are a Research Notes gap)
- Status/HallowedGround.lua: status 223249 from ability 27148, 20 s — W2N; "Impervious to most attacks" — CLT 1.23b; all attacks except certain ones since 1.22a — HF122a
- Status/HallowedGround.lua: no attack pierces it — DESIGN (exceptions not recorded)
- Status/Haste.lua: not in the 1.23b player kit — Battle Data status 223002: roster only
- Status/HawksEye.lua: status 223106 from 27220 ARC, 15 s — PN120; EL; "Increases physical accuracy." — CLT
- Status/HawksEye.lua: untraited +18.75% of current Accuracy (379 -> 450 on an untraited DRG) — Project Meteor capture note, kept as DESIGN
- Status/HawksEye.lua: Enhanced Hawk's Eye (27240) "Increases accuracy gained from Hawk's Eye by 50%." -> gain x1.5 = 28.125% — CL; OFF PN120
- Status/HpBoost.lua: granted by Battle Voice (27227 BRD50), 60 s (DB) — W2N; max HP +25% — CLAIM SEF-44650 1.22a
- Status/Incapacitation*.lua: "A body part is damaged beyond use.", 30 s — CL status sheet
- Status/IncapacitationSpecialRight.lua: "A body part is damaged beyond use.", 30 s — [CL status sheet]
- Status/LifeSurgeI.lua, LifeSurgeII.lua, LifeSurgeIII.lua: status ids 223215/223216/223217 — [ROSTER name-match]
- Status/LifeSurgeI-III.lua: ability 27262, LNC22, TP 250, recast 15 s — [CL]
- Status/LifeSurgeI-III.lua: duration 180 s (1.22a hotfix: 60 -> 180) — [HF122a; EL 1.23b]
- Status/LifeSurgeI-III.lua: "Consumes TP to grant an Absorb HP effect to auto-attacks, up to three stacks. Cannot be used simultaneously with Power Surge." — [CLT 1.23b]
- Status/LifeSurgeI-III.lua: Enhanced Life Surge (trait 27282, LNC32) "+20%" read as x1.2 — [CLT; PN120]
- Status/LifeSurgeI-III.lua: absorb 10/20/30% at stack I/II/III (emulator base values kept); emulator's traited 30/40/50% dropped — DESIGN (Research Notes: "Life Surge drain %" is a gap)
- Status/LunarCurtain.lua: item 3020538, "magic barrier (absorbs aetherial waves)", 0:15, recast 30:00 — [WIKI eLeMeN]
- Status/LunarCurtain.lua: which primal mechanic it was made for is unknown — DESIGN
- Status/MagicResistanceUp.lua: no 1.23b player action applies it, no source gives its size — [ROSTER]; [Battle Data status 223047: effect/magnitude blank]
- Status/MagicResistanceUp.lua: Wind/Earth/Water ward choices (processEventTrial001 ask 270) all give this one status — DESIGN
- Status/MagicResistanceUp.lua: -20% attack-spell damage default — DESIGN; "Revisit with a 1.0 log or video of the fight"
- Status/MagicResistanceUp.lua: header cited duty.lua applyMsqDutyWard, which does not exist in this branch; dropped — (stale reference)
- Status/Medicated.lua: stats min(stat x %, cap) or flat Enmity change per server_items_consumable — [OFF 1.21 dev1242; WIKI eLeMeN]
- Status/MightyStrikes.lua: from 27189 WAR50, 15 s — [W2N]; "Guarantees all attacks made with axes will be critical hits." — [CLT]
- Status/Necrogenesis.lua: status 223232 — [ROSTER name-match]; 30 s or until next attack spell — [PN120 1.20; EL 1.23b]; "Restores HP when next attack spell is cast." — [CLT 1.23b]
- Status/Necrogenesis.lua: heal 28% of first hit, one-shot (Fira 1132/1148/1167, one "You recover 314 HP." line; 314/1132 = 27.7%); emulator's 75% gone; one sample — [VID-Q0HO @5:52]
- Status/Paralysis.lua: status 223005 — [CLS]; sources Disembowel (longer on Feint combo), Paralyzing/Disabling Potion 10 s — [CLT; EL]
- Status/Paralysis.lua: CC diminishing-returns group Paralysis, 180 s — [OFF CC121]
- Status/Paralysis.lua: 25% fail chance per action; no 1.x source gives a number — DESIGN
- Status/Paralysis.lua: server_statuseffects 223005 flags ActivateOnPreactionCaster | LoseOnDeath | LoseOnEsuna | LoseOnLogout = 8213 — (as written)
- Status/Parsimony.lua: status 223233 — [ROSTER name-match]; 30 s or until next attack spell — [PN120 1.20; EL 1.23b]
- Status/Parsimony.lua: "Reduces MP cost of next attack spell by half, and restores MP when spell is cast." — [CLT 1.23b]; "...restores MP when cast is complete." — [PN121J]
- Status/Parsimony.lua: Enhanced Parsimony (trait 27323, THM16) "+25%" -> x1.25 — [CL; PN120]
- Status/Parsimony.lua: only attack spells (actionType Magic) use it; interrupted cast keeps it — (client/official reading)
- Status/Parsimony.lua: return rate 0.215 of damage (393 MP after 1467-damage Thundara = 26.8% traited, / 1.25 = 21.4%); also ~1.04x listed MP 378, damage reading chosen; one sample — [VID-Q0HO @2:02]
- Status/Parsimony.lua: needs server_statuseffects 223233 flags ActivateOnCastStart | ActivateOnHit | ActivateOnCommandFinish | LoseOnDeath | LoseOnDispel (1051145) — (as written)
- Status/PowerSurgeI.lua, PowerSurgeII.lua, PowerSurgeIII.lua: attack up, defense down — [HF122a 1.22a]
- Status/PowerSurgeI-III.lua: attack +~115 / +~230 / +~346 total, defense ~-158; old scripts gave 315/210/315 — [TEST BG 1.22a]
- Status/PowerSurgeI-III.lua: Enhanced Power Surge (LNC44) x1.1 after 1.22a hotfix — [CL trait text "by 10%"; W2N x1.1; HF122a]
- Status/PowerSurgeI-III.lua: 60 s, refreshed by each weaponskill or Jump, next stage after 10 refreshes (max III), exclusive with Life Surge, ends on reuse — [CLAIM SEF-46305 1.22a]
- Status/PresenceOfMind.lua: status 223116 (roster also lists 223076), client Lua name 神速魔, InstantEffectStatus, removed on class change — [CLL 1.23b]
- Status/PresenceOfMind.lua: ability 27344, WHM30, recast 300 s — [CL]
- Status/PresenceOfMind.lua: cast and recast time 0 (JP text and 1.21 list; EN says "reduces") — [CLT 1.23b; PN121J]; consumed by next spell — [PN121J]
- Status/PresenceOfMind.lua: any spell consumes it; consumed on cast completion; duration 30 s from the command row — DESIGN (no source)
- Status/PresenceOfMind.lua: needs server_statuseffects 223116 flags ActivateOnCastStart | ActivateOnCommandFinish | LoseOnDeath | LoseOnDispel | LoseOnClassChange (2825) — (as written)
- Status/Protect.lua: from 27351 CNJ6, 300 s — [PN120; CAP 301.7 s]; retail cast applied 223129 traited or not — [CAP]
- Status/Protect.lua, Protect2.lua, Shell.lua: DEF +1 per ~4.5 Enhancing potency (old script 4.56 x potency, ~20x too much); resistances +1 per ~6.7 potency — [TEST SEF-40800 1.21]
- Status/Protect.lua: Enhanced Protect (CNJ24) "Increases magic defense gained from Protect" — [CL]
- Status/Protect2.lua: 223239 is a roster row only — [CAP]
- Status/QuellingStrike.lua: status 223104 — [ROSTER name-match]; ability 27221, ARC22, recast 60 s — [CL]; 30 s or next attack — [PN120 1.20; EL 1.23b]
- Status/QuellingStrike.lua: "Reduces enmity and increases TP generated by next attack. Ends Raging Strike effect..." — [CLT 1.23b]; "Does not affect auto-attacks." — [PN120]
- Status/QuellingStrike.lua: Enhanced Quelling Strike (trait 27241, ARC32) +50% -> x1.5 of TP bonus — [CLT; PN120]
- Status/QuellingStrike.lua: TP bonus 300 (450 traited); enmity x0.8; "next attack" = next weaponskill, spell or physical ability — DESIGN (no source gives the sizes)
- Status/QuellingStrike.lua: needs server_statuseffects 223104 ActivateOnCommandStart | LoseOnLogout | LoseOnDeath (1041) — (as written)
- Status/RagingStrike2.lua: status 223221 candidate (other roster row 223105) — [ROSTER "Raging Strike 2"]
- Status/RagingStrike2.lua: ability 27225, ARC14, recast 10 s (official/eLeMeN say 60, unresolved) — [CL]
- Status/RagingStrike2.lua: toggle with no timer, command row duration infinite — [W2N]
- Status/RagingStrike2.lua: max 3 stacks, resets on missing a bow attack, ends on reuse (1.20 "fades upon missing" became "resets" in 1.21) — [CLT 1.23b; PN121 1.21]
- Status/RagingStrike2.lua: Enhanced Raging Strike (trait 27243, ARC36) x1.5 — [CLT; PN120]
- Status/RagingStrike2.lua: +5% Attack per stack (max +15%), enmity x1.25, any missed physical attack resets — DESIGN (Research Notes gap "Raging Strike per-stack bonus")
- Status/RagingStrike2.lua: needs server_statuseffects 223221 ActivateOnHit | ActivateOnMiss | ActivateOnPreactionCaster | Stance | LoseOnDeath | LoseOnLogout | LoseOnClassChange (537993489) — (as written)
- Status/Rampart.lua: 60 s — [OFF PN120; CAP ON->OFF 59-62 s]
- Status/Rampart.lua: Lv27 GLA, same mob's hits 58-63 -> 45 with Rampart only (~-24%), tiny n — [CAP §6a]
- Status/Rampart.lua: one extra level-typical DEF -> -20% damage, fit to the capture — DESIGN
- Status/Resting.lua: 223263 is the inn status — [CAP return_to_inn / move_out_of_room]
- Status/SacredPrism.lua: status 223225 — [ROSTER name-match]; 60 s or until next eligible spell — [OFF PN120; EL]
- Status/SacredPrism.lua: "Increases cast time to grant next Cure, Cura, Regen, Esuna, or enhancing spell an area of effect." — [CLT 1.23b]; eligible ids — [CLT list; ids CL]
- Status/SacredPrism.lua: cast time x1.5 (emulator value kept) — DESIGN
- Status/SacredPrism.lua: AoE circle radius 8 yalms, the client AoE radius of Protect/Curaga — DESIGN; [CL col aoe 8]
- Status/SacredPrism.lua: needs server_statuseffects 223225 ActivateOnCastStart | ActivateOnCommandFinish (2569, like resonance2) — (as written)
- Status/Sentinel.lua: enmity x1.2 on damage and Flash while active — [TEST JPENM 1.20]; old onHit +100 per weaponskill — [CLAIM SEF-47393] (Tachi's 1.22b guide), JP measurement outranks it
- Status/Sentinel.lua: damage taken -30% / -50% traited — [TEST BG 1.20 #175; CL trait 27160]
- Status/Shell.lua: players get it only from Ironwill Unguent since 1.20 — [CLS; WIKI eLeMeN 5:00]
- Status/Shell.lua: resistance +1 per 6.7 potency borrowed from Enhanced Protect's measured rate — DESIGN; [TEST SEF-40800]
- Status/Shell.lua: Protect and Shell overwrite each other — [OFF DEVJP 1.20]
- Status/ShroudOfSaints.lua: status 223226 — [ROSTER name-match]; ability 27341, CNJ38, recast 180 s — [CL]; 120 s with Swift Shroud of Saints 27361 — [CL; PN120]; duration 20 s — [PN120 1.20; EL 1.23b]
- Status/ShroudOfSaints.lua: "Temporarily reduces enmity by half, and gradually restores MP" — [CLT 1.23b; PN120]; 1.20a fixed halving not being granted — [PN1x 1.20a]
- Status/ShroudOfSaints.lua: enmity generated while up x0.5 (stored enmity untouched; give-back reading rejected) — DESIGN
- Status/ShroudOfSaints.lua: MP 3% of max MP per 3 s tick (~20% over 20 s) — DESIGN (not in Research Notes measurements)
- Status/ShroudOfSaints.lua: needs server_statuseffects 223226 ActivateOnPreactionCaster | LoseOnDeath | LoseOnDispel (8201) — (as written)
- Status/Slow.lua: source Aura Pulse combo (Pummel), 30 s — [PN120 1.20; EL]; "attack interval lengthened" — [PN120]
- Status/Slow.lua: default x1.65 = low end of mob delay +65-80% (pre-1.20 only) — DESIGN [BG 1.19 #41 low end; obsolete era]
- Status/SpinningHeel.lua: status 223245 — [CAP 1.23b]; "Adds kick to auto-attacks" — [CLT 1.23b]; fists 2 -> 3 hits
- Status/Swiftsong.lua: from 27226 BRD/ARC26, 180 s or until enmity — [PN120]
- Status/Swiftsong.lua: movement +20%, +40% under Battle Voice (was x1.25, unsourced) — [CLAIM SEF-44650 1.22a]
- Status/Taunted.lua: status 223073 — [ROSTER name-match "Taunted"]; Taunt 27102, PGL42, recast 60 s — [CL]; 45 s with Swift Taunt 27122 — [CL; PN120]; duration 5 s — [PN120 1.20; EL 1.23b]
- Status/Taunted.lua: "Temporarily focuses the target's attacks on you." — [CLT 1.23b; PN120]; 1.20+ text names no enmity gain
- Status/Taunted.lua: lock via hate list padding (top + 1, every 500 ms tick, taken back at end); a C# target lock in HandleHate would be cleaner — DESIGN
- Status/Taunted.lua: needs server_statuseffects 223073 debuff flags 21, tickMs 500 — (as written)
- Status/Vengeance.lua: Lv50 WAR vs Ifrit: unabsorbed swing took 344, countered 345 (unbuffed swings ~600-890); under Stoneskin counters 306-376; counter row text 30379, effect 0x48000200 (SelfHeal type), param 1 — [RCAP ifrit_fight t=16-20, 208-220]
- Status/Vengeance.lua: "-50% physical damage reduction"; AF body (Fighter's Cuirass) extends to magic — [TEST SEF-43454 1.21a]
- Status/Vengeance.lua: only attacks that land are countered (miss/evade/full block not captured) — DESIGN
- Status/Vengeance.lua: server_statuseffects 223250 flags ActivateOnPreactionTarget + ActivateOnDamageTaken — (as written)
- Status/Weakness.lua: max HP/MP -25% for 180 s after raise or Return — [CL xtx/status 223165 + status.csv; OFF 1.18 dev1091]
- Status/WellFed.lua: stats min(stat x %, cap) per server_items_consumable — [OFF 1.21 dev1242; WIKI eLeMeN]

## Abilities

- Command/Ability/Antagonize.lua: Antagonize 27187, WAR Lv35, recast 120 s, self — [CL]
- Command/Ability/Antagonize.lua: status 223251, 15 s — [W2N]
- Command/Ability/Antagonize.lua: "Increases enmity generated by all actions." — [CLT]
- Command/Ability/Antagonize.lua: x1.5 enmity, x1.65 with Fighter's Burgeonet (AF head) — [TEST BG 1.21a #324]
- Command/Ability/Antagonize.lua: Fighter's Burgeonet item 8013503 — gamedata_items; head slot 8 = Player.SLOT_HEAD
- Command/Ability/BattleVoice.lua: Battle Voice 27227, BRD Lv50, recast 900 s, party members within 8 — [CL]
- Command/Ability/BattleVoice.lua: "Party max HP up; songs enhanced" — [PN121J]
- Command/Ability/BattleVoice.lua: HP Boost 223029, max HP +25%, 60 s (DB row) — [CLAIM SEF-44650; W2N 60 s]
- Command/Ability/BattleVoice.lua: Battle Voice status 223253, 30 s — [CLAIM SEF-44650] (W2N says 60 s; song-doubling window follows the 1.22a post)
- Command/Ability/BattleVoice.lua: Minuet 35 -> 71 under Battle Voice — [TEST SEF-39924]; Swiftsong +20% -> +40%, Paeon, Ballad doubled
- Command/Ability/Benediction.lua: Benediction 27345, WHM Lv50, recast 900 s, range 20 — [CL; range raised by 1.22a hotfix HF122a]
- Command/Ability/Benediction.lua: "Restores HP of all party members within range." — [CLT]
- Command/Ability/Benediction.lua: full restore — [CLAIM SEF-41900 1.22c]
- Command/Ability/Benediction.lua: heal enmity 0.6 per HP restored, treated like a cure — DESIGN
- Command/Ability/Chameleon.lua: Chameleon 27223, ARC Lv42, recast 180 s, self — [CL]
- Command/Ability/Chameleon.lua: -760 enmity per enemy at Lv50 (1.20) -> -840 (1.21), per-enemy, not split — [TEST JPENM 1.21]
- Command/Ability/Chameleon.lua: level scaling via formulas.fixedEnmity — DESIGN
- Command/Ability/Chameleon.lua: Swift Chameleon 27245 (ARC48) recast -60 s — [CL trait]
- Command/Ability/DragonfireDive.lua: Dragonfire Dive 27268, DRG Lv50, recast 900 s, range 15, AoE 4 around target, Magical Fire — [CL]
- Command/Ability/DragonfireDive.lua: magnitude 1200; stat pairs A PIE(6)x1.5 / B PIE(6)x0.75 — [CL]
- Command/Ability/DragonfireDive.lua: "Delivers a jumping fire attack to target and enemies near it." — [CLT]
- Command/Ability/DragonfireDive.lua: stat ratio from PIE only (statsOnly) — DESIGN reading of the PIE pair
- Command/Ability/FistsOfEarth.lua: Fists of Earth 27105, PGL Lv22, status 223210, recast 10 s — [CL]
- Command/Ability/FistsOfEarth.lua: Enhanced Fists of Earth 27125 at PGL36 — [CL]
- Command/Ability/FistsOfFire.lua: Fists of Fire 27104, PGL Lv34, status 223209, recast 10 s — [CL]
- Command/Ability/FistsOfFire.lua: Enhanced Fists of Fire 27124 at PGL44 — [CL]
- Command/Ability/FistsOfWind.lua: Fists of Wind 27109, MNK Lv40, status 223211, recast 10 s — [CL]
- Command/Ability/FistsOfWind.lua: no trait enhances it in 1.23b — [CL trait sheet]
- Command/Ability/FistsOf*.lua: stances toggle off on reuse; Fire/Earth/Wind mutually exclusive — [CLT 1.23b]
- Command/Ability/Flash.lua: ~380 enmity at Lv50, not split — [TEST JP 1.20]; 400 — [CLAIM t-47393]
- Command/Ability/Flash.lua: x1.2 under Sentinel, x1.5 under Antagonize — [TEST JPENM]
- Command/Ability/HallowedGround.lua: Hallowed Ground 27148, PLD Lv50, no TP/MP, recast 900 s, self — [CL; OFF PN121J; EL]
- Command/Ability/HallowedGround.lua: status 223249 — [ROSTER name-match]; 20 s — [W2N]
- Command/Ability/HallowedGround.lua: "Renders you impervious to most attacks" — [CLT 1.23b]; physical only until 1.22a hotfix, then all but certain attacks — [HF122a]
- Command/Ability/HallowedGround.lua: no attack pierces it (which ones do is unrecorded) — DESIGN
- Command/Ability/HallowedGround.lua: 1140 enmity on activation — [TEST JPENM 1.21a "Invincible"; CLAIM SEF-47393 1.22b]
- Command/Ability/HallowedGround.lua: 1140 split across enemies already hating the paladin (cure/support rule [TEST JP 1.20]) — DESIGN
- Command/Ability/HallowedGround.lua: no trait shortens its recast — [CL]
- Command/Ability/HawksEye.lua: "Increases accuracy gained from Hawk's Eye by 50%"; tier 2 18.75% -> 28.125% — [CL]
- Command/Ability/Jump.lua: Jump 27266, DRG Lv30, recast 60 s, range 15, Piercing — [CL]
- Command/Ability/Jump.lua: "Evades physical attacks and delivers a jumping attack." — [CLT]; airborne evasion added by 1.22a hotfix — [HF122a]
- Command/Ability/Jump.lua: "+1 base damage ~ +2.225 to AA and Jump" (keyed to base Damage, AA slope, potency 1.0) — [TEST BG 1.23 p.24; TEST slope]
- Command/Ability/Jump.lua: Lv50 DRG Jumps on Ifrit beat same-moment auto-attacks by 83-112 (Jump 134/128/154/168/169/98 vs AA 22/23/49/74/71-74/14-15); flat = 1.2 x referenceWeaponDamage = 102 at Lv50 — [RCAP ifrit_fight]
- Command/Ability/Jump.lua: level scaling of the flat term — DESIGN (one level, one fight)
- Command/Ability/Jump.lua: advances Power Surge — [CLAIM SEF-46305]
- Command/Ability/LifeSurge.lua: Enhanced Life Surge 27282 "Increases Absorb HP effect of Life Surge by 20%." — [CLT; PN120]
- Command/Ability/LightShot.lua: Light Shot 27259, ARC Lv1, TP 0 — [CL]
- Command/Ability/LightShot.lua: "Recast time varies with delay value of main hand weapon." — [CLT 1.23b; CL recast column 0]
- Command/Ability/LightShot.lua: "a delay rating of 3.5 would equal a 3.5 second recast" — [OFF PN1x 1.18]
- Command/Ability/LightShot.lua: damage keyed to weapon base Damage like an auto-attack — [OFF 1.18/1.22]
- Command/Ability/LightShot.lua: retail BRD Flame Longbow 180-215 per shot — [BG 1.23]
- Command/Ability/LightShot.lua: 1.21: no longer breaks combos or uses up Blindside/Bloodbath/Blood for Blood — [OFF PN121]
- Command/Ability/LightShot.lua: potency 1.0 — DESIGN
- Command/Ability/LightShot.lua: Barrage "Reduces accuracy" — [CLT 27224]; -10 hit-rate per hit — DESIGN
- Command/Ability/LightShot.lua: TP per landed shot = round(100 x delay x (1 + Store TP/1000)), split across Barrage hits — DESIGN (1.18 made Light Shot the archer's ranged attack)
- Command/Ability/MightyStrikes.lua: Mighty Strikes 27189, WAR Lv50, recast 900 s, self — [CL]; status 223252, 15 s — [W2N]
- Command/Ability/MightyStrikes.lua: "Guarantees all attacks made with axes will be critical hits." — [CLT]
- Command/Ability/Outmaneuver.lua: Enhanced Outmaneuver 27165 (GLA44): blocks under Outmaneuver restore MP — [CL; PN120]
- Command/Ability/PowerSurge.lua: Enhanced Power Surge x1.1 at 1.23b — [CL; HF122a]
- Command/Ability/PresenceOfMind.lua: Presence of Mind 27344, WHM Lv30, recast 300 s, self — [CL]; status 223116 — [CLL]
- Command/Ability/PresenceOfMind.lua: Healer's Culottes (8051406, legs slot 12) recast -30 s — [TEST SEF-43454 1.21a]
- Command/Ability/Provoke.lua: ~550 enmity at Lv50 (JP 1.20; EN test 571), ~15 per level — [TEST JP via BG p.11/17]
- Command/Ability/Provoke.lua: ~750 per the 1.22b PLD guide — [CLAIM t-47393]
- Command/Ability/Provoke.lua: 550 x level/50 scaling — DESIGN
- Command/Ability/Provoke.lua: Attack Down 223034, 30 s — [PN120]
- Command/Ability/QuellingStrike.lua: "Ends Raging Strike effect if active to provide a further TP bonus" — [CLT 1.23b]; JP text: TP according to its stage
- Command/Ability/QuellingStrike.lua: 100 TP per Raging Strike stack — DESIGN (size unpublished)
- Command/Ability/RagingStrike.lua: Enhanced Raging Strike 27243 "Increases effect of Raging Strike by 50%." — [CL; PN120]
- Command/Ability/Rampart.lua: 190 enmity per target hit at Lv50 — [TEST JP 1.20]; 180 per member — [CLAIM t-47393] (forum thread 47393, Tachi's Guide to Paladin post-1.22b)
- Command/Ability/Refill.lua: Refill 27258, ARC Lv1, "Refills quiver with arrows from your inventory." — [CLT]
- Command/Ability/SacredPrism.lua: Sacred Prism 27340, CNJ Lv34, no TP/MP, recast 90 s, self — [CL; OFF PN120; EL]
- Command/Ability/SacredPrism.lua: status 223225, 60 s — [OFF PN120; EL]
- Command/Ability/SacredPrism.lua: Swift Sacred Prism 27360 (CNJ Lv40) recast -30 s — [CL; OFF PN120]
- Command/Ability/SacredPrism.lua: enmity on use 1-21, small and variable — [TEST JPENM 1.20]; none applied — DESIGN
- Command/Ability/SecondWind.lua: Second Wind 27100, PGL Lv6, no TP since 1.21 (was 250), recast 45 s, self — [CL; OFF PN121]
- Command/Ability/SecondWind.lua: client magnitude 1550, stat pair INT(4)x0.5 — [CL]
- Command/Ability/SecondWind.lua: retail Lv26 199-201, Lv27 204-215, Lv30 241 (cross-class MRD/GLA/WAR) — [CAP 09_gap_fill §8c]
- Command/Ability/SecondWind.lua: Lv50 WAR 580 base — [CLAIM t-51208]
- Command/Ability/SecondWind.lua: below Lv26 anchors scaled to ~25-35% of max HP — DESIGN
- Command/Ability/SecondWind.lua: PGL adds INT/2 — [CL pair INT x0.5; CLAIM t-51208 "2 INT = 1 HP"]
- Command/Ability/SecondWind.lua: Enhanced Second Wind 27120 +25% — [OFF trait text]
- Command/Ability/SecondWind.lua: spread +-2.6% within a level — [CAP]
- Command/Ability/ShoulderTackle.lua: Shoulder Tackle 27108, MNK Lv30, recast 60 s, range 15, Blunt — [CL]
- Command/Ability/ShoulderTackle.lua: "Chance to inflict Stun when target has no enmity towards you." — [CLT]
- Command/Ability/ShoulderTackle.lua: stun 223015, retail 7.7 s (1 sample) — [CAP 1.23b]; chance DB 0.75 via rider roll — DESIGN
- Command/Ability/ShoulderTackle.lua: generates no enmity — [CLAIM SEF-39933 1.21]
- Command/Ability/ShoulderTackle.lua: potency 1.0 — DESIGN; retail sample 661 at unknown level — [CAP]
- Command/Ability/SpinningHeel.lua: Spinning Heel 27107, MNK Lv35, recast 120 s, self — [CL]; status 223245, 20 s — [CAP 1.23b: 20.6 s; W2N]
- Command/Ability/SpinningHeel.lua: "Adds kick to auto-attacks. Damage of auto-attacks is reduced. Cannot be used simultaneously with Hundred Fists." — [CLT]
- Command/Ability/SpinningHeel.lua: removing Hundred Fists (223244) on start — DESIGN reading of "cannot be used simultaneously"
- Command/Ability/StoneThrow.lua: Stone Throw 22114, gameCommand col 64 range 12 — [CL]; recast 5 s (gameCommandBasic)
- Command/Ability/StoneThrow.lua: AttackCommand.useWeaponRangeInformation returns (false, false) for 22114 — [CL]
- Command/Ability/StoneThrow.lua: potency 0.5 on the auto-attack formula — DESIGN; animation is a PLACEHOLDER, as Throw
- Command/Ability/Taunt.lua: Swift Taunt 27122 recast -15 s — [CL; PN120]
- Command/Ability/Taunt.lua: Taunted 223073, 5 s — [PN120]
- Command/Ability/Throw.lua: Throw 22113, all classes Lv1, recast 5 s, range 8 — [CL]; "Hurl your throwing weapon at an enemy." — [CLT]
- Command/Ability/Throw.lua: kept with 5 s recast at 1.18, needs a throwing weapon — [OFF PN1x 1.18; EL]
- Command/Ability/Throw.lua: "Throw returns TP based on main weapon and is affected by Store TP" — [CLAIM BG 1.23 #549]
- Command/Ability/Throw.lua: 1.21: no longer uses up Blindside/Bloodbath/Blood for Blood — [OFF PN121]
- Command/Ability/Throw.lua: ThrowCommand judgeAttackWorkIndex -> attack index 3 (throwing-weapon set, equip slot 4) — [CL]
- Command/Ability/Throw.lua: potency 1.0 — DESIGN (no 1.x number)
- Command/Ability/Throw.lua: refusal text 32553 — exact retail text unknown
- Command/Ability/Throw.lua: server_battle_commands row added 2026-10-03; placeholder animation 0x11001000 (monster auto-attack); player ids 0x19001000 (AA) / 0x12xxxxxx (WS); no retail 22113 capture

## Magic

- Command/AutoAttack/Default.lua: AttackState builds command 22104 "Attack" each swing — as written (no tag)
- Command/AutoAttack/Default.lua: physicalDamage("aa") about 1.6 x weapon Damage before level difference and DEF — [CAP 09_gap_fill §5 fit]
- Command/AutoAttack/Default.lua: attacker TP round(100 x delay x (1 + StoreTP/1000)) per swing round, split in integer shares across the weapon's own hits (Character.autoAttackBaseHits); each extra hit (Spinning Heel's kick) +50% of the round value; monsters +300 per landed hit; defender gets ceil(damage x k) — [CAP §1a/§1b]
- Command/Magic/Aero.lua: Aero 27353 CNJ Lv4, MP 75, cast 3 s, recast 6 s, Wind, magnitude 800, INT x0.25 + MND x0.25 — [CL]
- Command/Magic/Aero.lua: bleed strength and landing from enfeebling potency — [OFF-JP DEVJP]; 1.23b tick size unknown
- Command/Magic/Aero.lua: tick 15 at Lv50 scaled by level, floor 2 — DESIGN; 1.19 DoTs capped near 15 — [TEST Kaeko]
- Command/Magic/Aerora.lua: Aerora 27354 CNJ Lv42, MP 150 per-mille, cast 4 s, recast 20 s, AoE 8 around target, Wind, magnitude 1200, pair A INT(4)x0.5 + MND(5)x0.5 / pair B half — [CL]
- Command/Magic/Aerora.lua: "Dispels an effect on each target." Combo from Aero: "Increased accuracy and conversion to single target." — [CLT 1.23b]; no x1.5 combo damage in 1.23b text (old script had it)
- Command/Magic/Aerora.lua: combo accuracy -10 resist-rate points — DESIGN size
- Command/Magic/Aerora.lua: dispel flag 8 = LoseOnDispel — [CLT]
- Command/Magic/Blizzara.lua: Blizzara 27309 THM Lv26, MP 150 per-mille, instant, recast 40 s, AoE 8, Ice, magnitude 550, pair A INT(4)x0.25 / B INT(4)x0.125 — [CL col 84/87-94]
- Command/Magic/Blizzara.lua: Bind 30 s, chance — [PN120; EL]; DB statusChance 0.75 — DESIGN
- Command/Magic/Blizzard.lua: Blizzard 27308 THM Lv4, MP 90, cast 3 s, recast 10 s, Ice, magnitude 800, INT x0.5 — [CL]
- Command/Magic/Blizzard.lua: Heavy 30 s — [OFF PN120; EL]; landing uses enfeebling potency, not magic accuracy — [OFF-JP DEVJP]
- Command/Magic/Burst.lua: Burst 27316 BLM Lv50, MP 90 per-mille, cast 4 s, recast 900 s, Lightning, magnitude 2200, pair A INT(4)x1.5 / B INT(4)x0.75 — [CL]
- Command/Magic/Burst.lua: combo from Thundara "Increased damage with lesser current HP" — [CLT]; size x(1 + (1 - HP%)) — DESIGN
- Command/Magic/Cura.lua: Cura 27347 CNJ Lv30, MP 100 per-mille, cast 2 s, recast 5 s, range 20, magnitude 2000, pairs A MND(5)x0.4, B VIT(2)x0.2 — [CL]; "Restores a large portion of target's HP." — [CLT]
- Command/Magic/Cura.lua: R50 CNJ +2.5 HP per healing potency (2x Cure's 1.25), WHM 484 HMP / 303 MND heals 1222-1275 — [TEST KAN]
- Command/Magic/Cura.lua: old script used 2.5 x HMP + 0.5 x MND (AF-chest fit) — SEF-41900
- Command/Magic/Curaga.lua: Curaga 27348 CNJ Lv46, MP 150 per-mille, cast 3 s, recast 10 s, party within 8 of target, magnitude 4000 "(pooled)" — [CL]; "Healing priority is given to those with lowest HP." — [CLT]
- Command/Magic/Curaga.lua: one member gets at most half the pool, heals until cap, lowest HP first — [CLAIM SEF-41900 1.22c]
- Command/Magic/Curaga.lua: retail WHM 484/303: 1046-1110 per member, crit 1378 — [TEST BG 1.21 #285]
- Command/Magic/Curaga.lua: water-fill on HP% distribution — DESIGN reading of "lowest HP first"
- Command/Magic/Curaga.lua: Cleric Stance (223227) x0.8 heal — [OFF 1.20]
- Command/Magic/Cure.lua: Cure 27346 CNJ Lv2, MP 40 per-mille (Lv1 5 MP, Lv50 112 MP), cast 2 s, recast 5 s, range 20, magnitude 1000, pairs A MND(5)x0.2, B VIT(2)x0.1 — [CL]
- Command/Magic/Cure.lua: CNJ 1.25/HMP + 0.25/MND, others 1.10/HMP — kanican 1.20; retail cross-class Cures 151-166 at Lv27 — [CAP]
- Command/Magic/Default.lua: monster spells 23508 Fire II, 23511 Blizzard II, 23514 Aero II, 23517 Stone II, 23520 Thunder II, basePotency = client magnitude 600 — [CL]
- Command/Magic/Default.lua: INT x0.5 stat weight for fallback spells — DESIGN (THM Fire weights)
- Command/Magic/Fira.lua: Fira 27311 THM Lv34, MP 180 per-mille, cast 5 s, recast 16 s, AoE 8 around target, Fire, magnitude 1200, pair A INT(4)x1 / B INT(4)x0.5 — [CL]; combo from Fire: reduced cast time — [CLT]; x0.5 — DESIGN (size unpublished)
- Command/Magic/Firaga.lua: Firaga 27312 THM Lv50, MP 255 per-mille, cast 8 s, recast 7 s, AoE 8 around target, Fire, magnitude 1600, pair A INT(4)x1.5 / B INT(4)x0.75 — [CL]; combo from Fira: reduced cast time — [CLT]; x0.5 — DESIGN
- Command/Magic/Fire.lua: Fire 27310 THM Lv10, MP 105, cast 3 s, recast 8 s, AoE radius 8 around target, Fire, magnitude 950, INT x0.5 — [CL]
- Command/Magic/Flare.lua: Flare 27318 BLM Lv40, MP 200 per-mille, cast 8 s, recast 120 s, Fire, enemies around caster (DB aoeTarget self, radius 8), magnitude 2000, pair A INT(4)x1.5 / B INT(4)x0.75 — [CL]
- Command/Magic/Flare.lua: "Damage dealt increases with proximity. Chance to inflict damage over time effect." — [CLT]; falloff x1.0 to x0.5 at 8 y — DESIGN; DoT 223262 magnitude 20/tick — legacy value, DESIGN
- Command/Magic/Freeze.lua: Freeze 27319 BLM Lv35, recast 120 s, Ice, magnitude 1200, INT x1.5 / INT x0.75 — [CL]; "Deals ice damage. Reduces enmity." — [CLT 1.23b; PN121J]
- Command/Magic/Freeze.lua: damage makes 0 enmity, removes flat 720 at Lv50 — [TEST JPENM 1.21]; EN "point for point" claim is lower tier; level scaling via formulas.fixedEnmity — DESIGN
- Command/Magic/Holy.lua: Holy 27359 WHM Lv45, instant, recast 300 s, AoE 8 around caster, magnitude 2000, pair A INT(4)x1 + MND(5)x1 / B half — [CL]; "Consumes all MP to deal damage to enemies in range. Chance to inflict Bind." — [CLT]; Bind 228011 — [PN121J]
- Command/Magic/Holy.lua: retail ~1,200 (no gear, Cleric Stance) to ~1,750 (well geared) at Lv50 — [TEST BG 1.21/1.22 #369]
- Command/Magic/Holy.lua: damage x(1 + 1.5 x MP/maxMP) — DESIGN, sized so Lv50 at stat ratio 1.0 does ~1,200, geared ~1,550 (1,850 Cleric Stance)
- Command/Magic/HolySuccor.lua: Holy Succor 27149 PLD Lv40, MP 100 per-mille (280 at Lv50), cast 2 s, recast 10 s — [CL; W2N]; magnitude 1500, pairs A MND(5)x0.4, B VIT(2)x0.2 — [CL]
- Command/Magic/HolySuccor.lua: "When cast on another player, you also heal 50% of the amount restored." — [CLT]; PLD uses 1.10/HMP — [CL; TEST KAN]
- Command/Magic/HolySuccor.lua: Gallant Gauntlets (AF, 8071401) +10% — [TEST SEF-43454 1.21a]
- Command/Magic/MinuetOfRigor.lua: +35 ACC/MACC at Lv50, +30 at Lv45 (level - 15); AF 43; Battle Voice 71; both 86 — [TEST SEF-39924 1.21]
- Command/Magic/MinuetOfRigor.lua: Choral Ringbands (AF) adds +8 (35 -> 43) — [TEST SEF-39924]; old +25 was from an unsourced "60 with AF" note
- Command/Magic/Protect.lua: Enhanced Protect 27365 is CNJ Lv24; retail applied 223129 with or without the trait — [CAP]
- Command/Magic/Protect.lua: Protect and Shell overwrite each other — [OFF DEVJP 1.20]
- Command/Magic/Raise.lua: Raise 27349 CNJ Lv18, corpse-only (server_battle_commands mainTarget 0x3034), MP 150 per-mille (420 at Lv50), cast 10 s, recast 300 s, range 20, magnitude 0 — [CL]
- Command/Magic/Raise.lua: Raise II / Rebirth / Resurrect exist only as pre-1.20 rows (28675, 29037-29040), not in the 1.23b kit — [PN120; Battle Data]
- Command/Magic/Raise.lua: revive at 100% of max HP (ko.RAISE_HP_PERCENT) — [CAP 1.23b caps/]
- Command/Magic/Raise.lua: Enhanced Raise "no longer inflict[s] enfeebling effects" — [CL]
- Command/Magic/Raise.lua: corpse entry is text 30354, effect 1, not the row's 30101 — [RCAP 1.23b ifrit_fight]
- Command/Magic/Regen.lua: Healer's Boots 8081806 (AF feet, Player.SLOT_BOOTS 14) Regen +25% — [TEST SEF-40800 "AF boots"]; old check used Healer's Culottes 8051406 in the boots slot
- Command/Magic/Regen.lua: cap 203 HP/tick (Lv50, 438 Enhancing, AF); ~0.625-0.75 HP/tick per potency; 136 -> 170 with AF (+25%) — [TEST SEF-40800 1.21]
- Command/Magic/Repose.lua: Repose 27352 WHM Lv50, cast 3 s, range 20 — [CL]; Sleep 228001, 60 s — [PN120; W2N]
- Command/Magic/Repose.lua, Sleep.lua, Sleepga.lua: 75% landing cap — [TEST Kaeko BG #101]; Sleep/Repose "is only affected by Magic Accuracy" — [CLAIM SEF-41900]; Sleep DR group 180 s: full -> 1/2 -> 1/4 -> immune — [OFF CC121]
- Command/Magic/Sleep.lua: Sleep 27306 THM Lv42, MP 75 per-mille, cast 3 s, range 20 — [CL]; Sleep 228001, 60 s — [PN120]
- Command/Magic/Sleepga.lua: Sleepga 27317 BLM Lv45, MP 100 per-mille, cast 4 s, target and enemies within 8 — [CL]; "Puts target and enemies near it to sleep." — [CLT]; Sleep 228001, 60 s (DB)
- Command/Magic/SanguineRite.lua: 27324 is Enhanced Sanguine Rite; 27365 is CNJ Enhanced Protect — [CL; PN120]
- Command/Magic/Stone.lua: Stone 27355 CNJ Lv1, MP 75, cast 2 s, recast 6 s, Earth, magnitude 950, INT x0.25 + MND x0.25 — [CL]; adds Magic Evasion Down — [CLT]; -29 MEVA on R40 lemurs — [TEST kanican]
- Command/Magic/Stone.lua: damage x1.1 — DESIGN (Thunder 1050 same cast/recast); MEVA-down magnitude 50 kept from old script, size DESIGN
- Command/Magic/Stonera.lua: Stonera 27356 CNJ Lv22, MP 150, cast 3 s, recast 30 s, AoE 8, Earth, magnitude 950, INT x0.5 + MND x0.5 — [CL]; Heavy; combo from Stone: single target and more damage — [CLT]; x1.5 — DESIGN
- Command/Magic/Stoneskin.lua: ~1.57 HP per Enhancing potency: 600 @383, 633 @404 untraited; 770 @393 with CNJ trait (x1.25) — [TEST BG 1.20]; was 1.34 / 1.96 (unsourced)
- Command/Magic/Stoneskin.lua: Enhanced Stoneskin 27364 +25% — [TEST BG 1.20 #175]
- Command/Magic/Swiftsong.lua: Battle Voice doubles Swiftsong +20% -> +40% movement speed — [CLAIM SEF-44650 1.22a]
- Command/Magic/Thundaga.lua: Thundaga 27315 THM Lv46, MP 195 per-mille, cast 5 s, recast 45 s, Lightning, magnitude 2150, pair A INT(4)x1.5 / B INT(4)x0.75 — [CL]; combo from Thundara: increased critical damage — [CLT]
- Command/Magic/Thundaga.lua: "a rough +175 magic critical potency" past the 175% cap — [TEST BG 1.20a #261 Kaeko; KAN IV]; 0.002 per point (formulas.CRIT_POTENCY_PER_POINT) — DESIGN
- Command/Magic/Thundara.lua: Thundara 27314 THM Lv18, MP 135, instant, recast 30 s, Lightning, magnitude 500, INT x1.0 — [CL]; Stun 4 s, combo from Thunder: more damage and shorter recast instead of stun — [CLT; OFF PN120]
- Command/Magic/Thundara.lua: combo ~+700 MATK-equivalent at Lv50 — [TEST BG #310]
- Command/Magic/Thundara.lua: on Ifrit (Lv58), one Lv50 BLM's Thundara 653-695 after Thunder, 188-197 uncomboed (x3.5, n=4/2); all Lv50 BLMs' comboed 448-736 (n=12); Thunder 1050 gives 235-253 vs retail 221-248 — [RCAP ifrit_fight]
- Command/Magic/Thundara.lua: x1.6 scale fitted to 188-197 — [RCAP; DESIGN fit, two samples]; recast /2 — DESIGN ("reduced recast", size unpublished)
- Command/Magic/Thunder.lua: Thunder 27313 THM Lv1, MP 75 per-mille (calculateCommandCost), cast 2 s, recast 6 s, range 20, Lightning, magnitude 1050, pair A INT(4)x0.5 / B INT(4)x0.25 — [CL col 84/87-94]

## Weaponskills

- Command/WeaponSkill/*.lua (potency paragraph, repeated in most player weaponskills): potency per TP cost, anchored on retail starter captures (1000 TP = 1.0; 1500 TP ~1.05-1.1): 250-500 TP procs 0.85-0.9, 1500 1.1, 2000 1.35, 3000 1.8 (whole action); x0.8 on multi-target hits; multi-hit actions split the total; +10% where the 1.22a hotfix says "physical damage increased" — DESIGN, 2026-10-03; [CAP]; [HF122a]
- Command/WeaponSkill/AuraPulse.lua: ID 27113, PGL Lv38, TP 1500, recast 40 s, self AoE 8 — [CL; PN120]
- Command/WeaponSkill/AuraPulse.lua: combo from Pummel inflicts Slow 30 s — [CLT; PN120; EL]; 1.22a damage up — [HF122a]; Slow chance 50% on combo is a legacy value — DESIGN
- Command/WeaponSkill/Bloodletter.lua: ID 27235, ARC/BRD Lv46, TP 1500, recast 80 s, ranged — [CL]; bleed DoT 30 s — [PN120; EL]; combo "Inflicts additional damage when bleed ends." — [CLT]
- Command/WeaponSkill/Bloodletter.lua: uncomboed status 223241 (tick only), comboed 223127 (tick + burst); tick 15 and the burst are legacy values — DESIGN
- Command/WeaponSkill/Bloodletter.lua: PIE raises DoT and landing (~60-70% at ~290 PIE vs Ifrit); landing through enfeebling potency (PIE/4) in formulas.statusLandChance — [CLAIM SEF-35795]
- Command/WeaponSkill/Bloodletter.lua: potency 1.3 (1500 TP but 80 s recast) — DESIGN
- Command/WeaponSkill/BrutalSwing.lua: ID 27193, MRD Lv4, TP 1500, recast 20 s — [CL]; flank increased damage — [OFF PN120]; retail 81-83 vs Heavy Swing 77-106 -> ~0.9x, flank size unknown — [CAP]; positionalPotency 1.2 — DESIGN
- Command/WeaponSkill/ChaosThrust.lua: ID 27276, LNC Lv50, TP 3000, recast 80 s, sixfold — [CL]; tooltip text on crit damage / combo crit rating — [CLT]; crit-damage bonus added by the 1.22a hotfix — [HF122a]; combo +15 crit points, crit damage +0.2, potency 1.8 x 1.2 / 6 — DESIGN
- Command/WeaponSkill/ConcussiveBlow.lua: ID 27111, PGL Lv10, TP 1500, recast 30 s — [CL]; combo damage raised in 1.22a — [OFF PN120/HF122a]; flank Blind 30 s — [OFF PN120]; retail Lv50 MNK combo 901-903 vs Pummel 780-870 -> ~1.1x (902/825) — [CAP]
- Command/WeaponSkill/CrimsonCyclone.lua: ID 23365, dashing clone lane corner to corner (FireLine); retail 1906 (n=1) on Lv50 players; MAGNITUDE 3630 fit = median / 0.525 — [RCAP ifrit_fight]; spell unit 2.8 x referenceWeaponDamage(58) x spellLevelFactor(-8) = 288.4 x 1.82 = ~525 per 1000 magnitude (Battle/Formulas.lua); shape/radius from ENCOUNTER_OVERRIDES in tools/seed/build_mob_skills.py
- Command/WeaponSkill/Default.lua: monster TP moves are 23xxx client commands seeded by tools/seed/build_mob_skills.py; retail moves cost 1000 TP and monsters gain +300 TP per landed swing — [CAP 09_gap_fill §1b]; per-move potencies unknown — DESIGN; monster weapon from Battle/Stats.lua stats.weapon
- Command/WeaponSkill/Demolish.lua: ID 27115, PGL Lv30, TP 1500, recast 30 s — [CL]; combo "Dispels an effect." — [CLT]; part damage legs — [ELP]; dispel text 30336
- Command/WeaponSkill/Disembowel.lua: ID 27272, DRG Lv35, TP 750, recast 30 s — [CL]; tooltip Paralysis / combo longer duration — [CLT]; Paralysis 223005, 15 s, chance 0.75 from DB, no source gives either; combo doubles duration (legacy) — DESIGN
- Command/WeaponSkill/DoomSpike.lua: ID 27271, LNC Lv46, TP 3000, recast 60 s, line range 8 — [CL; CLT]; combo "Increased accuracy." — [CLT]; TP fixed 3000 at 1.23b, "consumes up to 3000 TP" wording belongs to pre-1.20 26xxx weaponskills (e.g. 26640 Simian Thrash) — [CL t_command_battle_params]; combo +12.5 acc — DESIGN
- Command/WeaponSkill/DragonKick.lua: ID 27118, MNK Lv45, TP 2000, recast 60 s, twofold — [CL; CLT]; combo Pacification 223013 — [CLT]; part damage rear — [ELP; PN121]; 1.22a damage up — [HF122a]; Pacify 50% on combo, 10 s (DB), legacy — DESIGN
- Command/WeaponSkill/Eruption.lua: ID 23374, IfritDummy, 4 s after mark, radius 7.5 (FireAt); retail 1356-1936 (median ~1840) on Lv50; MAGNITUDE 3500 fit — [RCAP ifrit_fight]
- Command/WeaponSkill/FastBlade.lua: ID 27150, GLA Lv1, TP 1000, recast 10 s, Slashing — [CL]; front increased damage — [OFF PN120]; retail Lv27 GLA vs Lv30: 56-65 = GLA reference opener — [CAP]; front bonus 1.2, size unpublished — DESIGN
- Command/WeaponSkill/Feint.lua: ID 27278, LNC Lv4, TP 250 (500 before 1.21), recast 10 s, only after a miss — [CL; OFF PN121]; client accuracy modifier col96 = 1.0 — [CL]; 1.21 'accuracy significantly increased'; potency 0.85 — DESIGN
- Command/WeaponSkill/FlatBlade.lua: ID 27151, GLA Lv26, TP 1500, recast 10 s — [CL]; combo increased enmity — [CLT]; 1.21 combo enmity raised and affected by MND — [PN121]; part damage special (right); combo enmity x4.5 on top of x1 (x5.5) — [TEST JPENM 1.21: x2.0 -> x4.5]; old onCombo set skill.enmityModifier, which C# applied on top
- Command/WeaponSkill/Fracture.lua: ID 27198, MRD Lv18, TP 500, recast 40 s, only after a parry — [CL; OFF PN120]; Pacification 8 s — [OFF PN120; EL] (retail 10.8 s, n=1); retail 68-85 / 119 vs Heavy Swing -> ~0.75x — [CAP]; statusChance 1.0 (captured once, landed) — DESIGN
- Command/WeaponSkill/FullThrust.lua: ID 27279, LNC Lv38, TP 250, recast 30 s, only after a miss — [CL; CLT]; accuracy modifier +0.5 — [CL col96]; 1.21 more TP earned, damage bonus from PIE — [PN121]; +1000 TP on hit legacy, size unpublished — DESIGN
- Command/WeaponSkill/GloomArrow.lua: ID 27234, ARC Lv30, TP 1000, recast 10 s — [CL]; combo Blind 30 s — [CLT; PN120; EL]; part damage special (left) — [ELP]; Blind chance 0.75 legacy — DESIGN
- Command/WeaponSkill/Godsbane.lua: ID 27195, MRD Lv50, TP 3000, recast 60 s, threefold — [CL; PN120; EL]; combo crit rate / Berserk reset tooltip — [CLT; PN121]; part damage special (right) — [ELP]; +15 crit, accuracyModifier 50 — DESIGN; 223160 is the monster Berserk TP move — [CAP]
- Command/WeaponSkill/GoringBlade.lua: ID 27153, PLD Lv50, TP 3000, recast 60 s (1.22a: 80 -> 60) — [CL; HF122a]; bleed 223206, 30 s — [PN120; EL]; 1.22a damage up — [HF122a]; tick 25, 38 on combo, chance 0.9 from behind, legacy — DESIGN
- Command/WeaponSkill/Haymaker.lua: ID 27119, PGL Lv18, TP 250, recast 5 s, only after evading — [CL; OFF PN120]; retail 778/828, crit 1484 vs Pummel 780-870 -> ~0.97x; Stun 223015 applied on both captured uses — [CAP]
- Command/WeaponSkill/HeavyShot.lua: ID 27228, ARC Lv1, TP 1000, recast 10 s, Projectile — [CL]; Quick Nock combo only from >= 8 yalms — [CLT]
- Command/WeaponSkill/HeavySwing.lua: ID 27190, MRD Lv1, TP 1000, recast 10 s, Slashing — [CL]; front accuracy increased — [OFF PN120]; retail Lv26 MRD vs Lv30: 77-106 = MRD reference opener — [CAP]; +10 hit points, size unpublished — DESIGN
- Command/WeaponSkill/HeavyThrust.lua: ID 27273, LNC Lv10, TP 1500, recast 20 s — [CL]; Stun 4 s when target is attacking you, combo longer — [CLT; OFF PN120]
- Command/WeaponSkill/Hellfire.lua: ID 23409; 2 s readies (0x6F000010); retail 1410-1994 on every Lv50 player (median ~1870) — [RCAP ifrit_fight]; 3560 fitted the retail hits, lowered 10% (to 3200) after live fights with the trust party ran hot — DESIGN, 2026-10-06
- Command/WeaponSkill/HowlingFist.lua: ID 27116, PGL Lv46, TP 3000, recast 80 s — [CL]; flank accuracy, combo damage tooltip — [CLT]; combo bonus raised by 1.22a — [HF122a]; flank +12.5 (legacy modifier 50), combo x1.25 — DESIGN
- Command/WeaponSkill/ImpulseDrive.lua: ID 27275, LNC Lv18, TP 1500, recast 30 s — [CL]; combo crit rating, flank damage — [CLT]; potency 1.1, flank 1.2, combo +15 crit — DESIGN
- Command/WeaponSkill/Incinerate.lua: ID 23363; retail 1134-1234 unmitigated (375 under Stoneskin) on Lv50; MAGNITUDE 2270 fit — [RCAP ifrit_fight]
- Command/WeaponSkill/LeadenArrow.lua: ID 27229, ARC Lv10, TP 1500, recast 30 s — [CL]; Heavy 30 s — [OFF PN120; EL]; combo longer Heavy — [OFF PN120]
- Command/WeaponSkill/LegSweep.lua: ID 27270, LNC Lv30, TP 1000, recast 30 s, AoE 8 — [CL; CLT]; combo Stun 8 s — [CLT; PN120; EL]
- Command/WeaponSkill/Maim.lua: ID 27194, MRD Lv26, TP 1500, recast 30 s — [CL]; combo increased accuracy — [CLT]; part damage special (rear) — [ELP]; +12.5 (legacy +50 modifier) — DESIGN
- Command/WeaponSkill/Overpower.lua: ID 27199, MRD Lv30, TP 250, recast 5 s, cone, only after parrying — [CL; CLT; PN120]
- Command/WeaponSkill/PathOfTheStorm.lua: ID 27196, MRD Lv38, TP 1500, recast 30 s — [CL]; Heavy from behind — [CLT]; Heavy 228021, no source gives duration (30 s as other Heavies) — [PN120], DB; part damage right arm — [ELP]; chance 0.75 — DESIGN
- Command/WeaponSkill/Phalanx.lua: ID 27158, GLA Lv4, TP 250, recast 5 s, only after a block — [CL; OFF PN120]; retail 48-57 vs Fast Blade 56-65 -> ~0.87x — [CAP]
- Command/WeaponSkill/PiercingArrow.lua: ID 27233, ARC Lv4, TP 1000, recast 20 s — [CL]
- Command/WeaponSkill/Pounce.lua: ID 27114, PGL Lv4, TP 1500, recast 20 s — [CL]; rear Stun 10 s — [OFF PN120; EL]; Stun DR 30 s — [OFF CC121]; potency 1.0, no capture — DESIGN
- Command/WeaponSkill/Pummel.lua: ID 27110, PGL Lv1, TP 1000, recast 10 s, Blunt — [CL]; front increased damage — [OFF PN120]; retail Lv50 MNK 780-870, crit 1535 = MNK reference opener — [CAP]; front 1.2, size unpublished — DESIGN
- Command/WeaponSkill/QuickNock.lua: ID 27231, ARC/BRD Lv38, TP 1000, recast 180 s, cone range 10, 5 arrows — [CL; EL]; combo "Fivefold attack and conversion to single target." — [CLT; SEF-32638]; 0.5 per hit — DESIGN
- Command/WeaponSkill/RadiantPlume.lua: ID 23376; retail 425-1882 (median ~1620; 425 absorbed by a barrier) on Lv50; MAGNITUDE 3100 fit — [RCAP ifrit_fight]
- Command/WeaponSkill/RageOfHalone.lua: ID 27155, GLA Lv46, TP 1500, recast 20 s, fivefold low accuracy — [CL; CLT]; accuracy modifier -0.4 — [CL col96]; combo penalty lifted as the legacy script did — DESIGN
- Command/WeaponSkill/RainOfDeath.lua: ID 27232, BRD Lv45, TP 3000, recast 30 s, AoE 8 — [CL]; combo Stun — [CLT]; Stun 5 s, chance 0.75 (DB) — DESIGN
- Command/WeaponSkill/RingOfTalons.lua: ID 27277, DRG Lv45, TP 2000, recast 60 s, AoE 8 — [CL; CLT]; combo crit rate — [CLT]; +15 crit — DESIGN
- Command/WeaponSkill/RiotBlade.lua: ID 27154, GLA Lv30, TP 2000, recast 80 s, ranged — [CL; CLT]; Defense Down from behind — [CLT]; Defense Down 223038, 30 s — [PN120; EL]; 1.22a damage up — [HF122a]; -20% DEF (Status/DefenseDown.lua reads magnitude as percent), chance 0.75; legacy 100 was absolute DEF — DESIGN
- Command/WeaponSkill/SavageBlade.lua: ID 27152, GLA Lv10, TP 1000, recast 30 s — [CL]; combo increased damage — [OFF PN120]; retail combo 64/66 (crit 76) vs Fast Blade 56-65 -> ~1.07x — [CAP]
- Command/WeaponSkill/Sear.lua: ID 23361, IfritHotAir; retail 239-396 (median 333, 1-3 targets) on Lv50; MAGNITUDE 635 fit — [RCAP ifrit_fight]
- Command/WeaponSkill/Shadowbind.lua: ID 27236, ARC Lv18, TP 250, recast 40 s — [CL]; Bind 30 s — [OFF PN120; EL]; Bind DR 180 s — [OFF CC121]
- Command/WeaponSkill/ShieldBash.lua: ID 27156, GLA Lv18, TP 250, recast 30 s — [CL]; Stun 5 s — [OFF PN120; EL]; retail 49-55 (~0.85x Fast Blade), stun landed 8/8 — [CAP]
- Command/WeaponSkill/SimianThrash.lua: ID 27112, MNK/PGL Lv50, TP 2000 fixed at 1.23b ("up to 3000 TP" is the pre-1.20 26640 row), recast 80 s, ninefold — [CL; CLT]; combo damage raised by 1.22a — [CLT; HF122a]; 1.35 x 1.3 / 9, combo x1.3 — DESIGN
- Command/WeaponSkill/SkullSunder.lua: ID 27191, MRD Lv10, TP 1500, recast 30 s — [CL]; combo enmity (lowered in 1.21) — [OFF PN120/PN121]; combo enmity x(1 + 1.75) — [TEST JP 1.21]; retail combo 87-146 (leve) and 161 vs Heavy Swing 175 (field) -> ~1.05x — [CAP]
- Command/WeaponSkill/SpiritsWithin.lua: ID 27159, PLD Lv45, TP 3000, recast 60 s (1.21a: 120 -> 60) — [CL; PN121a]; accuracy +0.5 — [CL col96]; combo enmity x1.5 on top of 1x — [TEST JPENM 1.21]; HP curve — DESIGN
- Command/WeaponSkill/SteelCyclone.lua: ID 27192, WAR Lv45, TP 1000 (1.22a: 2000 -> 1000), recast 30 s, AoE 10 — [CL; HF122a]; hits at most 8 targets (not modelled) — [CLAIM BG]; Rampage reset cut in 1.22a, size unpublished; combo +15 crit, stun 3 s (DB) — DESIGN
- Command/WeaponSkill/SuckerPunch.lua: ID 27117, PGL Lv26, TP 1000, recast 15 s — [CL]; MP tooltip — [CLT]; 1.21 MP equation adjusted — [PN121]; MP 0.3 x / 0.4 x + 180 legacy fit, 1.21 equation unpublished — DESIGN; old script called DoAction without damage
- Command/WeaponSkill/TrueThrust.lua: ID 27269, LNC Lv1, TP 1000, recast 10 s, Piercing — [CL]; front accuracy increased — [OFF PN120]; +10 acc — DESIGN
- Command/WeaponSkill/VorpalThrust.lua: ID 27274, LNC Lv2, TP 1500, recast 20 s — [CL]; rear crit rating — [CLT]; 1.22a removed its accuracy penalty — [OFF HF122a]; +15 crit from behind — DESIGN
- Command/WeaponSkill/VulcanBurst.lua: ID 23362; retail 565-626 (2-3 targets) on Lv50; MAGNITUDE 1125 fit — [RCAP ifrit_fight]; every hit 0x08001E35 text 30301 = HitEffectType | KnockbackLv5 (0x1E00) | RecoilLv2 | HitVisual1/3/4 — [RCAP ifrit_fight t=285/388/450, all targets]
- Command/WeaponSkill/WarDrum.lua: ID 27157, GLA Lv38, TP 500, recast 60 s, AoE 8, only after a block — [CL; CLT]; "Generates massive enmity." — [CLT]; ~380 fixed enmity at Lv50 — [TEST JPENM]; old script's +400 was overwritten by the shared call
- Command/WeaponSkill/Whirlwind.lua: ID 27197, MRD Lv46, TP 3000, recast 80 s, AoE 10 — [CL]; combo Berserk reset to increase damage, changed from the old <50% HP TP dump — [CLT; HF122a]; Berserk 223207, 20 attack / -20 defense per stack (24 tier 2) per Status/Berserk2.lua; reset x1.5 legacy — DESIGN
- Command/WeaponSkill/WideVolley.lua: ID 27230, ARC Lv50, TP 2000, recast 80 s, AoE 8, low accuracy col96 -0.2 — [CL; CLT]; damage linear in weapon DPS, ~0 intercept — [TEST BG #387]; combo accuracy — [CLT]; +10 net (legacy 40) — DESIGN
