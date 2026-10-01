# EX316 Complete Practice Guide: CLI-First Approach

**Exam:** Red Hat Certified Specialist in OpenShift Virtualization (EX316)
**Time limit:** 4 hours | **Format:** Performance-based (CLI only, no multiple choice)
**Available during exam:** `oc explain`, `--help`, product docs. NO internet, NO personal notes.

---

## Part 1: CLI Discovery Strategy for Beginners

Before diving into topics, master these three techniques. They are your lifeline during the exam.

### Technique 1: `--help` + `grep` (Finding the right flags)
```bash
# Pattern: <command> --help | grep -iE "keyword1|keyword2"
virtctl --help | grep -iE "start|stop|console|ssh"
virtctl create vm --help | grep -iE "memory|volume|cloud-init"
oc create --help | grep -i secret
oc adm --help | grep -i drain
```

### Technique 2: `oc explain` (Finding YAML field paths)
```bash
# Pattern: oc explain <resource>.spec.path.to.field
oc explain vm.spec.template.spec.domain
oc explain vm.spec.template.spec.domain.resources
oc explain vm.spec.template.spec.readinessProbe
oc explain networkpolicy.spec.ingress.from
oc explain datavolume.spec.storage
# Tip: Add --recursive to see the full tree
oc explain vm.spec --recursive | grep -i eviction
```

### Technique 3: `oc api-resources` + `grep` (Finding resource names)
```bash
# Pattern: oc api-resources | grep -i <keyword>
oc api-resources | grep -i virtualmachine
oc api-resources | grep -i clone
oc api-resources | grep -i snapshot
oc api-resources | grep -i migration
oc api-resources | grep -i nodemaintenance
# Shows the API group and version you need for YAML manifests
```

### Technique 4: Discover available resources in the cluster
```bash
oc get datasources -n openshift-virtualization-os-images   # bootable images
oc get template -n openshift -l template.kubevirt.io/type=vm  # VM templates
oc get virtualmachineclusterinstancetype   # instance types
oc get virtualmachineclusterpreference     # preferences
oc get sc                                  # storage classes
oc get volumesnapshotclass                 # snapshot classes
oc get packagemanifest -n openshift-marketplace | grep -i virt  # operators
```

### Speed Tips for the Exam
1. **Don't write YAML from scratch** -- use `virtctl create vm` to generate it, then pipe or redirect
2. **Use `cat <<EOF | oc apply -f -`** for inline manifests -- faster than creating files
3. **Use `oc patch --type merge`** for quick changes instead of `oc edit`
4. **Use `-w` flag** to watch resources: `oc get vmi -w` until status changes
5. **Use `oc wait`** for automation: `oc wait vmi/<name> --for=jsonpath='{.status.phase}'=Running`

---

## Part 2: 15-Day Study Schedule

| Day | Topics (Objectives) | Estimated Practice Time | Focus |
|-----|---------------------|------------------------|-------|
| 1 | 1 (Operator), 2 (VM Access) | 1.5 hrs | Core foundations: install operator, create VMs, RBAC |
| 2 | 3 (Networking) | 1.5 hrs | NetworkPolicies, Services, UDN |
| 3 | 4 (External Networks), 13 (Load Balancing) | 1.5 hrs | NMState, bridges, Routes, NodePorts |
| 4 | 5 (Storage) | 1.5 hrs | DataVolumes, hot-plug, PVC expansion, fstab |
| 5 | 6 (OADP) | 1 hr | Backup/Restore/Schedule CRs |
| 6 | 7 (Templates), 8 (Snapshots) | 2 hrs | Custom templates, cloud-init, snapshot/restore |
| 7 | 9 (Migration), 10 (Cloning) | 1.5 hrs | OVA import, qemu-img, clone prep |
| 8 | 11 (Live Migration), 12 (Node Maintenance) | 1.5 hrs | virtctl migrate, NodeMaintenance, drain |
| 9 | 14 (Health Probes), 15 (Node Failure) | 1.5 hrs | Probes, anti-affinity, taints |
| 10 | 16 (Guest Sysadmin) + Review weak areas | 1.5 hrs | systemctl, dnf, journalctl |
| 11 | **Full drill: all 16 drill-blanks cold** | 1.5 hrs | Time yourself, log every miss |
| 12 | Re-drill weak objectives + questions 01-08 | 1.5 hrs | Focus on mistakes from Day 11 |
| 13 | Questions 09-16 cold | 1.5 hrs | Timed practice per topic |
| 14 | **Mock Exam 1: full 4-hour block** | 4 hrs | No breaks, no notes |
| 15 | Review misses, re-drill, light review | 1 hr | Don't cram new material |

---

## Part 3: Practice Questions by Topic with CLI Discovery Solutions

---

### Topic 1: Deploy the OpenShift Virtualization Operator
**Time budget: 8 minutes** | **Difficulty: Medium** | **Exam weight: Low-Medium**

#### Practice Question
> A fresh OCP 4.18 cluster has no virtualization capability. Install the OpenShift Virtualization operator from CLI only, using the package's actual default channel (don't guess). Create the HyperConverged CR and wait for it. Find the virtctl download URL.

#### Step-by-Step CLI Discovery Solution

**Step 1: Find the operator package and its default channel**
```bash
# HOW TO DISCOVER: What operators are available?
oc get packagemanifest -n openshift-marketplace --help | head -5
oc get packagemanifest -n openshift-marketplace | grep -i virt

# Get the default channel (DON'T MEMORIZE -- look it up every time)
CH=$(oc get packagemanifest kubevirt-hyperconverged -n openshift-marketplace \
      -o jsonpath='{.status.defaultChannel}')
echo "Channel: $CH"
```

