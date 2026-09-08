# Fork Notes

[![Sync main](https://github.com/bmusat/homekit-ratgdo32/actions/workflows/sync-main.yml/badge.svg?branch=main-fork)](https://github.com/bmusat/homekit-ratgdo32/actions/workflows/sync-main.yml)

This is my fork of [ratgdo/homekit-ratgdo32](https://github.com/ratgdo/homekit-ratgdo32),
maintained to develop and test personal bug fixes before submitting them upstream.  Currently
there are two branches tracked here.

`main` is kept as an untouched, byte-for-byte mirror of upstream `main` which is always safe to
fast-forward. This branch (`main-fork`) is the default branch and it carries the same source
as `main`, plus some unique files (like this `FORK-NOTES.md` and various helper scripts detailed
below in the Tools section) and the CI automation below.

## Active fix branches

- **[`laser-on-door-open`](../../tree/laser-on-door-open)** — Fires the parking-assist laser
  immediately on door-open instead of waiting on vehicle-presence detection, which took 6+
  minutes on my install. Minimal, single-commit timing fix — no HomeKit changes.
- **[`laser-fix-hk-sync`](../../tree/laser-fix-hk-sync)** — Branched on top of
  `laser-on-door-open`, adds two more commits: fixes HomeKit not reflecting laser state changes
  that originate from firmware (door-open trigger, vehicle-arrival trigger, or the auto-off
  timer) instead of a manual toggle, plus README documentation for the door-open checkbox.
  Kept as a separate branch on top so the timing fix and the HomeKit-sync fix stay as distinct,
  individually reviewable commits.

**Submitted upstream 2026-09-08 as [ratgdo/homekit-ratgdo32#201](https://github.com/ratgdo/homekit-ratgdo32/pull/201)**
("Add opt-in door-open laser trigger with HomeKit state sync") — both branches combined into
one PR (4 commits), rebased onto upstream's live `main` tip immediately before submitting.
Offered to split into two PRs if the maintainer would rather review them separately.

| Branch | Based on | Status |
|---|---|---|
| [`laser-on-door-open`](../../tree/laser-on-door-open) | `upstream/main` directly | Part of PR #201 |
| [`laser-fix-hk-sync`](../../tree/laser-fix-hk-sync) | `laser-on-door-open` + 2 commits | Part of PR #201, awaiting review |

Live staleness for each branch (commits behind `upstream/main`, days since its last commit) is
reported automatically in every `pinned` job's summary on the
[build-check.yml Actions page](../../actions/workflows/build-check.yml) — deliberately not
hand-tracked here anymore, since a number like that goes stale within a day and this note kept
drifting out of sync with reality.

### Rebasing fix branches: two different targets for two different purposes

`pinned` builds (see Automation below) aren't anchored to anything stable by default — a
fix branch only ever reflects whatever `upstream/main` looked like the last time someone
manually rebased it, then it just sits there while upstream keeps moving. There isn't one
single correct rebase target; it depends on what the rebase is for:

- **Routine maintenance** (periodically freshening a fix branch so it doesn't rot
  indefinitely, with no PR imminent): rebase onto the **latest release tag**, same policy
  as `main`'s own sync. Gives a citable, reproducible base ("built on top of `v3.5.4`")
  instead of an arbitrary, undocumented point on a moving branch.
- **Immediately before opening a PR**: rebase onto the **live `upstream/main` tip**, one
  final time, right before submitting. This isn't optional - GitHub evaluates PR
  mergeability against the maintainer's actual current `main`, not against whatever tag
  the branch was last anchored to, so this is the only way to catch (and fix yourself)
  any real content conflict before the maintainer ever sees it. Basing a submitted PR on
  an old tag doesn't protect against conflicts, it just delays discovering them.

In short: tag for stability between PRs, live tip right before submitting one.

## Test builds

Each active fix branch above gets a rolling pre-release build published automatically
whenever `build-check.yml` succeeds (see Automation below) — grab one from the
[Releases page](../../releases) (also linked in the sidebar) to try a branch without
setting up a PlatformIO build environment yourself. These are unofficial, unvetted test
builds from a personal fork, not affiliated with the upstream ratgdo project — use at
your own risk.

### Deleted branches (historical)

- ~~`lock-toggle-dedup`~~ — deleted 2026-07-15. Theorized (2026-07-07, against `v3.4.6`) that
  the "Remotes" toggle flip was caused by duplicate wall-console rolling-code frames on the
  wire, and added a guard in `comms.cpp` to drop exact repeat frames. Shelved 2026-07-09 after
  ~5 days of syslog capture found no supporting evidence — every observed flip traced to
  `lock-state-crosstalk`'s root cause instead. Kept here only as a historical note.
- ~~`lock-state-crosstalk`~~ — deleted 2026-08-26. Root-caused the "Remotes" toggle silently
  flipping to Enabled during HomeKit door operations (~5 days of syslog capture, 2026-07-10) to
  `DEV_GarageDoor::update()` acting on both the door and lock characteristics on every HomeKit
  write instead of only the one actually changed, and fixed it by guarding each with
  `updated()`. Never flashed to hardware — held back pending a repeatable pattern, since only
  one confirmed recurrence turned up in the following ~6 weeks of logs. Retired after
  discovering upstream independently landed the identical fix (commit `49e2884`, credited to a
  suggestion from @adub86 in [ratgdo/homekit-ratgdo32#190](https://github.com/ratgdo/homekit-ratgdo32/pull/190),
  2026-08-14) — same two characteristics, same `updated()` guard, same reasoning. `main`/
  `main-fork` now carries upstream's version, so this branch is redundant, not wrong. Kept here
  only as a historical note.

## Automation

- `sync-main.yml` — daily, fast-forwards `main` to upstream's **latest release tag**
  (not `upstream/main`'s branch tip, as of 2026-08-28), then merges `main` into `main-fork`.
  On success, triggers `build-check.yml`, and the job summary says so explicitly (with a
  link to the build-check.yml Actions page) rather than leaving that implicit. Switched from
  tracking the branch tip to tracking tags because upstream's maintainer treats the tip as a
  mutable staging area while a release is in progress - repeatedly amending its "Update
  CHANGELOG.md and version number" commit as more fixes land before the release ships. Turned
  out tags aren't fully immune either: on 2026-09-08 the same commit got rewritten again
  *before* `v3.5.3` was cut, so even the tag didn't descend cleanly from where `main` was
  parked. As of 2026-09-08, the fast-forward step **auto-recovers**: if `git merge --ff-only`
  to the latest tag fails, it falls back to `git reset --hard` onto that tag instead of
  erroring out - safe because `main` is documented to carry zero unique content and the tag
  is an immutable, deliberately-published release. The job summary flags this clearly
  (`### :warning: OK, but main was auto-recovered`) so it's visible without being a failure
  that pages anyone. Separately, `main`'s new content still has to merge into `main-fork`
  afterward, and that step **is not automated** - see the note below.
- `build-check.yml` — runs via the `sync-main.yml` chain above or manual dispatch (no
  independent schedule). Dry-run merges the latest upstream into each fix branch (scratch
  only, never pushed) and builds both a `pinned` (as-pushed) and `latest` (merged with
  upstream) variant via PlatformIO. Skips rebuilding when the exact code combination was
  already verified and the artifact is still fresh (7-day cap). Result is written to the
  run's job summary, and a merge conflict or build failure now fails the job rather than
  just warning. Artifact names include a short hash of the exact source tree built, so
  `pinned` and `latest` show the same hash whenever a branch is fully caught up with upstream.
  On a successful `pinned` build, also publishes/replaces a rolling GitHub pre-release
  tagged with the branch's short name (e.g. `laser-fix`), so anyone outside this fork can
  grab a build without digging through Actions runs — Actions artifacts are kept short-lived
  (7 days) purely as an internal CI/download convenience now that Releases cover the
  durable, public-facing copy. Only `pinned` is published, since `latest` is a scratch merge
  that's never committed anywhere and isn't tied to a reproducible ref. The release title and
  notes include the exact firmware version string (e.g. `3.5.0-laser-hk-fix-pinned`) - the
  same one the device itself reports as `Firmware version:` after flashing - so you can
  directly confirm a release matches what's currently running. Every `pinned` job's summary
  (both `OK` and `SKIPPED` outcomes) also reports how many commits behind `upstream/main` the
  branch tip is and how many days since its last commit, added 2026-08-27 so staleness is
  visible without running git commands by hand - see "Active fix branches" above for the
  reasoning on why that number isn't also hand-copied into this file.
- `cleanup-branch-release.yml` — fires on GitHub's `delete` branch event. Looks up the
  deleted branch's short name in `branch-tags.json` and deletes the matching pre-release
  (if any), so a merged/abandoned branch's release doesn't linger forever. Delete the
  branch first, then remove its `branch-tags.json` entry afterward in a separate commit —
  in the other order this lookup finds nothing and the release cleanup is skipped.

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
