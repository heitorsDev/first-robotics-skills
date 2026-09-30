---
name: frc-code-authoring
description: Authors and debugs FRC robot code against WPILib's command-based programming model (Subsystem/Command, CommandScheduler, requirements, default commands) and roboRIO/GradleRIO deployment conventions (vendordeps, deploy artifacts, the 20 ms loop budget). Use when writing a new subsystem or command, wiring RobotContainer, debugging a command that won't run or a scheduler conflict, or setting up a deploy/vendor library.
license: MIT
---

# FRC Code Authoring

Command-based is the framework WPILib ships and the one nearly every team's `frc.robot` package
is built on: `Robot` runs `CommandScheduler`, subsystems own hardware, commands express behavior,
and `RobotContainer` wires the two together. This skill is about writing and debugging that code
correctly — not about which vendor library a team uses for a given mechanism.

**Stay library-agnostic.** A repo might drive motors through CTRE Phoenix 5/6, REVLib, or
another vendor; swerve through YAGSL or a hand-rolled `SwerveDrivetrain`; autonomous through
PathPlannerLib or trajectories built by hand; logging through AdvantageKit or plain
`SmartDashboard`. Match whatever the repo already has — check `vendordeps/*.json` and existing
subsystem code before assuming a library — rather than introducing a new one.

## Step 1 — Orient before writing anything

Read, in order:

1. `vendordeps/*.json` — which vendor libraries (motor controllers, swerve, pathing, logging)
   this repo already depends on. Every new subsystem should use the vendor APIs already present,
   not a different library that does the same job.
2. `build.gradle` — confirm the GradleRIO version and Java toolchain; note whether
   `includeDesktopSupport` / simulation is enabled, since that affects whether a change can be
   verified in `simulateJava` before hardware access.
3. `Constants.java` (or equivalent) — existing CAN IDs, DIO/PWM ports, and named constants. Never
   invent a new CAN ID or port without checking it isn't already claimed here.
4. `RobotContainer.java` — how subsystems are instantiated, how default commands and button
   bindings are wired, and what `getAutonomousCommand()` currently returns.
5. One existing subsystem and one existing command — this repo's actual style (PID + feedforward
   split, telemetry keys, comment language, naming) is a better guide than a generic template.

## Step 2 — Author a subsystem

A subsystem is a `SubsystemBase` that owns one piece of hardware (or a tightly related group) and
exposes behavior through methods, not raw hardware references:

- Fields: the hardware objects (motor controllers, encoders, sensors), any `PIDController` /
  `ProfiledPIDController` / feedforward, and mutable state like a target setpoint.
- Constructor: hardware configuration only (inversion, idle/brake mode, current limits, encoder
  zeroing) — never scheduling or command logic.
- Methods that return `Command` (`runPID()`, `runOpenLoop(double speed)`) for anything that needs
  to run every scheduler cycle; plain methods (`setTarget(double)`, `getPositionCm()`) for state
  a command or `RobotContainer` needs to read or set once.
- `periodic()` — telemetry only (`SmartDashboard.putNumber`, logger calls). Never put control
  logic here; that belongs in a `Command` returned by a method, so the scheduler — not
  `periodic()` — decides whether it's allowed to run.
- Clamp setpoints and outputs (`MathUtil.clamp`) against the mechanism's physical range inside the
  subsystem, not in the caller — a subsystem should be impossible to command out of its own safe
  range.

## Step 3 — Author commands

Reach for the two `Command` shapes in order of how much state the behavior needs:

- **Inline factories** (`Commands.runOnce(...)`, `Commands.run(...)`, `subsystem.startEnd(...)`)
  for a single action or a loop with no internal state beyond what the subsystem already tracks —
  e.g. "set this setpoint once", "run this subsystem's PID loop until interrupted".
- **A `Command` subclass** when the behavior needs its own state across cycles — its own PID
  controller, a resolved target pose, a multi-step sequence — overriding:
  - `initialize()` — resolve anything that must be read fresh each run (current pose, current
    alliance from `DriverStation.getAlliance()`) and reset any controller state so stale error
    from a previous run doesn't leak in.
  - `execute()` — the per-cycle control logic.
  - `end(boolean interrupted)` — return the mechanism to a safe state (stop motors, hold position)
    regardless of whether the command finished or was interrupted.
  - `isFinished()` — a real termination condition. A command that means "run forever until
    interrupted" (most teleop default commands) should explicitly `return false` here, not omit
    the override and rely on the default.

