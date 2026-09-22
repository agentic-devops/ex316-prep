# Solution: Objective 9 (matches questions/09-migration.md)

## Task 1-2: namespace, extract and inspect
```bash
oc create namespace q9-import
tar -xvf legacy-app.ova
qemu-img info legacy-app-disk1.vmdk
# note: virtual size (VS) reported by qemu-img info
```

## Task 3: convert and upload
```bash
qemu-img convert -f vmdk -O qcow2 legacy-app-disk1.vmdk legacy-app.qcow2
# size the DV at least as large as the VS from Task 2, rounded up
virtctl image-upload dv q9-imported --size=20Gi --image-path=legacy-app.qcow2 \
  --insecure -n q9-import
oc get dv,pvc -n q9-import
```

## Task 4: VM matching legacy hardware
```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: q9-legacy
  namespace: q9-import
spec:
  runStrategy: Always
  template:
    spec:
      domain:
        cpu: {cores: 2}
        resources: {requests: {memory: 4Gi}}
        devices:
          disks:
            - {name: rootdisk, bootOrder: 1, disk: {bus: sata}}
          interfaces:
            - {name: default, masquerade: {}, model: e1000e}
      networks: [{name: default, pod: {}}]
      volumes:
        - name: rootdisk
          persistentVolumeClaim: {claimName: q9-imported}
```
```bash
oc apply -f q9-legacy-vm.yaml
```

## Task 5: confirm boot
```bash
virtctl console q9-legacy -n q9-import   # look for a login prompt
```

## Task 6: external access
```bash
cat <<EOF2 | oc apply -f -
apiVersion: v1
kind: Service
metadata: {name: q9-ssh, namespace: q9-import}
spec:
  type: NodePort
  selector: {app: q9-legacy}
  ports: [{port: 22, targetPort: 22, nodePort: 30322}]
---
apiVersion: v1
kind: Service
metadata: {name: q9-http, namespace: q9-import}
spec:
  selector: {app: q9-legacy}
  ports: [{port: 80, targetPort: 80, name: http}]
---
apiVersion: route.openshift.io/v1
kind: Route
metadata: {name: q9-http, namespace: q9-import}
spec:
  to: {kind: Service, name: q9-http}
  port: {targetPort: http}
EOF2
```
If the guest will not boot with `virtio`/`virtio-net`, that confirms it
needed `sata`/`e1000e` — the point of this task.
