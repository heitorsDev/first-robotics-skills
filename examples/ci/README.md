# Wiring these skills into CI

Every skill in this marketplace documents its own unattended behavior in its
`## Running unattended` section — the defaults that hold when nobody's at a keyboard to read a
report or run a printed push command. That section never hardcodes a CI platform's mechanics
(a specific Actions syntax, a specific bot account, a specific API call): it says what the skill
itself will and won't do, and leaves *how the output reaches anyone* to whatever system prompt is
driving it in that environment.

This directory is that missing concrete half: two real, copy-pasteable GitHub Actions workflows
showing one way to wire a skill in, following the pattern each skill's own docs already describe.
Adapt the agent-invocation step to whatever harness/CLI your team runs (Claude Code, opencode,
or another agent runtime) — that part is inherently harness-specific and isn't something a skill
or this example can assume for you.

## Pattern 1 — `docs-update`, opening its own PR

[`docs-update-workflow.yml`](./docs-update-workflow.yml). Triggers on every push to the source
branch's default. The skill itself never pushes — per its Rule 1, it commits on the docs branch
and prints the push command. This workflow supplies the *separate* CI step the skill's own
`## Running unattended` section describes: it takes that commit, pushes it to a
`docs-sync/<sha>`-style branch, and opens a PR back to the source branch with `gh pr create`. The
skill never opens the PR itself — the workflow does, after the skill has already stopped.

## Pattern 2 — a review skill, posting an actual PR review

[`pr-review-workflow.yml`](./pr-review-workflow.yml), usable for `pr-code-review`,
`frc-code-review`, or `ftc-code-reviewer` interchangeably (swap the skill invoked in the
"Run the review skill" step). Triggers on `pull_request` (`opened` and `synchronize`). The skill's
own rule is that its final message **is** the report, nothing else — this workflow captures that
message to a file and posts it with:

```bash
gh pr review "$PR_NUMBER" --comment --body-file report.md
```

`gh pr review` is GitHub's actual PR-review API (the same surface a human reviewer's Approve /
Request changes / Comment uses) — not `gh pr comment`, which posts a plain issue-style comment
with no review semantics. Issue #22 asked for output "we can later comment it as a actual PR
review from a agent"; `gh pr review --comment` is that literal mechanism. Swap `--comment` for
`--request-changes` or `--approve` in your own wiring if you want the review's verdict to drive
the GitHub review state — the skill's report already states a verdict per finding, so the workflow
(not the skill) is the right place to map that to a review event if you want one.

The skill never runs `gh pr review`, `gh pr comment`, or any posting command itself — per its own
rule, it only produces the report.

## Required permissions

Both workflows need, at minimum:

```yaml
permissions:
  contents: write        # docs-update: push the docs-sync branch
  pull-requests: write    # both: open a PR / post a review
```

And `GH_TOKEN` (or `GITHUB_TOKEN` in Actions) available to the `gh` CLI the skills' own scripts
already shell out to (`get-diff.sh`, `get-pr-history.sh`).
