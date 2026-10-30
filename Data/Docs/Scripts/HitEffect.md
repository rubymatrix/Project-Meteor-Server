# HitEffect: hit effect flags

Script: [`Data/scripts/HitEffect.lua`](../../scripts/HitEffect.lua)

A hit effect id is a type in the top byte plus that type's flags. Each type has its own flags;
`HitEffect` keeps them all in one table.

## Types

- `HitEffectType`: physical attacks.
- `AdditionalEffectType`: additional-effect hits. Same as `HitEffectType` but plays no sound.
- `StatusEffectType` (32 << 24): status effects.
- `StatusLossType`: losing a status while using a skill. Stops the hit effect playing on the actor
  playing the animation.
- `MagicEffectType` (48 << 24): magic; also statuses lost on attack.
- `SelfHealType`: puts the number on the user whatever the target, e.g. Bloodbath.
- `AnimationEffectType`: plays the effect animation with no text or extra effects, e.g. Convert.
  Unknown whether it has flags.

## HitEffectType flags

Recoil: the animation on the target, weak to strong. Leaving out `RecoilLv2` and `RecoilLv3` gives
the weak `RecoilLv1`. The level was probably picked from the share of HP the hit took. Heals and
spells show the same effects in reverse: `RecoilLv1` large, Lv3 none, crit very large. For spells
they stand for resists: Lv0 a full resist, Lv3 none; crit still means crit. Heals sometimes use
them too, for no clear reason (maybe a trait proc, maybe a bug). Both recoil flags together give
the "Critical!" pop-up and hit visual.

Hit visuals: the visual and sound on connecting. Combinations give different results; each visual
probably matches a weapon (`HitVisual4` alone looks like hand-to-hand). Probably the attack
property shifted left 2: `HitVisual1` slashing, `HitVisual2` piercing, both blunt, `HitVisual3`
projectile. For auto-attacks the property is the weapon's `damageAttributeType1`. Unclear for
weaponskills, and what `HitVisual4` and the other combinations mean.

`Protect` / `Shell`: an extra visual on the target when a physical attack hits Protect or a magic
one hits Shell (Shell was removed in later versions). Both together play another effect, unknown;
maybe a hybrid attack on a target with both buffs.

Hit effects: `HitEffect1` alone gives "Evade!" and the evade visual. No hit effect at all gives
"Miss!" and no visual.

`SkillCombo1..3`: the effect for chained combos, e.g. Thunder -> Thundara -> Thundaga.
`SkillCombo4` was never used in 1.0: combos chained three times at most.

## AdditionalEffectType flags

Used for the additional effects some weapons have. They don't repeat the attack's effect and show
only after a `HitEffectType` or `MagicEffectType`. `UnknownAdditionalFlag` is set on every hit of a
Black Mage using the Garuda weapon in the Ifrit fight capture, with no visible effect.

## MagicEffectType flags

For magic that deals or heals damage, and damage over time. Crit is the same as for
`HitEffectType`. `MagicShield` plays a purple shield with an animated command; damage over time
carries it too (at least on Ifrit) but has no animation, so nothing shows.

## SelfHealType flags

Numbers appear on the user whatever the target, with no animation. The flags pick the text (HP has
none).
