# Dftfst: Small Talk (Black Shroud)

Script: [`Data/scripts/Quest/Dft/Dftfst.lua`](../../../../scripts/Quest/Dft/Dftfst.lua)

Small Talk (DftFst, 110542): the default lines for talkable NPCs in the Forest Region (Black Shroud).
The quest is active for all players at all times.

## Client functions not mapped yet

```
defaultTalkWithAstrelle_001     -- "Astrelle" actor/name exists (1000736), but function calls blank dialog. Unused?  Perhaps Quest-only actor?
defQuest1g0_Bush                -- Empty function, unused? Perhaps Quest-only actor?
defQuest1g1_Bush                -- Empty function, unused? Perhaps Quest-only actor?

defaultTalkWithYonariumnari_001 -- "Yonari Umnari" actor/name exists (1000838), but cannot find existence of the npc or dialog on the internet.
defaultTalkWithMoogle010_001    -- No idea what moogles these are tied to.
defaultTalkWithMoogle002_001

defaultTalkCaravanChocoboGri_001
defaultTalkWithInn_ExitDoor
defaultTalkWithExit01
defaultTalkWithMarketNpc
defaultTalkWithHamletGuardGri_001
```

## Ronan Kognan (1001642)

The script plays `defaultTalkWithRonanKognan_001`, likely the line when the player holds no
deaspected crystals. Not wired:

```
defaultTalkWithRonanKognan_002(bool1, bool2) -- Called if any deaspected crystals on player? bool1=Has enough deaspected for buying helmet bool2=already has helmet dialog
defaultTalkWithRonanKognan_Hint_00  -- Lore dialog likely called in order as you make transactions with the npc?
defaultTalkWithRonanKognan_Hint_01
defaultTalkWithRonanKognan_Hint_02
defaultTalkWithRonanKognan_Hint_03
defaultTalkWithRonanKognan_Hint_04
```
