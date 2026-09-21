# EX316 Prep: Red Hat Certified Specialist in OpenShift Virtualization

Hands-on practice repo for **EX316** (OpenShift Container Platform 4.18).
Goal: command-recall fluency, not recognition. Everything here is meant to be
typed from memory against a live cluster.

## Exam facts
- Performance-based, single 4-hour section, live OCP 4.18 cluster
- No internet, no notes; product documentation is available in the exam
- Official objectives: https://www.redhat.com/en/services/training/red-hat-certified-specialist-openshift-virtualization-ex316

## Repo layout
| Path | Purpose |
|------|---------|
| `docs/objectives-map.md` | Official objectives mapped to labs, commands and questions |
| `setup/` | Operator install manifests (CNV, NMState, OADP, MTV) |
| `labs/NN-topic/` | Starter YAML and README per objective area |
| `commands/` | Must-know commands, grouped by objective, for daily drilling |
| `questions/` | Dummy exam tasks, written in exam style |
| `solutions/` | Worked answers (do not open before attempting) |
| `scripts/` | Reset, verify and grading helpers |

## How to use
1. Stand up a cluster with virtualization support (bare metal or nested virt) and `oc login`.
2. Apply `setup/` once.
3. Work a `questions/` file with a timer. Only the docs are allowed.
4. Run `scripts/verify-*.sh` for the section, then compare with `solutions/`.
5. Reset with `scripts/reset-lab.sh <NN>` and repeat until the commands are automatic.

## Rules for yourself
- No copy/paste from this repo during timed drills. Use `oc explain`, `virtctl --help` and the in-cluster docs only.
- Prefer CLI (`oc`, `virtctl`) over the console, but know the console path for VM create, clone, snapshot and migrate.
- Track misses in `docs/miss-log.md` and re-drill those first.

## Status
- [ ] Section 1 skeleton
- [ ] setup/
- [ ] labs/
- [ ] commands/
- [ ] questions/
- [ ] solutions/ and scripts/
- [ ] STUDY-PLAN.md