**Step 2: Create namespace, OperatorGroup, and Subscription**
```bash
# HOW TO DISCOVER: What kind/apiVersion for Subscription?
oc explain subscription  # or: oc api-resources | grep -i subscription

oc create namespace openshift-cnv
oc label namespace openshift-cnv openshift.io/cluster-monitoring=true

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: kubevirt-hyperconverged-group
  namespace: openshift-cnv
spec:
  targetNamespaces:
    - openshift-cnv
EOF

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: hco-operatorhub
  namespace: openshift-cnv
spec:
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  name: kubevirt-hyperconverged
  channel: $CH
  installPlanApproval: Automatic
EOF

# Watch until Succeeded
oc get csv -n openshift-cnv -w
```

**Step 3: Create HyperConverged CR and wait**
```bash
# HOW TO DISCOVER: What's the API version for HyperConverged?
oc api-resources | grep -i hyperconverged

cat <<EOF | oc apply -f -
apiVersion: hco.kubevirt.io/v1beta1
kind: HyperConverged
metadata:
  name: kubevirt-hyperconverged
  namespace: openshift-cnv
spec: {}
EOF

oc wait hco/kubevirt-hyperconverged -n openshift-cnv \
  --for=condition=Available --timeout=20m
```

**Step 4: Find virtctl download URL**
```bash
# HOW TO DISCOVER: What resource has the download link?
oc api-resources | grep -i download
oc get consoleclidownload virtctl-clidownload-kubevirt-hyperconverged \
  -o jsonpath='{.spec.links[*].href}{"\n"}'
```

**Verify:**
```bash
oc get csv -n openshift-cnv | grep -i succeeded
oc get hco kubevirt-hyperconverged -n openshift-cnv \
  -o jsonpath='{.status.conditions[?(@.type=="Available")].status}{"\n"}'
```

---

### Topic 2: Run and Access Virtual Machines + RBAC
**Time budget: 15 minutes** | **Difficulty: High** | **Exam weight: High**

#### Practice Question
> In namespace `q2-vmops`: Create a VM `app01` with 2 vCPU, 4Gi memory, Fedora container disk, cloud-init user `cloud-user` / password `Rexam-Pass1`. Start it, confirm login prompt via console. Grant user `q2-dev` edit rights, `q2-viewer` view rights (built-in roles). Create custom Role `vm-operator` for start/stop/restart only (no create/delete/console), bind to `q2-ops`. Prove RBAC with `oc auth can-i`.

#### Step-by-Step CLI Discovery Solution

**Step 1: Create namespace and VM**
```bash
oc create namespace q2-vmops

# HOW TO DISCOVER: What flags does virtctl create vm accept?
virtctl create vm --help | grep -iE "memory|cpu|volume|cloud-init|name"
# Key flags found: --name, --memory, --cpu, --volume-containerdisk, --cloud-init-user-data

virtctl create vm --name app01 --namespace q2-vmops \
  --memory 4Gi --cpu 2 \
  --volume-containerdisk src:quay.io/containerdisks/fedora:latest \
  --cloud-init-user-data - <<'CIEOF' | oc apply -f -
#cloud-config
user: cloud-user
password: Rexam-Pass1
chpasswd:
  expire: false
ssh_pwauth: true
CIEOF
```

**Step 2: Start and access console**
```bash
# HOW TO DISCOVER lifecycle commands:
virtctl --help | grep -iE "start|stop|console"

virtctl start app01 -n q2-vmops
oc wait vmi app01 -n q2-vmops --for=jsonpath='{.status.phase}'=Running --timeout=5m

# Console access (exit with Ctrl+])
virtctl console app01 -n q2-vmops
```

**Step 3: Assign built-in RBAC roles**
```bash
# HOW TO DISCOVER: What built-in roles exist for VMs?
oc get clusterrole | grep kubevirt
# Shows: kubevirt.io:admin, kubevirt.io:edit, kubevirt.io:view

oc adm policy add-role-to-user kubevirt.io:edit q2-dev -n q2-vmops
oc adm policy add-role-to-user kubevirt.io:view q2-viewer -n q2-vmops
```

**Step 4: Create custom Role (start/stop/restart ONLY, no console)**
```bash
# HOW TO DISCOVER: What API groups and subresources exist?
oc api-resources | grep -i virtualmachine
# virtualmachines                    kubevirt.io/v1
# virtualmachineinstances            kubevirt.io/v1
# Also: subresources.kubevirt.io for start/stop/restart/console

cat <<EOF | oc apply -f -
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
EOF
```

**Step 5: Verify RBAC**
```bash
oc auth can-i create virtualmachines.kubevirt.io -n q2-vmops --as=q2-dev          # yes
oc auth can-i delete virtualmachines.kubevirt.io -n q2-vmops --as=q2-viewer       # no
oc auth can-i update virtualmachines.subresources.kubevirt.io --subresource=start \
  -n q2-vmops --as=q2-ops                                                         # yes
oc auth can-i get virtualmachineinstances.subresources.kubevirt.io --subresource=console \
  -n q2-vmops --as=q2-ops                                                         # no
```

---

### Topic 3: Kubernetes Networking for VMs
**Time budget: 25 minutes** | **Difficulty: High** | **Exam weight: High**

#### Practice Question
> In namespace `q3-app`: Deploy VMs `q3-web` (tier:web, port 8080) and `q3-db` (tier:db, port 5432). Apply default-deny ingress. Allow only tier:web pods to reach q3-db on 5432. Create ClusterIP Service for q3-web. In namespace `q3-udn`: Create primary UserDefinedNetwork (Layer2, 10.200.0.0/24), confirm VM IP is in that subnet.

#### Step-by-Step CLI Discovery Solution

**Step 1: Create namespace and test reachability**
```bash
oc create namespace q3-app
# Deploy VMs (use virtctl create vm or apply manifests with tier labels)
# Verify IPs:
oc get vmi -n q3-app -o wide

# Test reachability with a temporary pod:
IP=$(oc get vmi q3-web -n q3-app -o jsonpath='{.status.interfaces[0].ipAddress}')
oc run tester -n q3-app --image=registry.access.redhat.com/ubi9/ubi \
  --restart=Never -- sleep infinity
oc exec -n q3-app tester -- curl -sm3 "http://$IP:8080"
```

