# Axis 1 — Clean code

> Goal of this axis: code should be readable by someone who joins the project next month.
> Almost nothing here is 🔴 — this is where habits get taught, not where a build gets saved.
> Never let an item from this axis crowd out an architecture or infra finding.

This axis is language-agnostic. Apply the spirit of each check using whatever naming/formatting
conventions the target repo already follows — don't impose a foreign style.

---

## 1.1 Names

A name is the comment that never goes stale.

- [ ] Types/classes are nouns; functions/methods start with a **verb** and say what they do
      (`calculateTotal`, `isReady`, `fetchUser`). 🟡 A function named `data()` or `handle()`
      doesn't say what it does.
- [ ] Variables say **what** they hold, with a unit when relevant (`timeoutMs`, `totalCents`).
      Avoid `x`, `temp`, `tmp2`, `data`, `val`, `flag`.
- [ ] Booleans read like a question: `isReady`, `hasPermission`, `canRetry` — not `ready`, `flag`.
- [ ] Naming convention (`camelCase`, `snake_case`, `PascalCase`, prefix style for constants,
      etc.) is **consistent with the rest of the file/repo**. 🟡 when a diff introduces a second
      convention alongside an existing one — flag the inconsistency, not the convention itself.
- [ ] 🟡 A name that lies: if `resetCache()` also resets a counter, either the name changes or
      the function splits in two.
- [ ] Don't report language/dialect choice in identifiers or comments as a problem — that's a
      repo convention, not a code-review finding. Only flag it when it makes a single identifier
      internally ambiguous (mixing two languages inside the same name) or genuinely confusing.

---

## 1.2 Formatting

- [ ] Indentation and brace style consistent with the file's existing convention.
- [ ] Control-flow blocks are unambiguous — no single-line `if` without braces/indentation that
      invites a silent bug when a second line gets added later.
- [ ] Very long lines broken at sensible points.
- [ ] No duplicated blank lines, no trailing whitespace.
- [ ] Imports/includes are actually used; none left over from removed code; no wildcard imports
      where the project avoids them.
- [ ] **Rule of thumb:** bundle ALL formatting findings into a **single** 🟡 item at the end of
      the report. Never produce six separate whitespace findings — readers stop reading.
- [ ] 🟡 Recurring formatting noise is a good signal to suggest an autoformatter/linter in CI
      (e.g. Prettier, Black, gofmt, Spotless) so this category stops needing human review.

---

## 1.3 Comments

A good comment explains **why**. A bad comment repeats what the code already says.

```
// bad — just restates the line below it
// set the flag to true
isReady = true;

// good — explains a decision the code can't show on its own
// Capped at 3 retries: the upstream API rate-limits after that and returns 429s.
isReady = attempt < 3;
```

- [ ] 🟡 Comment that repeats the code: suggest removing it.
- [ ] 🟠 Comment that **contradicts** the code (says one thing, code does another): always
      report — it's a sign the change was made halfway.
- [ ] Public functions/methods that are part of an API surface have a short doc comment: what it
      does, parameter units/expectations, and what "done"/error means.
- [ ] 🟠 **Commented-out code doesn't belong in the repository.** Git history already keeps it.
      A block commented "in case we need it later" rots and confuses.
- [ ] New `TODO`/`FIXME` markers need to say who/what. A bare `// TODO: fix this` is 🟡.
- [ ] A well-named constant **is** the documentation — prefer naming over commenting.

---

## 1.4 Function/method structure

- [ ] 🟡 A function that's too long or doing 3+ unrelated things: suggest splitting, and point at
      **where** to cut ("lines 30–55 are just input validation, pull that into its own
      function").
- [ ] Deep nesting (`if` inside `if` inside a loop): suggest an early return/guard clause.
      ```
      // before
      if (hasItem) { if (isReady) { process(); } }
      // after
      if (!hasItem) return;
      if (!isReady) return;
      process();
      ```
- [ ] 🟠 **Duplicated code** (the same block copied in 2+ places): report it. Changing one copy
      and forgetting the other is one of the most common sources of bugs. Suggest extracting a
      shared function.
- [ ] One function does one thing. A function that reads input **and** transforms it **and**
      writes output should probably be three.
- [ ] Immutability where the language supports it (`final`/`const`/`readonly`) on values that
      never change after construction.
- [ ] Minimal visibility: private/internal by default; public only what's genuinely the module's
      interface.

---

## 1.5 Errors, nulls, and types

- [ ] 🔴 Empty catch/except block that swallows a failure silently — the caller has no way to
      know something went wrong. At minimum, log or re-raise with context.
- [ ] 🟠 A catch/except that only prints/logs inside a hot loop or request path: turns into log
      spam and hides the real problem. Report or surface it meaningfully instead.
- [ ] 🟠 Unwrapping an optional/nullable value without checking presence first (`.get()`,
      `.unwrap()`, non-null assertions) where the value can legitimately be absent.
- [ ] Comparing floating-point numbers with `==` doesn't work reliably — use a tolerance.
- [ ] Integer division where a fractional result was intended (`1 / 2 == 0` in many languages).
- [ ] 🟡 A field/instance variable that's only used inside one method could be a local variable —
      reduces shared state.
- [ ] No mutable global/shared state introduced casually (see axis 2, section 3, for the fuller
      treatment) — flag it here too when it's purely a code-quality smell rather than a coupling
      problem.

---

## 1.6 Dead code

- [ ] 🟡 A variable, field, import, function, or class added by the diff and never used. If it's
      preparation for something upcoming, a comment saying so is enough; otherwise remove it.
- [ ] An unused parameter that's accepted and ignored: 🟠 (this is often a real bug, not just
      style).

---

## 1.7 What **not** to report on this axis

To keep the review useful and short:

- Personal style preference that the repo has already settled a different way.
- Rewriting something that works just because a "more elegant" form exists.
- Micro-optimizations with no measurable impact.
- Formatting, item by item (bundle it, see 1.2).
- The comment/identifier language the repo already uses on purpose.
