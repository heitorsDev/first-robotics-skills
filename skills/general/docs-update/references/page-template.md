# Page template

Fixed headings. They are what makes an update surgical: you rewrite the one section the change
touched and leave the rest of the page — including anything a human wrote — untouched.

Write the headings in the docs language (`state.json.language`). The **order and meaning** below are
fixed; the wording is translated.

## Component page (`10-components/*.md`)

```markdown
# <Name>

> One sentence: what this is and why it exists.

## What it is
Plain prose. Where it sits in the system, what problem it solves, what it is not.

## How it works
The mechanism. Enough for a reader to predict its behaviour without opening the source.
Source files: `path/to/file.ext`, `path/to/other.ext`.

## Interface
What the rest of the system may call, and what it gets back. Public functions, commands,
events, endpoints — whatever "interface" means here.

## Configuration
Constants, IDs, ports, tunables. Value, unit, and where it lives.

| Item | Value | Where |
|---|---|---|
| `kMaxSpeed` | 2.0 m/s | `Constants.java` |

## Gotchas
Non-obvious behaviour. Things that already bit someone. Two values that must be kept in sync.
Anything a reader would otherwise get wrong.

---
_Updated at `<short-sha>` · <YYYY-MM-DD>_
```

## Reference page (`30-reference/*.md`)

Tables first, prose only where a table cannot carry the meaning. Every row: name, value, unit,
source file. No narrative.

## Guide page (`20-guides/*.md`)

```markdown
# How to <task>

> When you need this.

## Before you start
Prerequisites.

## Steps
1. …
2. …

## Verify
How you know it worked.

## If it goes wrong
Known failure modes and what they mean.

---
_Updated at `<short-sha>` · <YYYY-MM-DD>_
```

## Operations page (`40-operations/*.md`)

Same shape as a component page, with `## Configuration` covering env vars, secrets and triggers, and
`## Gotchas` covering failure modes and how to roll back.

## Section index (`<section>/README.md`)

```markdown
# <Section title>

<!-- docs-update:index-start -->
- [Elevator](elevator.md) — two-motor lift, position control in cm.
- [Manipulator](manipulator.md) — brushed arm with an absolute encoder.
<!-- docs-update:index-end -->
```

## Global index (`docs/index.md`)

```markdown
# Documentation

> What this repository is, in two sentences.

<!-- docs-update:index-start -->
## Overview
- [Getting started](00-overview/getting-started.md) — install, build, run.
- [Architecture](00-overview/architecture.md) — the map.
- [Glossary](00-overview/glossary.md) — terms.

## Components
- [Elevator](10-components/elevator.md) — two-motor lift, position control in cm.
<!-- docs-update:index-end -->
```

## Deprecated page

Do not delete. Put this directly under the title, keep the body as history, and move the entry to
the bottom of its section index:

```markdown
> **Deprecated.** Removed from the code in `<short-sha>` (<YYYY-MM-DD>). Kept for historical
> reference — it no longer describes anything that exists.
```

## Writing rules

- Present tense, active voice. "The subsystem caps the speed", not "the speed is capped".
- A number in the docs must exist in the code. If you cannot point at the line, do not write it.
- Technical terms stay in their original form and get explained the first time they appear on the
  page; add them to the glossary too.
- No "simply", "just", "obviously". The reader is new to this, not careless.
- Link sideways: a component page that mentions another component links to its page.
