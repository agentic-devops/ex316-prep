# Lab 15: Preparing for node failure

Objective 15. Namespace: `fail-lab`. Cluster-scoped: node labels and taints, NodeHealthCheck.

## Tasks
1. Deploy `ha-live` and `ha-none`. Drain their node and compare the outcome (migrated vs shut down).
2. Deploy `spread-1` and `spread-2` with pod anti-affinity. Prove they land on different nodes and explain what happens with only one schedulable node.
3. Label a node `lab/dedicated=vm`, taint it `lab/dedicated=vm:NoSchedule`, and deploy `dedicated-vm` with the selector and toleration. Prove a VM without the toleration cannot land there.
4. Remove the taint and label to restore the node.
5. Use `nodeSelector` on a VM to pin it, and explain nodeSelector vs node affinity vs taints and tolerations.
6. Configure a NodeHealthCheck with Self Node Remediation (or describe Fence Agents Remediation) and explain what each component does after a node goes `NotReady`.
7. Add a watchdog device and readiness/liveness probes to a VM (lab 14) as part of a high-availability design.

## Gotchas
- Taint effects: `NoSchedule` (new pods only), `PreferNoSchedule`, `NoExecute` (also evicts running pods).
- `nodeSelector` and required node affinity are hard constraints; the VM stays Pending if nothing matches.
- Anti-affinity `topologyKey: kubernetes.io/hostname` means one per node.
- Without health checks and remediation, a dead node leaves its VMs stuck. Remediation fences the node and lets the VMs restart elsewhere (needs `runStrategy` Always or RerunOnFailure).
- Live migration cannot rescue a node that is already down. Migration is for planned events.
- `minHealthy` in a NodeHealthCheck stops remediation storms.

## Must-know commands
```bash
oc get nodes -L lab/dedicated
oc label node <node> lab/dedicated=vm
oc adm taint node <node> lab/dedicated=vm:NoSchedule
oc adm taint node <node> lab/dedicated=vm:NoSchedule-      # remove
oc label node <node> lab/dedicated-                       # remove
oc describe node <node> | grep -A3 Taints

oc get vmi -n fail-lab -o wide
oc get pods -n fail-lab -o wide
oc describe pod <virt-launcher-pod> -n fail-lab | grep -A5 -i events
oc explain vm.spec.template.spec.affinity.podAntiAffinity
oc explain vm.spec.template.spec.tolerations
oc explain vm.spec.template.spec.evictionStrategy

oc get nodehealthcheck
oc get selfnoderemediationtemplate -A
oc get csv -n openshift-workload-availability
```
