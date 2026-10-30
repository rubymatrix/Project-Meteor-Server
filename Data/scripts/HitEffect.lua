--[[
Hit effect ids for action results: a type in the top byte plus that type's flags.
--]]

HitEffect =
{
	--This is used for physical attacks
	HitEffectType = 0x8000000,
	--This is used for additioanl effect hits. Only difference from HitEffectType is that it does not play audio.
	AdditionalEffectType = 0x18000000,
	--Status effects use 32 << 24
	StatusEffectType = 0x20000000,
	--When losing a status effect while using a skill, this prevents the hit effect from playing on the actor playing the animation
	StatusLossType = 0x28000000,
	--Magic effects use 48 << 24, this is also used for when statuses are lost on attack
	MagicEffectType = 0x30000000,
	--This places the number on the user regardless of the target this hit effect is for, used for things like bloodbath
	SelfHealType = 0x48000000,
	--Plays the effect animation with no text or additional effects. Unsure if there are any flags. Used for things like Convert
	AnimationEffectType = 0x60000000,

	-- Each type has its own flags, all kept in this one table. Data/Docs/Scripts/HitEffect.md has
	-- the notes on what each flag shows.

	-- HitEffectType flags. Recoil on the target, weak to strong; neither Lv2 nor Lv3 means Lv1.
	-- For spells the levels are resists (Lv0 full resist, Lv3 none).
	RecoilLv1 = 0,
	RecoilLv2 = 0x1,
	RecoilLv3 = 0x2,

	--Setting both recoil flags triggers the "Critical!" pop-up text and hit visual effect.
	CriticalHit = 3,                        --RecoilLv2 | RecoilLv3

	-- Visual and sound on connecting: probably the attack property shifted left 2. 1 slashing,
	-- 2 piercing, 1 | 2 blunt, 3 projectile, 4 alone hand-to-hand. Auto-attacks use the weapon's
	-- damageAttributeType1.
	HitVisual1 = 0x4,
	HitVisual2 = 0x8,
	HitVisual3 = 0x10,
	HitVisual4 = 0x20,

	-- Extra visual on the target: a physical hit on Protect, a magic hit on Shell. Both together play
	-- an unknown third effect.
	Protect = 0x40,
	Shell = 0x80,
	ProtectShellSpecial = 192,              --Protect | Shell

	--If only HitEffect1 is set out of the hit effects, the "Evade!" pop-up text triggers along with the evade visual.
	--If no hit effects are set, the "Miss!" pop-up is triggered and no hit visual is played.
	HitEffect1 = 0x200,
	HitEffect2 = 0x400,       --Plays the standard hit visual effect, but with no sound if used alone.
	HitEffect3 = 0x800,       --Yellow effect, crit?
	HitEffect4 = 0x1000,       --Plays the blocking animation
	HitEffect5 = 0x2000,
	GustyHitEffect = 3072,                  --HitEffect3 | HitEffect2
	GreenTintedHitEffect = 4608,            --HitEffect4 | HitEffect1

	--For specific animations
	Miss = 0,
	Evade = HitEffect1,
	Hit = 1536,                             --HitEffect1 | HitEffect2,
	Crit = HitEffect3,
	Parry = 3584,                           --Hit | HitEffect3,
	Block = HitEffect4,

	--Knocks you back away from the attacker.
	KnockbackLv1 = 5632,                    --HitEffect4 | HitEffect2 | HitEffect1
	KnockbackLv2 = 6144,                    --HitEffect4 | HitEffect3
	KnockbackLv3 = 6656,                    --HitEffect4 | HitEffect3 | HitEffect1
	KnockbackLv4 = 7168,                    --HitEffect4 | HitEffect3 | HitEffect2
	KnockbackLv5 = 7680,                    --HitEffect4 | HitEffect3 | HitEffect2 | HitEffect1

	--Knocks you away from the attacker in a counter-clockwise direction.
	KnockbackCounterClockwiseLv1 = HitEffect5,
	KnockbackCounterClockwiseLv2 = 8704,    --HitEffect5 | HitEffect1

	--Knocks you away from the attacker in a clockwise direction.
	KnockbackClockwiseLv1 = 9216,           --HitEffect5 | HitEffect2
	KnockbackClockwiseLv2 = 9728,           --HitEffect5 | HitEffect2 | HitEffect1

	--Completely drags target to the attacker, even across large distances.
	DrawIn = 10240,                         --HitEffect5 | HitEffect3

	--An additional visual effect that plays on the target based on according buff.
	UnknownShieldEffect = 12288,            --HitEffect5 | HitEffect4
	Stoneskin = 12800,                      --HitEffect5 | HitEffect4 | HitEffect1

	--A special effect when performing appropriate skill combos in succession.
	--Ex: Thunder (SkillCombo1 Effect) -> Thundara (SkillCombo2 Effect) -> Thundaga (SkillCombo3 Effect)
	--Special Note: SkillCombo4 was never actually used in 1.0 since combos only chained up to 3 times maximum.
	SkillCombo1 = 0x8000,
	SkillCombo2 = 0x10000,
	SkillCombo3 = 98304,                    --SkillCombo1 | SkillCombo2
	SkillCombo4 = 0x20000,

	--This is used in the absorb effect for some reason
	Unknown = 0x80000,

	--AdditionalEffectType flags
	--The AdditionalEffectType is used for the additional effects some weapons have.
	--These effect ids do not repeat the effect of the attack and will not show without a preceding HitEffectType or MagicEffectType

	--It's unclear what this is for. The ifrit fight capture has a BLM using the garuda weapon
	--and this flag is set every time but has no apparent effect.
	UnknownAdditionalFlag = 1,

	--These play effects on the target
	FireEffect = 0x400,
	IceEffect = 0x800,
	WindEffect = 0xC00,
	EarthEffect = 0x1000,
	LightningEffect = 0x1400,
	WaterEffect = 0x1800,
	AstralEffect = 0x1C00,         --Possibly for blind?
	UmbralEffect = 0x2000,         --Posibly for poison?

	StatusEffect1 = 0x3000,
	StatusEffect2 = 0x3400,

	HPAbsorbEffect = 0x3800,
	MPAbsorbEffect = 0x3C00,
	TPAbsorbEffect = 0x4000,
	TripleAbsorbEffect = 0x4400,  --Not sure about this
	MoogleEffect = 0x4800,

	--MagicEffectType Flags
	--THese are used for magic effects that deal or heal damage as well as damage over time effects
	--Crit is the same as HitEffectType
	FullResist = 0,
	WeakResist = 0x1,    --Used for level 1, 2, and 3 resists probably
	NoResist = 0x2,

	MagicShell = 0x10,    --Used when casting on target with shell effects. MagicEffectType doesnt have a flag for protect or stoneskin
	MagicShield = 0x20,   --When used with an command that has an animation, this plays a purple shield effect. DoTs also have this flag set (at least on ifrit) but they have no animations so it doesnt show

	-- Required for heal text to be blue, not sure if that's all it's used for
	Heal = 0x100,
	MP = 0x200,            --Causes "MP" text to appear when used with MagicEffectType. | with Heal to make text blue
	TP = 0x400,           --Causes "TP" text to appear when used with MagicEffectType. | with Heal to make text blue

	--SelfHealType flags
	--This category causes numbers to appear on the user rather regardless of the target associated with the hit effect and do not play an animation
	--These determine the text that displays (HP has no text)
	SelfHealHP = 0,
	SelfHealMP = 0x1,    --Shows MP text on self. | with SelfHeal to make blue
	SelfHealTP = 0x2,    --Shows TP text on self. | with SelfHeal to make blue

	--Causes self healing numbers to be blue
	SelfHeal = 0x400,
}