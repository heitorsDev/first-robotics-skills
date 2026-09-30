---
name: docs-update
description: Keeps a documentation-only branch in sync with the code branch and rewrites the docs/ folder from the changes that came in. Merges the source branch (master/main) into the docs branch, diffs it against the last documented commit, routes each changed file to a section page, and regenerates the index files. Use when asked to "update the docs", "sync the docs branch", "document what changed", "atualizar a documentação", or when /docs-update is invoked.
license: MIT
metadata:
  scope: repository-agnostic
  writes: docs/ on the docs branch only
---

# Docs Update

You keep a **documentation branch** in step with a **source branch**. The source branch holds the
code; the docs branch holds the same code *plus* a `docs/` folder. Merges only ever go
**source → docs**, never back.

Every run answers one question: *what changed in the code since the last time we documented it, and
which pages have to change because of it?*

This skill is repository-agnostic. Nothing about the layout, the routing or the language is
hardcoded — it is discovered on the first run and persisted in `docs/.docsync/`.

---

## Rules that outrank everything else

1. **Never push.** Commit on the docs branch and print the push command. The human pushes. (This
   assumes a human is there to run it — see "Running unattended" below for what changes, and what
   doesn't, when nobody is.)
2. **Never touch the source branch.** No commits, no merges into it, no edits to files outside
   `docs/` while on the docs branch. Merging documentation *back* into the source branch, when a
   repository wants that, happens through a reviewed Pull Request opened by CI — never by you.
3. **Only document what actually changed.** A file in the diff is the *trigger*; the page content
   comes from reading the real file. A file that did not change gets no page edit.
4. **Never invent.** If the diff shows a constant renamed but you cannot tell why, document what it
   is, not why you guess it exists. No speculative behaviour, no invented units, no made-up defaults.
5. **Preserve human prose.** Pages accumulate hand-written explanation. Rewrite the sections the
   change touches; leave every other line alone.
6. **Stop and ask** on a merge conflict, a dirty working tree, or a diff you cannot make sense of.
   Do not guess your way through.

---

## Running unattended

A team can wire this skill into an autonomous agent in their own CI — the same way OffSeason_2026
runs it from a GitHub Action after every merge to the default branch, instead of a human typing
`/docs-update`. "Never push" (Rule 1) was written for a human at a keyboard; it does not become
optional just because nobody's there to run the printed command.

- **The default stays "never push," even unattended.** If the calling system prompt says nothing
  about it, stop after committing on the docs branch and report what you would push and why —
  don't push because nobody's around to tell you not to.
- **A CI harness may grant a different behavior explicitly.** A common pattern: the human-facing
  skill run stops at "committed, here's the push command" as always, while a *separate* CI step —
  outside this skill, written by the team wiring it up — takes that commit, pushes it to a
  `docs-sync/<sha>`-style branch, and opens the PR back to the source branch itself. If your
  calling system prompt tells you to push and open that PR yourself instead, that's an explicit
  override for that environment, not a default to assume.
- **Stop-and-ask (Rule 6) becomes decide-and-record.** A merge conflict, a dirty working tree, or a
  diff you can't make sense of still isn't something to guess your way through silently — but
  there's nobody to answer a question. Make the most conservative call available (usually: stop,
  commit nothing, explain why in your final output) and say so plainly, so a human reviews it after
  the fact instead of you blocking mid-run waiting for an answer that won't come.
- See `examples/ci/README.md` (repo root) for a concrete, copy-pasteable GitHub Actions workflow
  implementing this exact pattern.

## Step 0 — Preconditions

Resolve where this skill's scripts live. It is installed globally for local use and vendored into
`.claude/skills/` in repositories whose CI runs it — the same commands must work in both:

```bash
SKILL_DIR=~/.claude/skills/docs-update
[ -d "$SKILL_DIR" ] || SKILL_DIR=.claude/skills/docs-update
```

Every `bash "$SKILL_DIR"/scripts/...` below assumes that variable is set in the shell you run.

```bash
git status --short          # must be empty
git rev-parse --abbrev-ref HEAD
```

Dirty tree → stop and tell the user to commit or stash. Do not stash for them.

When a repository vendors this skill, the vendored copy is the one CI reads. Change the global copy
and the vendored one together, or they drift apart silently.

---

## Step 1 — Sync the docs branch

```bash
bash "$SKILL_DIR"/scripts/sync-branch.sh
```

Resolution order for the branches: explicit flags → `docs/.docsync/state.json` → `origin/HEAD` →
`main`/`master`; docs branch defaults to `docs`. Override with `--source` / `--docs`.

The script fetches, checks out the docs branch (creating it from the source branch if it does not
exist), merges the source branch, and prints the **source HEAD sha**. Keep that sha — Step 6 needs
it.

Exit code `2` means merge conflict. Print the conflicting paths and stop. Conflict resolution is
the user's call, not yours.

---

## Step 2 — Bootstrap, or load state

If `docs/.docsync/state.json` does not exist, this is the first run:

```bash
bash "$SKILL_DIR"/scripts/init-docs.sh --source <source> --language <code>
```

Pick `--language` from what the repository already speaks: its README, its comments, its existing
docs. When the signals conflict, ask. Everything the skill writes from then on uses that language —
`state.json.language` is the single source of truth for it, not this file.

The scaffold is the structure in `references/layout.md`. Read it now if you have not.

On a first run you **do not** document the whole repository at once. Write the section indexes,
`00-overview/architecture.md` and `00-overview/getting-started.md` from the current state of the
code, and say so in the report.

The rest of the existing code is **not** covered by later incremental runs — it is already written,
so it never appears in a diff. It is covered by backfill runs; see the section below. Say that in
the report too, so nobody waits for documentation that would never arrive.

