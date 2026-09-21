# EX316 Objectives Map (OCP 4.18)

Source: Red Hat EX316 exam page. Red Hat may change objectives; recheck before booking.

| # | Objective area | Key tasks | Lab dir |
|---|----------------|-----------|---------|
| 1 | Deploy the OpenShift Virtualization operator | Know component roles; install via OLM | `labs/01-operator` |
| 2 | Run and access virtual machines | Create/manage VMs (web console and CLI); per-user access to VM resources | `labs/02-vm-access` |
| 3 | Kubernetes networking for VMs | SDN connectivity, network policies, external access, user-defined networks (UDN), ClusterIP services | `labs/03-networking` |
| 4 | External networks | Multus CNI, NMState operator, multihomed nodes and VMs | `labs/04-external-networks` |
| 5 | Kubernetes storage for VMs | Persistent storage, attach/detach disks, external storage via Multus | `labs/05-storage` |
| 6 | OADP backup and restore | Deploy OADP operator; back up and restore VMs | `labs/06-oadp` |
| 7 | VM templates | Use/modify preconfigured templates; custom templates; cloud-init (credentials, repos, commands) | `labs/07-templates` |
| 8 | VM snapshots | Create, manage, restore | `labs/08-snapshots` |
| 9 | Migrate from other hypervisors | Import OVA; configure imported VM for external access | `labs/09-migration-import` |
| 10 | Clone VMs | Prepare for cloning; clone in console; clone disks with DataVolumes | `labs/10-cloning` |
| 11 | Live migration | Limitations; node affinity; start, monitor, cancel migrations | `labs/11-live-migration` |
| 12 | Node maintenance and updates | NodeMaintenance resources; drain via CLI | `labs/12-node-maintenance` |
| 13 | Load balancing with K8s networking | NodePort services; custom Routes | `labs/13-load-balancing` |
| 14 | Health probes | runStrategy; readiness/liveness probes; watchdog device | `labs/14-health-probes` |
| 15 | Prepare for node failure | Eviction strategies; selectors, affinity, anti-affinity, taints, tolerations; watchdog/health checks | `labs/15-node-failure` |
| 16 | Basic system administration (inside the guest) | Start/stop and enable services; install packages | `labs/16-sysadmin` |

## Confidence tracker (update weekly)
| # | Objective | Score 1-5 | Last drilled |
|---|-----------|-----------|--------------|
| 1 | Operator install | | |
| 2 | VM run/access | | |
| 3 | K8s networking | | |
| 4 | Multus/NMState | | |
| 5 | Storage | | |
| 6 | OADP | | |
| 7 | Templates/cloud-init | | |
| 8 | Snapshots | | |
| 9 | OVA import | | |
| 10 | Cloning | | |
| 11 | Live migration | | |
| 12 | Node maintenance | | |
| 13 | Load balancing | | |
| 14 | Health probes | | |
| 15 | Node failure | | |
| 16 | Guest sysadmin | | |
