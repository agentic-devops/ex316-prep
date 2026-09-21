# Lab 06: Back up and restore VMs with OADP

Objective 6. Namespace: `oadp-lab` (app); backup objects live in `openshift-adp`.
Prereq: `setup/oadp/` applied and `BackupStorageLocation` shows `Available`.

## Tasks
1. Verify the operator, the DataProtectionApplication and the BackupStorageLocation.
2. Deploy `backup-vm`, write a marker file inside it (`echo pre-backup | sudo tee /home/cloud-user/marker`).
3. Create a Backup of namespace `oadp-lab`. Wait until `Completed`.
4. Delete the VM (and its PVC), then restore. Confirm the marker file is back.
5. Delete the whole namespace and restore again.
6. Create a Schedule that runs nightly at 02:00 and keeps backups 7 days.
7. From scratch: write a DataProtectionApplication that uses an S3 bucket, with the `kubevirt` plugin enabled.

## Gotchas
- Backup and Restore CRs go in `openshift-adp`. Nothing happens if you create them in the app namespace.
- CSI-based backups need the VolumeSnapshotClass label `velero.io/csi-volumesnapshot-class=true`.
- Restore skips resources that already exist. Delete the VM first.
- `PartiallyFailed` means read the logs: `velero backup logs <name>`.
- The DPA needs the `kubevirt` default plugin to handle VM objects properly.

## Must-know commands
```bash
oc get dpa,backupstoragelocation -n openshift-adp
oc get pods -n openshift-adp
oc get volumesnapshotclass
oc label volumesnapshotclass <name> velero.io/csi-volumesnapshot-class=true

oc apply -f labs/06-oadp/02-backup-csi-datamover.yaml
oc get backup.velero.io -n openshift-adp
oc get backup.velero.io vm-backup-csi -n openshift-adp -o jsonpath='{.status.phase}{"\n"}'
oc get datauploads -n openshift-adp

oc get restore.velero.io -n openshift-adp
oc get restore.velero.io vm-restore-1 -n openshift-adp -o jsonpath='{.status.phase}{"\n"}'

alias velero='oc -n openshift-adp exec deployment/velero -c velero -it -- ./velero'
velero backup get
velero backup describe vm-backup-csi --details
velero backup logs vm-backup-csi
velero restore describe vm-restore-1
oc explain dpa.spec.configuration.velero.defaultPlugins
```
