# Questions: Migrate from other hypervisors (Objective 9)

**Time budget: 20 minutes**

## Scenario
You have been handed a single-disk OVA export of a small legacy Linux VM
(`legacy-app.ova`, containing one `.ovf` descriptor and one `.vmdk` disk).
It must end up running as a KubeVirt VM in namespace `q9-import`, reachable
by SSH and HTTP from outside the cluster.

## Tasks
1. (1 min) Create namespace `q9-import`.
2. (4 min) Extract the OVA and inspect the disk image: report its format and
   virtual size.
3. (3 min) Convert the disk to qcow2 and upload it into a new DataVolume
   sized appropriately for the source disk.
4. (5 min) Create a VM `q9-legacy` that boots from the imported disk. Assume
   the source used a SATA-attached disk and an e1000e-family NIC; configure
   the VM's devices to match so it can boot without modification.
5. (3 min) Confirm the VM boots and you can reach a login prompt via the
   serial console.
6. (4 min) Expose the VM: SSH externally via a NodePort Service, and HTTP
   (assume a service already runs on guest port 80) via a ClusterIP Service
   plus a Route.

## Acceptance criteria
- The DataVolume's requested size is not smaller than the source disk's
  virtual size.
- The VM's disk bus and NIC model match what a non-virtio-aware legacy guest
  needs to boot on first try.
- Both the NodePort SSH path and the Route HTTP path are reachable from
  outside the cluster network.