**Step 2: Default-deny NetworkPolicy**
```bash
# HOW TO DISCOVER: NetworkPolicy structure
oc explain networkpolicy.spec
oc explain networkpolicy.spec.podSelector

cat <<EOF | oc apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: q3-app
spec:
  podSelector: {}
  policyTypes: ["Ingress"]
EOF

# Confirm blocked:
oc exec -n q3-app tester -- curl -sm3 "http://$IP:8080" || echo "blocked"
```

**Step 3: Allow web-to-db policy**
```bash
# HOW TO DISCOVER: What goes under ingress.from?
oc explain networkpolicy.spec.ingress.from

cat <<EOF | oc apply -f -
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
EOF
```

**Step 4: ClusterIP Service**
```bash
# HOW TO DISCOVER: How to expose a VM as a Service?
virtctl expose --help | head -20

# Option A: virtctl shortcut
virtctl expose vm q3-web --name q3-web-svc --port 80 --target-port 8080 -n q3-app

# Option B: YAML (more control)
cat <<EOF | oc apply -f -
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
EOF

oc get endpoints q3-web-svc -n q3-app
```

**Step 5: UserDefinedNetwork**
```bash
# HOW TO DISCOVER: UDN resources
oc api-resources | grep -i userdefined
oc explain userdefinednetwork.spec

cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: q3-udn
  labels:
    k8s.ovn.org/primary-user-defined-network: ""
---
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
EOF
```

---

### Topic 4: External Networks (Multus, NMState)
**Time budget: 20 minutes** | **Difficulty: High** | **Exam weight: Medium-High**

#### Practice Question
> Create a Linux bridge `q4-br` on every worker via NNCP using a spare NIC. Create a NAD in namespace `q4-ext`. Attach two VMs with second NICs on the bridge using static IPs (192.168.150.11/24 and .12/24). Ping between them.

#### Step-by-Step CLI Discovery Solution

**Step 1: Find spare NIC name**
```bash
# HOW TO DISCOVER: What NMState resources exist?
oc api-resources | grep -i nmstate
oc api-resources | grep -i nodenetwork

oc get nns   # NodeNetworkState - shows each node's interfaces
oc get nns <worker-node> -o jsonpath='{.status.currentState.interfaces[*].name}{"\n"}'
```

**Step 2: Create NNCP (bridge policy)**
```bash
# HOW TO DISCOVER: NNCP structure
oc explain nncp.spec.desiredState

cat <<EOF | oc apply -f -
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: q4-br-policy
spec:
  nodeSelector:
    node-role.kubernetes.io/worker: ""
  desiredState:
    interfaces:
      - name: q4-br
        type: linux-bridge
        state: up
        ipv4: {enabled: false}
        bridge:
          options: {stp: {enabled: false}}
          port:
            - name: ens224
EOF

# Verify on ALL workers (not just that the policy exists):
oc get nnce | grep q4-br-policy
# If a node failed: oc describe nnce <node>.q4-br-policy
```

**Step 3: Create NAD**
```bash
oc create namespace q4-ext

cat <<EOF | oc apply -f -
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: q4-net
  namespace: q4-ext
  annotations:
    k8s.v1.cni.cncf.io/resourceName: bridge.network.kubevirt.io/q4-br
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "name": "q4-net",
      "type": "cnv-bridge",
      "bridge": "q4-br",
      "ipam": {}
    }
EOF
```

**Step 4: VMs with static IPs on bridge (use cloud-init networkData)**
```bash
# In VM spec, add second interface:
# interfaces:
#   - name: default
#     masquerade: {}
#   - name: bridge-net
#     bridge: {}
# networks:
#   - name: default
#     pod: {}
#   - name: bridge-net
#     multus:
#       networkName: q4-net

# Static IP via cloud-init networkData:
# networkData: |
#   ethernets:
#     eth1:
#       addresses: [192.168.150.11/24]

# Verify:
virtctl ssh cloud-user@vmi/q4-vm1 -n q4-ext -c 'ip -br a'
virtctl ssh cloud-user@vmi/q4-vm1 -n q4-ext -c 'ping -c3 192.168.150.12'
```

---

### Topic 5: Kubernetes Storage for VMs
**Time budget: 20 minutes** | **Difficulty: High** | **Exam weight: High**

#### Practice Question
> In namespace `q5-store`: Create VM with 10Gi root + 4Gi blank data disk. Format data disk as XFS, mount at /data, persist by UUID in fstab. Expand to 6Gi and grow filesystem. Hot-plug then remove a 2Gi disk. Set a StorageClass as default for virtualization.

#### Step-by-Step CLI Discovery Solution

**Step 1: Create VM with two DataVolumeTemplates**
```bash
oc create namespace q5-store

# HOW TO DISCOVER: DataVolume structure
oc explain datavolume.spec.storage
oc explain datavolume.spec.source

# VM manifest needs two dataVolumeTemplates:
# 1. Root disk: source.registry.url: docker://quay.io/containerdisks/fedora:latest, storage: 10Gi
# 2. Data disk: source.blank: {}, storage: 4Gi, serial: DATA01
```

**Step 2: Format, mount, and persist inside guest**
```bash
virtctl ssh cloud-user@vmi/q5-vm -n q5-store

# Inside guest:
lsblk -o NAME,SIZE,SERIAL          # Find disk by serial DATA01
sudo mkfs.xfs /dev/vdb
sudo mkdir -p /data
sudo mount /dev/vdb /data
sudo blkid /dev/vdb                 # Copy the UUID
echo 'UUID=<paste-uuid> /data xfs defaults 0 0' | sudo tee -a /etc/fstab
sudo mount -a                       # Verify no errors
```

