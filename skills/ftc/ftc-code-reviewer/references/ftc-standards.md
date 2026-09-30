# Axis 2 — FTC standards

> This is the **most important** axis of the review. A mistake here strips gears, cooks a motor,
> or leaves the robot unresponsive mid-match. Read this whole file before reviewing.

Applies to any repo built on the **FTC SDK** (`com.qualcomm.robotcore`, `org.firstinspires.ftc`),
regardless of which OpMode base class, drivetrain style, or vendor hardware (REV, goBILDA, Tetrix,
etc.) the team uses. Don't assume a specific drivetrain or vision library — check what's actually
imported before applying a checklist item that doesn't fit.

---

## 2.1 OpMode structure and lifecycle

The SDK gives two ways to write an OpMode, and the diff should stay consistent with whichever one
the file already uses:

- **`LinearOpMode`** — one `runOpMode()` method. Structure: hardware init → `waitForStart()` →
  a `while (opModeIsActive())` loop → cleanup after the loop. Blocking calls are fine only
  **before** `waitForStart()`; once the loop starts, it must return control every iteration.
- **`OpMode`** (event-driven) — `init()` runs once, `init_loop()` repeats until start, `start()`
  runs once when the match begins, `loop()` repeats until stop, `stop()` runs once at the end.
  None of these methods block or loop internally — the SDK calls `loop()` again itself.

### Checklist

- [ ] 🔴 **`LinearOpMode.runOpMode()` has a `while (opModeIsActive())` (or
      `!isStopRequested() && !isStarted()`-style) loop wrapping any repeating logic.** Code that
      runs once and returns, or a loop with no exit condition tied to `opModeIsActive()`, either
      ends the OpMode instantly or refuses to stop when the driver hits stop.
- [ ] 🔴 **Every iteration of the main loop actually yields.** No blocking I/O, no unbounded
      `while` waiting on a sensor, no `Thread.sleep()` of more than a few milliseconds inside the
      loop — see 2.6.
- [ ] 🟠 **`init()` (or the code before `waitForStart()`) only sets up hardware — it does not move
      anything.** Motors/servos should reach a known-safe position or stay at zero power during
      init; the robot can be sitting on a table with people around it.
- [ ] 🟠 **Hardware initialization happens once, not every loop iteration.** Grabbing devices from
      `hardwareMap`, setting motor direction/mode, or configuring PID coefficients belongs before
      the loop starts, not inside `loop()`/the `while` body.
- [ ] 🟠 **Autonomous state is re-initialized at the top of the OpMode**, never carried over as
      `static` fields from a previous run — see 2.7 in `clean-architecture.md`. A second
      autonomous run in the same match (rare, but happens in testing) must start clean.
- [ ] `@Autonomous` / `@TeleOp` annotations have a clear, unique `name`. Two OpModes with the same
      displayed name confuse the Driver Station op-mode list at competition.
- [ ] `@Disabled` OpModes still compiling and present in the diff without explanation: 🟡, worth a
      one-line question about whether it's meant to ship disabled.
- [ ] Shared setup logic (grabbing the same six motors, the same IMU calibration) duplicated
      across multiple OpModes instead of pulled into a shared class: 🟠 — see 3.1 in
      `clean-architecture.md`. Diverging copies of "the same" init code is a classic source of a
      TeleOp and an Autonomous OpMode behaving differently.

---

## 2.2 Hardware-map usage

`hardwareMap.get(DeviceClass.class, "name")` throws at `init()` if `"name"` doesn't match the
robot configuration on the Driver Station/Control Hub — one of the most common ways an OpMode
fails only in the pits.

### Checklist

- [ ] 🔴 **Every `hardwareMap.get(...)` call in the diff uses a name that plausibly exists in the
      robot configuration.** If the repo has a config XML, a REV Hardware Client export, or a
      `RobotConfig`/constants file listing device names, cross-check against it. If a new device
      name appears in code with no matching addition anywhere else in the diff, flag it — either
      the config change is missing, or the name is a typo.
- [ ] 🟠 **Device names are declared once as constants, not repeated as string literals** across
      multiple `hardwareMap.get("front_left")` calls. A rename means finding every copy, and
      missing one throws at runtime on that OpMode only.
- [ ] 🟠 **The device class requested matches the device type on the hub.** Getting a `DcMotor`
      handle for a device configured as a `DcMotorEx`-only feature (e.g. reading velocity) either
      fails to compile against the interface used or silently loses functionality — check for
      `DcMotorEx` where velocity/PIDF access is actually used.
- [ ] `hardwareMap.get(...)` calls wrapped in a `try/catch` that swallows the exception and
      continues silently: 🔴. A misconfigured or unplugged device should fail loudly (or degrade
      visibly via telemetry), not disappear into a caught exception the driver never sees.
