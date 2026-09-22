# Questions: Basic system administration inside the guest (Objective 16)

**Time budget: 15 minutes**

## Scenario
VM `q16-vm` (namespace `q16-sysadmin`) has two systemd units already
installed: `labweb.service` (correct, but not started or enabled) and
`labapp.service` (installed, but fails to start due to a typo in its
`ExecStart`).

## Tasks
1. (3 min) Start and enable `labweb.service`. Confirm it survives a VM
   restart (still active after `virtctl restart`).
2. (5 min) Diagnose why `labapp.service` fails using `systemctl status` and
   `journalctl`. Fix the unit file, reload systemd, then start and enable it.
3. (2 min) Install one additional package of your choice inside the guest,
   confirm it registered correctly, then remove it again and confirm it is
   gone.
4. (2 min) Create a systemd drop-in override for `labweb.service` that sets
   `Restart=always`, without editing the original unit file directly.
5. (3 min) Report the guest's current listening TCP ports, disk usage, and
   any failed units, in that order.

## Acceptance criteria
- Both `labweb.service` and `labapp.service` are `active` and `enabled`
  after the task, and both survive a VM restart.
- The drop-in override lives under a `.d` directory, not inside the
  original unit file.
- `systemctl list-units --failed` shows no failed units at the end.