**Step 3: Expand PVC and grow filesystem**
```bash
# From outside the guest:
oc patch pvc q5-vm-data -n q5-store --type merge \
  -p '{"spec":{"resources":{"requests":{"storage":"6Gi"}}}}'

# Inside guest:
sudo xfs_growfs /data               # Mount point, NOT device!
df -h /data                         # Should show ~6Gi now
```

**Step 4: Hot-plug disk**
```bash
# HOW TO DISCOVER: Hot-plug commands
virtctl --help | grep -i volume
virtctl addvolume --help

# First create the DV:
cat <<EOF | oc apply -f -
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: q5-hotplug
  namespace: q5-store
spec:
  source: {blank: {}}
  storage:
    resources: {requests: {storage: 2Gi}}
EOF

# Attach persistently:
virtctl addvolume q5-vm --volume-name=q5-hotplug --serial=hp01 --persist -n q5-store

# Verify inside guest: lsblk -o NAME,SERIAL

# Remove persistently:
virtctl removevolume q5-vm --volume-name=q5-hotplug --persist -n q5-store
```

**Step 5: Default virt StorageClass**
```bash
# HOW TO DISCOVER: What annotation controls this?
oc explain storageprofile  # or search docs for "default virt"

oc annotate sc <name> storageclass.kubevirt.io/is-default-virt-class=true --overwrite
```

---

### Topic 6: OADP Backup and Restore
**Time budget: 20 minutes** | **Difficulty: Medium** | **Exam weight: Medium**

#### Practice Question
> Create namespace `q6-oadp`, VM `q6-vm` with a marker file. Back up with CSI data movement. Delete VM entirely. Restore and verify marker file. Create daily 3AM schedule retaining 7 days. Describe troubleshooting PartiallyFailed backups.

#### Step-by-Step CLI Discovery Solution

**Step 1: Verify OADP is ready**
```bash
# HOW TO DISCOVER: What OADP resources exist?
oc api-resources | grep -i velero
oc get dpa,backupstoragelocation -n openshift-adp
```

**Step 2: Create Backup**
```bash
cat <<EOF | oc apply -f -
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: q6-backup
  namespace: openshift-adp
spec:
  includedNamespaces: ["q6-oadp"]
  snapshotMoveData: true
  ttl: 72h0m0s
EOF

# KEY GOTCHA: Backup CR goes in openshift-adp namespace, NOT the app namespace!
oc get backup.velero.io q6-backup -n openshift-adp -o jsonpath='{.status.phase}{"\n"}'
```

**Step 3: Delete and Restore**
```bash
oc delete vm q6-vm -n q6-oadp
oc delete pvc --all -n q6-oadp

cat <<EOF | oc apply -f -
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: q6-restore
  namespace: openshift-adp
spec:
  backupName: q6-backup
  includedNamespaces: ["q6-oadp"]
EOF

oc get restore.velero.io q6-restore -n openshift-adp -w
```

**Step 4: Schedule**
```bash
cat <<EOF | oc apply -f -
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: q6-daily
  namespace: openshift-adp
spec:
  schedule: "0 3 * * *"
  template:
    includedNamespaces: ["q6-oadp"]
    snapshotMoveData: true
    ttl: 168h0m0s
EOF
```

**Step 5: Troubleshoot PartiallyFailed**
```bash
# HOW TO DISCOVER: velero CLI inside the cluster
alias velero='oc -n openshift-adp exec deployment/velero -c velero -it -- ./velero'
velero backup describe <name> --details
velero backup logs <name>
# Common causes: missing VolumeSnapshotClass label, BSL not Available
```

---

### Topic 7: VM Templates and Cloud-Init
**Time budget: 20 minutes** | **Difficulty: Medium-High** | **Exam weight: High**

#### Practice Question
> List preconfigured templates and show parameters. Write custom Template `q7-appserver` with NAME and MEMORY parameters. Cloud-init: set password, install httpd, enable httpd at boot. Instantiate twice with different memory. Also create a VM using instance types.

#### Step-by-Step CLI Discovery Solution

**Step 1: Discover available templates**
```bash
# HOW TO DISCOVER: Where are VM templates?
oc get template -n openshift -l template.kubevirt.io/type=vm
oc process --parameters -n openshift fedora-server-small

# Instantiate:
oc process -n openshift fedora-server-small -p NAME=q7-from-rht | oc apply -n <ns> -f -
```

**Step 2: Write custom template**
```bash
cat <<'EOF' | oc apply -n <ns> -f -
apiVersion: template.openshift.io/v1
kind: Template
metadata:
  name: q7-appserver
  labels: {template.kubevirt.io/type: vm}
objects:
  - apiVersion: kubevirt.io/v1
    kind: VirtualMachine
    metadata:
      name: ${NAME}
    spec:
      runStrategy: Always
      template:
        metadata: {labels: {app: ${NAME}}}
        spec:
          domain:
            resources: {requests: {memory: ${MEMORY}}}
            devices:
              disks:
                - {name: rootdisk, disk: {bus: virtio}}
                - {name: cloudinitdisk, disk: {bus: virtio}}
              interfaces: [{name: default, masquerade: {}}]
          networks: [{name: default, pod: {}}]
          volumes:
            - name: rootdisk
              containerDisk: {image: quay.io/containerdisks/fedora:latest}
            - name: cloudinitdisk
              cloudInitNoCloud:
                userData: |
                  #cloud-config
                  user: cloud-user
                  password: lab-pass-123
                  chpasswd: {expire: false}
                  ssh_pwauth: true
                  packages: [httpd]
                  write_files:
                    - {path: /var/www/html/index.html, content: "app server\n"}
                  runcmd:
                    - [systemctl, enable, --now, httpd]
parameters:
  - {name: NAME, required: true}
  - {name: MEMORY, value: 2Gi}
EOF
```

**Step 3: Instantiate**
```bash
oc process -n <ns> q7-appserver -p NAME=q7-app01 | oc apply -n <ns> -f -
oc process -n <ns> q7-appserver -p NAME=q7-app02 -p MEMORY=3Gi | oc apply -n <ns> -f -

# Verify memory:
oc get vm q7-app02 -n <ns> -o jsonpath='{.spec.template.spec.domain.resources.requests.memory}{"\n"}'
```

