# Axis 3 — Clean architecture

> Clean architecture here isn't about "enterprise layers". It's one question:
> **"how many places do I have to change to change one thing?"**
> If the answer is more than one, something's wrong.

---

## 3.1 Nothing hardware-specific lives loose in the code

An FTC robot doesn't have environment variables. The equivalent is the set of values that describe
**this particular robot**: hardware-map device names, gear ratios, encoder ticks-per-revolution,
max lift height, PID coefficients, servo open/close positions. They change when the hardware
changes, and they can't be scattered.

- [ ] 🟠 **A magic number in the middle of logic.** Every literal that isn't `0`, `1`, or `-1`
      needs a name:
      ```java
      // ❌ what is 2000? what is 0.6?
      if (encoderPos > 2000) { liftMotor.setPower(0.6); }

      // ✅
      if (encoderPos > LiftConstants.MAX_ENCODER_TICKS) {
        liftMotor.setPower(LiftConstants.HOLD_POWER);
      }
      ```
- [ ] 🟠 **The same value appearing in two places.** That's the definition of a future bug. A
      gear ratio used to convert encoder ticks to inches, defined once in a drive class and again
      (slightly differently) in an autonomous OpMode, is exactly this.
- [ ] Constants grouped in a dedicated class per subsystem/mechanism (`LiftConstants`,
      `DriveConstants`) as `public static final` (Java) / `const val` in an `object` (Kotlin) —
      keeps names short and makes it obvious who owns the value.
- [ ] 🟠 **Hardcoded file path** pointing at a specific machine or a specific phone's storage
      layout. Anything read from storage on-device should go through the SDK's own path helpers.
- [ ] Hardware-map device name strings: a constant per device, not the same literal string
      repeated across multiple `hardwareMap.get(...)` calls — see `ftc-standards.md` 2.2.
- [ ] Servo open/close positions, claw angles, and similar calibration values: named constants,
      not literals repeated at each call site.

---

## 3.2 Who knows whom (coupling)

The direction of dependencies should stay consistent:

```
OpMode  →  Subsystem/hardware-wrapper classes  →  Hardware (motors, servos, sensors)
```

Never the other way, never sideways.

- [ ] 🟠 **A subsystem/hardware-wrapper class doesn't read the gamepad directly.** Gamepad input
      is read in the OpMode and passed in as a value (a target speed, a boolean trigger) — not by
      handing the `Gamepad` object itself into a subsystem class. A class that reads the gamepad
      directly can't be reused between TeleOp and an autonomous test.
- [ ] 🟠 **A subsystem class doesn't reach back into the OpMode** that owns it (no back-reference
      to call telemetry or read match state). Pass in what's needed instead.
- [ ] 🟠 **Coordination between subsystems happens in the OpMode**, not by one subsystem class
      calling methods on another subsystem class directly. If a claw needs to know the lift's
      height, the OpMode reads both and decides — the claw class doesn't hold a reference to the
      lift class.
- [ ] Constructor-based setup (pass in the `HardwareMap` and configuration, build what's needed)
      rather than a class silently reaching for a global/static hardware reference.

---

## 3.3 Singletons and global state

- [ ] 🔴 **Mutable `static` field carrying state between loop iterations or between OpMode runs**
      (`public static double lastKnownPosition`): anything can write it, nobody can tell who did.
      `static final` (a true constant) is fine; a mutable `static` is not — and it's a classic way
      an autonomous OpMode's leftover state leaks into the next TeleOp run.
- [ ] 🟠 A `getInstance()`-style singleton wrapping hardware access: hides dependencies (any class
      can reach in and command a motor from anywhere) and makes the class harder to test in
      isolation. Prefer constructing the object once and passing it to what needs it.
- [ ] Duplicated state: the same piece of data stored in two fields that have to be kept in sync
      manually. Store it once and derive the rest.

---

## 3.4 "Utils", "Helper", "Manager" files

- [ ] 🟠 A new file named `Utils.java`, `Helpers.java`, `Misc.java`, `Tools.java`: **push back on
      the name**. It's a bucket everything falls into and nothing is findable in two months.
      **Instead:**
      - math for a specific purpose (path following, alignment) → `PathMath.java` /
        `AlignmentMath.java`
      - a unit conversion for one mechanism → a private method **inside** the class that owns it
      - a shared autonomous routine → `AutoRoutines.java` or similar
      - a value → a `Constants` class
- [ ] A legitimate utility class (pure functions, no state) should be `final` with a private
      constructor, and describe **one** topic in its name.
- [ ] 🟠 A "Manager"/"Handler" class that only forwards calls to other classes (a layer with no
      responsibility of its own): call out as unnecessary indirection.
- [ ] 🟡 A new file outside the usual subsystem/OpMode packages needs to justify the package it's
      placed in.

---

## 3.5 One responsibility per class

- [ ] A hardware-wrapper class = **one** piece of hardware that moves together. 🟠 If a class
      controls both a lift and a claw, it should probably be two — otherwise they can never be
      independently reasoned about or tested.
- [ ] 🟠 An OpMode turning into a god class: if it's doing trajectory math, PID tuning, or unit
      conversion inline, that logic belongs in a subsystem or a domain class. The OpMode should
      mostly **wire pieces together and read input**.
- [ ] A state-machine step does one thing. A step doing three unrelated things should probably be
      three steps.

---

## 3.6 Testability

- [ ] 🟡 Pure calculation (converting encoder ticks to inches, deciding a target position,
      resolving alignment geometry) can become a method with no `HardwareMap` dependency — and
      then it's testable with a plain JUnit test, no robot needed. Logic glued to a live motor
      handle can't be tested this way.
- [ ] 🟡 For a larger subsystem change, it can be worth suggesting an interface between the
      subsystem and the hardware it drives (a `LiftIO` interface with a real implementation and a
      fake/simulated one for tests) — **a suggestion, never a requirement**; it's too large a
      refactor to ask for inside a normal PR.
- [ ] Code that only works with hardware physically present shouldn't be the only path exercised
      by a repo's automated tests, if it has any.

---

## 3.7 File organization

- [ ] OpModes, subsystem/hardware-wrapper classes, and pure-logic classes each have a consistent
      home in the `teamcode` package tree — follow whatever layout the repo has already
      established rather than inventing a new one mid-PR.
- [ ] One public class per file, filename matching the class name.
- [ ] 🟡 A proliferation of very small, near-duplicate OpMode files (one per minor variant of the
      same routine) is worth flagging — a shared base class or a configurable parameter is usually
      cleaner than a new file per variant.

---

## Sources

- [FTC SDK documentation](https://ftc-docs.firstinspires.org/en/latest/)
- [FTC SDK sample OpModes (FtcRobotController samples)](https://github.com/FIRST-Tech-Challenge/FtcRobotController)
