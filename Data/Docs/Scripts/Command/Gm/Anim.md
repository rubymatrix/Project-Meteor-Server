# Anim: animation id notes

Script: [`Data/scripts/Command/Gm/Anim.lua`](../../../../scripts/Command/Gm/Anim.lua)

Animation id layout as worked out by hand. Kept as written.

```text
Categories:
1 MGK: 01         - Magic
2 SYS: 02         - System noises
3 ETC: 03         - ??  - Item sound?
4 LIB: 04         - Posing animations
5-9 ITM: 05-09      - Items
10 KAO: 0A         - KAO = Face emotes?
11-12 GLI1/2/3: 0B/0C - Leve card things
13 CBI: 0D      - Two small Status
14 ABL: 0E      - Cooldown buffs
15 POP: 0F      - Warp Status
16 CFT: 10      - Crafting?
17 BTL: 11      - More Crafting?
18 WSC: 12      - Weapon Skills   Arg1 - Weapon Skill  Arg2 - Player Animation
19 WSS: 13      - Mob animations
20 PIC: 14      - Gathering weapons?
21 LIU: 15      - Player Hand Emotes
22 LIN: 16      - Doesn't exist?
23 LIF: 17      - Doesn't exist?
24 LIL: 18      - Mouth
25 ATK: 19      - Autoattacks

33 = ?
34 = Crash
120 = ???


Notes:
------
CATEGORY
Shift 18 bits right
CMP 0xB

ANIMATION??????
Shift 0xC bits right
AND 0x0FFF

PARTICLE EFFECT
AND 0x0FFF
This number is in the subfolder (wsc, abi, etc)


That 12 is:

CMP 7C
CMP 6f
CMP 70
CMP 71

7C000062
ec000000
00FFFFFF

19: Auto Attack?    
6F: Casting
71: Seems to deal with signaling monster parts
7C: Sheath/Unsheath
7F: Cast failed
```
