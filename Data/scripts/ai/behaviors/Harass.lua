-- A Lua behavior: a skirmisher that backs off whenever its target closes in, then returns to range.
local Harass = Behavior.define("Harass", { priority = 450, wants = { "Move" } })

function Harass:think(granted)
    local me = self.actor
    local t = me:target()
    local keep = self.params.keep or 6
    if not t or me:distance(t) >= keep then return {} end
    if granted.Move then me:moveTo(awayPoint(me, t, keep + 4), "run") end
    return { "Move" }
end

return Harass
