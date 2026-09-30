# Axis 2 — FRC / WPILib standards

> This is the **most important** axis of the review. A mistake here burns out a motor, bends a
> mechanism, or leaves the robot stalled mid-match. Read it in full before reviewing.

Applies to command-based Java/WPILib robot code: swerve drivetrains (YAGSL or similar),
autonomous routines (PathPlanner or similar), and motor controllers from CTRE Phoenix
(TalonFX/Kraken) and REV (SparkMax). Read the repo's own docs (`README`, `AGENTS.md`, or
equivalent) for its specific CAN IDs, ports, and hardware quirks before reviewing — don't assume
IDs or values from this checklist, they're examples, not this repo's actual configuration.

---

## 2.1 Command-based structure

WPILib organizes robot code into two pieces:

- **Subsystem** — a piece of hardware that acts on its own (drivetrain, elevator, intake). Owns
  the motors and sensors.
- **Command** — an action the robot performs (raise the elevator, align to a target). Borrows one
  or more subsystems while it runs.

The `CommandScheduler` guarantees that **two commands never control the same subsystem at the
same time** — but only if the command declares that.

### Checklist

- [ ] **Every command declares its requirements.** `addRequirements(subsystem)` in the
      constructor of a `Command` class, or use `subsystem.run(...)` / `subsystem.runOnce(...)`
      which declare it automatically. 🟠 **Without this, two commands fight over the same motor
      and the robot shakes, stalls, or breaks.**
- [ ] **The default command never finishes.** The default command (the one that runs when nothing
      else is, typically joystick drive) must not return `true` from `isFinished()` — it would be
      rescheduled infinitely. It should be simple: drive, stop, or hold position.
- [ ] **The default command doesn't decide anything.** Conditional logic ("if it has a game
      piece, do X") belongs in a `Trigger`/binding in `RobotContainer`, not inside the default
      command.
- [ ] **A command instance is not reused.** Once a command enters a group
      (`SequentialCommandGroup`, `andThen`...), it **belongs** to that group and can't be reused
      elsewhere. If the same behavior is needed in two places, use a **command factory**: a method
      that returns a new instance.
- [ ] **Command factories live inside the subsystem.** For single-subsystem actions:
      ```java
      public Command raiseToHeight(double heightMeters) {
        return run(() -> setSetpoint(heightMeters)).until(this::atSetpoint);
      }
      ```
      Named in `lowerCamelCase`, describing **intent** (`prepareToScore`), not implementation
      (`setMotorTo0Point8`).
- [ ] **Actions that span multiple subsystems live outside the subsystems** — in a class like
      `AutoRoutines` or in `RobotContainer`. 🔴 **A subsystem NEVER takes another subsystem in its
      constructor or as a method parameter** — that creates a circular dependency and a race
      condition. If a subsystem needs data from another, pass a `Supplier<T>` /
      `DoubleSupplier`, not the whole object.
- [ ] **Subsystem fields are `private final`.** Motor, encoder, PID controller, state — all
      private. No `public TalonFX motor;` for `RobotContainer` to poke directly.
- [ ] **Subsystem state is exposed as a `Trigger` or a yes/no getter**, in problem-domain
      language: `hasGamePiece()`, `atSetpoint()` — not `beamBreakTriggered()` or
      `getRawEncoderValue()`.
- [ ] **`CommandScheduler.getInstance().run()` appears exactly once**, in
      `Robot.robotPeriodic()`. Never also in `teleopPeriodic`/`autonomousPeriodic`.
- [ ] **`autonomousInit` schedules the auto; `teleopInit` cancels it.** If the auto isn't
      cancelled, it keeps driving over the operator's input.
- [ ] Prefer **composing existing commands** (`andThen`, `alongWith`, `until`, `withTimeout`) over
      writing a new `Command` class. A new class is warranted only for complex internal state.
- [ ] `Main.java` carries no logic — just `RobotBase.startRobot(Robot::new)`.

---

## 2.2 The 20 ms loop — the rule most people break

