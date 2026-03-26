# Project TODOs

## Known legacy issues (pending)

- [x] `tests/unit/test_boot_sequence.gd::test_total_systems_calculated`
  - Symptom: expected total systems is 7, current initialization path is 9.
  - Goal: align BootSequence test expectations with the current registered systems list.
  - Verified: passes via GUT targeted run (`-gselect=test_boot_sequence -gunit_test_name=test_total_systems_calculated`).

- [x] `tests/integration/test_player_weapon_init.gd::test_current_weapon_is_rifle`
  - Symptom: expected `"Rifle"`, actual is `"rifle_basic"`.
  - Goal: unify weapon naming contract between runtime weapon id and integration test expectation.
  - Verified: passes via GUT targeted run (`-gselect=test_player_weapon_init -gunit_test_name=test_current_weapon_is_rifle`).

- [x] `tests/unit/test_enemy_indicator.gd::test_state_transition`
  - Symptom: null tree access/unexpected errors when boot sequence runs in unit test context.
  - Goal: isolate boot dependencies in this test (or provide proper scene tree harness) to make transitions deterministic.
  - Verified: passes via GUT targeted run (`-gselect=test_enemy_indicator -gunit_test_name=test_state_transition`).

- [x] `src/weapons/shotgun_weapon.gd` parse errors
  - Symptom: `pellet_count` type inference fails, `faction_type` identifier is undeclared.
  - Goal: restore script compileability and make `test_shotgun_scene_loads` pass.
  - Verified: `tests/unit/test_rifle_weapon.gd::test_shotgun_scene_loads` passes in targeted GUT run.

- [x] `tests/unit/test_rifle_weapon.gd` legacy architecture assertions drifted
  - Symptom: assertions about deleting `WeaponBase` / old `rifle.gd` / old `shotgun.gd` mismatch current architecture.
  - Goal: update tests to current weapon architecture or add compatibility layer to remove drift.
  - Verified: full suite passes via GUT targeted run (`-gselect=test_rifle_weapon`) with 20/20.

- [x] `WeaponStats` schema mismatch (`test_rifle_weapon.gd` + `test_weapon_stats_resources.gd`)
  - Symptom: `pellet_count` / `pellet_spread` missing causes both unit suites to fail.
  - Goal: unify WeaponStats resource schema and test contract (definition or assertions) so both suites share one consistent model.
  - Verified: `test_rifle_weapon` and `test_weapon_stats_resources` both pass in targeted runs (20/20 + 25/25).

- [ ] GUIDE action resources invalid UID fallback warnings
  - Symptom: `weapon_primary.tres` and `weapon_secondary.tres` trigger "invalid UID, loading by path" warnings when loaded from `scenes/player.tscn` and `config/input/contexts/gameplay_context.tres`.
  - Impact: runtime behavior works via text-path fallback; no functional blocker but logs noise.
  - Goal: normalize UID registration for the new GUIDE action resources so warnings disappear.

## Pause system targeted regression checklist

- [x] During pause, player/enemy/projectile must remain frozen (stable positions and counts)
  - Verified: `tests/unit/test_game_pause_flow.gd::test_pause_freezes_runtime_and_sets_ui_input_mode`.
- [x] After resume, gameplay flow and input contexts are restored correctly
  - Verified: `tests/unit/test_game_pause_flow.gd::test_resume_restores_playing_state_processing_and_input`.
- [x] Triggering restart while paused must not deadlock or misalign game state
  - Verified: `tests/unit/test_game_pause_flow.gd::test_restart_while_paused_unpauses_then_clears_combat_artifacts`.
- [x] Quitting to main menu while paused must clear combat residue (active projectile pool objects)
  - Verified: `tests/unit/test_game_pause_flow.gd::test_quit_to_menu_while_paused_unpauses_and_clears_combat_residue`.
