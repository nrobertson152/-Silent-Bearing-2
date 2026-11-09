# AGENTS.md

Silent Bearing 2 is a Godot 4.7 naval warfare game (GPL-3.0). Everything, including ship
models, textures, sound and the campaign map, is generated in code; the repository holds no binary
assets.

## Roles

- **Director (Nate):** sets direction and priorities.
- **Claude:** solo developer with merge authority. Implements, tests, reviews its own PRs, merges
  when CI is green.

## Rules

- `scripts/sim/` is the simulation. It never touches rendering, so it stays testable headless
  (`tests/run_tests.gd`). The view (`scripts/view/`, `scripts/bridge/`) only reads sim state and events.
- Ship, weapon and aircraft figures in `scripts/data/` follow published data (1988 configurations).
  Comment any value adjusted for play.
- Before merging: `tools/check_scripts.gd` compiles everything, `tests/run_tests.gd` and
  `tests/flow_test.gd` pass, and the battle and mission smoke runs in CI finish without `SCRIPT ERROR`.
- Runtime-only code paths (effects, screens) belong in `tests/flow_test.gd`, because a script error
  there only shows up when the path actually runs.
- Keep the Forward+ look working with the automatic OpenGL fallback in mind: no feature should be
  required only by Vulkan.