The robot runs a cycle every **20 milliseconds**. Everything (every subsystem's `periodic`, every
command's `execute`, the scheduler, telemetry) has to fit in that window. If it doesn't, a
`Loop time overrun` shows up in the console and the robot starts responding late — the driver
feels it as the robot "lagging."

### 🔴 Forbidden inside any `periodic()` / `execute()`

- [ ] `Thread.sleep(...)` — **freezes the entire robot**. To wait, use `Commands.waitSeconds(x)`
      or `.withTimeout(x)` on the command.
- [ ] `while (condition) { ... }` waiting for something to happen (e.g. `while (!atSetpoint)`).
      The periodic loop **is** your while loop. Use `isFinished()` or `.until(...)`.
- [ ] Any blocking I/O: reading a file, network request, `Scanner`, opening a camera.
- [ ] `System.out.println` every cycle (50 prints per second clog the console and the network).
      Debug output goes to telemetry (`SmartDashboard` / AdvantageKit) or gate it with
      `if (counter++ % 50 == 0)`.
- [ ] Allocating a new object every cycle in a hot loop (`new PIDController(...)`,
      `new TalonFXConfiguration()`, `new PositionVoltage(...)`). Create it once as a field and
      reuse it — in Phoenix 6, request objects (`PositionVoltage`, `VelocityVoltage`) are meant to
      be reused with just the value updated.
- [ ] Configuring hardware every cycle: `motor.getConfigurator().apply(...)`,
      `sparkMax.configure(...)`, `setSmartCurrentLimit(...)`. 🔴 **Configuration goes in the
      subsystem's constructor**, once. Reconfiguring at 50 Hz saturates the CAN bus.

### What `periodic()` should contain

Updating sensor caches, updating odometry, publishing telemetry, running the position control
loop. Nothing else.

---

## 2.3 Motors — current limits, brake mode, inversion

### Current limit

A current limit is how much power a motor can draw before the controller cuts it off. Without
one: the motor **burns out** when it stalls (e.g. an elevator hitting a hard stop), or the
battery voltage sags and the roboRIO **browns out** — shutting everything off mid-match.

- [ ] 🔴 **Every new motor in the diff has a current limit configured.**
- [ ] CTRE Phoenix 6 (TalonFX / Kraken): `CurrentLimitsConfigs` with `StatorCurrentLimit` +
      `StatorCurrentLimitEnable = true`. The stator limit is the most effective guard against
      brownout on start-up. `SupplyCurrentLimit` protects the PDH breaker.
      ```java
      var config = new TalonFXConfiguration();
      config.CurrentLimits.StatorCurrentLimit = 60;
      config.CurrentLimits.StatorCurrentLimitEnable = true;
      config.CurrentLimits.SupplyCurrentLimit = 40;
      config.CurrentLimits.SupplyCurrentLimitEnable = true;
      motor.getConfigurator().apply(config);
      ```
  - [ ] REV SparkMax (2025+ API): `SparkMaxConfig` + `.smartCurrentLimit(40)`, then
        `motor.configure(config, ResetMode.kResetSafeParameters, PersistMode.kPersistParameters)`.
        **The old API (`motor.setSmartCurrentLimit(...)` on its own,
        `restoreFactoryDefaults()`) was removed** — code using it doesn't even compile on
        WPILib 2025+.
  - [ ] Reasonable starting value: current-limit and idle-mode numbers should live in
        `Constants`, sized to the actual mechanism (a drivetrain motor and a small
        manipulator motor need very different limits) — never hardcoded loose in the code.

### Idle mode (brake/coast)

- [ ] Drivetrain and mechanisms that must not fall on their own: **brake**. A mechanism that
      should give way by hand (or that heats up holding position): **coast**. The choice must be
      explicit in the config, not left at the manufacturer default.

### Inversion and direction

- [ ] Inversion configured **once** in the motor config (`InvertedValue.Clockwise_Positive` /
      `.inverted(true)`). 🟠 Don't scatter `-1 *` or `-speed` across several lines to "fix the
      direction" — the next motor swap and nobody finds all the minus signs.
- [ ] Motors that spin together on the same axis: use `Follower` (Phoenix) / `follow()` (REV),
      not two identical `set()` calls copy-pasted.

### Stopping the motor

- [ ] 🟠 **Every command that moves a motor stops the motor in `end(boolean interrupted)`**,
      including when `interrupted == true`. A command that gets interrupted and leaves the motor
      running means an uncontrolled robot.
- [ ] A mechanism with no mechanical brake can't rely on `set(0)` to hold a load — it needs
      PID + feedforward or brake mode.

---

## 2.4 Mechanisms with limited travel (elevator, arm, wrist)

Mechanisms with hard stops are where the robot destroys itself.

- [ ] 🔴 **Setpoint always clamped to the physical range:** `MathUtil.clamp(target, MIN, MAX)`
      before handing it to the PID loop. A `setSetpoint(999)` from an operator bug can't turn
      into "climb until it breaks."
- [ ] 🔴 **Soft limits configured on the controller** (`SoftwareLimitSwitchConfigs` on Phoenix,
      `.softLimit(...)` on REV) as a second barrier, independent of the Java code.
- [ ] Physical limit switch read and respected, when present. Also used to **zero the encoder**
      (homing) — a relative encoder loses its reference every boot.
- [ ] 🟠 An absolute encoder (`DutyCycleEncoder`, CANcoder) needs an **offset** saved in
      `Constants` and correct wrapping. For angular PID that crosses 0°/360°, call
      `pidController.enableContinuousInput(0, 360)` — without it the mechanism takes the long
      way around.
- [ ] 🟠 A PID loop fighting gravity (elevator, arm) needs **feedforward**
      (`ElevatorFeedforward`, `ArmFeedforward`). Just raising `kP` until it stops falling produces
      oscillation and overheats the motor.
- [ ] `setTolerance(...)` defined and `atSetpoint()` used as the finish condition — not a manual
      `if (error == 0)` comparison (it will never be exactly zero).
- [ ] PID gains (`kP`, `kI`, `kD`) live in `Constants`. 🟡 If they're being read from
      `SmartDashboard` for tuning, that needs to be clearly marked as temporary — competition code
      doesn't read gains from a dashboard.
- [ ] Non-zero `kI` with no integral limit (`setIZone` / clamp) is a classic trap: it accumulates
      error while stalled and the mechanism lurches when it breaks free.
- [ ] Test speed: a new mechanism doesn't debut at `set(1.0)`. Start limited (e.g. 0.3) and ramp
      up.

---

## 2.5 Drivetrain and swerve

- [ ] 🟠 **`Constants` and the swerve config files must not diverge.** Many swerve libraries
      (e.g. YAGSL) keep module config — IDs, offsets, module PID, physical properties — in
      `src/main/deploy/swerve/*.json`, read at runtime, not from the Java constants. A Java
      constant that contradicts the deploy config is a bug waiting to happen — the deploy file
      wins at runtime. Check whether this repo keeps that config in JSON, and if so, treat the
      JSON as the source of truth.
- [ ] Deadband applied to the joystick (`MathUtil.applyDeadband`) — the stick never reads exactly
      zero.
- [ ] Explicit speed limit, defined in one place. If the repo has more than one place that could
      cap speed (a constant, a subsystem-level max, an autonomous path-planner setting), any speed
      change in the diff should make clear which one wins.
- [ ] Field-relative control depends on the gyro **and** the alliance. See 2.6.
- [ ] Odometry updated every cycle in `periodic()`, never inside a command.
- [ ] The autonomous path-follower's one-time setup (e.g. `AutoBuilder.configure(...)` for
      PathPlanner) is called **exactly once**, when the drivetrain subsystem is constructed.
