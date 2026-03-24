# Project TODOs

## Known legacy issues (pending)

- [ ] `tests/unit/test_boot_sequence.gd::test_total_systems_calculated`
  - Symptom: expected total systems is 7, current initialization path is 9.
  - Goal: align BootSequence test expectations with the current registered systems list.

- [ ] `src/weapons/shotgun_weapon.gd` parse errors
  - Symptom: `pellet_count` type inference fails, `faction_type` identifier is undeclared.
  - Goal: restore script compileability and make `test_shotgun_scene_loads` pass.

- [ ] `tests/unit/test_rifle_weapon.gd` legacy architecture assertions drifted
  - Symptom: assertions about deleting `WeaponBase` / old `rifle.gd` / old `shotgun.gd` mismatch current architecture.
  - Goal: update tests to current weapon architecture or add compatibility layer to remove drift.

- [ ] `tests/unit/test_weapon_stats_resources.gd` field mismatch
  - Symptom: `WeaponStats` access to `pellet_count` / `pellet_spread` reports missing properties.
  - Goal: unify `WeaponStats` resource schema and test contract (resource definition and/or test expectations).

- [ ] `tests/unit/test_rifle_weapon.gd` weapon config field assertions fail
  - Symptom: `WeaponStats should have pellet_count/pellet_spread` fails.
  - Goal: restore consistency between config model and test expectations.

## Pause system targeted regression checklist

- [ ] During pause, player/enemy/projectile must remain frozen (stable positions and counts)
- [ ] After resume, gameplay flow and input contexts are restored correctly
- [ ] Triggering restart while paused must not deadlock or misalign game state
- [ ] Quitting to main menu while paused must clear combat residue (active projectile pool objects)
