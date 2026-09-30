---
name: game-manual-code-sync
description: Reads the current season's game manual (or an excerpt/summary of it), locates a robot codebase's existing constants file(s), and updates scoring values, field element coordinates/poses, game piece enums, and legal zones to match — library-agnostically, without assuming FRC or FTC conventions. Use when asked to "sync the game manual", "update constants for the new season", "check the code against the rules", when a manual revision/errata changes a value already hardcoded in the repo, or at the start of work on a new season's codebase.
license: MIT
---

# Game Manual Code Sync

You keep a robot codebase's **constants** in step with the **current season's game manual**. The
manual is the source of truth; the constants file(s) are the derived artifact. This skill only
ever goes manual → code, and only ever touches constants — never the subsystem/command logic that
consumes them.

This is the season-over-season *sync* tool: it assumes constants already exist somewhere (or
notices that they don't) and reconciles them against the manual you hand it. It is not the tool
that builds an FRC or FTC season's constants from scratch — that is a separate, platform-specific
skill. If a repo has no constants file at all yet, say so in your report (Step 2) instead of
inventing a file layout; that's the other skill's job, not this one's.

---

## Rules that outrank everything else

1. **Never invent a value.** If the manual doesn't state a number, pose, or enum member, don't
   write one. Missing information is a flag (Step 5), never a guess.
2. **Cite everything.** Every edit traces to a specific manual section/rule/table number; every
   flag cites the manual clause **and** the code location it concerns.
3. **Library-agnostic, always.** Don't assume `Constants.java`, WPILib units, or any specific
   layout — discover what this repo already uses (Step 2) and follow its own conventions.
4. **Constants only.** Edit the values that hold scoring/field/enum/zone data. Never touch the
   code that reads those constants — that's outside this skill's scope.
5. **The concrete-scenario test.** Before flagging anything in Step 5, ask: *can I name the exact
   manual clause this contradicts, or the exact rule this has no code for?* If not, it's not a
   finding.
6. **Never push.** Commit locally and print the push command. The human pushes.
7. **Read before you write.** Read the full manual excerpt/section you were given, not just the
   part that looks relevant — a scoring value can depend on a zone definition stated elsewhere.
8. **Re-run every time, from scratch.** Each new manual/errata/summary you're handed starts a
   fresh Step 1–6 pass against the *current* state of the repo. There is no memory of a prior
   sync to carry forward — don't skip a category because "it was already synced last time."

---

## Step 1 — Ingest the manual

Accept whatever the user actually hands you — there's no fixed ingestion mechanism to assume:

- Text pasted directly into the conversation (a full manual, a single section, a rules summary).
- A local file path already saved in the repo or elsewhere on disk.
- A URL, fetched with the web-fetch tool available in your environment.

If none of these were given, ask for the relevant manual section(s) rather than guessing which
season or which rules apply. Read the whole excerpt before moving on — a scoring value in one
section often refers to a zone or piece defined in another.

---

## Step 2 — Discover the repo's constants convention

Don't assume a layout. Search broadly for where this repo already keeps season-specific values:

```bash
grep -ril "constants\|fieldconstants\|scoring\|gamepiece\|game_piece" --include="*.java" --include="*.py" --include="*.kt" --include="*.cpp" --include="*.h" --include="*.yaml" --include="*.json" .
```

Look for a dedicated constants/config file or module (mirrors `frc-code-review`'s discipline of
checking for an existing constants file before flagging magic numbers), per-subsystem constants
split across files, enums for game pieces, and any field/pose data (coordinates, AprilTag poses,
zone boundaries).

**If nothing like this exists at all**, this repo has no constants to sync yet. Say so plainly in
your report and stop editing — scaffolding a constants architecture from nothing is the job of the
season-specific "season game constants" skill (FRC/FTC), not this one. Do not invent a file.

If something exists, list every file you found and treat that as the complete target set for
Steps 3–4.

---

## Step 3 — Diff the manual against the code

Work category by category — scoring values, field element coordinates/poses, game piece enums,
legal zones — and for each existing constant, find the manual clause it's supposed to represent
(or confirm there isn't one). Note, per constant: what the code currently has, what the manual
says, and whether they agree.

Don't widen scope to constants that have nothing to do with the manual (robot dimensions, PID
gains, CAN IDs) — those aren't this skill's concern even if they live in the same file.

---

## Step 4 — Apply edits

For every confirmed mismatch, edit the constant in place:

- Preserve the file's existing naming, units, and formatting conventions — don't introduce a new
  style for one value.
- If the file already comments constants with a manual section/table reference, keep doing that
  for the values you touch. Don't invent a new comment convention if the file has none.
- Leave everything that already matches the manual untouched.
- Never edit the code that *reads* these constants, even if a value change would logically require
  it (e.g., a zone boundary move that affects a path) — flag that downstream effect in Step 5
  instead of chasing it yourself.

---

## Step 5 — Flag what code can't fix

Two categories, both gated by the concrete-scenario test from the rules above — no vague or
speculative flags:

- **Manual rules with no corresponding code yet.** Cite the exact manual section/rule number.
  Example: *"Manual §4.3 'CORAL scored in L4 = 5 points' has no matching constant — `Constants`
  only defines L1–L3 scoring values."*
- **Code constants that no longer match the manual, that you did not already fix in Step 4**
  (e.g., ambiguous cases, or a value that depends on a downstream recalculation outside scope).
  Cite both the code location (`file:line`) and the exact manual clause it contradicts.

Don't flag general code-quality issues (a magic number unrelated to this season's rules, poor
naming, missing tests) — that's `pr-code-review`'s / `frc-code-review`'s / `ftc-code-reviewer`'s
job on the next PR, not this skill's.

