# WeaponSkill: damage formula notes

Script: [`Data/scripts/WeaponSkill.lua`](../../scripts/WeaponSkill.lua). `calculateDamage` returns a
flat 100; these notes were gathered for a real formula.

Dragoon numbers against level 52 Halberdiers
([STR/PIE/ATK testing](http://forum.square-enix.com/ffxiv/threads/36412-STR-PIE-ATK-Testing/page2)):

- 0.8 damage per STR, capped at 350.
- 0.67-0.69 damage per PIE, hard cap at 310.
- 0.35-0.37 damage per ATK, for both auto-attacks and weapon skills.

These may be out of date. Later sources:
[a DD base damage study](http://prestigexiv.guildwork.com/forum/threads/4fecdc94205cb248b5000526-dragoon-and-other-dd-dpsbase-damage-study?page=1#4fecdc94205cb248b5000525)
and [DPS testing, 2012-10-09](http://forum.square-enix.com/ffxiv/threads/55291-DPS-Testing/page4):
1 point of the primary stat gives 0.8 damage; ATK gives 0.1% or 0.38 damage (unclear).

A possible melee formula (how the weapon caps are worked out is unknown):

```lua
local strCap = CalculateCapOfWeapon(caster.getweapon)
local secondaryCap = CalculateSecondaryCapOfWeapon(caster.getweapon)
local cappedStr = math.min(caster.GetMod(Modifier.Strength), strCap)
local cappedSec = math.min(caster.GetMod(caster.secondaryStat), secCap)
local damageBase = skill.basePotency + (0.85 * cappedStr) + (0.65 * cappedSec)

-- The maximum deviation for weapon skills is about 8%.
local dev = 0.96 + (math.random() * 8)
damageBase = math.Clamp(damageBase * dev, 1, 9999)
return damageBase
```
