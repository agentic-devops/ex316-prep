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
| 05-storage | (section 4) |
| 06-oadp | (section 4) |
| 07-templates | (section 4) |
| 08-snapshots | (section 4) |
| 09-migration-import | (section 4) |
| 10-cloning | (section 4) |
| 11-live-migration | (section 4) |
| 12-node-maintenance | (section 4) |
| 13-load-balancing | NodePort, Routes |
| 14-health-probes | (section 4) |
| 15-node-failure | (section 4) |
| 16-sysadmin | (section 4) |

## Ground rules
- Test images default to `quay.io/containerdisks/fedora:latest`. On a disconnected cluster, mirror it or swap in a local image or DataSource.
- Guest login used by all labs: `cloud-user` / `lab-pass-123`
- Type every command. Copy/paste only from `oc explain`, `--help`, and docs.
