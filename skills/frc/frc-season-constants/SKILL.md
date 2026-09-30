---
name: frc-season-constants
description: Carries the current FRC season's scoring values, field element poses, AprilTag ID-to-pose table, and game piece definitions as a code-ready WPILib constants artifact, built from the season's game manual. Use when asked to "add this season's constants", "scaffold field/scoring/AprilTag constants", "build Constants.java for the new game", or at the start of an FRC codebase for a new season.
license: MIT
---

# FRC Season Constants

You carry the current FRC season's scoring values, field element poses, AprilTag ID-to-pose
table, and game piece definitions into a robot codebase as a maintained, code-ready constants
artifact — a WPILib `Constants`-style class (or the repo's existing equivalent), built directly
from that season's game manual.

This is not `game-manual-code-sync` (general scope). That skill assumes constants already exist
and reconciles them against manual errata/revisions — light, incremental, in-place edits. This
skill is the from-scratch builder: it's what runs first, at the start of a season, when there is
no constants artifact yet (or the whole thing needs replacing for a new game). The two pair:
this skill builds the initial artifact, `game-manual-code-sync` keeps it honest afterward as the
manual gets revised. If a repo already has a populated FRC constants file and you're just told
"the manual changed," that's `game-manual-code-sync`'s job, not this skill's — say so and stop.

This is also not `frc-code-authoring` or `frc-code-review`. Those write and review
subsystem/command logic. This skill only produces constants — it never writes a subsystem,
command, or `RobotContainer` wiring, and it never reviews a PR.

---

## Rules that outrank everything else

1. **Never invent a value.** Every scoring number, pose, AprilTag ID/pose, dimension, or game
   piece definition must come from the season manual/spec you were handed. No "typical" value,
   no carrying over last season's number, no filling a gap with a guess.
2. **Cite the manual for every constant.** Each value's comment names the manual section/table/
   rule it came from. AprilTag IDs/poses cite the manual's AprilTag table specifically — not a
   generic "field diagram" citation — since that table is a distinct, separately published part
   of the manual.
3. **Match the repo's existing units/pose convention — don't force one.** If a `Constants.java`
   already exists, follow its units (meters vs. inches), `Pose2d`/`Translation2d` construction
   style, and naming. If none exists, default to WPILib convention (SI units,
   `edu.wpi.first.math.geometry.Pose2d`) and say so in the report. Exception: AprilTag poses are
   inherently 3D — the manual publishes each tag's position *and* orientation — so use `Pose3d`
   for tags even when the repo's other field-element poses are flattened to `Pose2d`, unless the
   repo already has a deliberate, existing AprilTag layout convention that flattens them; then
   match that instead.
4. **Never push.** Commit locally and print the push command. The human pushes.
5. **Re-run every time, from scratch.** Each invocation re-ingests whatever manual/spec it's
   handed and re-derives constants against the *current* state of the repo — no assumed memory
   of a prior build.

---

## Step 1 — Ingest the season manual

No live knowledge of "the current season" is assumed. Accept whatever's handed over, same
flexible ingestion as `game-manual-code-sync`:

- Text pasted directly into the conversation (full manual, a scoring/field section, a rules
  summary).
- A local file path.
- A URL, fetched with the web-fetch tool available in the environment.

If none given, ask which season/manual to build from rather than guessing or defaulting to a
remembered season — model knowledge of "the current FRC game" is not a substitute for the actual
manual text. Read the full excerpt before extracting anything; a scoring value often depends on
a zone or piece defined elsewhere in the document, and the AprilTag ID-to-pose table often sits
in its own appendix, separate from the scoring rules.

---

## Step 2 — Orient in the target repo

Read, in order (mirrors `frc-code-authoring` Step 1):

1. `Constants.java` (or equivalent) — does an FRC constants file already exist? If it's already
   populated with this season's values, stop and point to `game-manual-code-sync` instead (see
   Scope boundary) — this skill is for building from nothing or a full-season replacement, not
   incremental edits.
2. `vendordeps/*.json` / `build.gradle` — confirms this is a WPILib project and which vendor
   libraries are declared (affects whether an `AprilTagFieldLayout` helper or a JSON deploy
   convention for tag poses is already in play).
3. Existing units convention — inches vs. meters, `Rotation2d` usage, and any existing AprilTag
   layout file — from whatever constants or subsystem code already exists.

