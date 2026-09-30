---
name: telemetry-dashboard-wiring
description: Detects the dashboard/telemetry tooling already wired into a repo (Shuffleboard, SmartDashboard, AdvantageKit/AdvantageScope, FTC Dashboard, etc.) and adds or standardizes bindings for live-tunable values (PID gains, setpoints) and debug output using that tooling's own conventions. Use when asked to "wire up telemetry", "add a dashboard binding", "expose this PID gain to the dashboard", "log this to AdvantageScope", or to standardize scattered/inconsistent telemetry calls.
license: MIT
---

# Telemetry Dashboard Wiring

You detect which **dashboard/telemetry tooling** a repo already uses — Shuffleboard,
SmartDashboard, AdvantageKit/AdvantageScope, FTC Dashboard, or raw NetworkTables — and add or
standardize **bindings** for live-tunable values (PID gains, setpoints, feedforward constants)
and debug output, following that tooling's own conventions rather than introducing a new one.

This is not a vendor/hardware integration skill. It doesn't construct or configure the motor
controller or sensor object itself — that's `vendor-hardware-integration`'s job. It doesn't
design the subsystem or its control logic either — that's the platform-specific "code authoring"
skill's job. This skill only wires the binding/logging calls that expose values a subsystem
already computes.

---

## Rules that outrank everything else

1. **Never assume a dashboard/telemetry tool.** Detect it from what's actually imported and
   called in the repo (Step 1) before writing anything. Don't default to Shuffleboard or
   SmartDashboard just because they're common in WPILib repos.
2. **Match the detected tool's own API/conventions exactly.** Method names, tab/layout
   structure, key naming, `@Config` annotations, `Logger.recordOutput` call shapes — use what
   that tool's declared version actually exposes. Never invent a method that doesn't exist.
3. **Touch only the binding/logging call, never the value's control logic.** Wire up the
   `SmartDashboard.putNumber(...)` or `Logger.recordOutput(...)` call around a PID gain or
   setpoint; never rewrite the PID math, the state machine, or how the setpoint is computed.
   That's adjacent logic this skill doesn't own.
4. **Cite every flagged gap concretely.** A flag names the exact unbound value or inconsistent
   call and its `file:line` — never a vague "should add telemetry here."
5. **Reuse the repo's existing binding pattern.** Don't introduce a second telemetry idiom
   (a new tab layout, a new key-naming scheme, a new logging wrapper) where the repo already has
   one established. Standardizing means converging on what's already there, not replacing it.
6. **Never push.** Commit locally and print the push command. The human pushes.
7. **Re-run every time, from scratch.** Each new request starts a fresh Step 1–5 pass against
   the *current* state of the repo — no assumed memory of a prior wiring pass.

---

## Step 1 — Detect existing dashboard/telemetry tooling

Don't assume one. Search for known tooling by import and call pattern:

```bash
# Shuffleboard (WPILib)
grep -rl "edu.wpi.first.wpilibj.shuffleboard\|Shuffleboard.getTab" --include='*.java' .

# SmartDashboard (WPILib)
grep -rl "edu.wpi.first.wpilibj.smartdashboard.SmartDashboard\|SmartDashboard\.put" \
  --include='*.java' .

# AdvantageKit / AdvantageScope
grep -rl "org.littletonrobotics.junction\|Logger\.recordOutput\|Logger\.processInputs" \
  --include='*.java' .

# FTC Dashboard
grep -rl "com.acmerobotics.dashboard\|FtcDashboard.getInstance\|@Config" \
  --include='*.java' .

# Raw NetworkTables (no wrapper library)
grep -rl "NetworkTableInstance" --include='*.java' .
```

Match what's found to a tool and record the **exact existing convention**: Shuffleboard tab
names and widget layout, SmartDashboard key prefixes, AdvantageKit's `recordOutput` key
hierarchy, or FTC Dashboard's `@Config` class/field grouping. This convention is what every new
binding must match.

