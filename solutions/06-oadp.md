# Solution: Objective 6 (matches questions/06-oadp.md)

## Task 1: namespace, VM, marker file
```bash
oc create namespace q6-oadp
# create q6-vm (any boot source), start it, then:
virtctl ssh cloud-user@vmi/q6-vm -n q6-oadp \
  -c 'echo hello > /home/cloud-user/before-backup.txt'
```

## Task 2: CSI data-mover backup
```bash
cat <<EOF2 | oc apply -f -
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: q6-backup
  namespace: openshift-adp
spec:
  includedNamespaces: ["q6-oadp"]
  snapshotMoveData: true
  ttl: 72h0m0s
EOF2
oc get backup.velero.io q6-backup -n openshift-adp -w   # until Completed
```

## Task 3-4: delete and restore
```bash
oc delete vm q6-vm -n q6-oadp
oc delete pvc --all -n q6-oadp

cat <<EOF2 | oc apply -f -
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: q6-restore
  namespace: openshift-adp
spec:
  backupName: q6-backup
  includedNamespaces: ["q6-oadp"]
EOF2
oc get restore.velero.io q6-restore -n openshift-adp -w   # until Completed
virtctl ssh cloud-user@vmi/q6-vm -n q6-oadp -c 'cat /home/cloud-user/before-backup.txt'
```

## Task 5: Schedule
```bash
cat <<EOF2 | oc apply -f -
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: q6-daily
  namespace: openshift-adp
spec:
  schedule: "0 3 * * *"
  template:
    includedNamespaces: ["q6-oadp"]
    snapshotMoveData: true
    ttl: 168h0m0s
EOF2
```

## Task 6: troubleshoot PartiallyFailed
```bash
alias velero='oc -n openshift-adp exec deployment/velero -c velero -it -- ./velero'
velero backup describe <name> --details
velero backup logs <name>
```
Check for: missing VolumeSnapshotClass label, BackupStorageLocation not
`Available`, or a DataUpload stuck/failed (`oc get datauploads -n openshift-adp`).
