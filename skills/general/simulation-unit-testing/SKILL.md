---
name: simulation-unit-testing
description: Sets up and writes simulation-backed unit tests for subsystem logic — WPILib sim classes, a custom hand-rolled harness, or (for FTC, where first-class sim support is limited) a hardware-abstraction/mock fallback — with no physical robot required. Use when asked to "write a sim-backed unit test", "set up simulation testing", "test this subsystem without hardware", or "add unit tests for this mechanism".
license: MIT
---

# Simulation Unit Testing

You write and extend **unit tests for subsystem logic** that run against the repo's
simulation support — WPILib sim classes, a custom hand-rolled sim harness, or (for FTC,
being honest about what's actually available) a hardware-abstraction/mock fallback — so the
tests run with no physical robot needed. If the repo has no test scaffolding yet, you set
it up first, following the language/build tool's own native testing convention.

This is not a hardware configurator: it never edits real hardware I/O code, only adds or
extends the sim-mode path around it. It doesn't generate paths, trajectories, or autonomous
sequences — it tests the logic that consumes them. It doesn't review a diff for defects —
a gap it flags here is its own output, not a PR-review finding to duplicate elsewhere.

---

## Rules that outrank everything else

1. **Never assume a sim framework.** Detect what's actually present (Step 1) before writing
   a single test. Don't default to WPILib sim classes because they're common, and don't
   invent FTC sim APIs that may not exist in the declared SDK version.
2. **Match the detected framework's own API and conventions exactly.** WPILib `SimHooks`
   and `*Sim` classes, JUnit + the build tool's own test source set, pytest, or the repo's
   existing hand-rolled harness — use what's actually there. Never invent a method, class,
   or test runner that doesn't exist in the detected tooling.
3. **Touch only the narrow thing this skill owns.** Test files and sim-mode hardware I/O
   paths — never the real (non-sim) hardware I/O code, and never adjacent subsystem logic
   unrelated to what's being tested.
4. **Cite every gap or finding concretely.** A flag names the exact untested path or missing
   seam and its `file:line` — never a vague "should add more tests here."
5. **Never push.** Commit locally and print the push command. The human pushes.
6. **Re-run every time, from scratch.** Each new request starts a fresh Step 1–5 pass against
   the *current* state of the repo — no assumed memory of a prior testing pass.

---

## Step 1 — Detect existing simulation and test tooling

Don't assume one. Search for what's actually present:

```bash
# WPILib sim support
grep -rl "SimHooks\|DCMotorSim\|FlywheelSim\|ElevatorSim\|SingleJointedArmSim\|edu.wpi.first.wpilibj.simulation" \
  --include=*.java --include=*.kt . 2>/dev/null

# Existing test source dir + build wiring (recurse — FTC's real wiring lives in a
# module subdir like TeamCode/build.gradle, not just the root file)
find . -type d -iname test -path "*src*"
find . -name "build.gradle" -o -name "build.gradle.kts" | xargs grep -l "junit\|testImplementation\|useJUnitPlatform" 2>/dev/null

# Python
find . -iname "pytest.ini" -o -iname "conftest.py"
grep -l "pytest" requirements*.txt pyproject.toml setup.cfg 2>/dev/null

# FTC project fingerprint — is this an Android/Gradle FTC repo at all (vs WPILib)?
grep -rl "com.qualcomm.robotcore\|org.firstinspires.ftc\|com.android.application" \
  --include=build.gradle --include=build.gradle.kts . 2>/dev/null

# FTC — check for sim hooks or a mock/abstraction seam; don't assume one exists
grep -rl "SimulatedOpMode\|Mockito\|HardwareMap.*mock" --include=*.java . 2>/dev/null

# A repo-local hand-rolled harness
find . -iname "*simharness*" -o -iname "*mockhardware*" -o -iname "*hardwarestub*"
```

Record, per repo, what's found and what's genuinely absent — an honest "no FTC sim support
detected" is a valid result, not a failure to search harder.

---

## Step 2 — Parse the request

Identify:

- Which subsystem(s) or class(es) need tests.
- Whether this is "write tests for X," "set up sim testing scaffolding," or both.
- Any explicitly named behavior to cover (a state transition, a setpoint calculation, an
  edge case).

Don't infer an unstated target subsystem — ask, or flag the ambiguity and make the most
conservative call (narrowest identifiable unit) rather than guessing broadly.

---

## Step 3 — Set up scaffolding if missing

If no test source dir or build config exists, add it using the build tool's own native
convention — never a custom test runner:

- **Java/WPILib:** `src/test/java`, JUnit 5, wired into the existing Gradle `test` task.
- **Python:** `tests/` + pytest, following whatever the repo's `pyproject.toml`/
  `requirements.txt` already implies.
- **FTC (Android Gradle, e.g. a `TeamCode` module):** `src/test/java`, JUnit 5, wired via
  `testOptions.unitTests.all { useJUnitPlatform() }` in the module's own `build.gradle` —
  never the shared `build.common.gradle`/`build.dependencies.gradle` files the FTC SDK
  itself calls "extraordinarily rare to edit":

  ```groovy
  android {
      testOptions {
          unitTests.all {
              useJUnitPlatform()
          }
      }
  }

  dependencies {
      testImplementation 'org.junit.jupiter:junit-jupiter:<latest 5.x — match repo/CI pin if one exists>'
      testRuntimeOnly 'org.junit.platform:junit-platform-launcher'
  }
  ```

  This runs on stock Android Gradle Plugin with no third-party JUnit5 plugin, as long as
  tests stay plain-JVM (mock/abstraction seam, not Robolectric or real Android framework
  calls — exactly what this skill already does for FTC below).

If the subsystem under test talks to hardware directly with no sim-mode path to exercise
it, add the minimal seam needed:

- **WPILib:** wire the relevant `*Sim` class and `SimHooks` stepping so the subsystem can
  be driven in simulation.
- **FTC, with no first-class sim support:** add a thin hardware-abstraction interface (or
  swap in a mock) around the device calls, scoped to what the test needs — not a rewrite of
  the subsystem's hardware layer.

Never touch the real, non-test, non-sim hardware I/O code paths in either case.

---

## Step 4 — Write or extend the unit tests

Author tests against the detected framework's real API:

- WPILib: drive the `*Sim` class, step time via `SimHooks`, assert on the subsystem's
  observable state/output — not on the vendor device's own internal behavior (that's
  `vendor-hardware-integration`'s concern, not this skill's).
