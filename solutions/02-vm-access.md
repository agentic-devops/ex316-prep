# Solution: Objective 2 (matches questions/02-vm-access.md)

## Task 1-2: namespace and VM
```bash
oc create namespace q2-vmops

virtctl create vm --name app01 --namespace q2-vmops \
  --memory 4Gi --cpu 2 \
  --volume-containerdisk src:quay.io/containerdisks/fedora:latest \
  --cloud-init-user-data - <<'EOF2' | oc apply -f -
#cloud-config
user: cloud-user
password: Rexam-Pass1
chpasswd:
  expire: false
ssh_pwauth: true
EOF2
```
If your `virtctl` version's flags differ, the safe fallback is to write the
VirtualMachine YAML by hand — see `labs/02-vm-access/01-vm-fedora.yaml` for
the shape (rename, set cores: 2, memory 4Gi, and this password).

## Task 3: start and console
```bash
virtctl start app01 -n q2-vmops
oc wait vmi app01 -n q2-vmops --for=jsonpath='{.status.phase}'=Running --timeout=5m
virtctl console app01 -n q2-vmops    # confirm a login prompt, then Ctrl+]
```

## Task 4: built-in roles
```bash
oc adm policy add-role-to-user kubevirt.io:edit q2-dev -n q2-vmops
oc adm policy add-role-to-user kubevirt.io:view q2-viewer -n q2-vmops
```

## Task 5: custom Role
```bash
cat <<EOF2 | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: vm-operator
  namespace: q2-vmops
rules:
  - apiGroups: ["kubevirt.io"]
    resources: ["virtualmachines", "virtualmachineinstances"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["subresources.kubevirt.io"]
    resources:
      - virtualmachines/start
      - virtualmachines/stop
      - virtualmachines/restart
    verbs: ["update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: q2-ops-vm-operator
  namespace: q2-vmops
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: q2-ops
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: vm-operator
EOF2
```
Note: no `console`/`vnc` verbs granted, and no `create`/`delete`/`update` on
the VM object itself — only the three lifecycle subresources.

## Task 6: prove it
```bash
oc auth can-i create virtualmachines.kubevirt.io -n q2-vmops --as=q2-dev
oc auth can-i delete virtualmachines.kubevirt.io -n q2-vmops --as=q2-viewer
oc auth can-i update virtualmachines.subresources.kubevirt.io --subresource=start \
  -n q2-vmops --as=q2-ops
oc auth can-i get virtualmachineinstances.subresources.kubevirt.io --subresource=console \
  -n q2-vmops --as=q2-ops
```
Expected: yes, no, yes, no.
