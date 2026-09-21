# Lab 11: Live migration

Objective 11. Namespace: `migr-lab`. Needs at least two schedulable workers and RWX storage.

## Tasks
1. Start `mig-vm`. Confirm the `LiveMigratable` condition is `True` and note the current node.
2. Migrate it with `virtctl migrate`, watch the migration and confirm the node changed and the VM stayed up (run `ping` or a counter in the guest).
3. Deploy `mig-rwo-vm`. Show why it cannot live migrate.
4. Start a migration and cancel it before it finishes.
5. Label two nodes `lab/zone=a`, deploy `aff-vm`, migrate it, and prove the destination respects the affinity.
6. Create a `MigrationPolicy` that limits bandwidth for namespace `migr-lab`.
7. Inspect and change the cluster-wide migration settings in the HyperConverged CR.
8. List the limits of live migration (RWO storage, some passthrough devices, node CPU model mismatch, no free target node).

## Gotchas
- `LiveMigratable=False` names the reason: read `.status.conditions`.
- A migration is a `VirtualMachineInstanceMigration` object; `virtctl migrate` just creates one.
- Cancel with `virtctl migrate-cancel <vm>` or by deleting the VMIM.
- Nodes must share the same storage backend and a compatible CPU model.
- Cluster limits (`parallelMigrationsPerCluster`, `parallelOutboundMigrationsPerNode`, `bandwidthPerMigration`, `completionTimeoutPerGiB`, `progressTimeout`) live in `hco.spec.liveMigrationConfig`.
- A dedicated migration network is set with `liveMigrationConfig.network` (a NAD name).

## Must-know commands
```bash
oc get vmi -n migr-lab -o wide
oc get vmi mig-vm -n migr-lab -o jsonpath='{.status.nodeName}{"\n"}'
oc get vmi mig-vm -n migr-lab -o jsonpath='{.status.conditions[?(@.type=="LiveMigratable")].status}{"\n"}'
oc get vmi mig-rwo-vm -n migr-lab -o jsonpath='{.status.conditions[?(@.type=="LiveMigratable")]}{"\n"}'

virtctl migrate mig-vm -n migr-lab
virtctl migrate-cancel mig-vm -n migr-lab
oc get vmim -n migr-lab
oc describe vmim <name> -n migr-lab
oc get vmi mig-vm -n migr-lab -o jsonpath='{.status.migrationState}{"\n"}'
oc get pods -n migr-lab -o wide -l kubevirt.io=virt-launcher

oc label node <node1> <node2> lab/zone=a
oc get nodes -L lab/zone
oc apply -f labs/11-live-migration/05-migration-policy.yaml
oc get migrationpolicy

oc get hco kubevirt-hyperconverged -n openshift-cnv -o jsonpath='{.spec.liveMigrationConfig}{"\n"}'
oc patch hco kubevirt-hyperconverged -n openshift-cnv --type merge \
  -p '{"spec":{"liveMigrationConfig":{"parallelMigrationsPerCluster":10,"bandwidthPerMigration":"128Mi"}}}'
```
