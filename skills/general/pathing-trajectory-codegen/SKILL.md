---
name: pathing-trajectory-codegen
description: Writes or tunes path-following/trajectory-generation code and its deploy-time config/field files, against whatever pathing library a repo already has — PathPlanner, Choreo, RoadRunner, or a custom format — detected or asked for, never assumed. Use when asked to "generate a path", "write a trajectory", "tune this PathPlanner/Choreo/RoadRunner path", or to add a new autonomous path to a robot codebase.
license: MIT
---

# Pathing / Trajectory Code Generation

You write or tune **path-following and trajectory-generation artifacts** — the deploy-time
config/field files a pathing library reads, plus whatever code hook the library needs to load
them — against whichever pathing library this repo already uses.

This is not the tool that picks a pathing library for a repo that has none — that's a one-time
architecture decision for the team, not something to make on their behalf. If Step 1 finds no
library in use, ask which one before writing anything.

---

## Rules that outrank everything else

1. **Never assume a library.** Detect it (Step 1) or ask. Don't default to PathPlanner, Choreo,
   or RoadRunner because it's common — silently guessing wrong produces a file the repo's
   tooling can't even load.
2. **Match the library's own schema exactly.** Coordinate units, JSON/config structure, file
   location, naming — follow what the detected library (and this repo's existing paths, if any)
   already does. Don't invent a format variant.
3. **Artifacts only.** Write/edit the path/trajectory file and its minimal load/reference hook.
   Never touch the drivetrain or subsystem code that *consumes* the path once loaded — that's
   outside this skill's scope.
4. **Don't touch paths you weren't asked about.** Tuning one named path/trajectory leaves every
   other existing one untouched.
5. **Never push.** Commit locally and print the push command. The human pushes.
6. **Re-run every time, from scratch.** Each new request starts a fresh Step 1–4 pass against
   the *current* state of the repo — no assumed memory of a prior path/trajectory.

---

## Step 1 — Detect the pathing library

Don't assume one. Check dependency manifests and deploy-file conventions:

```bash
grep -ril "pathplanner\|choreo\|roadrunner" \
  build.gradle build.gradle.kts pom.xml requirements.txt pyproject.toml vendordeps 2>/dev/null
find . -type d \( -iname "pathplanner" -o -iname "choreo" \) 2>/dev/null
find . -iname "*.path" -o -iname "*.traj" -o -iname "*.chor" 2>/dev/null
```

Match what's found to a library:

- **PathPlanner** — `deploy/pathplanner/*.path` JSON files, `PathPlannerLib` vendordep/gradle
  dependency, `AutoBuilder`/`PathPlannerAuto` references in code.
- **Choreo** — `deploy/choreo/*.traj` (or `.chor`) JSON files, `choreolib` dependency.
- **RoadRunner** — no deploy-time file; trajectories built via `TrajectorySequenceBuilder` (or
  the newer Actions API) calls directly in Java/Kotlin, `RoadRunner`/`roadrunner` gradle
  dependency, a `RoadRunnerConfig`/`DriveConstants`-style tuning file.
- **Custom** — a hand-rolled waypoint/trajectory format that matches none of the above.

**If nothing is found or detection is ambiguous**, ask the user which library to target before
writing anything. Don't pick one for them.

---

## Step 2 — Parse the request

Capture exactly what's being asked, without inferring the rest:

- New path/trajectory, or tuning an existing named one?
- Waypoints / start and end poses as stated.
- Constraints explicitly given (max velocity, max acceleration, rotation targets, hold points).

Don't invent waypoints, constraints, or rotation targets the user didn't state — flag gaps in
Step 5 instead of filling them in with a guess.

---

## Step 3 — Write or tune the artifact

In the detected library's exact schema:

- **PathPlanner / Choreo**: write or edit the `.path`/`.traj` JSON in `deploy/<library>/`,
  matching field/units/version conventions of any existing files in that folder.
- **RoadRunner**: write or edit the builder-call code that constructs the trajectory sequence,
  matching the repo's existing builder-call style and units (inches vs. meters — check existing
  calls, don't assume).
- **Custom**: match the existing custom format's structure precisely; if this is the repo's
  first path and no format exists, say so in the report (Step 5) instead of inventing one.

Add the minimal code hook needed to load/reference the new artifact (e.g. registering a
`PathPlannerAuto`, adding a trajectory-sequence method call) in the same place and style the
repo's existing paths are referenced from — without rewriting that referencing code's own logic.

Leave constraints not explicitly stated at the library's own defaults, and say so in the report.

---

## Step 4 — Commit

If Step 3 wrote or edited anything, stage and commit it before reporting — a push command for
uncommitted work is useless:

```bash
git add -- <files touched in Step 3>
git commit -m "feat(<path-or-trajectory-name>): add/tune path"
```

If nothing was written (no library could be determined and the user hasn't answered yet), skip
this step.

---

## Step 5 — Report

Short, structured:

- **Library detected:** PathPlanner / Choreo / RoadRunner / custom / none found.
- **Written/tuned:** file path (or `file:line` for code-based trajectories) — path/trajectory
  name.
- **Constraints used:** each constraint, tagged user-stated or library default.
- **Flagged — missing/ambiguous:** one line per gap (unstated waypoint, unclear constraint, no
  existing format to match for a first-ever path).
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
- **Ambiguity becomes decide-and-record, not stall-and-wait.** An unclear constraint or
  ambiguous library detection — use the most conservative default (library's own default
  constraint, or skip writing and flag it if the library itself can't be determined) and say so
  plainly in the report, rather than blocking the run.

---

## Scope boundary

**Not a library picker.** A repo with no pathing library gets asked, once, which one to target
— this skill never chooses on the team's behalf.

**Not `autonomous-routine-scaffolding`.** That skill scaffolds the step/action sequence that
*calls* a path or trajectory. This skill only produces the path/trajectory artifact itself —
the two compose, but neither does the other's job.

**Not a PR review.** A flagged missing constraint or waypoint is expected output here, not a
fresh finding for `pr-code-review` / `frc-code-review` / `ftc-code-reviewer` to repeat.
