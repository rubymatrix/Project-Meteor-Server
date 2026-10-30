# QuestDirectorMan20601: Moonspore Grove stealth run

Script: [`Data/scripts/Content/Quest/QuestDirectorMan20601.lua`](../../../../scripts/Content/Quest/QuestDirectorMan20601.lua)

Together We Stand (Man206 SEQ_020/025), director QuestDirectorMan20601: the stealth run through
Moonspore Grove.
Seven imperial sentries stand at their posts and see by this script, not by their senses: SIGHT_RANGE
in their forward half, CONCEALED_SIGHT under cover. A sentry that sees the player attacks; cover taken
while pursued, or the player LEASH_RANGE from its post, sends it back. Phase "cover" (the quest's
sylph talks, grove scene and pickup) gives CONCEAL_SECONDS of cover. The companion (the area's event
actor) walks behind the player; left COMPANION_FAIL_RANGE behind for COMPANION_FAIL_SECONDS, the run
fails ("companion"). The player keeps 1 HP. Only the quest wins it, with the delivery.
Sentry n is also alone in group "sentry<n>". Counters for the quest's lines: "sighted<n>" and
"halted<n>" each time sentry n spots the player or closes in, "sentryNear" once one is near.
opts.quest: the quest whose lines the fight shows.
