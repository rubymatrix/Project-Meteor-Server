# QuestDuty: quest duty helpers

Script: [`Data/scripts/QuestDuty.lua`](../../scripts/QuestDuty.lua)

Quest-side helpers for the story, company and Grand Company quests that start their own content.

## Flow

1. The quest makes the content copy and zones the player in (`startQuestDuty`).
2. The kicked director runs the fight (`runQuestBattle`: `Content/Quest/QuestBattle.lua` or the
   director's own content) and hands the outcome to the quest's
   `onDutyComplete(player, quest, director, fight, success, reason)`, where `reason` is `"cleared"`,
   `"script"`, `"ko"`, `"time"` or `"left"`.
3. The quest's closing scene ends with `endQuestDuty`.

## startQuestDuty def

- `zone`: parent zone id.
- `area`: content area name.
- `director`: script under `Director/`.
- `anchor = { x, y, z, rot }`: where the player arrives.
