# Fork Notes

[![Sync main](https://github.com/bmusat/homekit-ratgdo32/actions/workflows/sync-main.yml/badge.svg?branch=main-fork)](https://github.com/bmusat/homekit-ratgdo32/actions/workflows/sync-main.yml)

This is my fork of [ratgdo/homekit-ratgdo32](https://github.com/ratgdo/homekit-ratgdo32),
maintained to develop and test personal bug fixes before submitting them upstream.  Currently
there are three branches tracked here.

`main` is kept as an untouched, byte-for-byte mirror of upstream `main` which is always safe to
fast-forward. This branch (`main-fork`) is the default branch and it carries the same source
as `main`, plus some unique files (like this `FORK-NOTES.md` and various helper scripts detailed
below in the Tools section) and the CI automation below.

## Active fix branches

- **[`laser-on-door-open`](../../tree/laser-on-door-open)** — Fires the parking-assist laser
  immediately on door-open instead of waiting on vehicle-presence detection, which took 6+
  minutes on my install. Minimal, single-commit timing fix — no HomeKit changes.
- **[`laser-fix-hk-sync`](../../tree/laser-fix-hk-sync)** — Branched on top of
  `laser-on-door-open`, adds one more commit: fixes HomeKit not reflecting laser state changes
  that originate from firmware (door-open trigger, vehicle-arrival trigger, or the auto-off
  timer) instead of a manual toggle. Kept as a separate branch on top so the timing fix and
  the HomeKit-sync fix stay as distinct, individually reviewable commits. Current plan is to
  submit both together as one combined upstream PR once this branch has had a stability
  burn-in on hardware.
- **[`lock-state-crosstalk`](../../tree/lock-state-crosstalk)** — Fixes the "Remotes" toggle
  silently flipping on its own — root-caused via ~5 days of syslog capture to
  `DEV_GarageDoor::update()` acting on both the door and lock characteristics on every HomeKit
  write to the service, instead of only the one actually changed. Opening/closing the door
  could silently re-send whatever the lock was last set to. Rebased on top of
  `laser-fix-hk-sync` (not `upstream/main` directly) so it can become its own separate,
  later PR without being tangled up in the laser work. Not yet flashed to hardware —
  waiting on the `laser-fix-hk-sync` burn-in above before doing a real before/after
  comparison.

| Branch | Based on | Status |
|---|---|---|
| [`laser-on-door-open`](../../tree/laser-on-door-open) | `v3.5.0-7-gcdf0708` (current `upstream/main`) | Fully caught up |
| [`laser-fix-hk-sync`](../../tree/laser-fix-hk-sync) | `laser-on-door-open` + 1 commit | Fully caught up; running on hardware |
| [`lock-state-crosstalk`](../../tree/lock-state-crosstalk) | `laser-fix-hk-sync` + 1 commit | Fully caught up; not yet flashed |

Status: `laser-fix-hk-sync` is currently running on hardware for a stability burn-in.
`lock-state-crosstalk` is staged on top and ready, but deliberately held back until that
burn-in looks solid. Plan: `laser-on-door-open` + `laser-fix-hk-sync` as one combined
upstream PR first, then `lock-state-crosstalk` as its own separate PR afterward — not all
three at once.

### Deleted branches (historical)

- ~~`lock-toggle-dedup`~~ — deleted 2026-07-15. Theorized (2026-07-07, against `v3.4.6`) that
  the "Remotes" toggle flip was caused by duplicate wall-console rolling-code frames on the
  wire, and added a guard in `comms.cpp` to drop exact repeat frames. Shelved 2026-07-09 after
  ~5 days of syslog capture found no supporting evidence — every observed flip traced to
  `lock-state-crosstalk`'s root cause instead. Kept here only as a historical note.

## Automation

- `sync-main.yml` — daily, fast-forwards `main` to `upstream/main`, then merges `main` into
  `main-fork`. On success, triggers `build-check.yml`.
- `build-check.yml` — runs via the `sync-main.yml` chain above or manual dispatch (no
  independent schedule). Dry-run merges the latest upstream into each fix branch (scratch
  only, never pushed) and builds both a `pinned` (as-pushed) and `latest` (merged with
  upstream) variant via PlatformIO. Skips rebuilding when the exact code combination was
  already verified and the artifact is still fresh (90-day cap). Result is written to the
  run's job summary, and a merge conflict or build failure now fails the job rather than
  just warning. Artifact names include a short hash of the exact source tree built, so
  `pinned` and `latest` show the same hash whenever a branch is fully caught up with upstream.

## Tools

Fork-only helper scripts live in [`tools/`](../../tree/main-fork/tools).

- `./tools/sse-load-test.sh` — Docker-based load test for the SSE subscription slots (see
  script header for usage). Used to reproduce a socket-exhaustion issue caused by stale/dead
  SSE connections (e.g. a phone dropping off WiFi mid-session) accumulating until the device
  becomes unresponsive.
- `./tools/find-artifact.sh [pattern] [--download]` — finds the most recent non-expired
  `build-check.yml` artifact(s) via the repo-wide Actions API, since `build-check.yml`'s
  skip-if-unchanged logic means most runs produce nothing and the Actions UI is tedious to
  search by hand. Lists the latest per branch/variant by default; pass a pattern to filter,
  add `--download` to fetch the single matching one directly.
