---
name: vendor-hardware-integration
description: Detects declared motor controller/sensor vendor libraries (CTRE, REV, Studica, etc. via vendordeps/build.gradle) and wires up correct configuration/initialization code for them, flagging common per-vendor pitfalls like missing current limits, wrong CAN bus, or an unconfigured feedback sensor. Use when asked to "wire up this motor controller", "add REV/CTRE config", "configure this sensor", or to check a repo's hardware config for vendor pitfalls.
license: MIT
---

# Vendor / Hardware Library Integration

You detect which **motor controller/sensor vendor libraries** a repo has declared as
dependencies and wire up their **configuration/initialization code** correctly, flagging common
per-vendor pitfalls along the way.

This is not a subsystem author. It configures the vendor object — the motor controller or sensor
instance itself — correctly against that vendor's own API. It doesn't design the subsystem
around it; that's the platform-specific "code authoring & debugging" skill's job.

---

## Rules that outrank everything else

1. **Never assume a vendor.** Detect it from declared dependencies (Step 1) before writing
   anything. Don't guess CTRE vs. REV vs. anything else because it's common.
2. **Match the vendor library's own API exactly.** Config method names, constructor/factory
   signatures, current-limit calls, CAN ID/bus conventions — use what that library's declared
   version actually exposes. Never invent a method that doesn't exist in the library.
3. **Config/initialization only.** Touch only the construction and configuration of the vendor
   object itself. Never edit the surrounding subsystem logic that uses it once configured.
4. **Cite every pitfall concretely.** A flag names the exact missing/wrong config and its
   `file:line` — never a vague "should check this."
5. **Reuse the repo's existing constants convention** for values like CAN IDs and current
   limits. Don't introduce a new magic number where the repo already has a constants file.
6. **Never push.** Commit locally and print the push command. The human pushes.
7. **Re-run every time, from scratch.** Each new request starts a fresh Step 1–5 pass against
   the *current* state of the repo — no assumed memory of a prior wiring pass.

---

## Step 1 — Detect declared vendor dependencies

Don't assume one. Search dependency manifests for known vendor artifacts:

```bash
find . -path "*/vendordeps/*.json"
grep -ril "ctre\|phoenix\|revrobotics\|rev-robotics\|sparkmax\|navx\|studica" \
  build.gradle build.gradle.kts pom.xml vendordeps/*.json 2>/dev/null
```

Match what's found to a vendor: CTRE (Phoenix 5/Phoenix 6 — `TalonFX`, `TalonSRX`, `CANcoder`),
REV (REVLib — `SparkMax`, `SparkFlex`, `SparkMaxConfig`), Studica (NavX), or another declared
vendor library. Record the exact library **and major version**, since config APIs differ between
versions (e.g. Phoenix 5 vs. Phoenix 6, REVLib's pre- and post-config-object APIs).

**If nothing recognized is found**, say so in the report and ask which vendor/library to target
rather than guessing.

---

## Step 2 — Parse the request

Identify exactly which device(s) need wiring:

- A specific named motor controller or sensor instance.
- "Every declared-vendor device" for a blanket pass.
- Any explicitly stated config (CAN ID, current limit, feedback sensor type, idle mode).

Don't infer an unstated device identity or CAN ID — ask or flag instead of guessing.

---

## Step 3 — Wire up configuration/initialization

Using the detected vendor library's real, version-correct API:

- Construct the device object and apply its configuration calls (current limits, idle/neutral
  mode, feedback sensor source, CAN bus) following that library's actual method set for the
  detected version.
- Pull CAN IDs, current limits, and similar values from the repo's existing constants file if
  one exists, following its own naming/units convention — don't hardcode a new magic number
  next to an established constants pattern.
- Leave the subsystem logic that calls this device afterward untouched.

---

## Step 4 — Flag per-vendor pitfalls

Check the device(s) touched (or, on a blanket pass, every declared-vendor device found) against
known pitfall classes, citing `file:line` and the exact issue for each:

- Missing or zero current limit.
- Ambiguous or conflicting CAN bus assignment (two devices on different buses sharing an ID,
  or a bus name that doesn't match the rest of the repo's convention).
- A feedback sensor a control mode requires but that isn't configured.
- A motor-safety/watchdog default left at the library's factory default when the rest of the
  repo's devices explicitly set it.

Gate every flag with the concrete-scenario test: can you name the exact missing/wrong config and
where it is? If not, it's not a finding.

---

## Step 5 — Report

Short, structured:

- **Vendors/libraries detected:** name + version, one line each.
- **Wired/configured:** `file:line` — device, what was set.
- **Flagged — pitfalls:** `file:line` + exact pitfall, one line each.
- `git push origin <branch>` — the command the human runs, not something you run yourself.

---

## Running unattended

A team can wire this skill into an autonomous agent the same way `docs-update` and
`frc-code-review` run from CI instead of a human typing the slash command. Two things follow from
"nobody is there to answer":

- **"Never push" stays the default, even unattended.** Commit locally and report the push
  command — don't push just because nobody's there to say not to. A calling system prompt may
  grant a different behavior explicitly for that environment; that's an override, not something
  to assume.
- **Ambiguity becomes decide-and-record, not stall-and-wait.** An unrecognized vendor or unclear
  device identity — skip wiring that device, flag it plainly in the report, and move on instead
  of guessing a CAN ID or vendor and blocking the run.

---

## Scope boundary

**Not a subsystem author.** The FRC/FTC "code authoring & debugging" skills design the
subsystem around the hardware. This skill only configures the vendor object itself correctly.

**Not `pathing-trajectory-codegen` or `autonomous-routine-scaffolding`.** Adjacent skills
producing different artifacts — this one never touches path/trajectory files or autonomous
step sequences.

**Not a PR review.** A flagged pitfall here is expected output, not a fresh finding for
`pr-code-review` / `frc-code-review` / `ftc-code-reviewer` to repeat on the next PR.
