---
name: log-diagnostics
description: Parses robot/driver-station logs and pasted error output to diagnose hardware faults, config mismatches, and connectivity issues, citing exact log lines and the repo's actual Constants/deploy-JSON/vendordep config. Use when asked to "diagnose this log", "why did the robot brown out", "why did the radio drop", "what's wrong with this error output", or to investigate a crash/fault from a driver-station or roboRIO/Control Hub log.
license: MIT
---

# Log Diagnostics

You parse a robot/driver-station log or pasted error output and diagnose what went wrong,
cross-referencing the repo's actual hardware configuration so each diagnosis is grounded in code
that really exists, not a guess about what "usually" causes that error.

This is not a subsystem or vendor wiring tool — `vendor-hardware-integration` configures the
vendor object itself; this skill only checks whether logged runtime behavior matches what's
already configured, and never edits that configuration. It's also not a PR reviewer —
`pr-code-review`/`frc-code-review`/`ftc-code-reviewer` judge a diff before merge; this skill
diagnoses what already happened at runtime, from a log, after the fact. Different input, different
question.

---

## Rules that outrank everything else

1. **Never guess a root cause without evidence in the log.** Every diagnosis traces back to a
   specific quoted line and timestamp — not "this is usually caused by."
2. **Cross-reference the repo's actual config before naming a mismatch.** Never assume a CAN ID,
   device name, or vendor library from memory or convention — check Constants, deploy JSON, and
   vendordeps and say what's actually declared there.
3. **Cite everything concretely.** Every diagnosis pairs the exact log line (with timestamp/line
   number) with the exact code location (`file:line`) it relates to. No vague "check your wiring"
   or "this might be a CAN issue" flags.
4. **Read/diagnose-only.** Never edit code to "fix" what's found here — only report. Applying a
   fix is a human's call, or another skill's job.
5. **Never push — and by default, makes no commits at all.** Unlike sibling skills that edit and
   commit, this skill doesn't touch the working tree, so there's nothing to push. If a run somehow
   produces a change, that's a bug in the run, not this skill's intended behavior.
6. **Re-run every time, from scratch.** Each request parses the log fresh and cross-references the
   *current* state of the repo — no assumed memory of a prior diagnostic pass.
7. **Can't confidently diagnose something? Say so.** Report it as unresolved/ambiguous rather than
   picking the more likely of two plausible causes.

---

## Step 1 — Ingest the log or error output

Don't assume one fixed input format — detect what you were actually handed:

- **Pasted excerpt.** Error output or log lines pasted directly into the conversation.
- **Local file path.** A driver-station log, roboRIO console/system log, FTC Driver Station log,
  or similar text log file.
- **WPILib `.wpilog`/DataLog file.** A binary telemetry format, not parseable as text. This skill
  does not decode `.wpilog` binaries directly. Instead, look for an accompanying human-readable
  log in the same log directory — the DS log or rio console log — and parse that for fault and
  error text. **If only a raw `.wpilog` is given with no companion text log**, say so explicitly in
  the report and ask for a console/DS text log or export instead of pretending to read the binary.

If the input is ambiguous (e.g. a blob of text with no clear source), ask what produced it —
roboRIO console, DS log, FTC Driver Station — rather than guessing a format and misreading it.

---

## Step 2 — Cross-reference the repo's hardware config

Before classifying anything, build a picture of what the repo actually declares:

```bash
grep -rn "CAN\|canId\|CanId\|DeviceID" --include="*Constants*" .
find . -path "*/vendordeps/*.json"
find . -iname "*.json" -path "*deploy*"
```

Index the declared CAN IDs, device names, and vendor libraries from Constants files, deploy JSON
(e.g. swerve/PathPlanner config), and vendordeps declarations. This grep-based cross-reference
against real repo state — not assumption — is what distinguishes this skill from a generic log
reader: a later step checks each logged device/error against this index instead of describing the
error in the abstract.

