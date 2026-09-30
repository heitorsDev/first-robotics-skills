# Axis 3 — CI/infra and scripts

Checklist for diffs touching things other than application code: CI workflows, shell scripts,
build/dependency configs, deploy configs, and docs the diff itself edits.

This axis only applies when the diff touches these kinds of files. If the diff is pure
application code, skip this file entirely.

---

## CI workflows (e.g. `.github/workflows/*.yml`, other CI config)

- 🔴 **Secret leaked into logs.** A secret/token interpolated directly into a shell step
  (`${{ secrets.X }}` inside a `run:` string, or an equivalent in other CI systems) can echo into
  the log. Pass secrets through environment variables instead, and avoid `echo`-ing them.
- 🔴 **Untrusted input triggers a privileged workflow.** A workflow that runs on a fork's PR event
  but checks out and executes that fork's code with write permissions/secrets (e.g. GitHub's
  `pull_request_target` combined with a PR-head checkout) is a critical finding — this is a
  well-known supply-chain vector. The safe pattern (e.g. plain `pull_request`, or splitting
  privileged steps into a separate workflow gated on review) should be used instead.
- 🟠 **Third-party action/step pinned to a moving tag** (`@v1`, `@latest`) instead of a fixed
  version or commit SHA — its content can change without notice.
- 🟠 **Broader permissions than the job needs.** Explicit permission scopes should list only what
  the job actually uses; a read-only job with write access is unnecessary privilege escalation.
- 🟠 **No concurrency/cancellation guard** on a workflow triggered by every push/PR update: each
  push queues another run and burns CI minutes for no benefit.
- 🟡 An overly broad trigger (e.g. `on: push` with no branch/path filter) runs the workflow on
  changes that don't need it.

## Shell scripts (`*.sh`, `*.bash`)

- 🟠 **Missing strict-mode flags** (`set -euo pipefail` or the equivalent): the script keeps
  running after a failing command and silently reports a wrong result. Legitimate exception: a
  script that deliberately handles exit codes itself — `set -uo pipefail` without `-e` there is
  intentional, not a finding.
- 🟠 **Unquoted variable expansion** (`$VAR` instead of `"$VAR"`): breaks on paths with spaces or
  glob characters.
- 🟡 An external command used without checking it exists first
  (`command -v tool >/dev/null` before relying on `tool`).
- 🟡 Error output going to stdout instead of stderr (`>&2`), which pollutes the script's actual
  output when it's piped or captured.

## Build and dependency configuration (package manifests, lockfiles, build scripts)

- 🔴 **Two files that must agree on a version disagree** (e.g. a runtime pinned one place, a
  compiler/toolchain pinned to an incompatible version elsewhere): the project builds locally and
  fails elsewhere, or vice versa.
- 🟠 A new dependency added with no justification in the PR: extra weight, and one more thing that
  can break on the next upgrade.
- 🟡 A dependency version left as an open range (`^`, `~`, `*`, `latest`) where the project
  otherwise pins exact versions — makes the build non-reproducible.

## Deploy/runtime configuration (`*.json`, `*.yaml`, `*.toml` config files shipped with the app)

- 🔴 Invalid syntax (trailing comma, duplicate key, wrong type): the app won't start with this
  file. Worth running it through a real parser rather than eyeballing it.
- 🟠 A configuration value changed with nothing in the PR explaining why — an unexplained tuning
  change is impossible to review or revert with confidence later.

## Markdown and docs the diff itself edits

- 🟠 An instruction that's ambiguous or contradicts another file in the repo (e.g. a README says
  one port/command and the actual config uses another). Wrong documentation is worse than missing
  documentation.
- 🟠 A documented command that doesn't exist or doesn't run as written. Test it before approving.
- 🟡 A broken link, or a path referenced that no longer exists.
- Don't report writing style, line length, or Markdown formatting preference.

## What **not** to review here

- YAML/JSON formatting that an autoformatter would fix.
- Personal file-organization preference with no concrete impact.
- Missing automated tests in a CI script, if the project doesn't have that kind of infra at all
  and the PR isn't the place introducing it.
- **Documentation that didn't get updated alongside the code.** A missing page, a stale table, a
  guide describing old behavior — that's the job of a dedicated docs-sync process, not a gate on
  this PR. Wrong text that the diff **itself** wrote or edited stays in scope.
