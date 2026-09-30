---
name: ftc-code-authoring
description: Write and debug FTC SDK code — OpMode lifecycle (init/loop/stop), hardware-map device access, LinearOpMode vs. iterative OpMode, TeleOp and Autonomous structure, and the hardware-map pitfalls that cause the most FTC runtime crashes. Use when authoring a new OpMode, converting between OpMode styles, or debugging a "Config mismatch" / ClassCastException / NullPointerException thrown by the Robot Controller app.
license: MIT
---

# FTC Code Authoring

This skill writes and debugs code against the **FTC SDK** (`FtcRobotController` /
`com.qualcomm.robotcore` + `org.firstinspires.ftc.robotcore`) — the op-mode-based programming
model every FTC team's code runs on, regardless of which language binding (Java, Kotlin, or
Blocks-exported Java) or which vendor hardware the team uses. Stay library-agnostic below the SDK
layer: don't assume a specific drivetrain class, vendor motor library, or pathing library unless
the target repo already has one.

## Step 1 — Identify the OpMode style already in use

FTC OpModes come in two base classes with different lifecycles. Check which one the repo/file
uses before writing anything — mixing the two styles in one class is not possible (they have
different method contracts) and porting logic between them is a common source of bugs when done
carelessly.

**`LinearOpMode`** — one blocking method, sequential control flow:

```java
@TeleOp(name = "Linear TeleOp Example")
public class LinearTeleOpExample extends LinearOpMode {
    @Override
    public void runOpMode() {
        DcMotor leftDrive = hardwareMap.get(DcMotor.class, "left_drive");
        DcMotor rightDrive = hardwareMap.get(DcMotor.class, "right_drive");

        waitForStart();               // blocks until the driver presses PLAY

        while (opModeIsActive()) {    // replaces the loop() callback
            leftDrive.setPower(-gamepad1.left_stick_y);
            rightDrive.setPower(-gamepad1.right_stick_y);
            telemetry.addData("status", "running");
            telemetry.update();
        }
        // code after the while-loop runs once, on STOP — equivalent to stop()
    }
}
```

- `runOpMode()` runs on its own thread; everything before `waitForStart()` is the init phase —
  hardware-map lookups and one-time setup belong here, not inside the loop.
- `opModeIsActive()` returns `true` only while the OpMode is both started and not stop-requested;
  it also calls `idle()` internally. Never build a loop with `while (true)` — it won't observe
  STOP and will hang the Robot Controller app.
- `isStopRequested()` lets init-phase code exit early if the driver hits STOP before pressing
  PLAY (e.g. during a long autonomous init routine that reads sensors).

**`OpMode`** (iterative) — non-blocking callbacks, an explicit state machine:

```java
@TeleOp(name = "Iterative TeleOp Example")
public class IterativeTeleOpExample extends OpMode {
    private DcMotor leftDrive, rightDrive;

    @Override
    public void init() {                 // called once, before PLAY
        leftDrive = hardwareMap.get(DcMotor.class, "left_drive");
        rightDrive = hardwareMap.get(DcMotor.class, "right_drive");
    }

    @Override
    public void init_loop() { }          // called repeatedly between INIT and PLAY (optional)

    @Override
    public void start() { }              // called once, on PLAY (optional)

    @Override
    public void loop() {                 // called repeatedly at ~50 Hz while running
        leftDrive.setPower(-gamepad1.left_stick_y);
        rightDrive.setPower(-gamepad1.right_stick_y);
        telemetry.addData("status", "running");
    }

    @Override
    public void stop() { }               // called once, on STOP — release resources here
}
```

- `init()` → `init_loop()`* → `start()` → `loop()`* → `stop()`, where `*` marks "called
  repeatedly". The SDK owns the loop; never block inside any of these methods (no `Thread.sleep`,
  no `while(true)`) — that stalls the whole Robot Controller app, including telemetry and
  gamepad polling.
- `telemetry.update()` is called for you after each `loop()` — don't call it again unless a
  vendor telemetry class documents otherwise.

