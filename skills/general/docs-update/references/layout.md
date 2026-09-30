# docs/ layout

Numbered sections. The number fixes the reading order and keeps the folder sorted the way a newcomer
should walk it: what the thing is → what it is made of → how to work on it → the exact numbers → how
to run it in production.

```
docs/
├── index.md                    # global index (generated between markers)
├── CHANGELOG.md                # one entry per sync, newest first
├── 00-overview/
│   ├── README.md               # section index
│   ├── getting-started.md      # install, build, run, test
│   ├── architecture.md         # high-level map, entrypoints, data flow
│   └── glossary.md             # domain and technical terms
├── 10-components/
│   ├── README.md
│   └── <component>.md          # one page per module / service / subsystem
├── 20-guides/
│   ├── README.md
│   └── <task>.md               # task-shaped: "how to add X", "how to debug Y"
├── 30-reference/
│   ├── README.md
│   └── <topic>.md              # tables and exact values: config, env vars, API, IDs, ports
├── 40-operations/
│   ├── README.md
│   └── <topic>.md              # CI, deploy, release, runbooks, monitoring
└── .docsync/
    ├── state.json              # sync state — the skill's memory
    └── map.json                # source path → page routing
```

## What goes where

| Section | Answers | Typical trigger in a diff |
|---|---|---|
| `00-overview` | *What is this and how do I start?* | build files, root README, entrypoint, project-wide wiring |
| `10-components` | *What is this part and how does it work?* | a module / class / service / subsystem changed |
| `20-guides` | *How do I do this task?* | a workflow changed, or a repeated question deserves a written answer |
| `30-reference` | *What is the exact value?* | constants, config files, schemas, env vars, hardware maps, API surface |
| `40-operations` | *How does it ship and run?* | CI workflows, deploy scripts, containers, infra |

A section stays even when empty — its `README.md` says so. Empty sections are a to-do list, not
clutter.

## Adding a section

Only when a real body of pages does not fit any of the five. Number it in a free decade (`50-`,
`60-`), give it a `README.md` with the index markers, and link it from `docs/index.md`. Do not
renumber existing sections — links and routes point at those paths.

## Naming

- Files and folders: `lower-kebab-case.md`, no spaces, no accents, no uppercase.
- One page per concept, not per source file. Three classes that are one subsystem = one page.
- The page title (`# Heading`) may use the docs language freely, accents and all. Only the filename
  is constrained.

## state.json

```json
{
  "source_branch": "master",
  "docs_branch": "docs",
  "last_synced_sha": "8f50ade0...",
  "last_synced_at": "2026-09-25T12:00:00Z",
  "language": "pt-BR",
  "ignore": ["src/generated/**", "*.snap"]
}
```

| Field | Meaning |
|---|---|
| `source_branch` | branch that holds the code |
| `docs_branch` | branch this skill commits to |
| `last_synced_sha` | last source commit already documented — the diff boundary |
| `last_synced_at` | UTC timestamp of the last sync |
| `language` | language of everything the skill writes |
| `ignore` | extra git pathspecs to exclude from the diff, on top of the built-in ones |

`ignore` entries are plain globs (`src/generated/**`), not pathspecs — the script wraps each one in
`:(exclude)`.

## map.json

```json
{
  "routes": [
    { "glob": "src/**/subsystems/*.java", "page": "10-components/{basename}.md" },
    { "glob": "src/main/deploy/**",       "page": "30-reference/deploy-config.md" },
    { "glob": ".github/workflows/*",      "page": "40-operations/ci.md" },
    { "glob": "build.gradle",             "page": "00-overview/getting-started.md" }
  ],
  "fallback": "00-overview/architecture.md"
}
```

- `glob` — git-style pathspec, relative to the repository root.
- `page` — path relative to `docs/`. `{basename}` = filename without extension, lower-kebab-cased.
  `{dirname}` = parent directory name.
- Several routes may match one file; all of them fire.
- `fallback` is a last resort. A file landing there repeatedly means a route is missing — add it.
