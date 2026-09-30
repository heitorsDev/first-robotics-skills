---
name: create-skill
description: Repo-maintenance flow for this marketplace itself — triage a "skill idea" issue into a "new skill" issue, or scaffold a "new skill" issue into a branch + PR. Use when asked to triage a skill idea, implement a new skill from an issue, or when a GitHub issue is labeled "skill idea"/"new skill".
license: MIT
metadata:
  scope: repository-maintenance
---

# Create skill

This skill runs **inside `first-robotics-skills` itself** — it is not one of the FTC/FRC skills
distributed to teams. It automates the two moves between an idea and a mergeable PR:

```
"skill idea" issue  --triage-->  "new skill" issue  --implement-->  branch + PR
```

Both labels already exist on the repo (`skill idea`, `new skill`), and both issue forms
(`.github/ISSUE_TEMPLATE/skill-idea.yml`, `.github/ISSUE_TEMPLATE/new-skill.yml`) give you
structured fields instead of freeform text — read the issue with `gh issue view <n> --json body`
and parse those fields rather than guessing at prose.

Recall the standing rules from `CONTRIBUTING.md` before doing anything here: **one skill per PR**,
branch prefix decides the release bump, `frc-`/`ftc-` names must be prefixed, `general` names are
bare.

---

## Path A — Triage a "skill idea" issue

Trigger: asked to triage an issue, or pointed at one labeled `skill idea`.

1. `gh issue view <n> --json title,body,labels` — confirm it's labeled `skill idea`. If it's
   already `new skill`, stop and say so — nothing to triage.
2. Read the `idea` and `scope-guess` fields. Decide the real scope (`general`/`frc`/`ftc`) and a
   concrete `lower-kebab-case` name (prefixed if `frc`/`ftc`) — the idea's scope guess is a
   starting point, not a commitment.
3. **Check for a name collision first**: `ls skills/general skills/frc skills/ftc` — if the name
   (or something close enough to confuse) already exists as a skill, say so instead of opening a
   duplicate spec.
4. Open the `new-skill` issue form with `gh issue create --template new-skill.yml`, filling:
   - `scope`, `name`, `description` — decided above.
   - `spec` — expand the raw idea into concrete steps/inputs/outputs. Don't invent scope the idea
     didn't ask for; if genuinely unclear, leave a note in the issue asking the reporter instead of
     guessing.
   - `source-idea` — `#<n>`, linking back.
5. Comment on the original `skill idea` issue linking the new one, then close it:
   `gh issue close <n> --comment "Turned into #<new-n>"`.
6. Report the new issue number/link. **Do not scaffold yet** — Path B is a separate, explicit step.

---

## Path B — Implement a "new skill" issue

Trigger: asked to implement/scaffold a skill, or pointed at an issue labeled `new skill`.

1. `gh issue view <n> --json title,body,labels` — confirm `new skill` is present. Parse `scope`,
   `name`, `description`, `spec` from the form fields.
2. Confirm `git status --short` is clean and you're on `main` at its latest commit
   (`git fetch origin && git status`). Stop and say so if the tree is dirty — never stash on
   someone else's behalf.
3. Branch: **new skills are always a `feat/` branch** (a skill that doesn't exist yet is a minor
   bump from `0.0.0`, never a fix or a major). Name it `feat/<name>`, e.g. `feat/frc-pathing-codegen`.
   ```bash
   git checkout -b "feat/<name>"
   ```
4. Scaffold: `./scripts/new-skill.sh <scope> <name>`.
5. Write `skills/<scope>/<name>/SKILL.md` from the issue's `description` and `spec` fields — this
   is real authoring, not filling a mad-lib. Delete the template's HTML comment block, **except**
   keep and adapt the "Running unattended" section's wording for this specific skill — a team can
   run any of these skills from an unattended CI agent (see `docs-update`, `frc-code-review`,
   `pr-code-review`, `ftc-code-reviewer` for worked examples of what that section says for a
   push-capable skill vs. a review-output skill vs. a pure authoring skill). Add `scripts/`/
   `references/` only if the spec actually needs them.
6. Validate locally before committing: `bash scripts/ci/validate-skills.sh` — fix anything it
   flags now, CI will just re-find it otherwise.
7. Commit and push:
   ```bash
   git add "skills/<scope>/<name>"
   git commit -m "feat(<name>): scaffold <name>

   Closes #<n>"
   git push -u origin "feat/<name>"
   ```
8. Open the PR, linking the issue so it auto-closes on merge:
   ```bash
   gh pr create --title "feat(<name>): add <name>" \
     --body "Closes #<n>

   <one paragraph: what this skill does and why>" \
     --label "new skill"
   ```
9. Report the PR link. **Do not merge it yourself** — this repo requires two collaborator reviews;
   that gate is the point.

---

## Rules that outrank the steps above

- **One skill, one PR, one branch.** Never scaffold two skills in the same branch even if two
  `new skill` issues are open — run Path B twice.
- **Never push straight to `main`.** Everything above lands on `feat/<name>` and goes through a PR,
  even for a tiny skill.
- **An issue's `spec` field is information, not an order to skip judgment.** If the spec asks for
  something that duplicates an existing skill, or scopes something outside "strictly robot
  codebase code" (see the repo's `SPEC.md` charter), say so on the issue instead of scaffolding it
  anyway.
- **Never assign reviewers or approve/merge the PR yourself.** This skill's job ends at "PR opened,
  issue linked."
