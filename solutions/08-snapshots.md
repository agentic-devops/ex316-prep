# Solution: Objective 8 (matches questions/08-snapshots.md)

## Task 1: namespace, VM, checkpoint A
```bash
oc create namespace q8-snap
# VM q8-vm with a DataVolume root disk (see labs/08-snapshots/01-vm.yaml)
virtctl ssh cloud-user@vmi/q8-vm -n q8-snap \
  -c 'echo a > /home/cloud-user/checkpoint-a.txt'
```

## Task 2: snapshot A
```bash
cat <<EOF2 | oc apply -f -
apiVersion: snapshot.kubevirt.io/v1beta1
kind: VirtualMachineSnapshot
metadata:
  name: q8-snap-a
  namespace: q8-snap
spec:
  source: {apiGroup: kubevirt.io, kind: VirtualMachine, name: q8-vm}
EOF2
oc get vmsnapshot q8-snap-a -n q8-snap -o jsonpath='{.status.readyToUse}{"\n"}'
```

## Task 3-4: change guest, snapshot B
```bash
virtctl ssh cloud-user@vmi/q8-vm -n q8-snap -c \
  'rm /home/cloud-user/checkpoint-a.txt; echo b > /home/cloud-user/checkpoint-b.txt'
cat <<EOF2 | oc apply -f -
apiVersion: snapshot.kubevirt.io/v1beta1
kind: VirtualMachineSnapshot
metadata:
  name: q8-snap-b
  namespace: q8-snap
spec:
  source: {apiGroup: kubevirt.io, kind: VirtualMachine, name: q8-vm}
EOF2
```

## Task 5: restore to snapshot A
```bash
virtctl stop q8-vm -n q8-snap
cat <<EOF2 | oc apply -f -
apiVersion: snapshot.kubevirt.io/v1beta1
kind: VirtualMachineRestore
metadata:
  name: q8-restore-a
  namespace: q8-snap
spec:
  target: {apiGroup: kubevirt.io, kind: VirtualMachine, name: q8-vm}
  virtualMachineSnapshotName: q8-snap-a
EOF2
oc get vmrestore q8-restore-a -n q8-snap -o jsonpath='{.status.complete}{"\n"}'
virtctl start q8-vm -n q8-snap
virtctl ssh cloud-user@vmi/q8-vm -n q8-snap -c 'ls /home/cloud-user'
# expect: checkpoint-a.txt present, checkpoint-b.txt absent
```

## Task 6: delete snapshot B
```bash
oc delete vmsnapshot q8-snap-b -n q8-snap
oc get volumesnapshot,volumesnapshotcontent -n q8-snap
```
