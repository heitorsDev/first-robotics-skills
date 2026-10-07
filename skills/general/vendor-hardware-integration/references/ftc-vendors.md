# FTC vendor/sensor hardware — detection, API, pitfalls

Unlike the FRC vendors above (CTRE, REV, Studica), the sensors below ship as classes built
directly into the official **FTC SDK** itself once a team is on a recent enough SDK version —
there's no `vendordeps/*.json` to grep. Detect these by which built-in class a repo actually
imports/uses, and cross-check the SDK version floor in `build.gradle`/`build.dependencies.gradle`
— a repo pinned to an older SDK can't use the class at all, which is itself worth flagging.

---

## Limelight 3A

- **Built into the SDK since v10.0.** Robot config device type is `"Limelight3A"` (USB).
- **Detect:** import/use of `Limelight3A` (package `com.qualcomm.hardware.limelightvision`).
- **API surface:** `hardwareMap.get(Limelight3A.class, "limelight")`; `start()` / `pause()` to
  control polling; `setPollRateHz(...)`; `pipelineSwitch(index)`; `getLatestResult()` →
  `LLResult` (`isValid()`, `getTx()`/`getTy()`, `getBotpose()` / `getBotpose_MT2()`,
  `getFiducialResults()` for AprilTag/fiducial data). `updateRobotOrientation(yaw)` must be fed
  the robot's current IMU yaw every loop for `getBotpose_MT2()`'s sensor-fused accuracy.
- **Pitfall:** before SDK v10.3, `getLatestResult()` could return `null` (not an invalid-but-
  non-null result) if no frame had arrived yet — code copied from newer docs/examples can NPE on
  an older SDK. Separately, forgetting to call `updateRobotOrientation()` each loop silently
  degrades MegaTag2 pose accuracy without throwing anything.

## goBILDA Pinpoint

- **Built into the SDK since v10.3** (ships with a `SensorGoBildaPinpoint` sample). Robot config
  device type is `"goBILDA Pinpoint Odometry Computer"` (I2C).
- **Detect:** import/use of `GoBildaPinpointDriver` (package `com.qualcomm.hardware.gobilda` —
  *this package path is not independently verified against a rendered javadoc page; treat as
  likely-correct, not confirmed*).
- **API surface:** `setOffsets(xOffset, yOffset, unit)` (pod position relative to the tracking
  point); `setEncoderResolution(...)` (ticks-per-unit, or a `GoBildaOdometryPods` enum for a
  known pod type); `resetPosAndIMU()` / `recalibrateIMU()`; `update()` must be called once per
  loop; `getPosition()` → `Pose2D`; `getVelocity()`; `getPosX()`/`getPosY()`/`getHeading()`.
- **Pitfall:** `getPosition()` returns stale data unless `update()` is called every loop
  iteration *before* reading it — easy to miss since nothing throws. Also watch for a team that
  manually vendored the old standalone driver file (pre-v10.3) still committed alongside the
  SDK's now-built-in class — this caused real class/package collisions for teams upgrading SDK
  versions (see sources); flag a locally-committed `GoBildaPinpointDriver.java` as likely stale.

## SparkFun OTOS (Optical Tracking Odometry Sensor)

- **Built into the SDK since v9.2.** Robot config device type is `"SparkFun OTOS"` (I2C),
  commonly named `sensor_otos`.
- **Detect:** import/use of `SparkFunOTOS` (package `com.qualcomm.hardware.sparkfun` — *same
  caveat as above: inferred from secondary sources, not confirmed against a rendered javadoc
  page*).
- **API surface:** `setLinearUnit(...)` / `setAngularUnit(...)`; `setOffset(Pose2D)` (sensor
  mount offset from robot center); `setLinearScalar(...)` (valid range 0.872–1.127);
  `setAngularScalar(...)`; `calibrateImu()`; `resetTracking()`; `getPosition()` → `Pose2D`
  (`.x`, `.y`, `.h`); `getVelocity()`; `getAcceleration()`.
