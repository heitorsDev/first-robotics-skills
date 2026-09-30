# Axis 3 — Clean architecture

> Clean architecture here isn't about "enterprise layers." It's one question:
> **"how many places do I need to touch to change one thing?"**
> If the answer is more than one, something's wrong.

---

## 3.1 No loose values in the code (the robot's "environment variable")

A robot has no environment variable or `.env`. The equivalent here is the set of values that
describe **this specific robot**: CAN ID, control port, gear ratio, max height, PID gain, team
number. They change when the hardware changes, and they can't be scattered around.

- [ ] 🟠 **A magic number in the middle of logic.** Every literal other than `0`, `1`, or `-1`
      needs a name:
      ```java
      // ❌ what is 88.9? what is 35?
      if (height > 88.9) { ... }
      TalonFX motor = new TalonFX(35);

      // ✅
      if (height > ElevatorConstants.kMaxHeightCm) { ... }
      TalonFX motor = new TalonFX(ElevatorConstants.kMainMotorId);
      ```
- [ ] 🟠 **The same value appearing in two places.** That's the definition of a future bug. If the
      diff introduces (or worsens) a value that's defined in more than one spot — a max speed in
      `Constants` that disagrees with a hardcoded value inside a subsystem, or with a deploy-config
      file — flag it.
- [ ] Constants grouped in **nested static classes per subsystem** inside `Constants.java`
      (`OperatorConstants`, `ElevatorConstants`, `SwerveConstants`) — `public static final`. Keeps
      names short and makes the owner of each value obvious.
- [ ] 🟠 **A hardcoded filesystem path** (`"/home/lvuser/deploy/..."`, someone's local machine
      path). Use `Filesystem.getDeployDirectory()`.
- [ ] PathPlanner auto/path names and dashboard keys: a constant, not a loose repeated string.
- [ ] Config that **already lives in a deploy JSON** (swerve module config, PathPlanner settings)
      **doesn't get duplicated in Java**. One source of truth per value.
- [ ] Team number only in `.wpilib/wpilib_preferences.json`.

---

## 3.2 Who knows whom (coupling)

The direction of dependencies must always be the same:

```
Robot  →  RobotContainer  →  Commands  →  Subsystems  →  Hardware (motors, sensors)
```

Never backwards, never sideways.

- [ ] 🔴 **A subsystem does not take another subsystem.** Not in the constructor, not in a method.
      If the elevator needs to know the height the arm allows, pass a `DoubleSupplier
      armHeight`, not an `Arm arm`.
- [ ] 🔴 **A subsystem does not read the controller.** No `XboxController` /
      `CommandPS4Controller` inside a subsystem. The joystick is read in `RobotContainer` and
      handed to the command as a `DoubleSupplier`. A subsystem that reads the controller will
      never work in autonomous.
- [ ] 🟠 **A subsystem doesn't know about `RobotContainer`** or `Robot`. That's a circular
      dependency.
- [ ] 🟠 **Coordination between subsystems happens in `RobotContainer`**, via `Trigger` bindings
      and command composition — not by one subsystem calling another.
- [ ] A command receives what it needs through its constructor (dependency injection). No pulling
      a subsystem off a global static field.

---

## 3.3 Singletons and global state

- [ ] 🟠 `getInstance()` / singleton on a subsystem: an old pattern, now **discouraged** by
      WPILib. It hides dependencies (any class can reach in and touch the motor from anywhere) and
      breaks testing and simulation. The correct approach is to instantiate it in
      `RobotContainer` and pass it down.
- [ ] 🔴 A **mutable** `public static` field (`public static double currentSpeed`): anything can
      write to it, nobody knows who did. `static final` (a constant) is fine; a mutable `static`
      is not.
- [ ] Duplicated state: the same piece of data stored in two fields that have to be kept in sync.
      Store it once and derive the rest.

---

## 3.4 "Utils", "Helpers", "Manager" files

- [ ] 🟠 A new file named `Utils.java`, `Helpers.java`, `Misc.java`, `Tools.java`: **reject the
      name**. It's a bucket where everything lands and nothing can be found; in two months it's
      400 unrelated lines. **Instead:**
      - trajectory math → `PoseMath.java` / `AlignmentMath.java`
      - a single mechanism's unit conversion → a private method **inside** the owning subsystem
      - an autonomous routine → `AutoRoutines.java`
      - a constant → `Constants.java`
- [ ] A legitimate utility class (pure functions only, no state) should be `final`, with a private
      constructor, and a name describing **one** topic.
- [ ] 🟠 A "Manager"/"Handler" class that only forwards calls to other classes (a layer with no
      responsibility of its own): flag it as unnecessary indirection.
- [ ] 🟡 A new file outside `subsystems/` or `commands/` needs to justify the package it's in.

---

## 3.5 One responsibility per class

- [ ] A subsystem = **one** set of hardware that moves together. 🟠 If a subsystem controls both
      an elevator **and** a claw, they should be two subsystems — otherwise the two can never be
      commanded at the same time (the scheduler only lends a subsystem to one command at a time).
- [ ] 🟠 `RobotContainer` turning into a god class: if it's doing trajectory math, PID, or unit
      conversion, that code belongs in a subsystem or a domain class. `RobotContainer` should only
      **assemble and wire things together**.
- [ ] `Robot.java` holds only lifecycle. `Main.java` holds nothing.
- [ ] A command does one thing. A command doing three things should be three commands composed
      with `andThen` / `alongWith`.

---

## 3.6 Testability and simulation

- [ ] 🟡 Pure computation (converting rotation to distance, deciding a setpoint, solving alignment
      geometry) can become a `static` method with no hardware — and then it gets a JUnit test in
      `src/test/`. Logic glued to the motor can't be tested.
- [ ] 🟡 For a large subsystem change, it's worth mentioning the **IO layer** pattern (used by
      AdvantageKit): the subsystem talks to an `interface ElevatorIO`, with a real implementation
      (`ElevatorIOTalonFX`) and a simulation one (`ElevatorIOSim`). This lets the code run and be
      tested without a robot. **A suggestion, never a requirement** — too large a refactor to
      demand inside one PR.
- [ ] Code that only works with hardware present must not break `./gradlew simulateJava`.

---

## 3.7 File organization

- [ ] `frc/robot/subsystems/` → subsystems. `frc/robot/commands/` → commands.
- [ ] One file per public class, filename matching the class name.
- [ ] 🟡 Too many small command classes clutter the project — WPILib recommends **command
      factories inside the subsystem** instead of a new file for every simple action.
- [ ] A new file under `src/main/deploy/` gets shipped to the roboRIO. Confirm it's intentional.

---

## Sources

- [Organizing Command-Based Robot Projects — WPILib](https://docs.wpilib.org/en/stable/docs/software/commandbased/organizing-command-based.html)
- [Structuring a Command-Based Robot Project — WPILib](https://docs.wpilib.org/en/stable/docs/software/commandbased/structuring-command-based-project.html)
- [Best Practices for Command-Based Programming — BoVLB's FRC Tips](https://bovlb.github.io/frc-tips/commands/best-practices.html)
- [IO Interfaces — AdvantageKit](https://docs.advantagekit.org/data-flow/recording-inputs/io-interfaces/)