---

## Step 3 — Get the changes

```bash
bash "$SKILL_DIR"/scripts/docs-diff.sh
```

Diffs `state.last_synced_sha .. source HEAD`, minus `docs/` itself, build output, lockfiles and
binaries (plus anything in `state.ignore`). `--files-only` skips the patch body when the diff is
huge; `--context N` widens it.

`### RESULT: nothing new to document` → stop here and say so. No empty commit, no changelog entry.

### Read before you write

A diff lies by omission. Before editing any page:

- Read each changed file **in full**, not just the `+` lines.
- Read the page you are about to edit, in full.
- Read `AGENTS.md` / `CLAUDE.md` / the root `README` if they exist — they hold the conventions.
- Follow the commit messages in `### COMMITS` for intent the code does not state.

---

## Backfill — documenting the code that never changes

An incremental run only touches what the diff names. Everything that already existed when the docs
branch was created is absent from every diff, so it would stay undocumented forever. A backfill run
is what covers it, and it is the only way a repository with history ever reaches full coverage.

Run one when you are asked for it, or when the repository has areas with no page.

1. Deal with the pending diff first, exactly as Steps 3 to 7 describe. A backfill does not excuse
   you from documenting what changed.
2. List what is undocumented: the source areas of the repository that no `map.json` route points at
   and that no page describes. Group them the way a reader would — a subsystem spread over three
   files is one area, not three.
3. Take **at most four**, most valuable first: components, then reference tables, then operations,
   then guides. Four is a deliberate ceiling — an unattended agent with an open-ended task is how a
   run ends up hanging.
4. Write each page from the template in `references/page-template.md`, reading the real files. The
   diff tells you nothing here; the code is the only source.
5. Add a `map.json` route for every page you create, so the next change to those files lands on the
   right page instead of the fallback.
6. Rebuild the indexes and write the changelog entry as usual, then run `finish-sync.sh`.
7. **End the changelog entry with what is still undocumented.** That list is how the next backfill
   run knows where to continue, and how a human knows when the backlog is finally empty.

Repeat backfill runs until that list comes back empty.

## Step 4 — Route each change to a page

`docs/.docsync/map.json`:

```json
{
  "routes": [
    { "glob": "src/**/subsystems/*.java", "page": "10-components/{basename}.md" },
    { "glob": ".github/**",               "page": "40-operations/ci.md" },
    { "glob": "build.gradle",             "page": "00-overview/getting-started.md" }
  ],
  "fallback": "00-overview/architecture.md"
}
```

Paths in `page` are relative to `docs/`. `{basename}` is the filename without extension,
lower-kebab-cased; `{dirname}` is the parent directory name. A file may match several routes — it
then updates all of them. First-match-wins does **not** apply.

**When a changed file matches no route**, do not dump it into the fallback reflexively. Decide:

- It deserves its own page → create it under the right section, add the page to the section index,
  and **append the new route to `map.json`**. The map learns; that is the point.
- It is a detail of something already documented → edit that page, add a route pointing at it.
- It genuinely changes nothing a reader needs → skip it, and list it under *Skipped* in your report.

Choosing the section is a judgement call. `references/layout.md` says what each section is for.

---

## Step 5 — Write the pages

Follow the page template in `references/page-template.md`. Fixed headings, so edits stay surgical:
you rewrite the section the change touched, not the page.

- Changed behaviour → rewrite that section, keep the rest.
- New file → new page from the template.
- Deleted file → do not delete the page silently. Mark it deprecated at the top, state which commit
  removed it, and move it to the bottom of its section index.
- Renamed file → rename the page, fix every inbound link, update its route in `map.json`.

Stamp the footer of every page you touched with the source sha and the date.

Write for someone who has not read the code. Technical terms stay in their original form and get
explained the first time they appear on the page — that is what `00-overview/glossary.md` is for;
add the term there too.

---

## Step 6 — Regenerate the indexes

Two levels, both generated, both delimited by markers:

```markdown
<!-- docs-update:index-start -->
...generated list...
<!-- docs-update:index-end -->
```

Only ever rewrite **between** the markers. Text outside them is the human's.

- `docs/index.md` — every section, and under each one every page with a one-line description.
- `docs/<section>/README.md` — the pages of that section, one line each.

A page that exists and is not linked from its section index is a bug. So is a link to a page that
does not exist. Check both before committing.

---

## Step 7 — Changelog, state, commit

Prepend an entry to `docs/CHANGELOG.md` (newest first):

```markdown
## <short-sha> — <YYYY-MM-DD>

<one line: what changed in the code>

- `10-components/elevator.md` — <what changed on the page>
- `40-operations/ci.md` — <what changed on the page>

Skipped: `path/to/file` (<why>)
```

Then:

```bash
bash "$SKILL_DIR"/scripts/finish-sync.sh --sha <source-head-sha>
```

It bumps `last_synced_sha` / `last_synced_at`, stages `docs/`, commits, and prints the push command.
Pass `--message` for a custom subject, `--no-commit` to only bump the state.

`last_synced_sha` is the whole machine. Bump it only for work you actually finished — a wrong value
silently skips commits that were never documented.

---

## Step 8 — Report

Short, in the docs language:

- branch synced, sha range covered
- pages created / updated / deprecated
- new routes added to `map.json`
- files skipped, and why
- `git push origin <docs-branch>` — the user runs it

---

## Documentation drift is not a code review finding

Stale docs belong to **this** skill, not to a pull request. A reviewer must not block a PR for not
updating `docs/`, and you must not open one for it. Code lands on the source branch; documentation
catches up on the docs branch, on the next run of this skill.
