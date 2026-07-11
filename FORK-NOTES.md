# Fork Notes

[![Sync main](https://github.com/bmusat/homekit-ratgdo32/actions/workflows/sync-main.yml/badge.svg?branch=main-fork)](https://github.com/bmusat/homekit-ratgdo32/actions/workflows/sync-main.yml)

This is my fork of [ratgdo/homekit-ratgdo32](https://github.com/ratgdo/homekit-ratgdo32),
maintained to develop and test personal bug fixes before submitting them upstream.  Currently
there are three branches I'm working on.

`main` is kept as an untouched, byte-for-byte mirror of upstream `main` which is always safe to
fast-forward. This branch (`main-fork`) is the default branch and it carries the same source
as `main`, plus some unique files (this `FORK-NOTES.md`, `viewlog-fix.sh`, and `sse-load-test.sh`) and the CI automation below.

## Active fix branches

| Branch | Purpose |
|---|---|
| [`laser-on-door-open`](../../tree/laser-on-door-open) | Fires the parking-assist laser immediately on door-open instead of waiting on vehicle-presence detection, which took 6+ minutes on my install. Also fixes HomeKit not reflecting laser changes triggered by the firmware itself, not just manual toggles. |
| [`lock-state-crosstalk`](../../tree/lock-state-crosstalk) | Fixes the "Remotes" toggle silently flipping on its own — root-caused via ~5 days of syslog capture to `DEV_GarageDoor::update()` acting on both the door and lock characteristics on every HomeKit write to the service, instead of only the one actually changed. Opening/closing the door could silently re-send whatever the lock was last set to. |
| [`lock-toggle-dedup`](../../tree/lock-toggle-dedup) | Shelved — originally theorized the same "Remotes" flip was caused by duplicate wall-console rolling-code frames, but log evidence didn't support it (every observed flip traced back to `lock-state-crosstalk`'s root cause instead). Left as a still-plausible, untested defense against a separate wire-protocol scenario, not currently being pursued. |

`laser-on-door-open` and `lock-toggle-dedup` are rebased on the `v3.4.6` tag; `lock-state-crosstalk`
is branched from current `main`. Status: local testing in progress; intended as separate pull
requests to upstream once validated.

## Automation

- `sync-main.yml` — daily, fast-forwards `main` to `upstream/main`, then merges `main` into
  `main-fork`. On success, triggers `build-check.yml`.
- `build-check.yml` — runs via the `sync-main.yml` chain above or manual dispatch (no
  independent schedule). Dry-run merges the latest upstream into each fix branch (scratch
  only, never pushed) and builds both a `pinned` (as-pushed) and `latest` (merged with
  upstream) variant via PlatformIO. Skips rebuilding when the exact code combination was
  already verified and the artifact is still fresh (90-day cap). Result is written to the
  run's job summary.

## Tools

- `viewlog-fix.sh <host>` — streams the device's live log over SSE (corrected version of
  upstream's `viewlog.sh`, which has a query-param bug that silently breaks it).
- `sse-load-test.sh` — Docker-based load test for the SSE subscription slots (see script
  header for usage). Used to reproduce a socket-exhaustion issue caused by stale/dead SSE
  connections (e.g. a phone dropping off WiFi mid-session) accumulating until the device
  becomes unresponsive.
