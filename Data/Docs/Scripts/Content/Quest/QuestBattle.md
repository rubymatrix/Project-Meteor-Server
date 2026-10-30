# QuestBattle: quest battles

Script: [`Data/scripts/Content/Quest/QuestBattle.lua`](../../../../scripts/Content/Quest/QuestBattle.lua)

Quest battles: a player against a few foes in a quest content area, sometimes with an ally. Class
quest bouts and the Grand Company and company quest fights. A director's file picks its variant:
return require("Content/Quest/QuestBattle"):as("Gla20001").

Foes stand where they spawn and are sent at the player once they have stood engageDelay seconds; a
foe that drops the fight is sent back. Waves come in order, waveDelay seconds after the last foe of
the previous wave falls. Won when every wave is down, unless winOnClear is false and the quest wins
it. With hpLock the player can't drop below 1 HP, and being pinned there is the loss, so a retry
needs no Return. KO'd participants get up on a win.

Variant fields: level, waves = { { { pool, x, y, z, rot, level = n, classPath = s, yield = true,
count = name }, ..., joinAt = n }, ... }, allies (same entries), timeLimit, engageDelay, waveDelay,
settle, hpLock, winOnClear, foesOpenOnAlly (foes go for the first ally while it stands), defeat =
{ { displayId, count }, ... } or true, timeNotice. A wave with joinAt comes in once the foes still up
number joinAt or fewer. A yield foe can't drop below 1 HP and counts as down when it gets there. A
count foe adds 1 to that counter when it dies. settle is the pause between the last foe down and the
win.
opts.timeLimit overrides the variant's. opts.reserve is a wave the quest brings in with
GotoPhase("reserve"), which also turns winOnClear on.
