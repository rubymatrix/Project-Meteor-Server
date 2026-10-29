-- Dodos are skittish: they bolt when hurt and come back once healed.
return Profile.extend("ai/kinds/battlenpc") {
    behaviors = {
        Flee = { at = 25, distance = 20, recover = "hp", recoverHp = 50 },
    },
}
