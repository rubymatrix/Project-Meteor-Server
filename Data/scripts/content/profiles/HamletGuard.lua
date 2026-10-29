-- Hamlet militia (client class HamletGuard): hold a post, fight anything hostile that comes close,
-- never follow or wander.
return Profile.extend("ai/kinds/ally") {
    behaviors = {
        Follow = false,
        Assist = { group = "guards", range = 20 },
        Guard = { radius = 14, pace = "run" },
        Combat = {},
    },
    rules = {
        { tier = 1, use = 27190, on = "target", when = "self:tp() >= 1000" },   -- heavy swing
    },
}