---

## Step 3 — Extract scoring values

From the manual, pull every scoring-relevant number: points per game piece/action, per zone,
bonus/multiplier conditions, endgame values. One named constant per value, grouped logically
(e.g. a nested `ScoringConstants` class or equivalent), each with a manual citation comment.

---

## Step 4 — Extract field element poses

From the manual's field drawings/tables: fixed, non-tag field element positions (goals,
stations, zones) as `Pose2d`/`Translation2d` constants in the repo's chosen units and origin
convention (FRC field-coordinate origin per the manual's own diagram, or the repo's established
convention if one already exists — e.g. blue-alliance-origin vs. field-centric). Note explicitly
in the report which origin convention was used and why.

---

## Step 5 — Extract AprilTag IDs and poses

Its own named category (e.g. an `AprilTagConstants` class, or however the repo's existing
constants file nests categories), kept separate from Step 4's general field elements. Per the
manual's AprilTag ID-to-pose table specifically: tag ID number paired with its field `Pose3d`
(position + orientation), per Rule 3's Pose3d default.

If the repo already has, or a declared vendor library expects, an `AprilTagFieldLayout` JSON
under `src/main/deploy/` (rather than hardcoded Java), follow that convention instead — same
"match the repo's existing pattern" discipline as Step 4, applied specifically to tags. Cite the
manual's AprilTag table for every tag entry, not a general field-diagram citation.

---

## Step 6 — Extract game piece definitions

Game piece types/enums (e.g. an enum for the season's scoring objects) and any physical
constants the manual states (piece dimensions, weight) that the manual itself provides — not
invented dimensions.

---

## Step 7 — Write the constants artifact

- Follow the repo's existing `Constants.java` layout/nesting convention if one exists; create a
  new one following WPILib convention (nested `public static final class` per category) if not.
- Group by category from Steps 3–6 — scoring, field elements, AprilTag IDs/poses, game pieces —
  as distinct groups; don't merge AprilTags into general field elements, and don't mix any of
  these with unrelated constants (CAN IDs, PID gains) that already live elsewhere in the file.
- Every constant gets a comment citing its manual source.
- Commit locally with a message naming the season/manual version used.

---

## Step 8 — Report

Short, structured:

- **Manual/season used:** what was ingested (file/URL/pasted text), and its version/date if
  stated.
- **Written:** `file:line` — constant, manual citation, grouped by category (scoring / field
  elements / AprilTag IDs+poses / game pieces), one line each or grouped if long.
- **Flagged — manual values with no clean mapping:** anything ambiguous or requiring a judgment
  call, cited to the manual clause.
- **Units/origin convention used** for field elements, and **AprilTag pose format used**
  (`Pose3d` vs. a flattened/JSON layout convention) — each noted as matched-existing or
  fresh-default.
- `git push origin <branch>` — the command the human runs, not something you run yourself.

---

## Running unattended

- **"Never push" stays the default, even unattended.** Commit locally and report the push
  command — don't push just because nobody's there to say not to. A calling system prompt may
  grant a different behavior explicitly for that environment; that's an override, not something
  to assume.
- **No manual handed over and none discoverable:** don't guess a season or fabricate values,
  AprilTag IDs included. Say plainly in the report that no manual was provided and stop — an
  empty or wrong constants file is worse than no run.
- **Ambiguous mapping (unclear zone boundary, unstated units, an AprilTag entry with no clear
  pose):** make the most conservative call, flag it in Step 8, move on — don't stall the run.

---

## Scope boundary

**Not `game-manual-code-sync` (general).** That skill syncs *existing* constants — AprilTag
table included — against manual errata/revisions: lighter, incremental, assumes an artifact is
already there. This skill *builds* the FRC constants artifact from scratch (first season setup,
or a full replacement for a new game), with AprilTag IDs/poses as their own category from day
one, producing the very file `game-manual-code-sync` later keeps in sync. If a populated FRC
constants file already matches the target season and you're only handed a revision/errata,
that's `game-manual-code-sync`'s job — hand off, don't duplicate.

**Not `frc-code-authoring` or `frc-code-review`.** Those write and review subsystem/command
logic. This skill never writes a `SubsystemBase`, `Command`, or `RobotContainer` wiring, and
never produces a PR review — only the constants values themselves.