Prefer `LinearOpMode` for Autonomous (sequential "do A, then B, then C" routines read naturally as
a blocking method) and either style for TeleOp; iterative `OpMode` suits TeleOp code that's
naturally a state machine (e.g. a claw with open/closed/homing states) since each state transition
is just a branch inside `loop()` rather than a nested nested loop inside `runOpMode()`.

## Step 2 — Register the OpMode with the right annotation

```java
@TeleOp(name = "Comp TeleOp", group = "Competition")
@Autonomous(name = "Comp Auto - Left", group = "Competition")
```

- `@TeleOp` and `@Autonomous` are mutually exclusive — one annotation per class, and the class
  must extend `OpMode` or `LinearOpMode` for the annotation to have any effect.
- `@Disabled` hides an OpMode from the Driver Station list without deleting the file — useful for
  test/scratch OpModes that shouldn't be selectable at competition. Check for stray `@Disabled`
  left on a class the user expects to see on the Driver Station.
- `group` clusters related OpModes together in the Driver Station picker; it has no effect on
  behavior. Don't confuse it with anything access-control related — it's purely cosmetic.

## Step 3 — Access hardware through `hardwareMap`, and get the device class right

Every physical device (motor, servo, sensor, digital/analog I/O) is looked up by the **name
configured in the Driver Station's robot configuration file**, not by port number and not by any
name in the code:

```java
DcMotor    arm       = hardwareMap.get(DcMotor.class, "arm_motor");
Servo      claw      = hardwareMap.get(Servo.class, "claw_servo");
IMU        imu       = hardwareMap.get(IMU.class, "imu");
DistanceSensor range  = hardwareMap.get(DistanceSensor.class, "range_sensor");
```

`hardwareMap.get(Class, name)` throws an **unchecked `IllegalArgumentException`** at that line if
the name doesn't resolve at all, or a **`ClassCastException`** if the name resolves but to a
different type than requested. Both surface to the driver as an OpMode crash on init, with the
Robot Controller showing a red "OpMode ... encountered a problem" banner — that banner plus the
stack trace's first `hardwareMap.get(...)` line is where to start debugging, always.

**Pitfall 1 — device name mismatch.** The string passed to `hardwareMap.get(...)` must match the
configuration file's device name *exactly*, including case (`"Arm_Motor"` ≠ `"arm_motor"`) and
without extra whitespace. This is the single most common first-time-running-on-a-new-robot crash.
Fixes, in order of preference:
1. Rename the device in the Driver Station's config-file editor to match the code (keeps the code
   as the source of truth, which is easier to diff/review than a binary config file).
2. Or fix the string literal in code to match the existing config — check for typos, an
   underscore vs. space, or a leftover name from a renamed subsystem.
Grep the whole repo for the literal string before assuming it's a single typo — a renamed device
often has 2-3 stale call sites (a subsystem class, a test OpMode, and telemetry).

**Pitfall 2 — wrong device class.** `hardwareMap.get()` is generic over the *interface/class*
requested, and the SDK matches by exact configured type, not by "is-assignable-from" in the
direction a caller might expect:
- A device configured as `DcMotor` in the config file also satisfies `hardwareMap.get(DcMotorEx.class, name)`
  in current SDK versions (DcMotorEx extends the DcMotor interface and the underlying driver
  implements both) — but a device configured under the wrong *type* entirely (e.g. a servo
  physically wired to a motor port, or a continuous-rotation servo configured as a regular
  `Servo` instead of `CRServo`) throws `ClassCastException` immediately.
- `CRServo` (continuous rotation, exposes `setPower`) and `Servo` (positional, exposes
  `setPosition`) are different interfaces — configuring a CR servo as `Servo` compiles fine
  (both exist in the SDK) but crashes at the `hardwareMap.get(Servo.class, ...)` call, not at
  first use, because the SDK checks the configured type at lookup time.
- When a `ClassCastException` names an unexpected concrete class, check the config file's device
  type dropdown for that name before suspecting the code — the fix is almost always changing the
  configured type, or changing the requested class to match it, not restructuring the OpMode.