- JUnit/pytest: standard assertions against the subsystem's public behavior.
- FTC mock/abstraction: assert against the subsystem logic driven through the mock, not
  against SDK internals that aren't actually simulated.

Cover what Step 2 identified: state transitions, setpoint/output logic, and named edge
cases. Leave untouched any code path outside the target subsystem.

---

## Step 5 — Commit

If Step 3 or Step 4 added or edited anything, stage and commit it before reporting — a push
command for uncommitted work is useless:

```bash
git add -- <files touched in Step 3/4>
git commit -m "test(<subsystem-name>): add sim-backed unit tests"
```

If nothing was written (no sim seam reachable, nothing to scaffold), skip this step.

---

## Step 6 — Flag gaps and report

Flag anything left untestable, concretely:

- Subsystem logic with no sim-mode path reachable for testing.
- An FTC target with no sim/mock seam at all — say so plainly rather than papering over it
  with a fabricated API.
- A build config still missing test wiring after Step 3.

Then report, short and structured:

- **Tooling detected:** framework/build tool, one line.
- **Scaffolding added:** `file:line`/path — what was set up, if anything.
- **Tests written/extended:** `file:line` — what's covered.
- **Flagged — gaps:** `file:line` + exact issue, one line each.
- `git push origin <branch>` — the command the human runs, not something you run yourself.

---

## Running unattended

- **"Never push" stays the default, even unattended.** Commit locally and report the push
  command — don't push just because nobody's there to say not to. A calling system prompt
  may grant a different behavior explicitly for that environment; that's an override, not
  something to assume.
- **Ambiguity becomes decide-and-record, not stall-and-wait.** An unclear target subsystem
  or a target with no reachable sim/mock seam — make the most conservative call (test the
  narrowest identifiable unit; skip what's genuinely unreachable), flag it plainly in the
  report, and move on instead of guessing or blocking the run.

---

## Scope boundary

**Not `vendor-hardware-integration`.** That skill configures the real vendor device object
itself (CAN IDs, current limits, feedback sensor wiring). This skill never touches that
configuration — it only adds or extends the sim-mode path and test files around an
already-configured device.

**Not `pathing-trajectory-codegen` or `autonomous-routine-scaffolding`.** Those skills
produce path/trajectory files and autonomous step sequences. This skill never generates
either — it tests the subsystem logic that consumes their output.

**Not `pr-code-review` / `frc-code-review` / `ftc-code-reviewer`.** A gap flagged here
(a missing sim seam, an untested path) is this skill's own output, not a fresh finding for
those review skills to repeat on the next PR.
