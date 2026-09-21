# Lab 09: Import VMs from other hypervisors (OVA)

Objective 9. Namespace: `migrate-lab`. MTV (Migration Toolkit for Virtualization) is optional; the manual path always works.

## Tasks
1. Manual path: unpack an OVA, convert the VMDK to qcow2, upload it into a DataVolume, boot a VM from it.
2. Adjust the imported VM so it boots: disk bus (`sata` vs `virtio`), NIC model (`e1000e` vs `virtio`), firmware (BIOS vs UEFI).
3. Give the imported VM external access: SSH through a NodePort Service and HTTP through Service + Route.
4. If MTV is installed: create an OVA provider, network map, storage map and plan, then run the migration from the console.
5. Explain when you need virtio drivers inside the guest and how to add them.

## Gotchas
- An OVA is a tar file: one `.ovf` descriptor plus one or more `.vmdk` disks.
- `virtctl image-upload` needs the CDI upload proxy route to be reachable; `--insecure` skips TLS verification.
- A guest with no virtio drivers will not boot from `virtio` disks. Use `sata`, then install drivers.
- After import, guest network config may key on the old NIC name or MAC. Check inside the console.
- Windows guests: install virtio-win drivers, and keep the same firmware type as the source.

## Must-know commands
```bash
tar -tvf vm.ova
tar -xvf vm.ova
qemu-img info disk1.vmdk
qemu-img convert -f vmdk -O qcow2 disk1.vmdk disk1.qcow2

virtctl image-upload dv imported-disk --size=20Gi --image-path=disk1.qcow2 \
  --insecure -n migrate-lab
oc get dv,pvc -n migrate-lab
oc apply -f labs/09-migration-import/01-vm-from-uploaded-dv.yaml
virtctl console imported-vm -n migrate-lab
oc apply -f labs/09-migration-import/02-svc-expose-imported.yaml

# MTV
oc get pods -n openshift-mtv
oc get provider,plan,migration,networkmap,storagemap -n openshift-mtv
oc describe plan ova-plan -n openshift-mtv

# make a practice OVA from any qcow2
./labs/09-migration-import/make-dummy-ova.sh ./fedora.qcow2 practice-vm
```
