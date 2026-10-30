# Man2g0: Beckon of the Elementals

Script: [`Data/scripts/Quest/Man/Man2g0.lua`](../../../../scripts/Quest/Man/Man2g0.lua)

Beckon of the Elementals (Man2g0, 110008). Prereq: Whispers in the Wood (Man1g0, 110007); level 13.

```text
Seq 65535: offered by Miounne.
Seq 0:  Nonolato at the Quiver's Hold: processEvent007 (man1g900, after warp) into the Hold echo, 206 PA 13.
Seq 3/4: O-App-Pesi asks (processEvent007_2 the first time, 007_2_2 on a retry; 1 = set forth) and the
        duty starts (QuestDirectorMan2g001, content SimpleContentMan2g001, the West Shroud). Nonolato
        (processEvent007_3) puts a player who left back into the echo. In the duty O-App-Pesi hands out
        the ward (processEventTrial001 a3 = 1 the first time, 2 after; returns 1 Wind, 2 Earth, 3 Water).
Seq 5:  Won: processEvent010 (after warp), back to the Hold; A'naidjaa (processEvent020); Miounne calls.
Seq 15/20/25: Soileine (processEvent030, after warp) into the Fane echo, 206 PA 10; the guild push
        (processEvent040, after warp) into PA 11; Fye (processEvent045), then O-App-Pesi
        (processEvent050, after warp) back out; Miounne calls.
Seq 35/40/45: The amphitheatre push (processEvent060) into the grand rite, 206 PA 12; Fye
        (processEvent070) into the Echo in the West Shroud, 153 PA 0; the push there (processEvent080, the
        ending) wakes the player at the Roost.
Seq 60: Miounne's turn-in (processEvent080_01, a3 = the player's highest level: 279 at 18 or more, else
        280).

Scene re-entries (Nonolato, Soileine, the amphitheatre push) replay the scene into the echo the current
sequence owns without moving the journal. Miounne restates the objective in person.
```
