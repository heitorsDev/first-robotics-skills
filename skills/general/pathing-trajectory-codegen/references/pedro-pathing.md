# Pedro Pathing — 2.x → 3.x rename reference

Pedro Pathing 3.x is a re-architecture, not a point release. Check the gradle dependency
version before writing or editing any Pedro code — 3.x names and 2.x names are not
interchangeable, and silently mixing them compiles against the wrong artifact or produces
the wrong runtime behavior.

## Gradle dependency

- **2.x**: single artifact, `com.pedropathing:ftc:2.x.x`.
- **3.x**: split into `com.pedropathing:core:3.x.x` + `com.pedropathing:revhub:3.x.x` +
  `com.pedropathing:tuning:1.x.x` (all on Maven Central; the old custom Pedro repo is gone).
- SolversLib wrapper: `org.solverslib:pedroPathing` — `0.3.3`–`0.3.5` target Pedro 2.x,
  `0.3.6`+ targets Pedro 3.0.0+.

## API renames (2.x → 3.x)

| Pedro 2.x | Pedro 3.x |
|---|---|
| `PathChain` | `Path` (with `AtomicPath` / `CompoundPath`) |
| `com.pedropathing.geometry.Pose` | `com.pedropathing.math.Pose` |
| `pose.getX()` / `.getY()` / `.getHeading()` | `pose.x()` / `.y()` / `.heading()` |
| `follower.getPose()` | `follower.pose()` |
| `follower.followPath(path)` | `follower.follow(path)` |
| `follower.breakFollowing()` | `follower.stop()` |
| `follower.holdPoint(pose)` | `follower.hold(pose)` |
| `follower.isBusy()` / `.getFollowingPathChain()` | `follower.following()` / `.isBusy()` / `.idle()` / `.mode()` |
| `follower.startTeleopDrive()` | `follower.manual(...)` |

Write code matching whichever column the repo's gradle dependency version pins. Never write
a 2.x name against a 3.x dependency, or vice versa.

## Behavioral change: `maxPathSpeed`

Not just a rename — the semantics changed.

- **2.x**: a follower-wide power fraction, passed positionally.
  ```java
  follower.followPath(chain, 0.5, true);
  ```
- **3.x**: a fraction of the robot's maximum *achievable velocity*, attached per-path as a
  modifier.
  ```java
  follower.follow(path.with(foresightConfig.maxPathSpeed.at(0.5)));
  ```

Porting a 2.x call to 3.x syntax without this change produces code that compiles but drives
differently. Flag this in the Step 5 report if a repo's existing calls look like a
straight syntax port rather than an intentional re-tune.

Source: [Mona-Shores-FTC-Robotics/biobuzz#12](https://github.com/Mona-Shores-FTC-Robotics/biobuzz/pull/12)
(Pedro Pathing 2.1.2 → 3.0.1 migration), [docs.seattlesolvers.com/installation](https://docs.seattlesolvers.com/installation).
