# Lab 10: Cloning VMs

Objective 10. Namespace: `clone-lab`.

## Tasks
1. Deploy `src-vm`. Inside the guest, write `/home/cloud-user/original` so you can recognise the clone.
2. Prepare the guest for cloning: unique machine-id, fresh SSH host keys, cloud-init reset (see commands).
3. Clone the VM in the web console (VM > Actions > Clone).
4. Clone the disk only: create `clone-root` from the PVC of `src-vm`, then boot a new VM from it.
5. Clone the whole VM with a `VirtualMachineClone` object.
6. Confirm the clones have different MAC addresses, hostnames and IPs. Fix any duplicates.
7. Explain smart clone (CSI snapshot) versus host-assisted clone, and why the source may need to be stopped.

## Gotchas
- A clone inherits `/etc/machine-id`, SSH host keys and the hostname. Duplicate machine-ids break DHCP leases and logging.
- Host-assisted clone needs the source PVC not mounted read-write by a running VM (RWO). Stop it first.
- The clone target size must be at least the source size.
- Cross-namespace clones need permission to use the source PVC (`datavolumes/source`).
- Check the served clone API version with `oc api-resources` before writing the CR.

## Must-know commands
```bash
# prepare the guest (run inside the VM, then shut it down before cloning)
sudo truncate -s 0 /etc/machine-id
sudo rm -f /etc/ssh/ssh_host_*
sudo cloud-init clean --logs
sudo hostnamectl set-hostname localhost

virtctl stop src-vm -n clone-lab
oc apply -f labs/10-cloning/02-dv-clone-pvc.yaml
oc get dv,pvc -n clone-lab
oc describe dv clone-root -n clone-lab
oc get pods -n clone-lab                          # clone-source / clone-target pods

oc apply -f labs/10-cloning/03-vm-from-cloned-dv.yaml
oc api-resources | grep clone.kubevirt.io
oc apply -f labs/10-cloning/04-vmclone.yaml
oc get vmclone -n clone-lab
oc get vmclone clone-1 -n clone-lab -o jsonpath='{.status.phase}{"\n"}'

oc get vmi -n clone-lab -o custom-columns=NAME:.metadata.name,IP:.status.interfaces[0].ipAddress,MAC:.status.interfaces[0].mac
oc get vm cloned-by-crd -n clone-lab -o yaml | grep -i macAddress
oc get sc,volumesnapshotclass
```