---

## Step 6 — Commit

If Step 4 changed anything, stage and commit it before reporting — a push command for
uncommitted work is useless:

```bash
git add -- <files touched in Step 4>
git commit -m "fix(<constants-file-name>): sync constants to <manual/season identifier>"
```

If nothing was edited (every value already matched, or Step 2 found no constants file), skip
this step — there's nothing to commit.

---

## Step 7 — Report

Short, structured:

- **Updated:** `file:line` — old value → new value, manual citation.
- **Flagged — manual rules with no code yet:** manual citation, one line each.
- **Flagged — code no longer matching the manual:** `file:line` + manual citation, one line each.
- **Skipped, and why** (e.g., a constants file that doesn't exist yet — see Step 2).
- `git push origin <branch>` — the command the human runs, not something you run yourself.

---

## Running unattended

A team can wire this skill into an autonomous agent the same way `docs-update` and
`frc-code-review` run from CI instead of a human typing the slash command. Two things follow from
"nobody is there to answer":

- **"Never push" stays the default, even unattended.** Commit locally and report the push command,
  the same as a human-driven run — don't push just because nobody's there to say not to. A calling
  system prompt may grant a different behavior explicitly for that environment; that's an override,
  not something to assume.
- **Ambiguity becomes decide-and-record, not stall-and-wait.** A constants file you can't
  confidently locate, a manual clause you can't parse, or a value you're not sure how to map —
  make the most conservative call (usually: skip that one value, leave it for Step 5 or the report,
  don't guess) and say so plainly in the report, so a human reviews it after the fact instead of
  the run hanging.

---

## Scope boundary

**Not a PR review.** A hardcoded value that happens to be a game constant isn't a fresh
"magic number" finding for `pr-code-review` / `frc-code-review` / `ftc-code-reviewer` to repeat on
every PR — this skill is where that value gets caught and fixed, once, per season or per manual
revision.

**Not a from-scratch builder.** The FRC/FTC "season game constants" skills carry a *new* season's
constants into a codebase that doesn't have them yet, for their specific platform. This skill
assumes something already exists (or reports that it doesn't) and keeps it honest against the
manual from then on — the same way for either platform, since it never assumes one.
