# ElevatorStandard: Limsa and Ul'dah lifts

Script: [`Data/scripts/Chara/Npc/Object/ElevatorStandard.lua`](../../../../../scripts/Chara/Npc/Object/ElevatorStandard.lua)

Each lift entrance has its own client event per floor. Its one argument either shows the ask
dialog (0) or plays the cutscene for the floor the player picked.

Client functions:

- `elevatorAskLimsa001(eventNum)` .. `elevatorAskLimsa003(eventNum)`: ask dialog and cutscenes for
  the Crow's Head Lift, levels 1 to 3.
- `elevatorAskUldah001(eventNum)` .. `elevatorAskUldah003(eventNum)`: the same for the Wellhead
  Lift.
- `elevatorQuestAskEvent(questId)`: quest-specific lift dialog.