**Always call `addRequirements(...)` for every subsystem the command touches**, in the
constructor. This is the single most common command-based bug: without it, the scheduler has no
way to know two commands conflict, so both run at once and silently fight over the same motor —
there is no compile error and no crash, just a mechanism that behaves erratically or a default
command that won't get interrupted the way you expect.

## Step 4 — Wire it into RobotContainer

- Instantiate the subsystem once as a field.
- `subsystem.setDefaultCommand(...)` for any mechanism that should always be doing *something*
  when no other command needs it — teleop driving, a PID loop holding the last setpoint. A
  mechanism with no default command sits idle with whatever output its last command left it at,
  which for an open-loop motor usually means it keeps moving. This is the second most common
  "why isn't my robot doing anything" or "why does it drift" bug.
- Button bindings go through `Trigger`/`JoystickButton` (`.onTrue`, `.whileTrue`, `.onFalse`),
  bound in `configureBindings()`, called once from the constructor.
- `getAutonomousCommand()` returns whatever command (or composition — `Commands.sequence(...)`,
  a `PathPlannerAuto`, etc.) should run in `autonomousInit()`. If a repo wires a fixed auto here
  instead of a `SendableChooser`, that's a real limitation worth flagging, not a bug to silently
  "fix" by picking a different auto.

## Step 5 — Respect the 20 ms loop

`Robot.robotPeriodic()` calls `CommandScheduler.getInstance().run()` on a fixed 20 ms period.
Everything that runs inside a command's `execute()` or a subsystem's `periodic()` shares that
budget with every other subsystem and command. Concretely:

- Never block: no `Thread.sleep`, no network calls, no waiting on I/O inside `execute()` or
  `periodic()`. A blocking call there doesn't just make one loop late — it delays every
  subsystem's `periodic()` and the whole scheduler for that cycle, which can also blow the
  driver-station's communication watchdog.
- Don't allocate heavily or run unbounded loops per cycle (e.g. re-parsing a config file every
  `execute()`); do that once in the constructor or `initialize()` and cache the result.
- If a loop overrun shows up (driver station logs "loop time overrun" or the console prints a
  scheduler watchdog warning), profile which subsystem's `periodic()` or which command's
  `execute()` grew expensive — don't just raise the period.

## Step 6 — roboRIO deployment conventions

- `./gradlew deploy` (never a bare `gradle`) builds and pushes the jar plus `src/main/deploy/` to
  the roboRIO via GradleRIO. `./gradlew build` compiles, runs tests, and builds the jar — this is
  what CI runs, so it should pass before `deploy` is attempted.
- The team number comes from `.wpilib/wpilib_preferences.json`, not `build.gradle` — changing
  team number or debug deploys happens there.
- Vendor libraries are added as a JSON file under `vendordeps/`, normally via the vendor's
  "install for this project" URL through the WPILib VS Code extension or `vendordep install` —
  never hand-write one from scratch. `wpi.java.vendor.java()` in `build.gradle` picks all of them
  up automatically; a new vendordep JSON alone is enough, no `build.gradle` edit needed.
- Static, non-code deploy assets (swerve config JSON, PathPlanner paths/autos, any file a vendor
  library reads at runtime rather than compiles) live under `src/main/deploy/` and are copied
  verbatim to `/home/lvuser/deploy` on the RIO — don't put runtime config in `Constants.java` if
  the vendor library expects to read it from a deploy file instead.
- `wpi.java.debugJni` should normally stay `false` — enabling it is a real, noticeable performance
  cost, so treat a repo that flips it on as deliberate, not something to "clean up".

## Step 7 — Debugging checklist

When a command-based robot misbehaves, check in this order — see
`references/common-pitfalls.md` for the full symptom-to-cause table:

1. Is `addRequirements()` called for every subsystem the command touches?
2. Does every mechanism that should always be doing something have a default command set?
3. Does `isFinished()` return what you actually mean — `false` for "runs until interrupted",
   a real condition otherwise?
4. Is any control logic sitting in `periodic()` instead of behind a `Command`, or vice versa
   (telemetry-only code that shouldn't need `addRequirements()` living inside a command)?
5. Is there a blocking call, unbounded loop, or heavy allocation inside `execute()` or
   `periodic()`?
6. Does a `Command` subclass reset its own PID/profile state in `initialize()`, or is it carrying
   stale error/goal from the previous time it ran?
7. Is a value that should live in `Constants.java` hardcoded inline instead — making it easy for a
   CAN ID, port, or setpoint to silently drift out of sync between files?
