# solutions/

Worked answers to `questions/`. Don't open these before you attempt the task
and hit either the timer or a wall — that's the whole point of dummy exam
practice. Same numbering and namespaces as the matching `questions/*.md` file.

| File | Matches |
|------|---------|
| `01-operator.md` | `questions/01-operator.md` |
| `02-vm-access.md` | `questions/02-vm-access.md` |
| `03-networking.md` | `questions/03-networking.md` |
| `04-external-networks.md` | `questions/04-external-networks.md` |
| `05-storage.md` | `questions/05-storage.md` |
| `06-oadp.md` | `questions/06-oadp.md` |
| `07-templates.md` | `questions/07-templates.md` |
| `08-snapshots.md` | `questions/08-snapshots.md` |
| `09-migration.md` | `questions/09-migration.md` |
| `10-cloning.md` | `questions/10-cloning.md` |
| `11-live-migration.md` | `questions/11-live-migration.md` |
| `12-node-maintenance.md` | `questions/12-node-maintenance.md` |
| `13-load-balancing.md` | `questions/13-load-balancing.md` |
| `14-health-probes.md` | `questions/14-health-probes.md` |
| `15-node-failure.md` | `questions/15-node-failure.md` |
| `16-sysadmin.md` | `questions/16-sysadmin.md` |
| `mock-exam-1.md` | `questions/mock-exam-1.md` (maps each task to the solution above) |

## How to use these
1. Grade your own attempt against the acceptance criteria in the question
   file first, by hand, using plain `oc`/`virtctl` commands.
2. Then read this file to see one valid way to reach it and compare against
   what you did. There is usually more than one correct path (declarative
   YAML vs imperative `oc`/`virtctl` vs console) — the solution shows the
   fastest CLI path, since that's what the clock rewards.
3. `scripts/verify-qNN.sh <objective-number> <namespace>` runs a few of the
   acceptance checks automatically, for the parts that are fast to automate.
   It supplements your own grading; it does not replace it — several
   acceptance criteria (a ping actually working, a guest console showing a
   login prompt) need a human watching the terminal.
4. Log every miss in `docs/miss-log.md`, referencing the objective number.
