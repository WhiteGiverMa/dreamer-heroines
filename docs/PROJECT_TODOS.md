# Project TODOs

## Known legacy issues (pending)

- [ ] `tests/unit/test_boot_sequence.gd::test_total_systems_calculated`
  - Symptom: expected total systems is 7, current initialization path is 9.
  - Goal: align BootSequence test expectations with the current registered systems list.

- [ ] `tests/integration/test_player_weapon_init.gd::test_current_weapon_is_rifle`
  - Symptom: expected `"Rifle"`, actual is `"rifle_basic"`.
  - Goal: unify weapon naming contract between runtime weapon id and integration test expectation.

- [ ] `tests/unit/test_enemy_indicator.gd::test_state_transition`
  - Symptom: null tree access/unexpected errors when boot sequence runs in unit test context.
  - Goal: isolate boot dependencies in this test (or provide proper scene tree harness) to make transitions deterministic.

- [ ] `src/weapons/shotgun_weapon.gd` parse errors
  - Symptom: `pellet_count` type inference fails, `faction_type` identifier is undeclared.
  - Goal: restore script compileability and make `test_shotgun_scene_loads` pass.

- [ ] `tests/unit/test_rifle_weapon.gd` legacy architecture assertions drifted
  - Symptom: assertions about deleting `WeaponBase` / old `rifle.gd` / old `shotgun.gd` mismatch current architecture.
  - Goal: update tests to current weapon architecture or add compatibility layer to remove drift.

- [ ] `WeaponStats` schema mismatch (`test_rifle_weapon.gd` + `test_weapon_stats_resources.gd`)
  - Symptom: `pellet_count` / `pellet_spread` missing causes both unit suites to fail.
  - Goal: unify WeaponStats resource schema and test contract (definition or assertions) so both suites share one consistent model.

## Pause system targeted regression checklist

- [ ] During pause, player/enemy/projectile must remain frozen (stable positions and counts)
- [ ] After resume, gameplay flow and input contexts are restored correctly
- [ ] Triggering restart while paused must not deadlock or misalign game state
- [ ] Quitting to main menu while paused must clear combat residue (active projectile pool objects)
