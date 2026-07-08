# Fork Notes

[![Sync main](https://github.com/bmusat/homekit-ratgdo32/actions/workflows/sync-main.yml/badge.svg?branch=main-fork)](https://github.com/bmusat/homekit-ratgdo32/actions/workflows/sync-main.yml)

This is my fork of [ratgdo/homekit-ratgdo32](https://github.com/ratgdo/homekit-ratgdo32),
maintained to develop and test personal bug fixes before submitting them upstream.  Currently
there are two branches I'm working on.

`main` is kept as an untouched, byte-for-byte mirror of upstream `main` which is always safe to
fast-forward. This branch (`main-fork`) is the default branch and it carries the same source
as `main`, plus some unique files (this `FORK-NOTES.md`, `viewlog-fix.sh`, and `sse-load-test.sh`) and the CI automation below.

## Active fix branches

| Branch | Purpose |
|---|---|
| [`laser-on-door-open`](../../tree/laser-on-door-open) | Fires the parking-assist laser immediately on door-open instead of waiting on vehicle-presence detection, which took 6+ minutes on my install. Also fixes HomeKit not reflecting laser changes triggered by the firmware itself, not just manual toggles. |
| [`lock-toggle-dedup`](../../tree/lock-toggle-dedup) | Fixes the "Remotes" toggle silently reverting after a wall-console press — e.g. setting it to `disabled` and having it flip back to `enable` on its own. Caused by duplicate rolling-code frames each being processed as a separate toggle; fixed by dropping exact repeat frames. |

Both are rebased on the `v3.4.6` tag. Status: local testing in progress; intended as separate
pull requests to upstream once validated.

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
