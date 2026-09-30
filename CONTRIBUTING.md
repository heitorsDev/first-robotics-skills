# Contributing

## Layout

```
skills/
  general/<name>/            # valid for both FTC and FRC
  frc/frc-<name>/            # FRC-only, name prefixed frc-
  ftc/ftc-<name>/            # FTC-only, name prefixed ftc-
  _template/                 # scaffold source — don't edit skills in place, copy this
```

Each skill dir is a plain, harness-neutral skill: `SKILL.md` (+ optional `scripts/`, `references/`).
That's the canonical, hand-edited content. `.claude-plugin/plugin.json` and the three
`skills/{general,frc,ftc}/.claude-plugin/marketplace.json` files are **generated** by CI
(`scripts/ci/generate-marketplaces.sh`) — never edit them by hand, they get overwritten.

## Starting a new skill

```
./scripts/new-skill.sh <general|frc|ftc> <skill-name>
```

Scaffolds `skills/<scope>/<skill-name>/` from `skills/_template/`. FRC/FTC names must be
prefixed (`frc-...` / `ftc-...`); general names are bare.

## One skill, one PR

Every PR touches exactly one `skills/<scope>/<name>/`. The branch name decides the release
bump on merge:

| Branch prefix | Bump  |
|---|---|
| `fix/...`     | patch |
| `feat/...`    | minor |
| `release/...` | major |

Any other prefix (`chore/...`, `docs/...`) merges normally with no release.

## Merging

Two things gate a merge to `main`:

1. **Two collaborator reviews** (branch protection) — the human judgment call: does the skill
   do what it says, is the writing good, is the scope right.
2. **`ci.yml`** — a deterministic structural check (`scripts/ci/validate-skills.sh`), no content
   judgment: `SKILL.md` exists at the right path, its frontmatter parses and has `name` +
   `description`, the frontmatter name matches the folder, FRC/FTC prefixing is correct, and the
   name is unique across all three scopes.

On merge, `release.yml` reads the branch prefix, finds the one skill folder the PR changed,
tags it `<name>@x.y.z`, regenerates the `.claude-plugin` files, and cuts a GitHub Release.

## Installing a skill into a robot codebase

```
curl -fsSL https://raw.githubusercontent.com/heitorsDev/first-robotics-skills/main/install.sh | sh -s -- <skill-name>
```

Copies `skills/<scope>/<skill-name>/` into `.claude/skills/<skill-name>/` in the current repo —
the directory both Claude Code and opencode read. Claude Code users can instead add one of the
three marketplaces directly:

```
claude plugin marketplace add heitorsDev/first-robotics-skills --path skills/frc
claude plugin marketplace add heitorsDev/first-robotics-skills --path skills/ftc
claude plugin marketplace add heitorsDev/first-robotics-skills --path skills/general
```

The `frc` and `ftc` marketplaces each include the `general` skills too, so one add covers a team.
