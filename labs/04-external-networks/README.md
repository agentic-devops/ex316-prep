# Lab 04: External networks (Multus + NMState)

Objective 4. Namespace: `extnet-lab`. Cluster-scoped: NNCPs.
Requires a spare NIC on the workers (or a VLAN on an existing one). Edit `ens224`, `ens256` and `worker-0` first.

## Tasks
1. Confirm the NMState operator and `NMState` CR are ready. Find the NIC names on a worker.
2. Create an NNCP that builds Linux bridge `br-vm` on all workers. Verify it with `oc get nncp` and `oc get nnce`.
3. Create a NAD in `extnet-lab` that uses `br-vm` (optionally tagged with a VLAN).
4. Create two VMs with a second NIC on that NAD and static addresses `192.168.100.11/24` and `.12/24`. Ping between them.
5. Give one worker a static IP on a spare NIC (multihomed node) with a second NNCP.
6. Roll back a bad NNCP (for example, a wrong port name) and read the failure from `nnce` conditions.

## Gotchas
- When you supply `networkData` in cloud-init you must also configure the primary NIC (DHCP), or the pod-network NIC will come up unconfigured. The sample matches by MAC so interface names do not matter.
- The NAD needs the `k8s.v1.cni.cncf.io/resourceName: bridge.network.kubevirt.io/<bridge>` annotation.
- The NAD namespace must match the VM namespace unless you reference `<ns>/<name>` in `networkName`.
- NNCP failures show up on `NodeNetworkConfigurationEnactment` (`nnce`), not on the NNCP itself first.
- A wrong bridge port can cut off a node. Never bridge the NIC that carries the node's default route.

## Must-know commands
```bash
oc get nmstate
oc get nns
oc get nns <node> -o jsonpath='{.status.currentState.interfaces[*].name}{"\n"}'
oc get nncp
oc get nnce
oc describe nnce <node>.<policy>
oc get nncp br-vm-policy -o jsonpath='{.status.conditions[*].type}{"\n"}'

oc get net-attach-def -n extnet-lab
oc describe net-attach-def vm-br -n extnet-lab
oc get vmi -n extnet-lab -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.interfaces[*].ipAddress}{"\n"}{end}'
virtctl ssh cloud-user@vmi/mh-vm1 -n extnet-lab -c 'ip -br a'
virtctl ssh cloud-user@vmi/mh-vm1 -n extnet-lab -c 'ping -c3 192.168.100.12'
oc explain nncp.spec.desiredState
```

## Stretch
OVN-Kubernetes localnet: an NNCP with `ovn.bridge-mappings` plus a NAD of type `ovn-k8s-cni-overlay` with `topology: localnet`. Learn it from the 4.18 docs.
