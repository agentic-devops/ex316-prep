# Solution: Objective 5 (matches questions/05-storage.md)

## Task 1-2: namespace, VM with root + data DataVolumes
```bash
oc create namespace q5-store
```
Use two `dataVolumeTemplates` entries on the VM: `q5-vm-root` (10Gi,
registry source) and `q5-vm-data` (4Gi, blank source) — see
`labs/05-storage/03-vm-with-disks.yaml` for the full shape. Give the data
disk a `serial:` so it's identifiable in the guest.

## Task 3: format, mount, persist
```bash
virtctl ssh cloud-user@vmi/q5-vm -n q5-store
lsblk -o NAME,SIZE,SERIAL
sudo mkfs.xfs /dev/vdb
sudo mkdir -p /data
sudo mount /dev/vdb /data
sudo blkid /dev/vdb   # copy the UUID
echo 'UUID=<uuid> /data xfs defaults 0 0' | sudo tee -a /etc/fstab
sudo mount -a
```
Confirm survival: `virtctl restart q5-vm -n q5-store`, log back in, `df -h`.

## Task 4: expand PVC and guest filesystem
```bash
oc patch pvc q5-vm-data -n q5-store --type merge \
  -p '{"spec":{"resources":{"requests":{"storage":"6Gi"}}}}'
oc get pvc q5-vm-data -n q5-store
# inside guest:
sudo xfs_growfs /data
df -h /data
```

## Task 5: hot-plug and remove
```bash
cat <<EOF2 | oc apply -f -
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: q5-hotplug
  namespace: q5-store
spec:
  source: {blank: {}}
  storage:
    resources: {requests: {storage: 2Gi}}
EOF2
virtctl addvolume q5-vm --volume-name=q5-hotplug --serial=hp01 --persist -n q5-store
# in guest: lsblk -o NAME,SERIAL   -> confirm it shows up
virtctl removevolume q5-vm --volume-name=q5-hotplug --persist -n q5-store
```

## Task 6: default virt StorageClass
```bash
oc annotate sc <name> storageclass.kubevirt.io/is-default-virt-class=true --overwrite
oc get sc -o custom-columns=NAME:.metadata.name,ANNOT:'.metadata.annotations.storageclass\.kubevirt\.io/is-default-virt-class'
```