---

## Step 3 — Classify each error/warning line

Walk the log and sort what's found into three buckets, recording the exact timestamp or line
number for each item:

- **Hardware faults** — brownout events, motor controller fault codes (CTRE/REV-specific fault
  bits), watchdog/loop-overrun warnings, sensor disconnects.
- **Config mismatches** — a referenced CAN ID not found or in conflict, a missing vendor
  dependency (`ClassNotFoundException`, library-not-found errors), a firmware/library version
  mismatch.
- **Connectivity issues** — radio or robot radio bridge drops, NetworkTables connection loss,
  driver-station communications loss or unexpected E-stop.

A line that doesn't clearly fit one of these, or reads as ordinary operational noise, is left out
of the report rather than force-fit into a category.

---

## Step 4 — Diagnose root cause per issue

For each classified item, check it against Step 2's index:

- Does the logged CAN ID/device name match what's declared in Constants? If not, say exactly what
  the log shows vs. what the code declares, with both locations cited.
- Is the vendor library the log implicates actually present in vendordeps, and at the version the
  log's behavior implies?
- **If nothing in the repo's config explains the fault** — the code looks correctly configured —
  say so explicitly ("no repo config mismatch found; likely a physical or environmental cause,
  e.g. loose CAN wiring or a browned-out battery") instead of inventing a code-based explanation
  to have something to report.
- **If two causes are both plausible and the log doesn't disambiguate them**, report both and mark
  the item ambiguous rather than picking one.

---

## Step 5 — Report

Since this skill is diagnostic-only, the report is the primary output — short and structured, one
entry per issue:

- **Log evidence:** the exact quoted line, with timestamp/line number.
- **Category:** hardware fault / config mismatch / connectivity issue.
- **Likely root cause:** stated plainly, tied to the evidence.
- **Related code location:** `file:line` if the diagnosis ties to repo config, or "no repo config
  match — likely physical/environmental" if it doesn't.

Unresolved or ambiguous items get their own subsection at the end, clearly separated from
confident findings, so a reader doesn't mistake a guess for a diagnosis.

No push command follows the report — unlike the edit+commit sibling skills in this repo, this
skill makes no commits by default, so there's nothing to push. The report itself is the
deliverable, written to be posted as-is into a PR comment or chat thread, the same way
`pr-code-review`'s report is meant to be posted as an automated PR comment.

---

## Running unattended

Read-only changes what "unattended" means here: there's no push/commit gate to preserve, only a
reporting discipline to preserve.

- **Never take a corrective action beyond reporting, even when the root cause looks obvious.** No
  editing Constants, no opening a PR, no filing an issue — report the finding and stop.
- **Ambiguity becomes "report as unresolved," not a guess.** An autonomous run under time pressure
  still picks accuracy over confidence — an item that can't be disambiguated from the log gets
  flagged as such in the output, never resolved to the more likely of two causes just to look
  decisive.
- **No git operations at all.** Because nothing is edited, this skill can run as a pure read/report
  pass in CI or ad hoc, with no branch, commit, or push step to configure.

---

## Scope boundary

**Not `vendor-hardware-integration`.** That skill configures and edits the vendor object's
construction/configuration code. This skill only diagnoses whether logged runtime behavior matches
what's already configured — it never edits Constants, deploy JSON, or vendor config, even when the
fix looks obvious.

**Not `pr-code-review` / `frc-code-review` / `ftc-code-reviewer`.** Those review a PR diff for
code-quality and hardware-safety issues before merge. This skill diagnoses a runtime log or error
output after the fact — different input (log vs. diff), different question (why did the robot do
this vs. is this diff safe to merge). If diagnosing a log surfaces a clear code fix — say, a wrong
CAN ID in Constants — the report names it but never applies it; that's a human's call, or a task
for an edit+commit skill like `vendor-hardware-integration`, not this one.
