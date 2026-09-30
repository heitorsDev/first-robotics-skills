# Axis 4 — Infrastructure, scripts, and configuration

Checklist for diffs that are **not** robot Java code: GitHub Actions, shell scripts, Gradle,
deploy JSON, Markdown, and the skill/agent config files themselves.

This axis only enters the review when the diff touches these files. If the diff is only robot
Java, skip this file entirely.

---

## GitHub Actions (`.github/workflows/*.yml`)

- 🔴 **Exposed secret.** `secrets.*` never goes into an interpolated `run:` string
  (`${{ secrets.X }}` inside `run` leaks in the log if the command echoes it). Pass it through
  `env:` instead.
- 🔴 **`pull_request_target` checking out the PR's code.** That runs fork code with write
  permission on the repo. If this shows up, it's critical. `pull_request` is the correct trigger
  for PR CI.
- 🟠 **A third-party action on a floating tag.** `uses: owner/action@v1` can change content
  without warning. Pinning to a full SHA is correct for actions outside `actions/*`.
- 🟠 **More permission than needed.** `permissions:` should list only what the job uses.
  `contents: write` on a job that only reads is unnecessary privilege escalation. If there's
  `id-token: write` with no OIDC in use, it's unneeded.
- 🟠 **No `concurrency`** on a workflow triggered by push/PR: every push piles up a run and wastes
  Actions minutes for nothing.
- 🟡 An overly broad trigger (`on: push` with no branch/path filter) runs the workflow on changes
  that don't need it.

## Shell scripts (`*.sh`)

- 🟠 **Missing `set -euo pipefail`** (or equivalent): the script keeps running after a failed
  command and "succeeds" while showing a wrong result. Legitimate exception: a script that
  handles exit codes by hand — then `set -uo pipefail` without `-e` is deliberate, not a finding.
- 🟠 **Unquoted variable** (`$VAR` instead of `"$VAR"`): breaks on a path with a space.
- 🟡 An external command used without checking it exists (`command -v gh >/dev/null` before using
  `gh`).
- 🟡 Error output going to stdout instead of stderr (`>&2`), which pollutes the script's result.

## Gradle (`build.gradle`, `vendordeps/*.json`)

- 🔴 **A vendordep version bumped without bumping the matching WPILib version** (or vice versa):
  the robot compiles and fails at runtime at competition. Vendordep and WPILib have to be the same
  season/version.
- 🟠 A new dependency with no justification in the PR: extra weight on deploy and one more thing
  to break next year.
- 🟡 A plugin version pinned to `+` or an open range — the build stops being reproducible.

## Deploy JSON (`src/main/deploy/`)

The swerve- and PathPlanner-specific checklist lives in `frc-standards.md` — use that instead.
Here, only the general checks:

- 🔴 Invalid JSON (trailing comma, duplicate key): the robot won't boot. Worth running a parser.
- 🟠 A configuration value changed with nothing in the PR explaining why — a calibration number
  with no context is impossible to review later.

## Markdown and agent/skill config files (`*.md`, `.claude/`)

- 🟠 An instruction that's ambiguous or contradicts another file in the repo (e.g. one doc says
  one port and the constants file uses another). Wrong documentation is worse than missing
  documentation.
- 🟠 A documented command that doesn't exist or doesn't run as written. Test it before approving.
- 🟡 A broken link, a file path that no longer exists.
- Don't report writing style, line length, or Markdown formatting preference.

## What **not** to review here

- YAML/JSON formatting that an auto-formatter would fix.
- Personal file-organization preference with no concrete impact.
- Missing automated tests in a CI script — most teams don't have that infrastructure.
- **Documentation that didn't keep up with the code.** A missing page, a stale table, a guide
  describing old behavior: that's downstream doc-maintenance work, not this PR's job. Wrong text
  that the diff *itself* wrote is still fair game.