- [ ] A new path/auto referenced by name in Java must exist in the deploy directory with the
      name **exactly** matching — a name typo only shows up at runtime, mid-match.

---

## 2.6 Alliance and field

```java
// ❌ wrong — throws, or silently assumes red, if the Driver Station hasn't connected yet
var alliance = DriverStation.getAlliance().get();

// ✅ correct
Optional<Alliance> alliance = DriverStation.getAlliance();
boolean isRed = alliance.isPresent() && alliance.get() == Alliance.Red;
```

- [ ] 🟠 `DriverStation.getAlliance()` returns an `Optional` — calling `.get()` directly throws
      when the DS hasn't connected yet.
- [ ] 🟠 **Don't read the alliance in a constructor or an early-initialized static field.** At
      robot boot the alliance is still unknown. Read it in `autonomousInit()`, or store a
      `Supplier` that queries it at time of use.
- [ ] Initial pose and trajectory mirroring are consistent with the alliance.

---

## 2.7 Units

Unit confusion is cause #1 of "the code is correct but the robot moves wrong."

- [ ] 🟠 **One unit per quantity, per subsystem, documented in the name or in Javadoc.**
      `heightMeters`, `angleDegrees`, `speedMetersPerSecond`. No bare `double height` without
      saying what it measures.
- [ ] WPILib internally uses **meters and radians** (`Pose2d`, `ChassisSpeeds`,
      `SwerveModuleState`). Convert at the boundary, not in the middle of a calculation.