- [ ] Servo/motor retrieved from `hardwareMap` more than once for the same physical device (two
      different variables, two different names) — merge to one handle; two handles configured
      differently is a real bug waiting to happen.

---

## 2.3 Motor power and safety limits

FTC motors (both DC drive motors and mechanism motors) don't have a software-configurable current
limit the way FRC's motor controllers do — the Control/Expansion Hub has its own overcurrent
protection in firmware, but code still has to avoid demanding more than the mechanism, gearbox, or
battery can take.

- [ ] 🔴 **`setPower(...)` values are clamped to what the mechanism can safely take**, especially
      for anything driven by a joystick or a PID/state-machine output that isn't naturally bounded
      to [-1, 1] already:
      ```java
      // ❌ raw PID output can exceed the motor's usable range
      liftMotor.setPower(pid.calculate(currentPos, targetPos));

      // ✅
      double power = Range.clip(pid.calculate(currentPos, targetPos), -0.8, 0.8);
      liftMotor.setPower(power);
      ```
- [ ] 🔴 **A mechanism that can run into a hard stop (lift, arm, slides) has a software limit
      before it gets there** — checking an encoder position/limit switch and zeroing power (or
      clamping the commanded position) rather than relying only on the driver noticing. Running a
      DC motor stalled against a hard stop for more than a couple of seconds is a common way to
      burn out a brushed motor or strip a gearbox.
- [ ] 🟠 **Zero-power behavior (`setZeroPowerBehavior`) is set explicitly and matches the
      mechanism's needs.** `BRAKE` for anything that shouldn't drift when let go (arms, lifts
      without a mechanical latch); `FLOAT` for a drivetrain that should coast. Relying on the SDK
      default instead of setting it explicitly is worth a 🟡 at minimum — the default has changed
      across SDK versions.
- [ ] 🟠 **Motor direction (`setDirection`) is configured once, at init, not compensated for with
      scattered `-1 *` multipliers** through the code. The next hardware change (swapping a motor,
      re-gearing a side) means hunting down every sign flip.
- [ ] 🟠 **Motors that must move together use the same commanded power path**, not two separate
      `setPower()` calls with independently-computed values that can drift apart (e.g. two lift
      motors on the same spool — if their power differs, the mechanism binds).
- [ ] Gamepad stick or trigger value passed straight into `setPower()` with no deadband: 🟡 unless
      the repo already applies one at a shared input layer. A stick that reads a small non-zero
      value at rest causes drift and wasted motor wear.
- [ ] `RUN_TO_POSITION` mode: confirm both `setTargetPosition(...)` and a following `setPower(...)`
      are present (the target alone does nothing), and that the target is validated against the
      mechanism's known range before being set.

## 2.4 Servo power and position limits

- [ ] 🔴 **`setPosition(...)` values are clamped to the servo's safe physical range**, not the
      servo's full `[0, 1]` unless that's actually been measured safe for this mechanism.
      A value outside the mechanism's real range can jam a linkage or strip a servo's internal
      gearing against a hard stop.
      ```java
      // ❌ 0.0–1.0 assumed safe without checking the linkage
      clawServo.setPosition(input);

      // ✅ measured-safe range for this mechanism, named
      clawServo.setPosition(Range.clip(input, ClawConstants.MIN_POS, ClawConstants.MAX_POS));
      ```
- [ ] 🟠 A continuous-rotation servo driven with `setPosition(...)` (which sets speed/direction,
      not an angle, for that servo type) reviewed as if it were positional: check the diff
      actually intends continuous-rotation semantics, and that `0.5` (stop) is used where the
      servo should hold still, not `0.0`.
- [ ] 🟡 Repeated open/close position literals for a claw/gripper scattered through multiple
      OpModes instead of one named pair of constants — see `clean-architecture.md` 3.1.
- [ ] Servo commanded to move immediately at `init()` before the driver has confirmed the field is
      clear: same concern as 2.1 — init should reach a safe rest position, not perform the
      match-opening motion early.

## 2.5 Telemetry usage

Telemetry is the only feedback the driver/coach gets once the robot is on the field — code that
computes something useful but never surfaces it is invisible until it's already a problem.

- [ ] 🟠 **`telemetry.update()` is actually called** after adding data — `telemetry.addData(...)`
      alone queues the line but doesn't push it to the Driver Station. A loop that never calls
      `update()` shows a permanently stale (or blank) screen.
- [ ] 🟠 Calling `telemetry.update()` more than once per loop iteration, or once per sub-step
      inside a state machine: usually unintentional and can visibly slow the loop down. One
      `update()` per iteration, after all `addData()` calls for that iteration.
- [ ] 🟡 Telemetry key built as a new string every loop (`"Motor " + i + " power"` at high
      frequency) — cheap on FTC's loop rates but still worth naming as a constant if it's
      identical every call.
