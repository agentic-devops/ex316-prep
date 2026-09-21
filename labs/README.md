# labs/

One folder per exam objective area (see `docs/objectives-map.md`).

Each lab folder contains:
- `README.md`: exam-style tasks, must-know commands, and time targets
- numbered `NN-*.yaml` starter manifests (apply in order)
- `NAMESPACES`: namespaces created by the lab (used by `scripts/reset-lab.sh`)
- `RESET_OBJECTS`: other objects to delete on reset (one `oc delete` argument list per line)

| Lab | Topic |
|-----|-------|
| 01-operator | Component map, CLI install drill |
| 02-vm-access | Create/manage VMs, RBAC for VM access |
| 03-networking | Pod network, NetworkPolicy, ClusterIP, UDN |
| 04-external-networks | NMState, Linux bridge, Multus NAD, multihomed VMs |
| 05-storage | DataVolumes, hot-plug, expansion, external storage over Multus |
| 06-oadp | Backup, restore, schedules with OADP |
| 07-templates | Templates, instance types, cloud-init |
| 08-snapshots | VM snapshots and restores |
| 09-migration-import | OVA import (manual and MTV), external access |
| 10-cloning | DataVolume clones, VirtualMachineClone, guest preparation |
| 11-live-migration | Migrate, cancel, affinity, MigrationPolicy, HCO limits |
| 12-node-maintenance | NodeMaintenance, cordon and drain |
| 13-load-balancing | NodePort, Routes |
| 14-health-probes | Readiness/liveness probes, runStrategy, watchdog |
| 15-node-failure | Eviction strategy, affinity, taints, health checks, remediation |
| 16-sysadmin | Services and packages inside the guest |

## Ground rules
- Test images default to `quay.io/containerdisks/fedora:latest`. On a disconnected cluster, mirror it or swap in a local image or DataSource.
- Guest login used by all labs: `cloud-user` / `lab-pass-123`
- Type every command. Copy/paste only from `oc explain`, `--help`, and docs.
- Labs 11, 12 and 15 need at least two schedulable workers. Lab 11 needs RWX storage.
