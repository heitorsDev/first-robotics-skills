---
name: ftc-season-constants
description: Builds an FTC team's current-season scoring values, field-element coordinates, AprilTag ID/pose table, and game-piece definitions as a hardware-map-friendly, code-ready constants artifact (Constants-style class/object) from the season's game manual. Use when starting a new FTC season's codebase, when no constants file exists yet, or when a full-season refresh of every constant is needed (not a single errata fix).
license: MIT
---

# FTC Season Constants

You turn an FTC team's current-season **game manual** into a maintained,
code-ready **constants artifact** — a `Constants`-style class/object carrying
scoring values, field element coordinates, the AprilTag ID/pose table, and
game piece definitions. FTC-conventional (hardware-map-friendly, readable
from an OpMode) but language-agnostic beyond that: detect the repo's existing
language and constants convention, don't force a Java idiom on a Python or
Kotlin repo.

This skill has no live knowledge of "the current FTC season" by default —
it builds from whatever manual/spec you hand it, the same flexible ingestion
as the general `game-manual-code-sync` skill.

**Not `game-manual-code-sync`** (general scope). That skill *syncs* an
already-existing constants file against manual revisions/errata — lightweight,
incremental, and it explicitly punts "no constants file yet" back to this
skill. This skill *builds or replaces* the FTC constants artifact from a
manual: the initial season build, or a full-season refresh when every value
needs re-deriving. The two pair together — this skill runs first (a new
season, or a full reset), `game-manual-code-sync` runs after, for errata.

**Not `ftc-code-authoring`.** That skill writes and debugs OpMode/subsystem
logic. This skill never touches OpMode or subsystem code — its only output is
the constants those OpModes read.

---

## Rules that outrank everything else

1. **Never invent a value.** If the manual/spec you were handed doesn't state
   a number, pose, ID, or enum member, don't write one — flag it missing
   instead (Step 8).
2. **Cite the manual source for every constant.** Section/table/page, as an
   in-code comment next to the value. AprilTag constants cite the manual's
   AprilTag ID/pose table specifically — not a generic field-element section.
3. **Four categories, always kept distinct.** Scoring values, field element
   coordinates/positions, AprilTag IDs/poses, and game piece definitions each
   get their own named section in the artifact and their own line in the
   report. Never fold AprilTags into a generic "field element" bucket.
4. **Language-agnostic constants pattern.** Detect the repo's existing
   convention (Step 2) before choosing one. No convention found — follow the
   FTC-conventional default (Step 7), don't invent a new house style.
5. **Never push.** Commit locally and print the push command. The human
   pushes.
6. **Re-run every time, from scratch.** A new manual, errata, or corrected
   excerpt triggers a full fresh Step 1-9 pass against the *current* repo
   state — no stale carry-forward assumed correct from a prior run.

---

## Step 1 — Ingest the current season's manual/spec

Accept whatever you're actually handed — there's no fixed ingestion
mechanism to assume, and this skill does not know "the current season" on
its own:

- Text pasted directly into the conversation (full manual, a section, a
  rules summary).
- A local file path already saved in the repo or elsewhere on disk.
- A URL, fetched with the web-fetch tool available in your environment.

If none of these were given, ask which manual/season to use rather than
guessing. Read the whole excerpt before moving on — a scoring value often
depends on a zone or AprilTag defined in a different section.

---

## Step 2 — Discover the repo's constants convention (or decide placement)

Don't assume a layout. Search broadly for where this repo already keeps
season-specific values:

```bash
grep -ril "constants\|fieldconstants\|apriltag\|scoring\|gamepiece\|game_piece" \
  --include="*.java" --include="*.kt" --include="*.py" --include="*.cpp" \
  --include="*.h" --include="*.yaml" --include="*.json" .
```

If something exists, match its layout, naming, units, and coordinate-frame
convention exactly — don't introduce a second style next to it. If nothing
exists (the common case this skill is for), place a new constants
class/object following the FTC/`ftc-code-authoring` convention: static
fields grouped by category, easily readable from an OpMode's `init()`. Detect
the repo's language from what's already there (build.gradle → Java/Kotlin,
etc.) — don't assume Java just because that's the common FTC SDK case.

