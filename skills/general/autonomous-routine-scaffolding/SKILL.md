---
name: autonomous-routine-scaffolding
description: Turns a plain-language autonomous routine description (e.g. "drive to the hub, score, drive back") into scaffolded step/action-sequence code, using whatever command/state-machine pattern the repo already has — library-agnostic across command-based, op-mode-based, and custom state machines. Use when asked to "scaffold an auto routine", "generate an autonomous sequence", "block out an auton", or to turn a described autonomous plan into a code skeleton.
license: MIT
---

# Autonomous Routine Scaffolding

You turn a **plain-language autonomous routine description** into a **code skeleton** for that
routine, in whatever step/action-sequence pattern this repo's autonomous code already uses. This
skill produces *structure* — the ordered sequence of steps/actions, wired together — not full
subsystem logic, tuning, or pathing math.

This is not the tool that writes the actual drive/score/intake implementations, tunes trajectories,
or authors new subsystem code from scratch — that's the platform-specific "code authoring &
debugging" skill's job (FRC/FTC). If a step needs logic that doesn't exist yet, scaffold a
clearly-named stub for it and say so in the report (Step 5), rather than inventing the
implementation yourself.

---

## Rules that outrank everything else

1. **Never invent robot behavior.** A step in the scaffold must trace directly to a clause in the
   routine description the user gave you. If a step is ambiguous or missing detail, scaffold the
   closest reasonable stub and flag it (Step 5) — don't guess at timing, distances, or mechanism
   behavior.
2. **Library/framework-agnostic, always.** Don't assume command-based, op-mode-based, or any
   specific state-machine library — discover what this repo's autonomous code already uses
   (Step 1) and scaffold in that same pattern.
3. **Structure only.** Generate the step/action sequence and its wiring. Never write full
   subsystem control logic, PID tuning, or pathing/trajectory math — stub those with a clearly
   marked TODO and cite what's missing.
4. **Preserve existing conventions.** Match the repo's existing naming, file layout, and
   action/command style for autonomous code. Don't introduce a second autonomous pattern
   alongside an existing one.
5. **Never push.** Commit locally and print the push command. The human pushes.
6. **Re-run every time, from scratch.** Each new routine description starts a fresh Step 1–4 pass
   against the *current* state of the repo — no memory of a prior scaffold to carry forward.

---

## Step 1 — Discover the repo's autonomous pattern

Don't assume a pattern. Search for how this repo already structures autonomous code:

```bash
grep -rilE "autonomous|opmode|command|sequentialcommandgroup|statemachine" \
  --include="*.java" --include="*.py" --include="*.kt" --include="*.cpp" --include="*.h" .
```

Identify which of these (or another) the repo already uses:

- **Command-based** (e.g. WPILib `Command`/`CommandGroup` compositions).
- **Op-mode-based** (e.g. FTC SDK linear/iterative op modes with an internal step index or state
  variable).
- **Custom state machine** (a hand-rolled enum/switch or step-list driver).

**If no existing autonomous code exists at all**, this repo has nothing to scaffold from. Say so
plainly in your report (Step 5) and propose the simplest pattern consistent with whatever
programming model the rest of the codebase already uses (command-based if WPILib command classes
exist elsewhere, op-mode-based if only op modes exist, etc.) rather than defaulting to one pattern
unconditionally.

---

## Step 2 — Parse the routine description

Break the plain-language description into an ordered list of discrete steps/actions (e.g. "drive
to the hub" → one step, "score" → one step, "drive back" → one step). For each step, capture:

- The action verb/intent (drive, score, intake, wait, etc.).
- Any stated target, distance, position, or condition.
- Ordering and dependencies (sequential by default; note explicit parallelism only if the user
  states it).

Don't infer unstated steps (e.g. don't add a "stow" step nobody asked for) — scaffold exactly what
was described.

---

## Step 3 — Scaffold the sequence

Using the pattern discovered in Step 1, generate the code skeleton:

- One file (or addition to an existing autonomous-routines file/directory, matching repo
  convention) containing the ordered sequence, named after the routine (or as the user specifies).
- Each step becomes a call/command/state matching the repo's existing style — reuse an existing
  action/command class if one already does what the step needs; otherwise scaffold a clearly-named
  stub (e.g. `ScoreInHub` command with a `// TODO: implement — see report` body, or an equivalent
  op-mode/state-machine stub) rather than writing the real implementation.
- Wire the steps together in the repo's existing composition style (command groups, a step list,
  a switch/enum driver — whatever Step 1 found).

Leave every other part of the codebase untouched — this skill only adds the new routine's
scaffold, it doesn't refactor existing autonomous code.

---

## Step 4 — Commit

Stage and commit the scaffold from Step 3 before reporting — a push command for uncommitted
work is useless:

```bash
git add -- <files added/edited in Step 3>
git commit -m "feat(<routine-name>): scaffold autonomous routine"
```

---

## Step 5 — Report

Short, structured:

- **Pattern detected:** command-based / op-mode-based / custom state machine / none found.
- **Scaffolded:** `file:line` — routine name, ordered step list.
- **Stubbed — needs real implementation:** one line per stub, naming the step and what's missing.
- **Flagged — ambiguous or unstated detail:** one line per ambiguity, citing the exact part of the
  routine description that was unclear.
- `git push origin <branch>` — the command the human runs, not something you run yourself.

---

## Running unattended

A team can wire this skill into an autonomous agent the same way `docs-update` and
`frc-code-review` run from CI instead of a human typing the slash command. Two things follow from
"nobody is there to answer":

- **"Never push" stays the default, even unattended.** Commit locally and report the push command
  — don't push just because nobody's there to say not to. A calling system prompt may grant a
  different behavior explicitly for that environment; that's an override, not something to assume.
- **Ambiguity becomes decide-and-record, not stall-and-wait.** A routine detail you can't
  confidently resolve — scaffold the most reasonable stub, flag it in the report (Step 5), and
  move on instead of blocking the run.

---

## Scope boundary

**Not a code author.** The FRC/FTC "code authoring & debugging" skills write the actual
drive/score/intake logic and tune it against real hardware. This skill only produces the step
sequence and stubs — it never fills in the real behavior.

**Not a pathing/trajectory generator.** Distance/position targets inside a step are passed through
as given, never computed or tuned here — that's the "pathing/trajectory code generation" skill's
job.

**Not a PR review.** A stub left by this skill isn't a fresh finding for `pr-code-review` /
`frc-code-review` / `ftc-code-reviewer` to flag as incomplete — it's expected output, called out
plainly in this skill's own report.
