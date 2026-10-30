# QuestDirectorMan20601: Moonspore Grove stealth run (Together We Stand)

Script: [`Data/scripts/Director/Quest/QuestDirectorMan20601.lua`](../../../../scripts/Director/Quest/QuestDirectorMan20601.lua)

Together We Stand (Man206 SEQ_020/025): the stealth run through Moonspore Grove (content
SimpleContentMan20601, zone 151). The fight is
[`Content/Quest/QuestDirectorMan20601.lua`](../../../../scripts/Content/Quest/QuestDirectorMan20601.lua);
the director plays the quest's part:

- Cover: a sylph's talk (`CNTR_CONCEAL`), the grove scene and the pickup each move the fight to
  `cover`.
- The sentries' lines as they spot the player and close in. The companion's opening line after
  `OPENING_LINE_SECONDS`, and its one warning when a sentry is near.
- Hand-overs on approach (`HANDOFF_RANGE`): the grove's mouth plays processEvent016, Dokixia the
  pickup (after the scene), Flaxio the delivery (carrying), which wins the run. Their talks do the
  same.
- A lost run (time up, the companion left behind) returns the step to 15 at the camp.
