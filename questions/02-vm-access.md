# Questions: Run and access VMs, per-user access (Objective 2)

**Time budget: 15 minutes**

## Scenario
Namespace `q2-vmops` will host a small fleet of VMs for the operations team.
Two users exist in the cluster's identity provider: `q2-dev` and `q2-viewer`.

## Tasks
1. (1 min) Create namespace `q2-vmops`.
2. (4 min) Create a VM named `app01` with 2 vCPU and 4Gi memory, booting the
   Fedora container disk `quay.io/containerdisks/fedora:latest`, with a
   cloud-init user `cloud-user` and password `Rexam-Pass1`.
3. (2 min) Start `app01`, wait until it is `Running`, then open its serial
   console just long enough to confirm a login prompt appears, and exit.
4. (2 min) Grant `q2-dev` the ability to create, edit and delete VMs in
   `q2-vmops` only. Grant `q2-viewer` read-only access to VMs in the same
   namespace only. Use built-in roles; do not write custom RBAC for this task.
5. (3 min) Write a custom Role named `vm-operator` that allows: viewing VMs,
   and starting/stopping/restarting them, but NOT creating, editing or
   deleting them, and NOT opening the console. Bind it to a third user,
   `q2-ops`.
6. (3 min) Prove your RBAC is correct using `oc auth can-i --as=<user>` for at
   least four different permission checks across the three users.

## Acceptance criteria
- `app01` exists with the specified CPU/memory and is `Running`.
- `oc auth can-i create virtualmachines.kubevirt.io -n q2-vmops --as=q2-dev` → yes.
- `oc auth can-i delete virtualmachines.kubevirt.io -n q2-vmops --as=q2-viewer` → no.
- `oc auth can-i update virtualmachines.subresources.kubevirt.io --subresource=start -n q2-vmops --as=q2-ops` → yes.
- `oc auth can-i get virtualmachineinstances.subresources.kubevirt.io --subresource=console -n q2-vmops --as=q2-ops` → no.
