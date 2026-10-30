# NegotiationCommand: Parley client functions

Script: [`Data/scripts/Command/NegotiationCommand.lua`](../../../scripts/Command/NegotiationCommand.lua)

- `openListWidget(player, originId, 10 bools to show/hide)`: list of things to Parley for, from a sequential list in `xtx_negotiationTable`.
- `openAskWidget(player, title, difficulty, desiredItemId, requiredItemId)`: asks whether the player will Parley.
- `openNegotiationWidget(player, title, itemId, maxTurns, time, ability1, ability2, ability3, ability4, ability5)`: sets up the widget (call first).
- `inputNegotiationWidget(player, ?, abort, resumeTimer)`: starts player input.
- `closeNegotiationWidget(player)`: closes the Parley widget.
- `negotiationEmote(player, animId)`: plays an animation.
- `updateNegotiationWidget(player, gridIndex, key, itemIconId, pointValue, ?, ?)`: updates the UI by the first argument:

| gridIndex | Effect |
|---|---|
| < 12 | Places an item |
| 13 | Plays a sound effect + ? |
| 14 | Sets the negotiation gauge (max, value) |
| 15 | Sets the achievement gauge (max, value) |
| 16-18 | Additional item 1-3 (bool) |
| 19 | Sets the last chosen items (index 1-6, iconId) |
| 20, 21 | ? |
| 22 | Clears the timer |
| 23 | Plays the player move sound |
| 24 | Plays the opponent move sound |
| 25 | Plays the time's up sound and closes the ability widget |
| 26, 27 | ? |
| 28 | Pauses the timer |
| 29 | Resumes the timer |
