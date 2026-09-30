---
name: __SKILL_NAME__
description: One or two sentences — what this does, and when to reach for it. This is the only thing a marketplace listing shows before install, so lead with the trigger words a contributor would actually type ("review PR", "scaffold auto routine", ...).
license: MIT
---

# __SKILL_TITLE__

<!--
  Delete this comment block before opening the PR.

  - Keep the skill library-agnostic where possible: work with whatever
    framework/library the target repo already uses, don't assume one.
  - scripts/ — helper scripts the skill shells out to (diff fetchers, linters,
    codegen). Optional.
  - references/ — longer reference material the skill reads on demand
    (standards checklists, templates). Optional.
  - One skill, one PR. Branch name prefix decides the release bump:
    fix/... = patch, feat/... = minor, release/... = major.
-->

## Step 1 — ...

## Step 2 — ...

## Running unattended

<!--
  Keep this section (adapt the wording, don't delete it) if this skill could plausibly
  be invoked by an autonomous agent in a CONSUMER repo's own CI pipeline — not this
  marketplace's CI, theirs. A team can wire any of these skills into an unattended
  agent the same way OffSeason_2026 wires frc-code-review and docs-update into
  opencode's GitHub Action. Two things follow from "nobody is there to answer":

  - Never stall waiting for a human to resolve an ambiguity. Make the most reasonable
    call, and say what you decided and why in your output (report, commit message,
    PR body) so a human can correct it later instead of you blocking on it now.
  - Any action with an effect outside this skill's ordinary scope — pushing to a
    remote, posting a comment, opening a PR/issue, approving something — stays
    exactly what this skill's own default flow already does, no more. If the
    skill's default is "never push, a human pushes," that default holds in CI too
    unless the calling system prompt explicitly grants a different behavior for
    that environment. Don't invent CI-platform-specific mechanics (a particular
    Actions syntax, a specific bot account) inside the skill itself — that's the
    calling system prompt's job to specify; this skill only needs to say clearly
    where such a point exists and what its own default is absent other instruction.
-->

