# Axis 1 — Clean code

> Goal of this axis: next season's code has to be readable by a student who hasn't joined the team
> yet. Almost nothing here is 🔴 — this is where you teach habits, not where you save the robot.
> Never let an item from this axis crowd out an FTC-standards finding.

Applies equally to Java and Kotlin FTC codebases — call out language-appropriate idioms where the
diff uses them (e.g. `data class`/`val` in Kotlin vs. a plain field-and-getter class in Java), but
don't push one language's style onto the other's file.

---

## 1.1 Names

A name is the comment that never goes stale.

- [ ] Class in `PascalCase`, a noun: `Lift`, `MecanumDrive`, `AutoAlign`.
- [ ] Method in `camelCase` (or Kotlin's usual style), starting with a **verb**:
      `raiseToPosition`, `getHeadingDegrees`, `isAtTarget`. 🟡 A method called `lift()` doesn't say
      what it does.
- [ ] Variable in `camelCase`, saying **what it is, with the unit when there is one**:
      `targetHeightInches`, `driveSpeedInchesPerSecond`. Avoid `x`, `temp`, `val2`.
- [ ] Constant: `static final` (Java) / `const val` (Kotlin) in `UPPER_SNAKE_CASE`. 🟡 What matters
      is *not mixing two constant-naming styles in the same file*; follow whatever's already there.
- [ ] Package lowercase only, following the `org.firstinspires.ftc.teamcode` convention the SDK
      expects.
- [ ] Boolean reads like a question: `hasGamePiece`, `isAtTarget`, `isRedAlliance` — not `piece`,
      `flag`.
- [ ] 🟡 A name that lies: if `resetEncoder()` also resets the target position, either the name
      changes or the method splits in two.
- [ ] `@TeleOp`/`@Autonomous` `name=` and `group=` attributes are descriptive and unique — two
      OpModes with the same displayed name confuse the Driver Station's op-mode picker.

---

## 1.2 Formatting

- [ ] Indentation consistent with the file (Android Studio's default Java/Kotlin style is common
      in FTC repos — follow whatever the file already uses).
- [ ] Braces `{}` **always**, even for a one-line `if`. Without them, whoever adds a second line
      later creates a silent bug.
- [ ] Very long lines (> ~120 columns) wrapped at sensible points.
- [ ] No duplicated blank lines, no trailing whitespace.
- [ ] Imports used, no wildcard imports, no leftover import for removed code.
- [ ] **Rule of thumb:** fold ALL formatting findings into a **single** 🟡 item at the end of the
      report. Never produce six separate spacing findings — the reader stops reading.
- [ ] 🟡 A recurring, valid suggestion: adopt an auto-formatter (`ktlint`/Spotless) in
      `build.gradle` so this category stops showing up in review at all.

---

## 1.3 Comments

A good comment explains **why**. A bad comment repeats what the code already says.

```java
// ❌ useless — reads the code and says the same thing
// set the motor to power
liftMotor.setPower(power);

// ✅ useful — explains a decision the code alone can't show
// Clamped to 60% because above that the lift outruns the PID and slams the hard stop.
liftMotor.setPower(Range.clip(power, -0.6, 0.6));
```

- [ ] 🟡 Comment that repeats the code: suggest removing it.
- [ ] 🟠 Comment that **contradicts** the code (says 0.5, code uses 0.8): always report — it's a
      sign the change was made halfway.
- [ ] Javadoc/KDoc on **public** methods of a subsystem/hardware-wrapper class and on OpModes: one
      sentence on what it does, units on parameters ("height in inches"), and what "done" means
      for anything that runs to completion.
- [ ] 🟠 **Commented-out code doesn't belong in the repo.** Git history already keeps it. A block
      commented "in case we need it later" rots and confuses.
- [ ] New `TODO`/`FIXME` needs to say who/what. `// TODO: fix this` with no context is 🟡.
- [ ] A well-named constant for a magic number **is** the documentation — prefer naming it over
      commenting it.

---

## 1.4 Method structure

- [ ] 🟡 Very long method (more than ~40 lines, or doing 3 different things): suggest splitting,
      pointing out **where** to cut ("lines 30–55 are just motor setup, that could become
      `configureDriveMotors()`").
- [ ] Deep nesting (`if` inside `if` inside `for`): suggest an early return.
      ```java
      // ❌
      if (hasGamePiece) { if (isAtTarget) { release(); } }
      // ✅
      if (!hasGamePiece) return;
      if (!isAtTarget) return;
      release();
      ```
- [ ] 🟠 **Duplicated code** (the same block copied in 2+ places): report it. Changing one copy
      and forgetting the other is the most common bug in a student codebase. Suggest extracting a
      method or a shared factory.
- [ ] One method does one thing. A method that reads a sensor **and** moves a motor **and**
      pushes telemetry should probably be three.
- [ ] `final`/`val` on fields that don't change after construction — let the compiler enforce it.
- [ ] Minimal visibility: `private` by default; `public` only for what's actually the class's
      interface.

---

## 1.5 Errors, nulls, and types

- [ ] 🔴 Empty `catch (Exception e) {}` — swallows a hardware failure and the robot "just doesn't
      work" with nobody knowing why. At minimum log it or surface it through telemetry.
- [ ] 🟠 A `catch` that only does `e.printStackTrace()` inside the main loop: turns into spam and
      hides the problem. Surface it through telemetry so it's visible on the Driver Station.
- [ ] 🟠 `Optional`/nullable value accessed without a null/presence check where a null return is
      documented as possible (e.g. a vision pipeline result that can legitimately be absent).
- [ ] Comparing `double`/`float` with `==` doesn't work reliably. Use a tolerance or the SDK's own
      `isAtTarget`-style helper if one exists.
- [ ] Integer division where a decimal was intended: `1 / 2` is `0`. Write `1.0 / 2`.
- [ ] 🟡 Instance field that could be a local variable (used in one method only) — reduces shared
      state.
- [ ] No mutable `static` fields carrying state between OpMode runs unless deliberately and
      explicitly used for that — see `clean-architecture.md` 3.3.

---

## 1.6 Dead code

- [ ] 🟡 Variable, field, import, method, or class **added in the diff and never used**. If it's
      preparation for something coming later, a comment saying so is fine; otherwise, remove it.
- [ ] An OpMode added in the diff that isn't wired to run from anywhere meaningful (not a real
      competition routine, no clear test purpose stated) — worth a 🟡 asking where it'll be used.
- [ ] A parameter received and ignored by a method: 🟠 (usually a sign of a real bug).

---

## 1.7 What **not** to report on this axis

To keep the review useful and short:

- Personal style preference the repo has already settled differently.
- Rewriting something that works just because a "more elegant" form exists.
- Micro-optimization with no measurable impact on loop responsiveness.
- Formatting, item by item (fold into one, see 1.2).

---

## Sources

- [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html)
- [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html)
- [FTC SDK documentation](https://ftc-docs.firstinspires.org/en/latest/)
