# Questions: OADP backup and restore of VMs (Objective 6)

**Time budget: 20 minutes**

## Scenario
The OADP operator and a working `DataProtectionApplication` already exist,
with a `BackupStorageLocation` in phase `Available`. Namespace `q6-oadp`
needs to be protected.

## Tasks
1. (3 min) Create namespace `q6-oadp` and a VM `q6-vm` (any boot source is
   fine). Once running, write a marker file at
   `/home/cloud-user/before-backup.txt` inside the guest.
2. (4 min) Create a `Backup` of namespace `q6-oadp` that uses CSI snapshot
   data movement. Wait for it to reach `Completed`.
3. (3 min) Delete the VM `q6-vm` and its underlying disk entirely.
4. (4 min) Restore namespace `q6-oadp` from the backup. Confirm `q6-vm`
   comes back and `/home/cloud-user/before-backup.txt` is present with its
   original content.
5. (3 min) Create a `Schedule` that backs up namespace `q6-oadp` every day at
   03:00, retaining each backup for 7 days.
6. (3 min) One of your backups shows phase `PartiallyFailed`. Describe the
   two commands you would run to find out why, and what you would check.

## Acceptance criteria
- The Backup reaches `Completed`, not `PartiallyFailed` or `Failed`.
- The Restore reaches `Completed`, the VM exists again, and the marker file's
  content matches exactly.
- The Schedule's cron expression and TTL are both correct.
