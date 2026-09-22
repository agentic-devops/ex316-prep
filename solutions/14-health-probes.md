# Solution: Objective 14 (matches questions/14-health-probes.md)

## Task 1: namespace, VM with probes
```bash
oc create namespace q14-probes
```
Under `spec.template.spec` of `q14-vm` (same HTTP-listener cloud-init as
Objective 13):
```yaml
readinessProbe:
  httpGet: {port: 8080, path: /}
  initialDelaySeconds: 120
  periodSeconds: 20
  timeoutSeconds: 10
  failureThreshold: 3
  successThreshold: 3
livenessProbe:
  tcpSocket: {port: 8080}
  initialDelaySeconds: 120
  periodSeconds: 20
  timeoutSeconds: 10
  failureThreshold: 3
```

## Task 2: Service and Endpoints
```bash
cat <<EOF2 | oc apply -f -
apiVersion: v1
kind: Service
metadata: {name: q14-svc, namespace: q14-probes}
spec:
  selector: {app: q14-vm}
  ports: [{port: 80, targetPort: 8080}]
EOF2
oc get endpoints q14-svc -n q14-probes
```

## Task 3-4: stop/restart the listener
```bash
virtctl ssh cloud-user@vmi/q14-vm -n q14-probes -c 'sudo systemctl stop labhttp'
oc get endpoints q14-svc -n q14-probes   # empty
oc get vmi q14-vm -n q14-probes          # still Running

virtctl ssh cloud-user@vmi/q14-vm -n q14-probes -c 'sudo systemctl start labhttp'
oc get endpoints q14-svc -n q14-probes   # populated again
```

## Task 5: watchdog device
```yaml
devices:
  watchdog:
    name: q14-wd
    i6300esb: {action: poweroff}
```
For the action to do anything, the guest needs the `watchdog` daemon
package installed, `/dev/watchdog` present, and the `watchdog` service
enabled feeding it. Without that, the device exists but nothing acts on it.
