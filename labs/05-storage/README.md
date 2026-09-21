# Lab 05: Storage for VMs

Objective 5. Namespace: `storage-lab`. Cluster tools: StorageClass, StorageProfile, CDI.

## Tasks
1. List StorageClasses, find the default, and mark one as the default *virtualization* class.
2. Create a blank DataVolume (2Gi), then import a disk from a registry into a 10Gi DataVolume.
3. Create a VM with a DataVolume root disk plus a second 5Gi data disk. Inside the guest: partition or format the disk, mount it at `/data`, and persist it in `/etc/fstab` by UUID.
4. Hot-plug `hotplug-disk` into a running VM and make it persistent. Find it in the guest, then detach it.
5. Expand a VM disk's PVC from 5Gi to 8Gi and confirm the guest sees the new size.
6. Upload a local qcow2/ISO with `virtctl image-upload`.
7. Connect a VM to an external storage server over a second (Multus) network and mount the export inside the guest.

## Gotchas
- `spec.storage` (storage API) fills accessModes and volumeMode from the StorageProfile; `spec.pvc` does not.
- Live migration needs RWX. Block-mode RBD is the usual choice.
- Hot-plugged disks attach on the SCSI bus and show up as `/dev/sdX`; identify them by serial: `lsblk -o NAME,SIZE,SERIAL`.
- `addvolume` without `--persist` is lost at restart.
- PVC expansion needs `allowVolumeExpansion: true` on the StorageClass and, for filesystem mode, the guest must grow its filesystem.
- A DataVolume pending on `WaitForFirstConsumer` is normal until a VM uses it.

## Must-know commands
```bash
oc get sc
oc get sc -o custom-columns=NAME:.metadata.name,PROV:.provisioner,EXPAND:.allowVolumeExpansion
oc annotate sc <name> storageclass.kubevirt.io/is-default-virt-class=true --overwrite
oc get storageprofile
oc get storageprofile <sc> -o yaml

oc get dv,pvc -n storage-lab
oc describe dv fedora-golden -n storage-lab
oc get pods -n storage-lab                     # importer pods
oc explain datavolume.spec.storage
oc explain datavolume.spec.source

virtctl addvolume storage-vm --volume-name=hotplug-disk --serial=hp01 --persist -n storage-lab
virtctl removevolume storage-vm --volume-name=hotplug-disk --persist -n storage-lab
virtctl image-upload dv up-disk --size=2Gi --image-path=./disk.qcow2 --insecure -n storage-lab

oc patch pvc storage-vm-data -n storage-lab --type merge \
  -p '{"spec":{"resources":{"requests":{"storage":"8Gi"}}}}'

# inside the guest
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,SERIAL
sudo mkfs.xfs /dev/vdb && sudo mkdir /data && sudo mount /dev/vdb /data
sudo blkid /dev/vdb
echo 'UUID=<uuid> /data xfs defaults 0 0' | sudo tee -a /etc/fstab && sudo mount -a
sudo xfs_growfs /data
```
