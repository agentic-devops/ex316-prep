# Solution: Objective 13 (matches questions/13-load-balancing.md)

## Task 1: namespace, VM with HTTP listener
```bash
oc create namespace q13-lb
```
`q13-web` needs a systemd unit serving on 8080, same pattern as
`labs/03-networking/01-vms.yaml`'s `labhttp.service`.

## Task 2: NodePort SSH
```bash
cat <<EOF2 | oc apply -f -
apiVersion: v1
kind: Service
metadata: {name: q13-ssh, namespace: q13-lb}
spec:
  type: NodePort
  selector: {app: q13-web}
  ports: [{port: 22, targetPort: 22, nodePort: 30222}]
EOF2
```

## Task 3: ClusterIP
```bash
cat <<EOF2 | oc apply -f -
apiVersion: v1
kind: Service
metadata: {name: q13-http, namespace: q13-lb}
spec:
  selector: {app: q13-web}
  ports: [{port: 80, targetPort: 8080, name: http}]
EOF2
```

## Task 4: edge Route with redirect
```bash
oc create route edge q13-route --service=q13-http \
  --hostname=q13.apps.<your-cluster-domain> \
  --insecure-policy=Redirect -n q13-lb
oc get route q13-route -n q13-lb -o jsonpath='{.spec.host}{"\n"}'
```

## Task 5: why not for SSH
Routes only carry HTTP/HTTPS/TLS-SNI traffic terminated or passed through
the OpenShift router; they cannot proxy an arbitrary TCP protocol like SSH.
NodePort (or a LoadBalancer Service) is required for raw TCP.