- [ ] Useful-for-diagnosis values missing from a newly added mechanism: current position vs.
      target, current power, any relevant sensor reading. Doesn't need to be exhaustive, but a new
      subsystem with zero telemetry is a 🟡 worth raising.
- [ ] `telemetry.addData(...)` inside a tight loop dumping large objects (full sensor arrays,
      whole lists) every iteration: flag if it looks like it could visibly slow the Driver Station
      down.
- [ ] FTC Dashboard (`FtcDashboard`) or similar, if already a repo dependency: new tunable values
      (PID coefficients, target positions) should go through it instead of being hardcoded, when
      the repo has already established that pattern elsewhere.

## 2.6 The main loop — what breaks it

The FTC SDK doesn't enforce a fixed loop period the way FRC's 20 ms cycle does, but the same
principle holds: everything in the loop body has to return control promptly, or the robot stops
responding to input and the Driver Station may report a "loop time" warning of its own.

### 🔴 Forbidden inside a `while (opModeIsActive())` body or `loop()`

- [ ] `Thread.sleep(...)` for anything beyond trivial debouncing (a handful of milliseconds) —
      it freezes input reading and telemetry for that whole duration. Use a state machine with a
      timer (`ElapsedTime`) instead of sleeping to wait for something.
- [ ] `while (condition) { ... }` busy-waiting for a sensor or motor to reach a state inside the
      main loop. The outer loop **is** the wait — check the condition once per iteration and fall
      through, don't block until it's true.
- [ ] Blocking I/O: reading a file, opening a network connection, blocking camera/vision calls
      not designed for the loop.
- [ ] Constructing new heavyweight objects every iteration (`new PIDController(...)`,
      `new ElapsedTime()` used as a stopwatch reset via reassignment when `.reset()` would do).
      Create once as a field, reuse.
- [ ] Reconfiguring hardware every iteration (`motor.setDirection(...)`,
      `motor.setZeroPowerBehavior(...)`, `imu.initialize(...)`) — configuration belongs at init,
      once.

### What the loop body should contain

Read inputs (gamepad, sensors), update state, compute and apply motor/servo commands, push
telemetry. Nothing that can take an unbounded amount of time.

---

## 2.7 People and hardware safety

- [ ] 🔴 Code that moves a mechanism **before** `waitForStart()` returns (or in `init()`/
      `init_loop()` for event-driven OpModes) — people can be standing around the robot on the
      field or in the pits during init.
- [ ] 🔴 A newly added, potentially dangerous action (intake spinning up, a launcher firing) that
      isn't gated behind a deliberate button/trigger press — it must never run from a default/idle
      state alone.
- [ ] 🟠 A new hardware-map device name: check it isn't already used for a different physical
      device elsewhere in the repo. A duplicate name is a config error that surfaces as one device
      silently not responding, or the wrong device responding to input meant for another.
- [ ] Changing an existing gamepad binding without updating wherever the team documents controls
      (a README, a comment block, a driver reference sheet) confuses the driver at competition —
      🟡, but worth flagging.
- [ ] New mechanism's first commanded power/position in the diff should be conservative
      (`setPower(0.3)`, not `setPower(1.0)`) if this is clearly a first pass — worth a 🟡 note if
      the diff reads like an untested addition going straight to full power.

---

## 2.8 Build and deploy

- [ ] The Gradle build (`./gradlew build` or `./gradlew assembleDebug`, whichever the CI runs)
      must pass — that's what CI runs against the diff.
- [ ] Always the wrapper (`./gradlew`), never a system-installed `gradle`.
- [ ] FTC SDK version bump (`FtcRobotController`/`TeamCode` `build.gradle` / `build.dependencies.gradle`)
      done consistently across all modules that reference it, not just one.
- [ ] 🟡 Pure logic (state machines, geometry/math helpers, path calculations) extracted so it can
      run in a plain JUnit test without a `HardwareMap` — see `clean-architecture.md` 3.6. If the
      diff adds non-trivial calculation with no hardware dependency, suggest (don't require) a
      test.
- [ ] A risky change to a competition OpMode should be verified on the robot (or the bench, with
      wheels off the ground / mechanism secured) before being treated as done.

---

## Sources

- [FTC SDK documentation (game-manual-0 / GitHub wiki)](https://ftc-docs.firstinspires.org/en/latest/)
- [FTC SDK API reference (javadoc)](https://javadoc.io/doc/org.firstinspires.ftc)
- [OpMode concepts — FTC SDK docs](https://ftc-docs.firstinspires.org/en/latest/programming_resources/index.html)
- [Robot Configuration — FTC SDK docs](https://ftc-docs.firstinspires.org/en/latest/hardware_and_software_configuration/index.html)
- [FTC Dashboard](https://acmerobotics.github.io/ftc-dashboard/)
