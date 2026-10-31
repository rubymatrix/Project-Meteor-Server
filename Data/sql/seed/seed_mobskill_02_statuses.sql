-- Statuses for monster moves that apply a status and deal no damage.
-- Only moves whose status has a server_statuseffects row. Chance is 0-1.
-- Rollback: seed_mobskill_02_statuses_rollback.sql
UPDATE server_battle_commands SET statusId = 223011, statusDuration = 20, statusChance = 0.75 WHERE id = 23014; -- rancid_belch: poison
UPDATE server_battle_commands SET statusId = 223011, statusDuration = 20, statusChance = 0.75 WHERE id = 23015; -- rancid_belch: poison
UPDATE server_battle_commands SET statusId = 223011, statusDuration = 20, statusChance = 0.75 WHERE id = 23016; -- rancid_belch: poison
UPDATE server_battle_commands SET statusId = 223007, statusDuration = 30, statusChance = 0.75 WHERE id = 23017; -- fowl_stench: blind
UPDATE server_battle_commands SET statusId = 223007, statusDuration = 30, statusChance = 0.75 WHERE id = 23018; -- fowl_stench: blind
UPDATE server_battle_commands SET statusId = 223007, statusDuration = 30, statusChance = 0.75 WHERE id = 23019; -- fowl_stench: blind
UPDATE server_battle_commands SET statusId = 223011, statusDuration = 20, statusChance = 0.75 WHERE id = 23020; -- regurgitate: poison
UPDATE server_battle_commands SET statusId = 228011, statusDuration = 15, statusChance = 0.75 WHERE id = 23022; -- cold_gaze: bind
UPDATE server_battle_commands SET statusId = 223004, statusDuration = 10, statusChance = 0.75 WHERE id = 23023; -- stone_gaze: petrification
UPDATE server_battle_commands SET statusId = 223002, statusDuration = 30, statusChance = 1 WHERE id = 23036; -- fast_burn: haste
UPDATE server_battle_commands SET statusId = 223002, statusDuration = 30, statusChance = 1 WHERE id = 23062; -- feeding_frenzy: haste
UPDATE server_battle_commands SET statusId = 223007, statusDuration = 30, statusChance = 0.75 WHERE id = 23071; -- furfall: blind
UPDATE server_battle_commands SET statusId = 223004, statusDuration = 10, statusChance = 0.75 WHERE id = 23094; -- level_5_petrify: petrification
UPDATE server_battle_commands SET statusId = 223006, statusDuration = 30, statusChance = 0.75 WHERE id = 23116; -- impish_incantations: silence
UPDATE server_battle_commands SET statusId = 223014, statusDuration = 15, statusChance = 0.75 WHERE id = 23140; -- brain_spike: amnesia
UPDATE server_battle_commands SET statusId = 228001, statusDuration = 20, statusChance = 0.75 WHERE id = 23150; -- desert_respite: sleep
UPDATE server_battle_commands SET statusId = 223015, statusDuration = 4, statusChance = 0.75 WHERE id = 23157; -- bellowing_grunt: stun
UPDATE server_battle_commands SET statusId = 223015, statusDuration = 4, statusChance = 0.75 WHERE id = 23160; -- kinetic_pulse: stun
UPDATE server_battle_commands SET statusId = 223015, statusDuration = 4, statusChance = 0.75 WHERE id = 23161; -- kinetic_pulse: stun
UPDATE server_battle_commands SET statusId = 223015, statusDuration = 4, statusChance = 0.75 WHERE id = 23162; -- kinetic_pulse: stun
UPDATE server_battle_commands SET statusId = 228021, statusDuration = 30, statusChance = 0.75 WHERE id = 23163; -- magnetic_pulse: heavy
UPDATE server_battle_commands SET statusId = 228021, statusDuration = 30, statusChance = 0.75 WHERE id = 23164; -- magnetic_pulse: heavy
UPDATE server_battle_commands SET statusId = 228021, statusDuration = 30, statusChance = 0.75 WHERE id = 23165; -- magnetic_pulse: heavy
UPDATE server_battle_commands SET statusId = 223180, statusDuration = 45, statusChance = 1 WHERE id = 23189; -- lay_of_the_leaves: regen
UPDATE server_battle_commands SET statusId = 228001, statusDuration = 20, statusChance = 0.75 WHERE id = 23190; -- woodland_lullaby: sleep
UPDATE server_battle_commands SET statusId = 223002, statusDuration = 30, statusChance = 1 WHERE id = 23195; -- swift_gust: haste
UPDATE server_battle_commands SET statusId = 223002, statusDuration = 30, statusChance = 1 WHERE id = 23196; -- swift_gale: haste
UPDATE server_battle_commands SET statusId = 228001, statusDuration = 20, statusChance = 0.75 WHERE id = 23208; -- yawn: sleep
UPDATE server_battle_commands SET statusId = 223008, statusDuration = 30, statusChance = 0.75 WHERE id = 23236; -- deafening_caw: mute
UPDATE server_battle_commands SET statusId = 223006, statusDuration = 30, statusChance = 0.75 WHERE id = 23237; -- silencing_caw: silence
UPDATE server_battle_commands SET statusId = 228001, statusDuration = 20, statusChance = 0.75 WHERE id = 23239; -- lullaby: sleep
UPDATE server_battle_commands SET statusId = 223007, statusDuration = 30, statusChance = 0.75 WHERE id = 23259; -- blinding_burst: blind
UPDATE server_battle_commands SET statusId = 228011, statusDuration = 15, statusChance = 0.75 WHERE id = 23263; -- ranine_stare: bind
UPDATE server_battle_commands SET statusId = 223180, statusDuration = 45, statusChance = 1 WHERE id = 23264; -- slimy_secretion: regen
UPDATE server_battle_commands SET statusId = 223005, statusDuration = 15, statusChance = 0.75 WHERE id = 23269; -- ranine_glare: paralysis
UPDATE server_battle_commands SET statusId = 223015, statusDuration = 3, statusChance = 0.75 WHERE id = 23340; -- gillbrations: stun
UPDATE server_battle_commands SET statusId = 223015, statusDuration = 6, statusChance = 0.75 WHERE id = 23341; -- good_gillbrations: stun
UPDATE server_battle_commands SET statusId = 223015, statusDuration = 4, statusChance = 1 WHERE id = 23345; -- stunner: stun
UPDATE server_battle_commands SET statusId = 223133, statusDuration = 30, statusChance = 1 WHERE id = 23357; -- immortal_effigy: stoneskin
UPDATE server_battle_commands SET statusId = 223007, statusDuration = 30, statusChance = 0.75 WHERE id = 23396; -- firedamp: blind
UPDATE server_battle_commands SET statusId = 223014, statusDuration = 15, statusChance = 0.75, mainTarget = 768, validTarget = 17152 WHERE id = 23402; -- mindwipe: amnesia
UPDATE server_battle_commands SET statusId = 223029, statusDuration = 60, statusChance = 1 WHERE id = 23422; -- maximoogle: hp_boost
UPDATE server_battle_commands SET statusId = 228011, statusDuration = 30, statusChance = 0.75, mainTarget = 768, validTarget = 17152 WHERE id = 23446; -- entangle: bind
UPDATE server_battle_commands SET statusId = 223180, statusDuration = 45, statusChance = 1 WHERE id = 23447; -- photosynthesis: regen
UPDATE server_battle_commands SET statusId = 223015, statusDuration = 4, statusChance = 0.75 WHERE id = 23482; -- n100_tonze_swing: stun
UPDATE server_battle_commands SET statusId = 223081, statusDuration = 30, statusChance = 1 WHERE id = 23491; -- bloodbath_mob: bloodbath
UPDATE server_battle_commands SET statusId = 223094, statusDuration = 30, statusChance = 1 WHERE id = 23492; -- invigorate_mob: invigorate
