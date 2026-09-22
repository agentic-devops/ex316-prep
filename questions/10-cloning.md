# Questions: Clone VMs (Objective 10)

**Time budget: 15 minutes**

## Scenario
Namespace `q10-clone` has a working "golden" VM, `q10-src`, that should be
cloned twice to produce two independent, differently-identified copies.

## Tasks
1. (2 min) Create namespace `q10-clone` and VM `q10-src` with a 10Gi
   DataVolume root disk. Start it and confirm it boots.
2. (3 min) Prepare the guest so a clone will not collide with the source:
   reset the machine-id, remove SSH host keys, and clean cloud-init state.
   Then stop the VM.
3. (5 min) Clone the disk only: create a new DataVolume `q10-clone-a` sourced
   from `q10-src`'s PVC, and a new VM `q10-vm-a` that boots from it.
4. (3 min) Separately, create a whole-VM clone named `q10-vm-b` using a
   `VirtualMachineClone` object (check which API version is actually served
   on this cluster before writing the manifest).
5. (2 min) Start all three VMs and confirm each has a distinct MAC address
   and a distinct IP address; none should collide.

## Acceptance criteria
- `q10-vm-a` and `q10-vm-b` boot independently of `q10-src` continuing to
  exist or run.
- No two of the three VMs share a MAC address.
- The DataVolume-based clone (`q10-vm-a`) is at least as large as the
  source PVC.
