# EX316 Study Plan

Ties together everything else in this repo. The goal stated up front was a
2-3 week prep window aimed at a first-attempt pass, so this plan assumes
that budget and roughly 45-90 minutes on weekdays plus one longer weekend
session. Compress or stretch it based on how the confidence tracker and mock
scores actually look — the schedule below is a default, not a promise.

## Before day 1
- [ ] `./scripts/setup-all.sh` against a real cluster with virtualization
      support (bare metal or nested virt). Confirm with `./scripts/verify-setup.sh`.
- [ ] Read `docs/objectives-map.md` once, end to end, so every lab and
      command file's purpose is obvious later.
- [ ] Skim `commands/master-commands.md` once. Don't try to memorize it yet —
      just know it exists and roughly what's in each section.

## Week 1 — build the labs, drill as you go
Work `labs/` in order. For each objective: read the lab README, do the
tasks once with the file open, then immediately redo the same tasks from
`commands/drill-blanks.md` with the lab file closed. Update the confidence
score in `docs/objectives-map.md` before moving on.

| Day | Objectives | Labs |
|-----|-----------|------|
| 1 | 1, 2 | `01-operator`, `02-vm-access` |
| 2 | 3 | `03-networking` |
| 3 | 4, 13 | `04-external-networks`, `13-load-balancing` |
| 4 | 5 | `05-storage` |
| 5 | 6 | `06-oadp` |
| 6 (weekend) | 7, 8 | `07-templates`, `08-snapshots` — longer session, catch up on anything slipping |
| 7 | 9, 10 | `09-migration-import`, `10-cloning` |
| 8 | 11 | `11-live-migration` |
| 9 | 12, 15 | `12-node-maintenance`, `15-node-failure` |
| 10 | 14 | `14-health-probes` |
| 11 | 16 | `16-sysadmin` |

By the end of week 1, every objective has been touched at least once and
has a confidence score. Anything you scored 3 or below goes on the week 2
priority list below, not at the bottom of the pile.

## Week 2 — recall drills, first mock, close gaps
| Day | Focus |
|-----|-------|
| 12 | Full pass through `commands/drill-blanks.md`, all 16 objectives, timed, no notes. Log every miss. |
| 13 | Re-drill only the objectives scored 3 or below in `docs/objectives-map.md`. Re-run their lab from a fresh reset (`scripts/reset-lab.sh <NN>`). |
| 14 | Work every file in `questions/01-*.md` through `08-*.md` cold, timed individually. Grade against `solutions/`. |
| 15 (weekend) | **Mock exam 1**: `questions/mock-exam-1.md`, full 4-hour block, no breaks longer than a bathroom trip. Grade with `scripts/verify-qNN.sh` plus your own eyes. |
| 16 | Miss review from the mock: for every failed or slow task, redo just that objective's lab and drill file again. |
| 17 | Work every file in `questions/09-*.md` through `16-*.md` cold, timed individually, if not already covered by the mock miss review. |
| 18 | Second full pass of `commands/drill-blanks.md`. Target: every answer typed correctly on the first try, under the time it took in week 1. |

## Week 3 (if needed) — repeat until confident, then book it
| Day | Focus |
|-----|-------|
| 19 | **Mock exam 2** (rerun `mock-exam-1.md` cold — you'll remember specifics, but the point now is speed and not fumbling syntax, not surprise). |
| 20 | Close whatever `docs/miss-log.md` still shows after two mocks. |
| 21 | Light review only: reread `commands/master-commands.md` end to end, skim every lab README's "Gotchas" section. Do not cram new material the day before. |

Book the exam once you can complete `mock-exam-1.md` in under 4 hours with
every acceptance criterion met, twice in a row on different days.

## Daily 20-30 minute maintenance drill (once week 1 is done)
Pick the 2-3 lowest-confidence objectives from `docs/objectives-map.md` and
run their block in `commands/drill-blanks.md` cold. This is the single
highest-leverage habit in this whole repo — it's what turns "I did this
once" into "I can't get this wrong."

## Definition of done, per objective
An objective is genuinely ready when all three are true:
1. You can complete its `commands/drill-blanks.md` block with zero
   hesitation and zero looked-up syntax.
2. You can complete its `questions/*.md` file inside the stated time
   budget, cold, and pass every acceptance criterion.
3. You can explain, out loud, every item in its lab README's "Gotchas"
   section without rereading it first.

## Keeping score
- `docs/objectives-map.md` confidence tracker: update weekly, not daily —
  it should reflect a trend, not today's mood.
- `docs/miss-log.md` (create this the first time you need it): one line per
  miss — objective number, what went wrong, one-line fix. Review it before
  every mock exam. Delete an entry once you've gotten it right cold three
  times in a row.
- Mock exam scores: keep a running note at the bottom of this file (below)
  so you can see the trend across attempts.

## Mock exam log
| Date | Attempt | Score (/16) | Time used | Notes |
|------|---------|-------------|-----------|-------|
| | 1 | | | |
| | 2 | | | |
| | 3 | | | |

## Exam-day reminders
- No internet, no personal notes — only in-exam product documentation.
- Read every task fully before typing anything; partial credit exists per
  task, so don't burn 40 minutes perfecting task 1 while task 9 sits
  untouched.
- If something is genuinely stuck (an operator not installing, a node not
  draining), move on and come back — same rule as `mock-exam-1.md`.
- Verify your own work as you go (`oc get`, `oc describe`, `virtctl` console
  checks) rather than assuming a manifest applied correctly. `scripts/verify-qNN.sh`
  is repo-only, but the habit of self-checking each task before moving to
  the next is exactly what carries over.
