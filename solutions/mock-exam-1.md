# Solution: mock-exam-1.md

This mock is the same 16 tasks as the single-objective question files, just
renamed to the `mock1-` prefix and run back to back. Rather than repeat every
command a third time, this file maps each mock task to the solution that
already has it in full, plus the one-line substitution needed.

| Mock task | Full solution | Substitute |
|-----------|----------------|------------|
| 1 — Operator | `01-operator.md` | none — identical task |
| 2 — VM access | `02-vm-access.md` | `q2-vmops` → `mock1-access`, `app01` → `t2-vm`, users → `mock1-editor`/`mock1-reader`/`mock1-operator` |
| 3 — Networking | `03-networking.md` | `q3-app` → `mock1-net`, `q3-web`/`q3-db` → `t3-web`/`t3-db` |
| 4 — External networks | `04-external-networks.md` | bridge/NAD name `q4-*` → `mock1-br` / reuse the NAD in `mock1-net`; attach the second NIC to `t3-web` instead of a fresh VM |
| 5 — Storage | `05-storage.md` | `q5-store` → `mock1-store`, `q5-vm` → `t5-vm` |
| 6 — OADP | `06-oadp.md` | back up `mock1-store` (Task 5's namespace) instead of a fresh one; VM name `t5-vm` |
| 7 — Templates | `07-templates.md` | template name → `mock1-tmpl`; same two-instantiation pattern |
| 8 — Snapshots | `08-snapshots.md` | `q8-snap` → `mock1-snap` |
| 9 — Migration/import | `09-migration.md` | `q9-import` → `mock1-import` |
| 10 — Cloning | `10-cloning.md` | `q10-clone` → `mock1-clone` |
| 11 — Live migration | `11-live-migration.md` | `q11-migr` → `mock1-migr` |
| 12 — Node maintenance | `12-node-maintenance.md` | target the node running the mock's Task 11 VM |
| 13 — Load balancing | `13-load-balancing.md` | `q13-lb` → reuse a VM's namespace from an earlier mock task, or `mock1-lb` |
| 14 — Health probes | `14-health-probes.md` | same substitution pattern |
| 15 — Node failure | `15-node-failure.md` | `q15-ha` → `mock1-ha`, taint key `q15/dedicated` → `mock1/dedicated` |
| 16 — Guest sysadmin | `16-sysadmin.md` | run inside any mock VM's guest — no manifest changes needed |

## Grading a full mock
```bash
for n in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16; do
  echo "=== $n ==="
  ./scripts/verify-qNN.sh "$n" mock1-<matching-namespace> || true
done
```
(`verify-qNN.sh` checks the automatable parts of each objective's acceptance
criteria — see `scripts/README.md`. It is not a full grader; anything it
can't check mechanically — like "the ping actually succeeded" or "the guest
booted" — still needs your own eyes on the terminal output.)

## Scoring
Give yourself one point per task that fully met its acceptance criteria in
`questions/mock-exam-1.md`. Sixteen tasks, four-hour budget. Anything under
12/16 on your first full mock is normal — that's what `docs/miss-log.md` and
a second pass through `commands/drill-blanks.md` are for before you try
again.