**If nothing recognized is found**, say so in the report and default to the ecosystem norm for
the repo type (WPILib repo → SmartDashboard; FTC repo → FTC Dashboard) rather than stalling —
flag the default plainly so a human can correct it.

---

## Step 2 — Parse the request

Identify exactly what needs wiring:

- A specific named subsystem, class, or value.
- "Every unbound tunable value" for a blanket pass.
- Debug output only, vs. live-tunable values only, vs. both.

Classify each candidate value:

- **Live-tunable**: a hardcoded constant that governs real-time behavior and is a reasonable
  target for runtime adjustment — PID gains (`kP`/`kI`/`kD`/`kF`), setpoints, feedforward
  constants, tolerances.
- **Debug output**: a computed or sensed value useful to observe but not meant to be edited live
  — sensor readings, current state, error terms.

Don't infer an unstated scope. If a value's classification is genuinely unclear, flag it in the
report rather than guessing.

---

## Step 3 — Add or standardize bindings

Using the detected tool's real, convention-matching API:

- For each unbound live-tunable value, add a binding that both reads the current value and lets
  it be set at runtime, using the tool's own idiom for that (e.g. FTC Dashboard's `@Config`
  static field, a Shuffleboard `addPersistent` entry with a change listener, an AdvantageKit
  `LoggedTunableNumber`).
- For each unbound debug value, add a binding for observation only, matching the tool's existing
  output convention (e.g. `Logger.recordOutput("Subsystem/Value", value)` matching the repo's
  existing key hierarchy).
- Where telemetry calls already exist but are inconsistent with the repo's dominant convention
  (a stray `System.out.println`, a one-off key naming scheme, a second dashboard library used in
  only one file), rewrite them to match the dominant convention — this is the "standardizing"
  half of the skill.
- Don't create a new tab, layout, or key grouping that duplicates one already established.
- Leave the value's own computation — the control logic producing it — untouched.

---

## Step 4 — Flag gaps outside this skill's scope

Note, but don't fix, anything outside binding/logging work:

- Control logic that looks wrong while wiring around it (e.g. a PID gain that's clearly unused
  by the controller it's bound from).
- A value whose live-tunable vs. debug-only classification couldn't be confidently made.
- A repo with no detectable dashboard tooling at all, where a human should confirm the assumed
  default from Step 1 before it's relied on.

Gate every flag with the concrete-scenario test: can you name the exact value and its
`file:line`? If not, it's not a finding.

---

## Step 5 — Commit

If Step 3 added or standardized anything, stage and commit it before reporting — a push command
for uncommitted work is useless:

```bash
git add -- <files touched in Step 3>
git commit -m "feat(<subsystem-or-value-name>): wire up telemetry binding"
```

If Step 3 made no edits, skip this step.

---

## Step 6 — Report

Short, structured:

- **Tooling detected:** tool name + version/convention summary, one line.
- **Bindings added:** `file:line` — value, binding call.
- **Bindings standardized:** `file:line` — what it was, what it's now.
- **Flagged — out of scope:** `file:line` + exact issue, one line each.
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
- **Ambiguity becomes decide-and-record, not stall-and-wait.** No detectable tooling, or an
  unclear live-tunable classification — make the most conservative call (default to the
  ecosystem norm, or skip binding that one value), flag it plainly in the report, and move on
  instead of blocking the run.

---

## Scope boundary

**Not `vendor-hardware-integration`.** That skill configures the vendor motor controller or
sensor object itself — construction, current limits, CAN bus, feedback sensor source. This skill
never touches device construction or configuration; it only binds values that already exist to
a dashboard.

**Not `frc-code-authoring` / `ftc-code-authoring`.** Those skills design the subsystem and its
control logic. This skill never edits the logic that computes a value — only the telemetry call
around it.

**Not a PR review.** A missing or inconsistent telemetry binding is this skill's fix target, not
a fresh finding for `pr-code-review` / `frc-code-review` / `ftc-code-reviewer` to repeat on the
next PR — a reviewer should point an author at this skill instead of duplicating the fix as a
review comment.