---

## Step 3 — Extract scoring values

From the manual: point values per scoring action, bonus/penalty conditions,
per-game-piece or per-zone scoring, end-game scoring. Note the manual
section/table each comes from — you'll need it for Step 8.

---

## Step 4 — Extract field element coordinates/positions

Fixed field element locations the current manual defines — goals,
backdrops/backboards, scoring zones, parking/parking-zone boundaries,
whatever this season's field actually has. Express as position constants in
the repo's existing coordinate/units convention if Step 2 found one (field
origin, inches vs. mm, axis orientation) — don't invent a new coordinate
frame next to an established one.

---

## Step 5 — Extract AprilTag IDs and poses

Its own category — never merged into Step 4. FTC seasons publish an official
AprilTag ID-to-location table as part of the manual/field drawings: a tag ID
number plus its field pose (position + orientation). Pull this table and
build it as an ID enum/map paired with a pose per tag (whatever pose
representation the repo's vision/localization code already expects, if any —
otherwise a plain position+orientation struct). Cite the manual's AprilTag
table specifically (Rule 2), not the general field-element section.

---

## Step 6 — Extract game piece definitions

Game piece types/enums the manual defines, their dimensions, and any
legal-state definitions (e.g. "must be fully within the zone to score").

---

## Step 7 — Build the constants artifact

Write or replace the constants class/object in the Step 2 convention, with
the four categories (Steps 3-6) as their own clearly named sections —
scoring, field coordinates, AprilTag IDs/poses, game pieces. Named constants
only, no inline magic numbers duplicated elsewhere in the artifact. Units in
the constant's name or an adjacent comment — FTC manuals mix unit systems
(inches, mm, degrees, radians) across seasons, so never leave a bare number
ambiguous.

---

## Step 8 — Cite every constant to its manual source

Pass over the finished artifact: every constant has a comment citing the
manual section/table/page it came from (AprilTag constants → the AprilTag
table specifically, per Rule 2). Any gap found in either direction — a
manual value with no constant, or a constant you can't trace to the manual —
gets flagged in the report (Step 9), never silently dropped or silently
guessed.

---

## Step 9 — Report

Short, structured, with the four categories reported **separately** (never
merged):

- **Constants written:** `file:line` per category — scoring, field
  coordinates, AprilTag IDs/poses, game pieces — with a count for each.
- **Flagged — unmapped or ambiguous manual values:** manual citation, one
  line each.
- **Citation coverage:** anything written without a traceable manual source.
- `git push origin <branch>` — the command the human runs, not something you
  run yourself.

---

## Running unattended

A team can wire this skill into an autonomous agent the same way
`docs-update`, `frc-code-review`, and other skills in this marketplace run
from CI instead of a human typing a slash command. Two things follow from
"nobody is there to answer":

- **"Never push" stays the default, even unattended.** Commit locally and
  report the push command — don't push just because nobody's there to say
  not to. A calling system prompt may grant a different behavior explicitly
  for that environment; that's an override, not something to assume.
- **Ambiguity becomes decide-and-record, not stall-and-wait.** An
  unparseable clause, an unclear unit, or a value you're not confident
  about — skip that one constant, flag it plainly in the report, and move
  on instead of guessing or blocking the run.

---

## Scope boundary

**Not `game-manual-code-sync`** (general scope, open PR #29). That skill
syncs an *existing* constants file against manual revisions/errata —
lighter, incremental, and assumes constants already exist (it says so
explicitly and defers to this skill when they don't). This skill creates or
replaces the full FTC constants artifact from a manual: the initial build, or
a full-season refresh. `game-manual-code-sync` takes over afterward for
errata.

**Not `ftc-code-authoring` / `ftc-code-reviewer`.** Those write and review
OpMode/subsystem logic. This skill never touches OpMode or subsystem code —
its output is constants only, consumed by that code elsewhere.
