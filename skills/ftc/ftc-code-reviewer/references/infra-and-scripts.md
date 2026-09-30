# Axis 4 — Infrastructure, scripts, and configuration

Checklist for diffs that **aren't** robot Java/Kotlin: GitHub Actions, shell scripts, Gradle,
robot-configuration files, Markdown, and the repo's own `.claude/`/skill files.

This axis only enters the review when the diff touches these files. If the diff is only robot
code, ignore this file entirely.

---

## GitHub Actions (`.github/workflows/*.yml`)

- 🔴 **Exposed secret.** `secrets.*` never goes into an interpolated `run:` string
  (`${{ secrets.X }}` inside `run` can leak into the log if the command echoes it). Pass it via
  `env:` instead.
- 🔴 **`pull_request_target` checking out the PR's code.** That runs fork code with write
  permission to the repo. If it appears, it's critical. `pull_request` is the right trigger for PR
  CI.
- 🟠 **Third-party action pinned to a moving tag.** `uses: owner/action@v1` can change content
  without notice. Pinning to a full SHA is correct for actions outside `actions/*`.
- 🟠 **Broader permission than needed.** `permissions:` should list only what the job uses.
  `contents: write` on a job that only reads is unnecessary privilege escalation. `id-token: write`
  with no OIDC use is dead weight.
- 🟠 **No `concurrency`** on a workflow triggered by push/PR: every push piles up a run and burns
  Actions minutes for nothing.
- 🟡 Trigger too broad (`on: push` with no branch/path filter) runs the workflow on changes that
  don't need it.

## Shell scripts (`*.sh`)

- 🟠 **No `set -euo pipefail`** (or equivalent): the script keeps going after a failing command and
  "succeeds" while showing a wrong result. Legitimate exception: a script that handles exit codes
  by hand — `set -uo pipefail` without `-e` there is deliberate, not a finding.
- 🟠 **Unquoted variable** (`$VAR` instead of `"$VAR"`): breaks on a path with a space.
- 🟡 An external command used without checking it exists (`command -v gh >/dev/null` before using
  `gh`).
- 🟡 Error output going to stdout instead of stderr (`>&2`), which pollutes the script's actual
  output.

## Gradle (`build.gradle`, `build.dependencies.gradle`)

- 🔴 **FTC SDK version changed inconsistently** across the modules that reference it (e.g.
  `TeamCode` bumped but `FtcRobotController` left behind, or vice versa): the project can fail to
  build or mismatch behavior between modules.
- 🟠 A new dependency added with no justification in the PR: extra APK size and one more thing that
  can break next season.
- 🟡 A plugin/dependency version left on `+` or an open range — the build stops being reproducible.

## Robot configuration and deploy files

- 🔴 Invalid config XML (mismatched tags, duplicate device name): the robot configuration fails to
  load on the Driver Station/Control Hub. Worth validating if you can.
- 🟠 A device name changed in the config without a matching update to the `hardwareMap.get(...)`
  calls that reference it (or vice versa) — see `ftc-standards.md` 2.2.
- 🟠 A calibration value (PID coefficients, servo range, gear ratio) changed with nothing in the
  PR explaining why — an unexplained calibration change is impossible to review later.

## Markdown and skill files (`*.md`, `.claude/`)

- 🟠 Instruction that's ambiguous or contradicts another file in the repo (e.g. a README lists one
  gamepad binding and the OpMode code uses another). Wrong documentation is worse than missing
  documentation.
- 🟠 A documented command that doesn't exist or doesn't run as written. Test it before approving.
- 🟡 Broken link, path to a file that no longer exists.
- Don't report writing style, line length, or formatting preference in Markdown.

## What **not** to review here

- YAML/JSON formatting that an auto-formatter would fix.
- Personal file-organization preference with no concrete impact.
- Missing automated tests in a CI script, for a team with no such infrastructure yet.
- **Documentation that didn't keep up with the code.** A missing page, a stale table, a guide
  describing old behavior: that's the job of a separate docs-sync workflow, if the repo has one —
  not this PR. Wrong text the *diff itself* wrote is still reviewable.
