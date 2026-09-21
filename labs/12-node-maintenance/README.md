# Lab 12: Node maintenance and updates

Objective 12. No namespace of its own: reuses the migratable VMs from lab 11 (`migr-lab`).
Never do this on a single-worker or single-node cluster. Keep at least two workers schedulable.

## Tasks
1. Start `mig-vm` (lab 11) and note its node.
2. Put that node into maintenance with a `NodeMaintenance` object. Watch the VM live-migrate away and the node become `SchedulingDisabled`.
3. Remove the `NodeMaintenance` object and confirm the node is schedulable again.
4. Repeat with the CLI only: `oc adm cordon`, `oc adm drain`, then `oc adm uncordon`.
5. Explain what happens to a VM with `evictionStrategy: None` when its node is drained.
6. List which nodes still allow VM scheduling and which VMs would block a drain.
7. Bonus: describe how OpenShift updates (MachineConfig rollouts) trigger drains and live migrations of VMs.

## Gotchas
- A drain needs `--ignore-daemonsets` (virt-handler and other DaemonSet pods) and usually `--delete-emptydir-data`.
- VMs with `evictionStrategy: LiveMigrate` migrate; VMs with RWO disks or `None` block the drain or get shut down.
- `NodeMaintenance` is cluster-scoped. The API group depends on the operator version: check `oc get crd | grep nodemaintenance`.
- Uncordon is not automatic after a manual `drain`.
- Parallel migration limits in the HyperConverged CR throttle how fast a drain completes.

## Must-know commands
```bash
oc get nodes
oc get crd | grep nodemaintenance
oc apply -f labs/12-node-maintenance/02-node-maintenance.yaml
oc get nodemaintenance
oc describe nodemaintenance nm-lab
oc get vmi -A -o wide
oc get vmim -A
oc delete nodemaintenance nm-lab

oc adm cordon worker-0
oc adm drain worker-0 --ignore-daemonsets --delete-emptydir-data --force --timeout=10m
oc get nodes worker-0
oc adm uncordon worker-0

oc get node worker-0 -o jsonpath='{.spec.unschedulable}{"\n"}'
oc get pods -A -o wide --field-selector spec.nodeName=worker-0
oc get vmi -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{" "}{.status.nodeName}{"\n"}{end}'
```
