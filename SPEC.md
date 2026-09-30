This repository is a skills marketplace compatible with any coding harness. The main problem it is trying to solve is to scope things related to writing and maintaining **robot codebases** for FIRST Robotics Competition (FRC) and FIRST Tech Challenge (FTC). Skills here are scoped strictly to code — not scouting, awards, outreach, budgeting, or other non-code team activities. Skills should stay library-agnostic where possible, working with whatever framework/library a given team's repo already uses rather than assuming a specific one.

This is a list of skills to be created individually, and the repo structure:

- General skills (valid for both FTC and FRC codebases):
  - **Game manual → code sync** — map current season's scoring rules/field elements to code constants (field coordinates, scoring values, game piece enums) so code stays in sync with the rules.
  - **Pull request code review** — review a PR diff across clean-code, hardware-safety (current limits, control-loop timing, mechanism soft limits), architecture (constants vs. magic numbers, coupling, layering), and CI/infra (workflows, build scripts, deploy configs) axes; produce a severity-tagged report suitable for posting as an automated PR comment. SCAFFOLD FROM OFFSEASON_2026
  - **Autonomous routine scaffolding** — generate/scaffold autonomous code structure (step/action sequences) from a described routine.
  - **Pathing/trajectory code generation** — write/tune path-following or trajectory-generation code and its accompanying deploy-time config/field files, against whatever pathing library the repo already has, without assuming one.
  - **Vendor/hardware library integration** — detect and wire up whatever motor controller/sensor vendor libraries a repo declares as dependencies (config, initialization, common pitfalls).
  - **Telemetry & dashboard wiring** — add/standardize telemetry, logging, and dashboard bindings for live-tunable values and debug output, against whatever dashboard tooling the repo uses.
  - **Simulation & unit testing** — set up/write simulation-backed unit tests for subsystems, no physical robot needed.
  - **Log diagnostics** — parse robot/driver-station logs and error output to diagnose hardware/config mismatches and connectivity issues.
  - **Code-to-docs sync** — keep a developer-docs folder in sync with the actual code by diffing against the last documented commit and regenerating only the pages the change touches. *(exists on `OffSeason_2026` as the `docs-update` skill — scaffold from there.)*

- FTC skills:
  - **Season game constants** — carries the current FTC season's scoring/field-element values as code-ready constants.
  - **FTC code authoring & debugging** — write/debug code against the FTC SDK's op-mode-based programming model and hardware-map conventions.
  - **FTC code reviewer** — review a PR diff for this codebase across clean-code, FTC-specific hardware-safety standards (op-mode structure, hardware-map usage, motor/servo power limits, telemetry), architecture, and CI/infra axes; produce a severity-tagged report suitable for posting as an automated PR comment.

- FRC skills:
  - **Season game constants** — carries the current FRC season's scoring/field-element values as code-ready constants.
  - **FRC code authoring & debugging** — write/debug code against the FRC command-based programming model and roboRIO deployment conventions.
  - **FRC code reviewer** — review a PR diff for this codebase across clean-code, FRC-specific hardware-safety standards (command-based patterns, motor current limits, 20 ms loop timing, CAN IDs, swerve/path deploy JSON), architecture, and CI/infra axes; produce a severity-tagged report suitable for posting as an automated PR comment. *(exists on `OffSeason_2026` as the `frc-code-review` skill — scaffold from there.)*