- [ ] `Rotation2d.fromDegrees(...)` / `Units.degreesToRadians(...)` for conversions — never a
      hand-written `* 3.14 / 180`.
- [ ] 🟡 Prefer WPILib's **units library** (`Distance`, `Angle`, `LinearVelocity`, with
      `Meters.of(2)`, `Degrees.of(90)`) in new code — the compiler then catches unit mixing. Not
      mandatory, but the recommended path since 2025.
- [ ] Encoder-to-real-unit conversion (gear ratio, pulley/wheel radius) lives in **one named
      constant** in `Constants`, not as a loose `/ 48 * 14 * 2 * Math.PI` in the middle of a
      method.

---

## 2.8 Telemetry and logging

- [ ] 🟡 NetworkTables/SmartDashboard keys are constants, not strings built every cycle
      (`"Module " + i + " angle"` at 50 Hz allocates garbage and clutters the table).
- [ ] Publish what's useful for diagnosis (setpoint, measured value, current, state) — not
      everything.
- [ ] If the repo already has a logging framework (e.g. AdvantageKit) in its dependencies, and
      the diff introduces logging, check whether it follows the project's existing pattern instead
      of creating a second, parallel mechanism.
- [ ] `SmartDashboard.putX` inside the `execute()` of a high-frequency command: prefer the
      subsystem's `periodic()` instead.

---

## 2.9 Human and hardware safety

- [ ] 🔴 Code that **moves a mechanism in `robotInit` / a constructor** — people may be standing
      around the robot on the bench. Movement should only come from a scheduled command.
- [ ] 🔴 A new dangerous action (elevator rising, shooter spinning up) needs to sit behind a
      deliberate button, not the default command.
- [ ] Changing an existing binding without updating the team's driver-facing docs confuses the
      driver at competition — 🟡, but worth flagging.
- [ ] 🟠 A new CAN ID: check it isn't already in use elsewhere in the repo. **A duplicate ID makes
      two devices fight on the bus** and is miserable to diagnose.
- [ ] A new DIO/PWM/Analog port: same check.
- [ ] Organizational tip: using the same PDH circuit number as the CAN ID documents the wiring
      for free.

---

## 2.10 Build, simulation, and deploy

- [ ] `./gradlew build` must pass. CI runs exactly that.
- [ ] Always the `./gradlew` wrapper, never a system-installed `gradle`.
- [ ] A new file under `src/main/deploy/` gets shipped to the roboRIO — confirm it's intentional
      and that the name matches what the code looks for.
- [ ] The team number belongs in `.wpilib/wpilib_preferences.json`, not in `build.gradle`.
- [ ] 🟡 Pure logic (math, conversions, state machines) can get a JUnit test in `src/test/`. If
      the diff adds non-trivial computation, suggest (don't require) a test.
- [ ] A risky change should be checked in `./gradlew simulateJava` before going on the robot.

---

## Sources

- [Command-Based Programming — WPILib](https://docs.wpilib.org/en/stable/docs/software/commandbased/index.html)
- [Structuring a Command-Based Robot Project — WPILib](https://docs.wpilib.org/en/stable/docs/software/commandbased/structuring-command-based-project.html)
- [Organizing Command-Based Robot Projects — WPILib](https://docs.wpilib.org/en/stable/docs/software/commandbased/organizing-command-based.html)
- [Best Practices for Command-Based Programming — BoVLB's FRC Tips](https://bovlb.github.io/frc-tips/commands/best-practices.html)
- [roboRIO Brownout and Understanding Current Draw — WPILib](https://docs.wpilib.org/en/stable/docs/software/roborio-info/roborio-brownouts.html)
- [Improving Performance with Current Limits — CTRE Phoenix 6](https://v6.docs.ctr-electronics.com/en/stable/docs/hardware-reference/talonfx/improving-performance-with-current-limits.html)
- [The Java Units Library — WPILib](https://docs.wpilib.org/en/stable/docs/software/basic-programming/java-units.html)
