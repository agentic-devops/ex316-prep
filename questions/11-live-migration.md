# Questions: Live migration (Objective 11)

**Time budget: 20 minutes**

## Scenario
Namespace `q11-migr` needs a highly-available VM that can be moved between
nodes without downtime, plus a demonstration that migration policies and
node placement work as expected.

## Tasks
1. (4 min) Create namespace `q11-migr` and VM `q11-vm` with a DataVolume
   root disk using an access mode and volume mode that support live
   migration. Set its eviction strategy so it migrates rather than restarts
   when its node is drained.
2. (2 min) Confirm the VMI reports `LiveMigratable: True` before continuing.
3. (3 min) Trigger a live migration and confirm, while it runs, that the VM
   remains reachable (for example, a continuous ping from another pod does
   not drop packets for more than a couple of seconds).
4. (2 min) Confirm the VM landed on a different node than it started on.
5. (3 min) Start a second migration and cancel it before completion. Confirm
   the VM stayed on its original node afterward.
6. (3 min) Create a `MigrationPolicy` scoped to namespaces labelled
   `migration-policy: q11`, capping migration bandwidth to 32Mi and
   disabling post-copy.
7. (3 min) Adjust the cluster-wide HyperConverged setting so up to 8
   migrations can run in parallel across the cluster.

## Acceptance criteria
- The VMI's `LiveMigratable` condition is `True` prior to migrating.
- The completed migration shows a different `status.nodeName` afterward.
- The cancelled migration leaves the VM on its original node, still running.
- The MigrationPolicy's selector matches only namespaces with the specified
  label.
