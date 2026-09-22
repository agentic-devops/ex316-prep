# Solution: Objective 10 (matches questions/10-cloning.md)

## Task 1: namespace, source VM
```bash
oc create namespace q10-clone
# q10-src: DataVolumeTemplate q10-src-root, 10Gi, registry source (see labs/10-cloning/01-vm-source.yaml)
virtctl start q10-src -n q10-clone
```

## Task 2: prepare the guest, then stop
```bash
virtctl ssh cloud-user@vmi/q10-src -n q10-clone <<'EOF2'
sudo truncate -s 0 /etc/machine-id
sudo rm -f /etc/ssh/ssh_host_*
sudo cloud-init clean --logs
EOF2
virtctl stop q10-src -n q10-clone
```

## Task 3: DataVolume clone + VM
```bash
cat <<EOF2 | oc apply -f -
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata: {name: q10-clone-a, namespace: q10-clone}
spec:
  source:
    pvc: {namespace: q10-clone, name: q10-src-root}
  storage:
    resources: {requests: {storage: 10Gi}}
EOF2
# then a VM q10-vm-a whose rootdisk volume is:
#   dataVolume: {name: q10-clone-a}
```

## Task 4: whole-VM clone
```bash
oc api-resources | grep clone.kubevirt.io   # confirm served version, e.g. v1alpha1
cat <<EOF2 | oc apply -f -
apiVersion: clone.kubevirt.io/v1alpha1
kind: VirtualMachineClone
metadata: {name: q10-clone-vm, namespace: q10-clone}
spec:
  source: {apiGroup: kubevirt.io, kind: VirtualMachine, name: q10-src}
  target: {apiGroup: kubevirt.io, kind: VirtualMachine, name: q10-vm-b}
EOF2
oc get vmclone q10-clone-vm -n q10-clone -o jsonpath='{.status.phase}{"\n"}'
```

## Task 5: start all three, confirm no collisions
```bash
virtctl start q10-src -n q10-clone
virtctl start q10-vm-a -n q10-clone
virtctl start q10-vm-b -n q10-clone
oc get vmi -n q10-clone -o custom-columns=\
NAME:.metadata.name,IP:.status.interfaces[0].ipAddress,MAC:.status.interfaces[0].mac
```
Every MAC and IP in the output should be unique across the three rows.
