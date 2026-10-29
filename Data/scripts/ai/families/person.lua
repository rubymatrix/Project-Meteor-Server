-- People: story allies and trusts. Their combat comes from content profiles.
return Profile.extend("ai/kinds/battlenpc") {
    behaviors = { Roam = false, Link = false },
}
