# Lab 08: VM snapshots

Objective 8. Namespace: `snap-lab`. Needs a CSI StorageClass with a VolumeSnapshotClass.

## Tasks
1. Deploy `snap-vm`, write `/home/cloud-user/state1` in the guest.
2. Take snapshot `snap-1` while the VM runs. Wait until `READYTOUSE` is true.
3. Change the guest (delete `state1`, create `state2`), take snapshot `snap-2`.
4. Stop the VM and restore it from `snap-1`. Confirm `state1` is back and `state2` is gone.
5. Delete a snapshot and explain what happens to its VolumeSnapshots.
6. Take a snapshot from the web console (VM > Snapshots tab) and restore from it.
7. Explain why a VM using only a `containerDisk` cannot be snapshotted meaningfully.

## Gotchas
- Only PVC/DataVolume disks are snapshotted. `containerDisk` and `emptyDisk` are not.
- Online snapshots are crash-consistent unless the guest agent is running, then filesystems are frozen and thawed.
- Restore requires the VM to be stopped.
- Snapshot support depends on the storage provider having a VolumeSnapshotClass.
- Snapshots are not backups. They live in the same storage system as the disk.

## Must-know commands
```bash
oc get volumesnapshotclass
oc apply -f labs/08-snapshots/02-snapshot.yaml
oc get vmsnapshot -n snap-lab
oc get vmsnapshot snap-1 -n snap-lab -o jsonpath='{.status.readyToUse}{"\n"}'
oc describe vmsnapshot snap-1 -n snap-lab
oc get volumesnapshot,volumesnapshotcontent -n snap-lab

virtctl stop snap-vm -n snap-lab
oc apply -f labs/08-snapshots/03-restore.yaml
oc get vmrestore -n snap-lab
oc get vmrestore restore-snap-1 -n snap-lab -o jsonpath='{.status.complete}{"\n"}'
virtctl start snap-vm -n snap-lab
oc delete vmsnapshot snap-1 -n snap-lab
oc api-resources | grep snapshot.kubevirt
```
