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
| `09-migration.md` (section 7b) | `questions/09-migration.md` |
| `10-cloning.md` (section 7b) | `questions/10-cloning.md` |
| `11-live-migration.md` (section 7b) | `questions/11-live-migration.md` |
| `12-node-maintenance.md` (section 7b) | `questions/12-node-maintenance.md` |
| `13-load-balancing.md` (section 7b) | `questions/13-load-balancing.md` |
| `14-health-probes.md` (section 7b) | `questions/14-health-probes.md` |
| `15-node-failure.md` (section 7b) | `questions/15-node-failure.md` |
| `16-sysadmin.md` (section 7b) | `questions/16-sysadmin.md` |
| `mock-exam-1.md` (section 7b) | `questions/mock-exam-1.md` |

## How to use these
1. Grade your own attempt against the acceptance criteria in the question
   file first, by hand, using plain `oc`/`virtctl` commands.
2. Then read this file to see one valid way to reach it and compare against
   what you did. There is usually more than one correct path (declarative
   YAML vs imperative `oc`/`virtctl` vs console) — the solution shows the
   fastest CLI path, since that's what the clock rewards.
3. `scripts/verify-qNN.sh <namespace>` (section 7b) runs a few of the
   acceptance checks automatically, for the objectives where that's fast to
   automate. It supplements your own grading; it does not replace it.
4. Log every miss in `docs/miss-log.md`, referencing the objective number.
