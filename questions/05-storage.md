# Questions: Kubernetes storage for VMs (Objective 5)

**Time budget: 20 minutes**

## Scenario
Namespace `q5-store` will host a VM that needs a growable secondary data
volume, plus a demonstration of live disk hot-plug.

## Tasks
1. (1 min) Create namespace `q5-store`.
2. (4 min) Create a VM `q5-vm` with a 10Gi DataVolume root disk (imported
   from the Fedora container disk) and a second, blank 4Gi data disk defined
   at creation time.
3. (4 min) Inside the guest, partition or format the second disk as XFS,
   mount it at `/data`, and make the mount persistent across reboots by UUID
   (not by device name).
4. (3 min) Expand the data disk's PVC to 6Gi. Grow the filesystem inside the
   guest to use the new space, without losing existing data.
5. (4 min) Hot-plug a new, separate 2Gi blank disk into the running VM,
   persistently. Confirm it is visible inside the guest, then remove it
   again, persistently.
6. (4 min) Mark one StorageClass in the cluster as the default class used
   specifically for new virtualization disks (distinct from the general
   default StorageClass, if there is one).

## Acceptance criteria
- `/data` survives a `virtctl restart q5-vm` and still shows the correct UUID
  in `/etc/fstab`.
- The expanded filesystem shows the full 6Gi with `df -h`, and the original
  files are intact.
- The hot-plugged disk is gone from `lsblk` after the persistent removal, and
  the VM's spec no longer references it.