**Step 4: Instance type VM**
```bash
oc get virtualmachineclusterinstancetype
oc get virtualmachineclusterpreference
# VM spec uses instancetype + preference instead of domain.cpu/resources
# KEY GOTCHA: instance types REJECT explicit cpu/memory in the spec
```

---

### Topic 8: VM Snapshots
**Time budget: 15 minutes** | **Difficulty: Medium** | **Exam weight: Medium**

#### Practice Question
> Create VM with DataVolume, create marker file, snapshot, change guest, snapshot again, restore to first snapshot, verify original marker file is back. Delete second snapshot and confirm cleanup.

#### Step-by-Step CLI Discovery Solution

```bash
# HOW TO DISCOVER: Snapshot API resources
oc api-resources | grep -i snapshot

# Create snapshot:
cat <<EOF | oc apply -f -
apiVersion: snapshot.kubevirt.io/v1beta1
kind: VirtualMachineSnapshot
metadata:
  name: q8-snap-a
  namespace: q8-snap
spec:
  source: {apiGroup: kubevirt.io, kind: VirtualMachine, name: q8-vm}
EOF

# Check ready:
oc get vmsnapshot q8-snap-a -n q8-snap -o jsonpath='{.status.readyToUse}{"\n"}'

# RESTORE (VM MUST be stopped first!):
virtctl stop q8-vm -n q8-snap

cat <<EOF | oc apply -f -
apiVersion: snapshot.kubevirt.io/v1beta1
kind: VirtualMachineRestore
metadata:
  name: q8-restore-a
  namespace: q8-snap
spec:
  target: {apiGroup: kubevirt.io, kind: VirtualMachine, name: q8-vm}
  virtualMachineSnapshotName: q8-snap-a
EOF

oc get vmrestore q8-restore-a -n q8-snap -o jsonpath='{.status.complete}{"\n"}'
virtctl start q8-vm -n q8-snap

# Delete and verify cleanup:
oc delete vmsnapshot q8-snap-b -n q8-snap
oc get volumesnapshot,volumesnapshotcontent -n q8-snap
```

---

### Topic 9: Migrate from Other Hypervisors (OVA Import)
**Time budget: 20 minutes** | **Difficulty: Medium** | **Exam weight: Medium**

#### Practice Question
> Extract OVA, inspect VMDK, convert to qcow2, upload to DataVolume. Boot VM with SATA disk bus and e1000e NIC (legacy guest). Expose SSH via NodePort, HTTP via Route.

#### Step-by-Step CLI Discovery Solution

```bash
# Extract and inspect:
tar -xvf legacy-app.ova
qemu-img info legacy-app-disk1.vmdk    # Note: virtual size

# Convert:
qemu-img convert -f vmdk -O qcow2 legacy-app-disk1.vmdk legacy-app.qcow2

# Upload:
# HOW TO DISCOVER: upload command
virtctl --help | grep -i upload
virtctl image-upload --help | head -20

virtctl image-upload dv q9-imported --size=20Gi --image-path=legacy-app.qcow2 \
  --insecure -n q9-import

# VM with legacy hardware:
# KEY: disk bus: sata (not virtio), NIC model: e1000e (not virtio)
# In VM spec:
#   disks:
#     - name: rootdisk
#       bootOrder: 1
#       disk: {bus: sata}
#   interfaces:
#     - name: default
#       masquerade: {}
#       model: e1000e
```

---

### Topic 10: Clone VMs
**Time budget: 15 minutes** | **Difficulty: Medium** | **Exam weight: Medium**

#### Practice Question
> Prepare a golden VM for cloning (reset machine-id, remove SSH host keys, clean cloud-init). Create DataVolume-based disk clone. Create whole-VM clone via VirtualMachineClone. Confirm no MAC/IP collisions.

#### Step-by-Step CLI Discovery Solution

```bash
# Step 1: Prepare guest (INSIDE the VM):
sudo truncate -s 0 /etc/machine-id
sudo rm -f /etc/ssh/ssh_host_*
sudo cloud-init clean --logs

# Step 2: Stop source, then DataVolume clone:
virtctl stop q10-src -n q10-clone

cat <<EOF | oc apply -f -
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata: {name: q10-clone-a, namespace: q10-clone}
spec:
  source:
    pvc: {namespace: q10-clone, name: q10-src-root}
  storage:
    resources: {requests: {storage: 10Gi}}
EOF

# Step 3: Whole-VM clone
# HOW TO DISCOVER: API version for VirtualMachineClone
oc api-resources | grep clone.kubevirt.io

cat <<EOF | oc apply -f -
apiVersion: clone.kubevirt.io/v1alpha1
kind: VirtualMachineClone
metadata: {name: q10-clone-vm, namespace: q10-clone}
spec:
  source: {apiGroup: kubevirt.io, kind: VirtualMachine, name: q10-src}
  target: {apiGroup: kubevirt.io, kind: VirtualMachine, name: q10-vm-b}
EOF

# Verify no collisions:
oc get vmi -n q10-clone -o custom-columns=\
NAME:.metadata.name,IP:.status.interfaces[0].ipAddress,MAC:.status.interfaces[0].mac
```

---

### Topic 11: Live Migration
**Time budget: 20 minutes** | **Difficulty: Medium-High** | **Exam weight: Medium**

#### Practice Question
> Create VM with RWX/Block storage and evictionStrategy: LiveMigrate. Confirm LiveMigratable. Migrate and confirm different node. Start second migration and cancel it. Create MigrationPolicy limiting bandwidth. Adjust cluster-wide parallel migrations.

#### Step-by-Step CLI Discovery Solution

