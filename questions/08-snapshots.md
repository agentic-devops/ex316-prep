# Questions: VM snapshots (Objective 8)

**Time budget: 15 minutes**

## Scenario
Namespace `q8-snap` hosts a VM whose disk is backed by a DataVolume on a
CSI storage class with snapshot support.

## Tasks
1. (3 min) Create namespace `q8-snap` and VM `q8-vm` with a 10Gi DataVolume
   root disk. Once running, create `/home/cloud-user/checkpoint-a.txt`
   inside the guest.
2. (3 min) Take an online snapshot named `q8-snap-a`. Wait until it reports
   ready to use.
3. (2 min) Delete `checkpoint-a.txt`, then create
   `/home/cloud-user/checkpoint-b.txt` instead.
4. (2 min) Take a second snapshot, `q8-snap-b`.
5. (3 min) Restore the VM to the state captured in `q8-snap-a`. Confirm
   `checkpoint-a.txt` is back and `checkpoint-b.txt` is gone.
6. (2 min) Delete snapshot `q8-snap-b` and confirm its associated
   VolumeSnapshot objects are cleaned up.

## Acceptance criteria
- Both snapshots report `readyToUse: true` before you rely on them.
- The VM was stopped before the restore, per the platform's requirement.
- After restoring `q8-snap-a`, the guest's file contents exactly match that
  point in time, not `q8-snap-b`'s.
