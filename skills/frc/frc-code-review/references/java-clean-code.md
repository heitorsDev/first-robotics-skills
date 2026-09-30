# Axis 1 — Java and clean code

> The goal of this axis: next year's code has to be readable by a student who hasn't joined the
> team yet. Almost nothing here is 🔴 — this is where habits get taught, not where the robot gets
> saved.
> Never let an item from this axis crowd out an FRC-axis finding.

---

## 1.1 Names

A name is the comment that never goes stale.

- [ ] Class in `PascalCase`, a noun: `Elevator`, `SwerveSubsystem`, `AutoAlign`.
- [ ] Method in `camelCase`, starting with a **verb**: `raiseToHeight`, `getAngleDegrees`,
      `atSetpoint`. 🟡 A method named `elevator()` doesn't say what it does.
- [ ] Variable in `camelCase`, saying **what it is, with the unit when relevant**:
      `targetHeightCm`, `speedMetersPerSecond`. Avoid `x`, `temp`, `aux`, `value2`.
- [ ] Constant: `public static final` in `UPPER_SNAKE_CASE` (`DRIVER_CONTROLLER_PORT`) — or the
      `k` prefix (`kDriverControllerPort`), the classic WPILib style. 🟡 What matters is *not
      mixing the two styles in the same file*; follow whatever the file already uses.
- [ ] Package in all lowercase: `frc.robot.subsystems`.
- [ ] Booleans read like a question: `hasGamePiece`, `atSetpoint`, `isRed` — not `piece`, `flag`.
- [ ] 🟡 A name shouldn't lie: if `resetGyro()` also resets the pose, either rename it or split it
      into two functions.
- [ ] If the repo mixes two human languages in identifiers/comments on purpose (documented
      somewhere in the repo), don't flag that as a problem by itself. Only flag 🟡 when the mixing
      happens *within a single identifier* (`getVelocidadeSpeed`) or makes a name ambiguous.

---

## 1.2 Formatting

- [ ] Indentation consistent with the file (check what the project's own style already uses).
- [ ] Braces `{}` **always**, even for a one-line `if`. Without them, whoever adds a second line
      later creates a silent bug.
- [ ] An overly long line (> ~120 columns) wrapped at a sensible point.
- [ ] No duplicate blank lines, no trailing whitespace.
- [ ] Imports actually used, no `import *`, no import of something that was removed.
- [ ] **Practical rule:** bundle ALL formatting findings into a **single** 🟡 item at the end of
      the report. Never produce 6 separate spacing findings — the reader stops reading.
- [ ] 🟡 A recurring valid suggestion: adopt an auto-formatter (e.g. Spotless with
      `googleJavaFormat`) in `build.gradle` so this category stops showing up in review.

---

## 1.3 Comments

A good comment explains **why**. A bad comment repeats what the code already says.

```java
// ❌ useless — reads the code and says the same thing
// set the motor to speed
motor.set(speed);

// ✅ useful — explains the decision the code can't show on its own
// Clamped to 50% because above that the elevator hits the hard stop before the PID can brake.
motor.set(MathUtil.clamp(speed, -0.5, 0.5));
```

- [ ] 🟡 A comment that repeats the code: suggest removing it.
- [ ] 🟠 A comment that **contradicts** the code (says 0.5, code uses 0.8): always report it — it's
      a sign the change was made halfway.
- [ ] Javadoc (`/** ... */`) on **public** subsystem methods and on commands: one sentence saying
      what it does, `@param` with **units** ("height in centimeters"), and what the command
      considers "done."
- [ ] 🟠 **Commented-out code doesn't belong in the repository.** Git history already keeps it. A
      commented block "in case it's needed again" rots and confuses.
- [ ] New `TODO` / `FIXME` comments need to say who/what. `// TODO: fix this` with no context is
      🟡.
- [ ] A well-named constant for a magic number **is** the documentation — prefer naming it over
      commenting it.

---

## 1.4 Method structure

- [ ] 🟡 A method that's too long (more than ~40 lines, or doing 3 different things): suggest
      splitting it, pointing at **where** to cut ("lines 30–55 are just motor configuration, that
      could become `configureMotor()`").
- [ ] Deep nesting (`if` inside `if` inside `for`): suggest an *early return*.
      ```java
      // ❌
      if (hasGamePiece) { if (atSetpoint) { shoot(); } }
      // ✅
      if (!hasGamePiece) return;
      if (!atSetpoint) return;
      shoot();
      ```
- [ ] 🟠 **Duplicated code** (the same block copied in 2+ places): report it. Changing one copy
      and forgetting the other is the single most common bug on a robotics team. Suggest
      extracting a method or a command factory.
- [ ] A method does one thing. A method that reads a sensor **and** moves a motor **and**
      publishes telemetry should be three methods.
- [ ] `final` on fields that don't change after construction — lets the compiler enforce it.
- [ ] Minimum visibility: `private` by default; `public` only for what's actually the subsystem's
      interface.

---

## 1.5 Errors, nulls, and types

- [ ] 🔴 An empty `catch (Exception e) {}` — swallows a hardware failure and the robot "just
      doesn't work" with nobody knowing why. At minimum,
      `DriverStation.reportError(...)`.
- [ ] 🟠 A `catch` that only does `e.printStackTrace()` inside the periodic loop: turns into spam
      and hides the problem. Report via `DriverStation.reportWarning/Error`, which shows up on
      the Driver Station.
- [ ] 🟠 `.get()` on an `Optional` without checking `isPresent()` (the classic case:
      `DriverStation.getAlliance()`). Use `isPresent()`, `orElse(...)`, or `ifPresent(...)`.
- [ ] Comparing `double` with `==` doesn't work. Use a tolerance / `atSetpoint()`.
- [ ] Integer division where a decimal was intended: `1 / 2` is `0`. Write `1.0 / 2`.
- [ ] 🟡 An instance field that could be a local variable (used in only one method) — reduces
      shared state.
- [ ] No mutable `static` (`public static double currentSpeed`) — see axis 3.

---

## 1.6 Dead code

- [ ] 🟡 A variable, field, import, method, or class **added in the diff and never used**. If it's
      preparation for something coming later, a comment saying so is fine; otherwise, remove it.
- [ ] If the repo already has commands that aren't bound to any button or any auto routine, and
      the diff **adds another orphan command**, a 🟡 asking where it will be used is fair.
- [ ] A parameter received and ignored by a method: 🟠 (usually a sign of a real bug).

---

## 1.7 What **not** to report on this axis

To keep the review useful and short:

- Personal style preference that the repo has already settled another way.
- Rewriting something that works just because a "more elegant" form exists.
- Comments in a non-English language, when the repo documents that as accepted practice.
- Micro-optimization with no impact on the 20 ms loop.
- Formatting, item by item (bundle it into one, see 1.2).

---

## Sources

- [Style Guide — WPILib](https://docs.wpilib.org/en/stable/docs/contributing/frc-docs/style-guide.html)
- [wpilibsuite/styleguide (official WPILib formatting)](https://github.com/wpilibsuite/styleguide)
- [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html)
