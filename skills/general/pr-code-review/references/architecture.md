# Axis 2 — Architecture

> Architecture here isn't about "enterprise layers". It's one question:
> **"how many places would I have to touch to change one thing?"**
> If the answer is more than one, something's off.

---

## 2.1 No loose values wandering through the code

Every codebase has values that describe **this particular deployment/configuration**: an API
base URL, a timeout, a limit, a feature threshold, a magic size. They change independently of
logic and shouldn't be scattered.

- [ ] 🟠 **Magic number/string in the middle of logic.** Every literal that isn't `0`, `1`, `-1`,
      or an obviously self-explanatory value needs a name:
      ```
      // bad — what is 0.9? what is 3?
      if (score > 0.9) { flag(); }
      retry(url, 3);

      // good
      if (score > FRAUD_SCORE_THRESHOLD) { flag(); }
      retry(url, MAX_RETRY_ATTEMPTS);
      ```
- [ ] 🟠 **The same value duplicated in two places.** That's the definition of a future bug — a
      value changed in one spot and forgotten in another (a constant in code vs. the same number
      repeated in a config file, a default duplicated between a client and a server). If the diff
      makes an existing duplication worse, that's a finding.
- [ ] Related constants grouped sensibly (a config object/module, a constants file, an enum) —
      not sprinkled as bare literals across unrelated files.
- [ ] 🟠 **Hardcoded local/absolute file path** (someone's machine, an environment-specific
      directory). Use a configured path or environment variable instead.
- [ ] Config that already lives in a dedicated file (JSON/YAML/TOML/env) isn't duplicated in code.
      One source of truth per value.
- [ ] Secrets, tokens, and credentials never appear as literals in source, even "temporarily."

---

## 2.2 Who knows about whom (coupling)

Dependencies should point in one consistent direction end to end (entry point → orchestration →
business logic → low-level/IO). Never sideways in a way that creates a cycle, and never backward.

- [ ] 🔴 **A circular dependency between modules** (A depends on B which depends on A). This is
      always worth flagging regardless of language — it blocks independent testing and reasoning.
- [ ] 🟠 **A low-level/leaf module reaching back into a high-level one** to get context it should
      have been handed instead (pass the specific value/interface it needs, not a reference to
      the orchestrator).
- [ ] 🟠 **Business logic that knows about a specific transport/UI/framework detail** it shouldn't
      need to (e.g., a domain function importing an HTTP framework type just to read one field).
- [ ] Coordination between independent components happens at a clear composition point (the
      entry point, a router, a controller) — not by one component reaching in and calling another
      component's internals directly.
- [ ] Dependencies are passed in explicitly (constructor/parameter/injection) rather than fetched
      from a global registry or static accessor.

---

## 2.3 Singletons and global state

- [ ] 🟠 A new global singleton / static accessor pattern (`getInstance()`-style) for something
      that holds mutable state: this hides dependencies (anything, anywhere, can reach in and
      mutate it) and makes testing and parallel execution harder. Prefer constructing once at the
      composition root and passing the instance down.
- [ ] 🔴 **Mutable global/static state** written from multiple places with no clear owner.
      A `static final`/`const` (a true constant) is fine; a mutable `static` variable is not.
- [ ] Duplicated state: the same fact stored in two fields/variables that must be kept in sync
      manually. Store it once and derive the rest.

---

## 2.4 "Utils", "Helpers", "Manager" files

- [ ] 🟠 A new file named `Utils`, `Helpers`, `Misc`, `Common`, or similar catch-all: **push back
      on the name**. It's a bucket where everything gets dropped and nothing gets found; within a
      few months it's hundreds of unrelated lines.
      **Instead:**
      - if it's math/calculation for one domain concept → name it after that concept
        (`PricingMath`, `DateRange`)
      - if it's a conversion used by exactly one component → a private method **inside** that
        component
      - if it's a genuinely shared, cohesive set of pure functions → a real name for that one
        subject
      - if it's a constant → a constants module/file
- [ ] A legitimate utility module (pure functions only, no state) should have a name that
      describes **one** subject, not "misc stuff."
- [ ] 🟠 A "Manager"/"Handler" class that only forwards calls to other objects (a layer with no
      responsibility of its own): call out the unnecessary indirection.
- [ ] 🟡 A new file placed outside the project's established module layout needs to justify why
      it lives where it does.

---

## 2.5 One responsibility per unit

- [ ] 🟠 A module/class that owns two unrelated responsibilities should probably be two — check
      whether they need to change, be tested, or be deployed independently.
- [ ] 🟠 A central "god" file/class (a top-level orchestrator, a main entry point) accumulating
      business logic, calculations, or conversions that belong to a more specific module. The
      orchestrator should **assemble and wire**, not compute.
- [ ] A function/command/handler does one action. Something doing three unrelated things should
      be composed from three smaller pieces.

---

## 2.6 Testability

- [ ] 🟡 Pure computation (parsing, formatting, deciding an outcome from inputs, resolving
      geometry/business rules) can be extracted into a small, side-effect-free function — and
      then it's trivially unit-testable. Logic tangled together with IO/hardware/network calls
      can't be tested in isolation.
- [ ] 🟡 For a larger new component, it's fair to suggest separating the "what to do" (pure logic)
      from the "how it talks to the outside world" (an interface/port with a real implementation
      and a fake/mock one for tests) — **a suggestion, never a requirement** inside a single PR;
      it's too large a refactor to demand at review time.
- [ ] Code shouldn't require live external dependencies (network, hardware, a real database) just
      to run its unit tests — that's what fakes/mocks/test doubles are for.

---

## 2.7 File organization

- [ ] New files land in the location the project's existing layout implies (mirror sibling
      modules) rather than at the root or in an unrelated folder.
- [ ] One file per public type/class where that's the project's convention; filename matches the
      primary exported name.
- [ ] 🟡 A proliferation of very small, single-purpose files can be as hard to navigate as one
      giant file — if the project already groups related small units together, follow that
      pattern instead of adding one more tiny file per action.

---

## Sources

- [Clean Architecture — Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Dependency Inversion Principle](https://en.wikipedia.org/wiki/Dependency_inversion_principle)
- [Refactoring Guru — Code Smells](https://refactoring.guru/refactoring/smells)