**Pitfall 3 — hardware-map lookups inside the loop.** `hardwareMap.get(...)` does a map lookup and
should run once, during `init()`/before `waitForStart()`. Calling it every iteration of
`loop()`/the `while (opModeIsActive())` loop still works but wastes cycles on a 50 Hz control loop
and usually signals the class is missing member fields for its devices — flag it during review
even though it isn't a crash.

## Step 4 — Structure Autonomous as a readable sequence, not a monolith

Prefer small named steps over one giant `runOpMode()`:

```java
@Autonomous(name = "Park and Score")
public class ParkAndScore extends LinearOpMode {
    private DcMotor leftDrive, rightDrive;
    private Servo clawServo;

    @Override
    public void runOpMode() {
        initHardware();
        waitForStart();
        if (isStopRequested()) return;

        driveForward(24, 0.5);
        openClaw();
        driveForward(-12, 0.5);
    }

    private void initHardware() {
        leftDrive = hardwareMap.get(DcMotor.class, "left_drive");
        rightDrive = hardwareMap.get(DcMotor.class, "right_drive");
        clawServo = hardwareMap.get(Servo.class, "claw_servo");
    }

    private void driveForward(double inches, double power) {
        // encoder- or time-based drive helper; keep magic numbers named constants at the
        // top of the class, not inline literals here
    }

    private void openClaw() {
        clawServo.setPosition(1.0);
    }
}
```

- Every helper that spins in a loop internally (e.g. `driveForward`, a PID-to-target loop) must
  still check `opModeIsActive()`/`isStopRequested()` on each internal iteration — a helper method
  that ignores STOP will hang the 30-second autonomous period and the whole match with it.
- Keep distances, powers, and timings as named constants, not inline literals, so a between-match
  tune doesn't require re-reading the whole method.

## Step 5 — Keep TeleOp loops non-blocking and state, not motion, driven

- Never call anything blocking inside `loop()` or the `while (opModeIsActive())` body:
  `Thread.sleep`, a tight `while` waiting on a sensor threshold, or a long-running I/O call all
  stall the 50 Hz cycle and make the whole robot feel unresponsive, including drive.
- Debounce button-edge actions (toggle a claw on press, not on hold) by tracking the previous
  loop's gamepad state and comparing, rather than relying on the driver's timing:
  ```java
  boolean clawPressed = gamepad1.a && !lastAState;
  lastAState = gamepad1.a;
  if (clawPressed) { clawOpen = !clawOpen; }
  ```
- Report state through `telemetry.addData(key, value)` + `telemetry.update()` every loop — it's
  the primary debugging tool once the robot is untethered from a laptop; a TeleOp with no
  telemetry is much harder to diagnose live at a competition.

## Step 6 — Debugging checklist

When an OpMode crashes or misbehaves, work through these in order — they cover the large majority
of FTC runtime failures:

1. **Read the Robot Controller's crash banner and stack trace fully** before changing anything —
   the exception type (`IllegalArgumentException` vs. `ClassCastException` vs.
   `NullPointerException`) points directly at Step 3's pitfalls.
2. **`IllegalArgumentException` at a `hardwareMap.get(...)` line** → name mismatch (Pitfall 1).
   Compare the string literal against the Driver Station's current config, not a remembered one —
   configs drift when the robot is reconfigured after a repair.
3. **`ClassCastException` at a `hardwareMap.get(...)` line** → wrong device class (Pitfall 2).
   Check the config file's type dropdown for that device name.
4. **`NullPointerException` on a hardware field inside `loop()`/after `waitForStart()`** → a
   device field assigned in `init()` never actually got assigned (early return, exception
   swallowed by a try/catch during init, or a typo'd field name shadowing the real one) — add a
   log/telemetry line right after each hardware-map lookup during init if the failure is
   intermittent.
5. **OpMode doesn't appear on the Driver Station list** → check for a stray `@Disabled`, a missing
   `@TeleOp`/`@Autonomous` annotation, or the class not being `public`.
6. **Robot feels laggy / gamepad input feels delayed** → search for blocking calls in the loop
   (Step 5) before suspecting Wi-Fi or hardware latency.
7. **Autonomous runs past its expected time or never finishes** → check every internal loop
   (helper methods included) actually re-checks `opModeIsActive()`/`isStopRequested()`.
