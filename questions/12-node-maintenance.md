# Questions: Node maintenance and updates (Objective 12)

**Time budget: 15 minutes**

## Scenario
A worker node needs firmware maintenance. It currently runs at least one
live-migratable VM. The cluster has at least two schedulable workers.

## Tasks
1. (3 min) Identify a worker node running a VM from a namespace of your
   choice (reuse a VM from an earlier task, or create one quickly with
   `evictionStrategy: LiveMigrate`).
2. (5 min) Using a `NodeMaintenance` object (not manual cordon/drain), put
   that node into maintenance. Confirm the VM live-migrates off it and the
   node becomes unschedulable.
3. (3 min) Remove the `NodeMaintenance` object and confirm the node becomes
   schedulable again.
4. (4 min) Repeat the same outcome using only `oc adm` commands (cordon,
   drain with the correct flags for a node running VMs, then uncordon).

## Acceptance criteria
- The VM ends up running (not restarted) on a different node after the
  `NodeMaintenance` object is created.
- The node shows `SchedulingDisabled` while in maintenance and clears once
  maintenance ends.
- The manual `oc adm drain` uses flags that succeed against DaemonSet pods
  and any local/ephemeral storage.