```bash
# KEY GOTCHA: Live migration requires ReadWriteMany access mode + Block volume mode

# Check LiveMigratable:
oc get vmi q11-vm -n q11-migr \
  -o jsonpath='{.status.conditions[?(@.type=="LiveMigratable")].status}{"\n"}'

# Migrate:
virtctl migrate q11-vm -n q11-migr
oc get vmim -n q11-migr -w      # Watch until Succeeded

# Confirm node changed:
oc get vmi q11-vm -n q11-migr -o jsonpath='{.status.nodeName}{"\n"}'

# Cancel:
virtctl migrate q11-vm -n q11-migr
virtctl migrate-cancel q11-vm -n q11-migr

# MigrationPolicy:
oc label namespace q11-migr migration-policy=q11

cat <<EOF | oc apply -f -
apiVersion: migrations.kubevirt.io/v1alpha1
kind: MigrationPolicy
metadata: {name: q11-policy}
spec:
  allowPostCopy: false
  bandwidthPerMigration: 32Mi
  selectors:
    namespaceSelector: {migration-policy: q11}
EOF

# Cluster-wide parallel migrations:
oc patch hco kubevirt-hyperconverged -n openshift-cnv --type merge \
  -p '{"spec":{"liveMigrationConfig":{"parallelMigrationsPerCluster":8}}}'
```

---

### Topic 12: Node Maintenance
**Time budget: 15 minutes** | **Difficulty: Medium** | **Exam weight: Medium**

#### Practice Question
> Identify a worker node running a VM. Put it in maintenance using NodeMaintenance CR. Confirm VM migrates off. Remove maintenance. Then repeat manually with `oc adm cordon/drain/uncordon`.

#### Step-by-Step CLI Discovery Solution

```bash
# Find which node runs a VM:
oc get vmi -A -o wide

# NodeMaintenance:
# HOW TO DISCOVER: API version
oc api-resources | grep -i nodemaintenance

cat <<EOF | oc apply -f -
apiVersion: nodemaintenance.medik8s.io/v1beta1
kind: NodeMaintenance
metadata: {name: q12-nm}
spec:
  nodeName: <node>
  reason: "Firmware update"
EOF

# Verify:
oc get node <node>                  # SchedulingDisabled
oc get vmi -A -o wide | grep <node> # Should be empty

# Remove:
oc delete nodemaintenance q12-nm

# Manual equivalent:
oc adm cordon <node>
oc adm drain <node> --ignore-daemonsets --delete-emptydir-data --force --timeout=10m
oc adm uncordon <node>
```

---

### Topic 13: Load Balancing with K8s Networking
**Time budget: 15 minutes** | **Difficulty: Medium** | **Exam weight: Medium**

#### Practice Question
> Expose VM HTTP on port 8080 via ClusterIP + edge TLS Route with custom hostname and HTTP-to-HTTPS redirect. Expose SSH via NodePort. Explain why Routes can't handle SSH.

#### Step-by-Step CLI Discovery Solution

```bash
# NodePort for SSH:
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata: {name: q13-ssh, namespace: q13-lb}
spec:
  type: NodePort
  selector: {app: q13-web}
  ports: [{port: 22, targetPort: 22, nodePort: 30222}]
EOF

# ClusterIP for HTTP:
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata: {name: q13-http, namespace: q13-lb}
spec:
  selector: {app: q13-web}
  ports: [{port: 80, targetPort: 8080, name: http}]
EOF

# Edge Route:
# HOW TO DISCOVER:
oc create route --help
oc create route edge --help

oc create route edge q13-route --service=q13-http \
  --hostname=q13.apps.<domain> \
  --insecure-policy=Redirect -n q13-lb

# Why not Route for SSH:
# Routes only handle HTTP/HTTPS traffic via the OpenShift router.
# SSH is raw TCP -- needs NodePort or LoadBalancer Service.
```

---

### Topic 14: Health Probes
**Time budget: 15 minutes** | **Difficulty: Medium** | **Exam weight: Medium**

#### Practice Question
> Add readiness HTTP probe and liveness TCP probe to a VM on port 8080. Create Service, confirm VM is Endpoint. Stop listener inside guest -- verify removed from Endpoints but VM stays running. Restart listener -- confirm Endpoint returns. Add i6300esb watchdog device.

#### Step-by-Step CLI Discovery Solution

```bash
# HOW TO DISCOVER: Probe field paths
oc explain vm.spec.template.spec.readinessProbe
oc explain vm.spec.template.spec.livenessProbe
oc explain vm.spec.template.spec.domain.devices.watchdog

# In VM spec.template.spec:
# readinessProbe:
#   httpGet: {port: 8080, path: /}
#   initialDelaySeconds: 120    # VMs boot slowly!
#   periodSeconds: 20
#   failureThreshold: 3
#   successThreshold: 3
# livenessProbe:
#   tcpSocket: {port: 8080}
#   initialDelaySeconds: 120
#   periodSeconds: 20
#   failureThreshold: 3

# Test readiness removes from Endpoints:
virtctl ssh cloud-user@vmi/q14-vm -n q14-probes -c 'sudo systemctl stop labhttp'
oc get endpoints q14-svc -n q14-probes    # Empty!
oc get vmi q14-vm -n q14-probes           # Still Running

# Watchdog device (in VM spec):
# devices:
#   watchdog:
#     name: q14-wd
#     i6300esb: {action: poweroff}
# Guest needs watchdog daemon running to feed /dev/watchdog
```

---

### Topic 15: Prepare for Node Failure
**Time budget: 20 minutes** | **Difficulty: High** | **Exam weight: Medium-High**

#### Practice Question
> Create two VMs with required pod anti-affinity (never same node). Taint and label a node, create VM that only schedules there with matching toleration. Clean up taint/label afterward.

#### Step-by-Step CLI Discovery Solution

