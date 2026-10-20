CommandType = 
{
    None = 0,
    AutoAttack = 1,
    Weaponskill = 2,
    Ability = 3,
    Spell = 4
}

ActionType =
{
    None = 0,
    Physical = 1,
    Magic = 2,
    Heal = 3,
    Status = 4
}

ActionProperty = 
{
    None = 0,
    Physical = 1,
    Magic = 2,
    Heal = 4,
    Status = 8,
    Ranged = 16
}

DamageTakenType =
{
    None,
    Attack,
    Magic,
    Weaponskill,
    Ability
}

HitDirection =
{
    None = 0,
    Front = 1,
    Right = 2,
    Rear = 4,
    Left = 8
}

HitType =
{
    Miss = 0,
    Evade = 1,
    Parry = 2,
    Block = 3,
    Resist = 4,
    Hit = 5,
    Crit = 6
}

TargetFindAOEType =
{
    None = 0,
    Circle = 1,
    Cone = 2,
    Box = 3
}

StatusEffectFlags =
{
    None = 0,

    --Loss flags - Do we need loseonattacking/caststart? Could just be done with activate flags
    LoseOnDeath =                   0x1,     -- effects removed on death
    LoseOnZoning =                  0x2,     -- effects removed on zoning
    LoseOnEsuna =                   0x4,     -- effects which can be removed with esuna (debuffs)
    LoseOnDispel =                  0x8,     -- some buffs which player might be able to dispel from mob
    LoseOnLogout =                  0x10,     -- effects removed on logging out
    LoseOnAttacking =               0x20,     -- effects removed when owner attacks another entity
    LoseOnCastStart =               0x40,     -- effects removed when owner starts casting
    LoseOnAggro =                   0x80,     -- effects removed when owner gains enmity (swiftsong)
    LoseOnClassChange =             0x100,     --Effect falls off whhen changing class

    --Activate flags
    ActivateOnCastStart =           0x200,     --Activates when a cast starts.
    ActivateOnCommandStart =        0x400,    --Activates when a command is used, before iterating over targets. Used for things like power surge, excruciate.
    ActivateOnCommandFinish =       0x800,    --Activates when the command is finished, after all targets have been iterated over. Used for things like Excruciate and Resonance falling off.
    ActivateOnPreactionTarget =     0x1000,    --Activates after initial rates are calculated for an action against owner
    ActivateOnPreactionCaster =     0x2000,    --Activates after initial rates are calculated for an action by owner
    ActivateOnDamageTaken =         0x4000,
    ActivateOnHealed =              0x8000,

    --Should these be rolled into DamageTaken?
    ActivateOnMiss =                0x10000,    --Activates when owner misses
    ActivateOnEvade =               0x20000,    --Activates when owner evades
    ActivateOnParry =               0x40000,    --Activates when owner parries
    ActivateOnBlock =               0x80000,    --Activates when owner evades
    ActivateOnHit =                 0x100000,    --Activates when owner hits
    ActivateOnCrit =                0x200000,    --Activates when owner crits

    --Prevent flags. Sleep/stun/petrify/etc combine these
    PreventSpell =                  0x400000,    -- effects which prevent using spells, such as silence
    PreventWeaponSkill =            0x800000,    -- effects which prevent using weaponskills, such as pacification
    PreventAbility =                0x1000000,    -- effects which prevent using abilities, such as amnesia
    PreventAttack =                 0x2000000,    -- effects which prevent basic attacks
    PreventMovement =               0x4000000,    -- effects which prevent movement such as bind, still allows turning in place
    PreventTurn =                   0x8000000,    -- effects which prevent turning, such as stun
    PreventUntarget =               0x10000000,    -- effects which prevent changing targets, such as fixation
    Stance =                        0x20000000     -- effects that do not have a timer
}