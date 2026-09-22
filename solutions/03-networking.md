# Solution: Objective 3 (matches questions/03-networking.md)

## Task 1: namespace and two VMs
Reuse the shape from `labs/03-networking/01-vms.yaml` (web/db pattern),
renamed to `q3-web` / `q3-db`, labelled `tier: web` / `tier: db`, with
cloud-init `write_files` + a systemd unit serving on 8080 / 5432
respectively (see that lab file for the exact `runcmd` pattern).

```bash
oc create namespace q3-app
oc apply -n q3-app -f q3-vms.yaml     # your VM manifests
oc get vmi -n q3-app -o wide
```

## Task 2: reachability check
```bash
IP=$(oc get vmi q3-web -n q3-app -o jsonpath='{.status.interfaces[0].ipAddress}')
oc run tester -n q3-app --image=registry.access.redhat.com/ubi9/ubi \
  --restart=Never -- sleep infinity
oc exec -n q3-app tester -- curl -sm3 "http://$IP:8080"
```

## Task 3: default-deny
```bash
cat <<EOF2 | oc apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: q3-app
spec:
  podSelector: {}
  policyTypes: ["Ingress"]
EOF2
oc exec -n q3-app tester -- curl -sm3 "http://$IP:8080" || echo "blocked as expected"
```

## Task 4: web-to-db only
```bash
cat <<EOF2 | oc apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web-to-db
  namespace: q3-app
spec:
  podSelector:
    matchLabels: {tier: db}
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - podSelector:
            matchLabels: {tier: web}
      ports:
        - protocol: TCP
          port: 5432
EOF2
```
Prove both directions: a pod labelled `tier: web` reaches `q3-db:5432`; the
`tester` pod (no `tier` label) does not.

## Task 5: ClusterIP Service
```bash
cat <<EOF2 | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: q3-web-svc
  namespace: q3-app
spec:
  selector: {tier: web}
  ports:
    - port: 80
      targetPort: 8080
EOF2
oc exec -n q3-app tester -- curl -sm3 http://q3-web-svc
oc get endpoints q3-web-svc -n q3-app
```

## Task 6: primary UDN
```bash
cat <<EOF2 | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: q3-udn
  labels:
    k8s.ovn.org/primary-user-defined-network: ""
EOF2
cat <<EOF2 | oc apply -f -
apiVersion: k8s.ovn.org/v1
kind: UserDefinedNetwork
metadata:
  name: q3-udn-primary
  namespace: q3-udn
spec:
  topology: Layer2
  layer2:
    role: Primary
    subnets: ["10.200.0.0/24"]
    ipam:
      lifecycle: Persistent
EOF2
# VM in q3-udn: interfaces use binding: {name: l2bridge} instead of masquerade
oc get vmi -n q3-udn -o jsonpath='{.items[0].status.interfaces[*].ipAddress}{"\n"}'
```
Confirm the printed IP falls inside `10.200.0.0/24`.
