# Solution: Objective 12 (matches questions/12-node-maintenance.md)

## Task 1: identify a target node
```bash
oc get vmi -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{" "}{.status.nodeName}{"\n"}{end}'
```
Pick any live-migratable VM's node (or reuse `q11-vm` from Objective 11).

## Task 2: NodeMaintenance
```bash
oc get crd | grep nodemaintenance   # confirm served group/version
cat <<EOF2 | oc apply -f -
apiVersion: nodemaintenance.medik8s.io/v1beta1
kind: NodeMaintenance
metadata: {name: q12-nm}
spec:
  nodeName: <node>
  reason: "Mock exam: firmware update"
EOF2
oc get nodemaintenance q12-nm -w
oc get node <node>                       # SchedulingDisabled
oc get vmi -A -o wide | grep <node>      # should be empty once drained
```

## Task 3: remove maintenance
```bash
oc delete nodemaintenance q12-nm
oc get node <node>                       # schedulable again
```

## Task 4: manual equivalent
```bash
oc adm cordon <node>
oc adm drain <node> --ignore-daemonsets --delete-emptydir-data --force --timeout=10m
oc adm uncordon <node>
```
