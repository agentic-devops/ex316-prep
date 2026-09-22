# Solution: Objective 15 (matches questions/15-node-failure.md)

## Task 1: two VMs, required anti-affinity
```bash
oc create namespace q15-ha
```
Both `q15-a` and `q15-b` need, under `spec.template`:
```yaml
metadata:
  labels: {group: q15-pair}
spec:
  evictionStrategy: LiveMigrate
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector: {matchLabels: {group: q15-pair}}
          topologyKey: kubernetes.io/hostname
```

## Task 2: confirm different nodes
```bash
oc get vmi q15-a q15-b -n q15-ha -o jsonpath='{.items[*].status.nodeName}{"\n"}'
```

## Task 3: dedicated node
```bash
oc label node <node> q15/dedicated=vm
oc adm taint node <node> q15/dedicated=vm:NoSchedule
```
`q15-dedicated`'s spec:
```yaml
nodeSelector: {q15/dedicated: vm}
tolerations:
  - {key: q15/dedicated, operator: Equal, value: vm, effect: NoSchedule}
```

## Task 4: confirm exclusivity
```bash
# a VM WITHOUT the toleration and WITHOUT the nodeSelector stays Pending
# if the only free capacity is the tainted node; or schedule elsewhere and
# confirm it never lands on <node>:
oc get vmi -A -o wide | grep <node>
```

## Task 5: cleanup
```bash
oc adm taint node <node> q15/dedicated=vm:NoSchedule-
oc label node <node> q15/dedicated-
```

## Task 6: NodeHealthCheck + SNR reasoning
A `NodeHealthCheck` watches node conditions (for example `Ready=Unknown`
for 300s) against a `minHealthy` threshold. Once triggered, it hands off to
the `SelfNodeRemediationTemplate`, which fences the unhealthy node (marks it
for reboot/removal) so the cluster can safely reschedule its workloads.
Because `q15-dedicated` has `runStrategy: Always`, once the fenced node is
confirmed gone and its VMI is removed, the VM controller restarts it on a
healthy node automatically — without this, a VM stuck on a genuinely dead
node stays down indefinitely, since live migration cannot rescue a node
that never responds in the first place.