```bash
# HOW TO DISCOVER: Anti-affinity structure
oc explain vm.spec.template.spec.affinity.podAntiAffinity

# Both VMs need under spec.template:
# metadata:
#   labels: {group: q15-pair}
# spec:
#   evictionStrategy: LiveMigrate
#   affinity:
#     podAntiAffinity:
#       requiredDuringSchedulingIgnoredDuringExecution:
#         - labelSelector: {matchLabels: {group: q15-pair}}
#           topologyKey: kubernetes.io/hostname

# Verify different nodes:
oc get vmi -n q15-ha -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.nodeName}{"\n"}{end}'

# Taint and label:
oc label node <node> q15/dedicated=vm
oc adm taint node <node> q15/dedicated=vm:NoSchedule

# VM with toleration + nodeSelector:
# nodeSelector: {q15/dedicated: vm}
# tolerations:
#   - {key: q15/dedicated, operator: Equal, value: vm, effect: NoSchedule}

# Cleanup:
oc adm taint node <node> q15/dedicated=vm:NoSchedule-
oc label node <node> q15/dedicated-
```

---

### Topic 16: Guest System Administration
**Time budget: 15 minutes** | **Difficulty: Medium** | **Exam weight: Medium**

#### Practice Question
> Inside a VM: Start and enable a service, confirm it survives reboot. Diagnose a failed service (typo in ExecStart), fix it, reload, start, enable. Install/remove a package. Create a systemd drop-in override for Restart=always. Report listening ports, disk usage, failed units.

#### Step-by-Step CLI Discovery Solution

```bash
# Enable and start a service:
sudo systemctl enable --now labweb.service
systemctl is-enabled labweb ; systemctl is-active labweb

# Diagnose failed service:
systemctl status labapp.service
journalctl -u labapp -b --no-pager | tail -20
# Fix the typo (e.g., pyton3 -> python3):
sudo vi /etc/systemd/system/labapp.service   # or use sed
sudo systemctl daemon-reload
sudo systemctl enable --now labapp.service

# Package management:
sudo dnf install -y tmux
rpm -q tmux
sudo dnf remove -y tmux

# Drop-in override (does NOT edit original file):
sudo systemctl edit labweb.service
# In editor, add:
#   [Service]
#   Restart=always
sudo systemctl daemon-reload
sudo systemctl restart labweb.service
# Creates: /etc/systemd/system/labweb.service.d/override.conf

# Report state:
ss -ltnp                         # Listening TCP ports
df -h                            # Disk usage
systemctl list-units --failed    # Failed units

# Bonus: Inspect a stopped VM's filesystem without booting:
virtctl guestfs <pvc-name> -n <ns>
```

---

## Part 4: Additional Practice Questions (from DO316 v4.16 Material)

These are extra exam-style tasks from the DO316 v4.16 course. They provide variety and cover the same objectives.

### Extra Q1: Operator + Node Maintenance Combo
> Deploy the Virtualization operator. Then find a node that has been cordoned (maintenance mode) and uncordon it to make it Ready and Schedulable.
> **Time: 10 min**
```bash
oc get nodes                             # Find the SchedulingDisabled node
oc adm uncordon <node-name>
oc get nodes                             # Confirm Ready
```

### Extra Q2: RBAC with Groups
> Create groups `leaders`, `developers`, `qa`. Add users to groups. Assign admin rights to leaders group on project, view rights to qa, VM edit to individual users.
> **Time: 10 min**
```bash
oc adm groups new leaders
oc adm groups add-users leaders suraj
oc adm policy add-role-to-group admin leaders -n banana
oc adm policy add-role-to-group view qa -n banana
oc adm policy add-role-to-user kubevirt.io:edit raja -n banana
```

### Extra Q3: VM from Template with Full Cloud-Init
> Create a VM from Red Hat template with specific: PVC URL, StorageClass, Block volume mode, cloud-init user/password/SSH key, yum repo setup, httpd install.
> **Time: 15 min**
```bash
# List available templates:
oc get template -n openshift -l template.kubevirt.io/type=vm | grep rhel9
oc process --parameters -n openshift rhel9-server-small
```

### Extra Q4: Multihomed VM with Two NICs
> Create a VM with pod network (masquerade) + bridge network (attached to NAD). Install and configure MariaDB inside. Create NodePort Service + Route.
> **Time: 20 min**

### Extra Q5: Move Disk Between VMs
> Move a disk from one VM to another. Hot-unplug from source, hot-plug to target with same settings.
> **Time: 10 min**
```bash
virtctl removevolume <source-vm> --volume-name=<disk> --persist -n <ns>
virtctl addvolume <target-vm> --volume-name=<disk> --serial=<s> --persist -n <ns>
```

### Extra Q6: Node Failure with HA Template
> Create a VM with node affinity (schedule only on specific workers) and eviction strategy LiveMigrate. Verify it auto-migrates on node failure.
> **Time: 10 min**

### Extra Q7: Import vSphere VM via OVA
> Download OVA, extract, convert VMDK to qcow2, upload as DataVolume, create VM with two networks (pod + secondary bridge).
> **Time: 20 min**

---

## Part 5: Command Quick-Reference by Topic

### How to Find ANY Command During the Exam

| What You Need | Discovery Command |
|:---|:---|
| VM creation flags | `virtctl create vm --help` |
| VM lifecycle (start/stop/etc) | `virtctl --help \| grep -iE "start\|stop\|restart\|console\|ssh"` |
| Any YAML field path | `oc explain <resource>.spec.path` |
| Available API resources | `oc api-resources \| grep -i <keyword>` |
| Available boot images | `oc get datasources -n openshift-virtualization-os-images` |
| Available templates | `oc get template -n openshift -l template.kubevirt.io/type=vm` |
| Instance types | `oc get virtualmachineclusterinstancetype` |
| Storage classes | `oc get sc` |
| Snapshot classes | `oc get volumesnapshotclass` |
| Cluster roles for VMs | `oc get clusterrole \| grep kubevirt` |
| NMState resources | `oc get nns,nncp,nnce` |
| OADP status | `oc get dpa,backupstoragelocation -n openshift-adp` |

### Critical Commands to Practice Until Automatic

