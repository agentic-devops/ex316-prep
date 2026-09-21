# Lab 02: Run and access VMs, per-user access

Objective 2. Namespace: `vm-lab`. Target: every task under 3 minutes.

## Tasks
1. Create namespace `vm-lab`, then create a VM `fedora-lab` (2Gi RAM, 1 vCPU) from the CLI without copying `01-vm-fedora.yaml`. Use `virtctl create vm` or write the YAML by hand.
2. Start, stop, restart and pause/unpause the VM with `virtctl`. Explain the difference between `runStrategy` values.
3. Open the serial console and log in as `cloud-user`. Exit the console.
4. SSH into the VM with `virtctl ssh`.
5. Grant `dev1` permission to create and edit VMs in `vm-lab`, and `viewer1` read-only access. Prove it with `oc auth can-i`.
6. Create a custom Role that lets `ops1` start, stop and restart VMs and open the console, but not edit or delete them.
7. In the web console, create a VM from a template, then find its console, metrics and events tabs.

## Must-know commands
```bash
# create
virtctl create vm --help
virtctl create vm --name fedora-lab --instancetype u1.medium --preference fedora \
  --volume-containerdisk src:quay.io/containerdisks/fedora:latest | oc apply -n vm-lab -f -
oc explain vm.spec.template.spec.domain.devices
oc get vm,vmi -n vm-lab
oc get vmi fedora-lab -n vm-lab -o wide

# lifecycle
virtctl start fedora-lab -n vm-lab
virtctl stop fedora-lab -n vm-lab
virtctl restart fedora-lab -n vm-lab
virtctl pause vm fedora-lab -n vm-lab
virtctl unpause vm fedora-lab -n vm-lab
oc patch vm fedora-lab -n vm-lab --type merge -p '{"spec":{"runStrategy":"Halted"}}'

# access
virtctl console fedora-lab -n vm-lab            # exit with Ctrl+]
virtctl vnc fedora-lab -n vm-lab
virtctl ssh cloud-user@vmi/fedora-lab -n vm-lab
virtctl port-forward vmi/fedora-lab 2222:22 -n vm-lab

# RBAC
oc adm policy add-role-to-user kubevirt.io:edit dev1 -n vm-lab
oc adm policy add-role-to-user kubevirt.io:view viewer1 -n vm-lab
oc get clusterrole | grep kubevirt.io
oc describe clusterrole kubevirt.io:edit
oc auth can-i create virtualmachines.kubevirt.io -n vm-lab --as=dev1
oc auth can-i delete virtualmachines.kubevirt.io -n vm-lab --as=viewer1
oc auth can-i update virtualmachines.subresources.kubevirt.io --subresource=start \
  -n vm-lab --as=ops1
```
Verify the flags of `virtctl create vm` with `--help` on your version; they change between releases.

## runStrategy values to know
`Always`, `RerunOnFailure`, `Manual`, `Halted`, `Once`. Changing `spec.running` is the older field; prefer `runStrategy`.