- **Pitfall:** the linear/angular scalar and offset are volatile on the sensor itself — they are
  **lost on every power cycle** and must be re-applied in `init()` on every single OpMode run,
  not set once and assumed to stick. (A SparkFun community thread is literally titled "OTOS not
  holding configuration in FTC SDK" — this is a known, recurring team mistake.)

## OctoQuad

- **Built into the SDK since v9.2** (8-channel quadrature/PWM decoder over I2C). Robot config
  device type is `"OctoQuad"`.
- **Detect:** import/use of `OctoQuad` (package `com.qualcomm.hardware.digitalchickenlabs` —
  *not independently verified against a rendered javadoc page; moderate confidence only*).
- **Purpose/API surface:** reads up to 8 encoder/PWM channels. Its entire value proposition is
  bulk-reading all channels in a single I2C transaction instead of one read per channel; the
  v10.3-era driver (firmware v3.x) added MK2-hardware localizer support and absolute-encoder
  multi-rotation tracking. *The exact bulk-read method name could not be confirmed from a
  primary source — verify the literal method signature against the SDK/driver source before
  citing it in code, rather than assuming a name.*
- **Pitfall:** reading channels one at a time via repeated single-channel calls defeats the
  entire purpose of the device and costs the same I2C-bus time as not having it. Also watch for
  a firmware-version mismatch between the physical OctoQuad and the driver in use — the driver
  API changed across firmware v2.x → v3.x, so a driver/firmware mismatch can silently
  misbehave rather than error clearly.

## Axon / Taura analog feedback servos

- **Not a vendor class at all** — there's no `Axon`/`Taura` import to grep for. Detect by usage
  pattern instead: an `AnalogInput` (`hardwareMap.get(AnalogInput.class, "name")`) read
  alongside a servo channel driving the same mechanism.
- **API surface:** `AnalogInput.getVoltage()` — readable range tops out at `getMaxVoltage()`
  (nominally 3.3V), though the hub's analog input ports are documented as tolerating up to 5V on
  the signal line.
- **Pitfall:** the analog feedback wire is a *separate* physical connection from the servo's PWM
  control wire and must land on an Analog Input port, not an encoder port — wiring it to the
  wrong port is the most common mistake. **Could not verify** a documented voltage-to-angle
  formula or calibration constant from Axon's own docs — their analog-output page explicitly
  says "Docs coming soon!" as of this writing. Don't hardcode a voltage/angle conversion
  constant pulled from a forum post; flag that it needs to be measured/calibrated per unit, not
  invented. The same applies to Taura analog-feedback servos — no independent documentation was
  found distinct from the Axon write-up; treat it as the same pattern, not a separately-verified
  API.

## Bulk caching (`LynxModule`) — cross-cutting, feeds all four sensors above

Every I2C sensor above (Pinpoint, OTOS, OctoQuad) is read through the same hub bulk-read path,
so a bulk-caching mistake silently stales out all of their readings, not just one device's.

- **Class:** `com.qualcomm.hardware.lynx.LynxModule`.
- **API surface:** `setBulkCachingMode(LynxModule.BulkCachingMode mode)` with modes `OFF`,
  `AUTO`, `MANUAL`; `clearBulkCache()`.
- **Pitfall:** in `MANUAL` mode, the cache is **never cleared automatically** — a missing
  `clearBulkCache()` call at the top of every loop iteration (for every hub on the robot) just
  keeps returning the same stale values forever, with no exception at all. `AUTO` mode is the
  safer default for most teams; `MANUAL` only pays off if the small performance edge matters and
  the per-loop clear is applied reliably on every hub.

---

## Sources

- [Limelight 3A Quick-Start (FTC)](https://docs.limelightvision.io/docs/docs-limelight/getting-started/limelight-3a)
- [Limelight3A 11.0.0 API (javadoc.io)](https://javadoc.io/static/org.firstinspires.ftc/Hardware/11.0.0/com/qualcomm/hardware/limelightvision/Limelight3A.html)
- [com.qualcomm.hardware.limelightvision package summary](https://javadoc.io/static/org.firstinspires.ftc/Hardware/11.1.0/com/qualcomm/hardware/limelightvision/package-summary.html)
- [goBILDA-Official/FtcRobotController-Add-Pinpoint](https://github.com/goBILDA-Official/FtcRobotController-Add-Pinpoint)
- [Pinpoint Odometry Computer User Guide (PDF)](https://www.gobilda.com/content/user_manuals/3110-0002-0001%20User%20Guide.pdf)
- [SDK v11.0 Broke Old GoBilda Pinpoint — FTC community forum](https://ftc-community.firstinspires.org/t/sdk-v11-0-broke-old-gobilda-pinpoint/1288)
- [SparkFun_Qwiic_OTOS_FTC_Java_Library (GitHub)](https://github.com/sparkfun/SparkFun_Qwiic_OTOS_FTC_Java_Library)
- [SensorSparkFunOTOS.java — official FTC SDK sample](https://github.com/FIRST-Tech-Challenge/FtcRobotController/blob/master/FtcRobotController/src/main/java/org/firstinspires/ftc/robotcontroller/external/samples/SensorSparkFunOTOS.java)
- [SparkFun OTOS software setup — FTC](https://docs.sparkfun.com/SparkFun_Optical_Tracking_Odometry_Sensor/software_setup-FTC/)
- [OTOS not holding configuration in FTC SDK — SparkFun community](https://community.sparkfun.com/t/sparkfun-optical-tracking-odometry-sensor-otos-not-holding-configuration-in-ftc-sdk/60220)
- [Calibrating Your Odometry Sensor — SparkFun Learn](https://learn.sparkfun.com/tutorials/calibrating-your-odometry-sensor/all)
- [DigitalChickenLabs/OctoQuad (GitHub)](https://github.com/DigitalChickenLabs/OctoQuad)
- [LynxModule (FTC API, SkyStone-era doc)](https://first-tech-challenge.github.io/SkyStone/com/qualcomm/hardware/lynx/LynxModule.html)
- [LynxModule.BulkCachingMode](https://first-tech-challenge.github.io/SkyStone/com/qualcomm/hardware/lynx/LynxModule.BulkCachingMode.html)
- [Bulk Reads — Game Manual 0](https://gm0.org/en/latest/docs/software/tutorials/bulk-reads.html)
- [Game Manual 0 — servo guide](https://gm0.org/en/latest/docs/power-and-electronics/servo-guide/choosing-servo.html)
- [Axon Analog Output docs (incomplete — "Docs coming soon!")](https://docs.axon-robotics.com/servos/analog-output)
- [FTCLib Hardware docs — AnalogInput usage](https://docs.ftclib.org/ftclib/features/hardware)
- [Game Manual 0 — common hardware components / AnalogInput](https://gm0.org/en/latest/docs/software/getting-started/common-hardware-components.html)