```bash
# 1. VM Creation (fastest path)
virtctl create vm --name X --memory 4Gi --volume-containerdisk src:IMAGE \
  --cloud-init-user-data - <<'EOF' | oc apply -f -
#cloud-config
user: cloud-user
password: pass123
chpasswd: {expire: false}
EOF

# 2. VM Lifecycle
virtctl start/stop/restart/pause/unpause <vm> -n <ns>
virtctl console <vm> -n <ns>        # Ctrl+] to exit
virtctl ssh user@vmi/<vm> -n <ns>

# 3. Quick Patch (avoid oc edit)
oc patch vm <vm> -n <ns> --type merge -p '{"spec":{"runStrategy":"Always"}}'
oc patch pvc <pvc> -n <ns> --type merge -p '{"spec":{"resources":{"requests":{"storage":"8Gi"}}}}'

# 4. RBAC
oc adm policy add-role-to-user kubevirt.io:edit <user> -n <ns>
oc auth can-i <verb> <resource> -n <ns> --as=<user>

# 5. Services and Routes
virtctl expose vm <vm> --name <svc> --port 80 --target-port 8080 -n <ns>
oc create route edge <name> --service <svc> --hostname <host> --insecure-policy Redirect -n <ns>

# 6. Node Operations
oc adm cordon <node>
oc adm drain <node> --ignore-daemonsets --delete-emptydir-data --force
oc adm uncordon <node>
oc adm taint node <node> key=value:NoSchedule
oc adm taint node <node> key=value:NoSchedule-   # remove (trailing -)
oc label node <node> key=value
oc label node <node> key-                         # remove (trailing -)
```

---

## Part 6: Cloud-Init Cheat Sheet

Cloud-init is used in many tasks. Master this format:

```yaml
cloudInitNoCloud:
  userData: |
    #cloud-config
    user: cloud-user
    password: mypassword
    chpasswd: {expire: false}
    ssh_pwauth: true
    ssh_authorized_keys:
      - ssh-rsa AAAAB3... user@host
    hostname: my-vm
    packages: [httpd, mariadb-server]
    write_files:
      - path: /var/www/html/index.html
        content: "Hello World\n"
      - path: /etc/yum.repos.d/custom.repo
        content: |
          [custom]
          name=Custom Repo
          baseurl=http://repo.example.com/rhel9/
          enabled=1
          gpgcheck=0
    runcmd:
      - [systemctl, enable, --now, httpd]
      - [systemctl, enable, --now, mariadb]
```

For static IP on secondary NIC:
```yaml
  networkData: |
    ethernets:
      eth1:
        addresses: [192.168.150.11/24]
```

---

## Part 7: Exam Day Reminders

1. **Read every task fully** before typing. Partial credit exists.
2. **Don't spend more than 15 min stuck** on one task. Move on and come back.
3. **Verify your work** as you go: `oc get`, `virtctl console`, `oc get endpoints`.
4. **Use `oc explain`** instead of trying to remember YAML fields.
5. **Backup/Restore CRs go in `openshift-adp`** namespace, not the app namespace.
6. **VM must be stopped** before snapshot restore.
7. **Live migration needs RWX + Block** storage.
8. **`oc adm drain` needs three flags**: `--ignore-daemonsets --delete-emptydir-data --force`
9. **Routes are HTTP/HTTPS only**. SSH needs NodePort or LoadBalancer.
10. **`daemon-reload` after editing** systemd unit files.

---

## Part 8: Estimated Time Per Topic (for practice runs)

| # | Topic | First Attempt | Target Speed | Questions/Exercises |
|---|-------|:---:|:---:|:---:|
| 1 | Operator Install | 15 min | 8 min | 1 main + 1 extra |
| 2 | VM Access + RBAC | 25 min | 15 min | 1 main + 2 extras |
| 3 | Networking | 40 min | 25 min | 1 main + 3 extras |
| 4 | External Networks | 35 min | 20 min | 1 main + 1 extra |
| 5 | Storage | 35 min | 20 min | 1 main + 1 extra |
| 6 | OADP | 30 min | 20 min | 1 main + 1 extra |
| 7 | Templates/Cloud-Init | 30 min | 20 min | 1 main + 2 extras |
| 8 | Snapshots | 20 min | 15 min | 1 main |
| 9 | Migration/Import | 30 min | 20 min | 1 main + 1 extra |
| 10 | Cloning | 25 min | 15 min | 1 main |
| 11 | Live Migration | 30 min | 20 min | 1 main |
| 12 | Node Maintenance | 20 min | 15 min | 1 main |
| 13 | Load Balancing | 20 min | 15 min | 1 main + 1 extra |
| 14 | Health Probes | 25 min | 15 min | 1 main + 1 extra |
| 15 | Node Failure | 30 min | 20 min | 1 main + 1 extra |
| 16 | Guest Sysadmin | 20 min | 15 min | 1 main |
| **Total** | | **~7 hrs** | **~4 hrs** | **16 main + 17 extras** |

**Goal:** Practice until you can complete all 16 topics in under 4 hours total.

---

## Part 9: Practice Tracking Template

Copy this and update daily:

```
Day:  ___  Date: ___________

Topics practiced: ______________________
Time taken: ___ min (target: ___ min)

Objectives scored (1-5):
  1-Operator:     [ ]    9-Migration:      [ ]
  2-VM Access:    [ ]   10-Cloning:        [ ]
  3-Networking:   [ ]   11-Live Migration: [ ]
  4-Ext Networks: [ ]   12-Node Maint:     [ ]
  5-Storage:      [ ]   13-Load Balance:   [ ]
  6-OADP:         [ ]   14-Health Probes:  [ ]
  7-Templates:    [ ]   15-Node Failure:   [ ]
  8-Snapshots:    [ ]   16-Guest Admin:    [ ]

Mistakes made:
  1. ___________________________________
  2. ___________________________________
  3. ___________________________________

Tomorrow's focus: _________________________
```
