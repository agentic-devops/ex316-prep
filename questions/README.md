# questions/

Dummy exam tasks, written in the same voice as EX316: a scenario, then numbered
instructions, each with a fixed time budget. Do these cold, with a timer, using
only `oc explain`, `--help` and product documentation — no labs/, no commands/.

| File | Objectives covered |
|------|---------------------|
| `01-operator.md` | 1 |
| `02-vm-access.md` | 2 |
| `03-networking.md` | 3 |
| `04-external-networks.md` | 4 |
| `05-storage.md` | 5 |
| `06-oadp.md` | 6 |
| `07-templates.md` | 7 |
| `08-snapshots.md` | 8 |
| `09-migration.md` (section 6b) | 9 |
| `10-cloning.md` (section 6b) | 10 |
| `11-live-migration.md` (section 6b) | 11 |
| `12-node-maintenance.md` (section 6b) | 12 |
| `13-load-balancing.md` (section 6b) | 13 |
| `14-health-probes.md` (section 6b) | 14 |
| `15-node-failure.md` (section 6b) | 15 |
| `16-sysadmin.md` (section 6b) | 16 |
| `mock-exam-1.md` (section 6b) | full-length mock, one task per objective |

## How to run one
1. Reset the target namespace(s) if you've used them before: `scripts/reset-lab.sh <lab-number>`.
2. Set a timer for the stated budget.
3. Work only from the task text. If you'd need the internet or a saved note in the real exam, you can't use it here either.
4. When the timer ends (or you finish), grade yourself against `solutions/` (section 9) and log any miss in `docs/miss-log.md`.

## Naming
These use their own namespaces (not the ones in `labs/`) so you can't half-remember the answer from having built it in `labs/` five minutes earlier.
