# EX316 Practice Questions & CLI-First Solutions

> **15-Day Exam Prep Guide** | Every question includes CLI help discovery steps so you never need to memorize commands.
>
> **Strategy for beginners**: On every question, start with `<command> --help | grep -i <keyword>`, then `<command> --help | grep <command-name>` for complete copy-paste examples, then `oc explain <resource.spec.field>` to find YAML paths. Build commands interactively, never from memory.
>
> **Companion file**: `EX316-COMPLETE-PRACTICE-GUIDE.md` has the same techniques in Part 1, plus the 15-day study schedule. Keep both in sync.

---

## How to Use This Guide

| Symbol | Meaning |
|--------|---------|
| **Discovery** | How to find the command using `--help` and `grep` |
| **Solution** | The actual commands to execute |
| **Verify** | How to confirm your work is correct |
| **Time** | Approximate time for a beginner to solve |

### The CLI Discovery Method (Use This on EVERY Question)

```
Step 1: Find the right command
  oc --help | grep -i <keyword>
  virtctl --help | grep -i <keyword>

Step 2: Find the right flags
  <command> --help | grep -iE "flag1|flag2|flag3"

Step 3: Get a COMPLETE example command -- grep the command's own name
  virtctl create vm --help | grep virtctl
  virtctl create vm --help | grep virtctl | grep memory

Step 4: Find the right YAML fields
  oc explain <resource>.spec.<path>
  oc explain vm.spec.template.spec.domain

Step 5: Find apiVersion + kind for a YAML file you must write by hand
  oc api-resources | grep -i <keyword>
```

#### Step 3 in detail: getting complete, copy-paste-ready commands

`grep -i memory` shows flag lines with no context. But every help page also has an
`Examples:` section of **complete working commands**, and every one of those lines starts
with the command's own name -- so grep for that:

```bash
virtctl create vm --help | grep virtctl              # ~25 full commands, ready to copy
virtctl create vm --help | grep virtctl | grep memory   # narrow it: just grep again
oc create secret generic --help | grep "oc create secret" | grep from-literal
```
Read left to right: *show the help -> keep the example lines -> keep the ones about memory.*

Want the `#` description line above each example too? Add `-B1` ("1 line **B**efore"):
```bash
virtctl create vm --help | grep -B1 memory
```
```
  # Create a manifest for a VirtualMachine with specified memory and an ephemeral containerdisk volume
  virtctl create vm --memory=1Gi --volume-containerdisk=src:my.registry/my-image:my-tag
```

If you forget all of it: `virtctl create vm --help | less`, then `/memory` + Enter to jump
to a match, `n` for the next, `q` to quit.

### When the question needs a FULL YAML file -- never type one from scratch

`oc explain` and `oc api-resources` do **not** write YAML for you. `explain` tells you where
*one field* nests; `api-resources` gives you the top two lines (`apiVersion:` and `kind:`).
Something else has to produce the file. Always these four steps:

> **1. Generate a skeleton -> 2. `oc explain` the extra field -> 3. edit -> 4. apply**

```bash
# 1. Generate. Use whichever source exists, in this order:

#    a) VMs -- virtctl writes the whole manifest; ">" saves it to a file
virtctl create vm --name=db --memory=4Gi \
  --volume-import=type:ds,src:openshift-virtualization-os-images/rhel9 > db.yaml

#    b) Common objects -- oc generates them with --dry-run=client -o yaml
oc create secret generic my-keys --from-literal=key1=abc --dry-run=client -o yaml > secret.yaml
oc create rolebinding bob-vm --role=vm-operator --user=bob --dry-run=client -o yaml
oc create role vm-operator --verb=get,list --resource=virtualmachines.kubevirt.io --dry-run=client -o yaml
oc create serviceaccount my-sa --dry-run=client -o yaml
oc expose vm/my-vm --port=22 --dry-run=client -o yaml

#    c) Copy something already running, then edit the copy
oc get vm existing-vm -o yaml > new-vm.yaml   # delete status: and uid/resourceVersion

#    d) Red Hat's shipped VM templates
oc process -n openshift rhel9-server-small -p NAME=myvm -o yaml > vm.yaml

# 2. Find the extra field the question asks for
oc explain vm.spec.template.spec --recursive | grep -i eviction
oc explain vm.spec.template.spec.evictionStrategy

# 3. Edit db.yaml, adding the field at the path explain just showed you

# 4. Validate against the real API without changing anything, then apply
oc apply -f db.yaml --dry-run=server
oc apply -f db.yaml
```

**No generator exists** for a few resources (NetworkPolicy, NodeNetworkConfigurationPolicy,
DataVolume, OADP Backup/Restore, VirtualMachineSnapshot). That is the one case where you
hand-write it, using Step 5 then Step 4:

```bash
oc api-resources | grep -i snapshot
#  -> virtualmachinesnapshots  snapshot.kubevirt.io/v1beta1  true  VirtualMachineSnapshot
oc explain virtualmachinesnapshot.spec
```
```yaml
apiVersion: snapshot.kubevirt.io/v1beta1   # from api-resources
kind: VirtualMachineSnapshot               # from api-resources
metadata:
  name: db-snap
  namespace: vm-project
spec:                                      # fields from oc explain
  source:
    apiGroup: kubevirt.io
    kind: VirtualMachine
    name: db
```

---

## Topic 1: OpenShift Basics (Users, Projects, Labels)

**Estimated total time: 25-35 minutes**

---

### Q1.1: Create Users with htpasswd (Time: 8 min)

**Task**: Create users `raja`, `suraj`, `punit`, and `rajan` with password `anishrana2001` using htpasswd identity provider.

#### Discovery:
```bash
# How do I find the htpasswd secret?
oc --help | grep -i secret
oc get secrets -n openshift-config

# How do I decode a secret?
oc extract --help | head -5

# How do I create htpasswd entries?
htpasswd --help 2>&1 | head -10
```

#### Solution:
```bash
# Step 1: Extract existing htpasswd file
oc -n openshift-config get secrets htpasswd-secret -o json \
  | jq -r '.data.htpasswd' | base64 --decode > /tmp/htpasswd.txt

# Step 2: Add users (use -b flag for batch mode with password on command line)
htpasswd -b /tmp/htpasswd.txt raja anishrana2001
htpasswd -b /tmp/htpasswd.txt suraj anishrana2001
htpasswd -b /tmp/htpasswd.txt punit anishrana2001
htpasswd -b /tmp/htpasswd.txt rajan anishrana2001

# Step 3: Replace the secret
oc -n openshift-config delete secrets htpasswd-secret
oc -n openshift-config create secret generic htpasswd-secret \
  --from-file htpasswd=/tmp/htpasswd.txt
```

#### Verify:
```bash
oc login -u raja -p anishrana2001 https://api.ocp4.example.com:6443
oc whoami
```

---

### Q1.2: Create Projects (Time: 3 min)

**Task**: Create projects named `banana`, `apple`, `kiwi`, and `mango`.

#### Discovery:
```bash
oc --help | grep -i project
oc new-project --help | head -5
```

#### Solution:
```bash
oc new-project banana
oc new-project apple
oc new-project kiwi
oc new-project mango
```

#### Verify:
```bash
oc get projects | grep -E "banana|apple|kiwi|mango"
```

---

### Q1.3: Create SSH Keys (Time: 3 min)

**Task**: Create an SSH key pair for user `student` at `/home/student/.ssh/lab_rsa`.

#### Discovery:
```bash
ssh-keygen --help 2>&1 | grep -iE "type|file"
```

#### Solution:
```bash
ssh-keygen -t rsa -f /home/student/.ssh/lab_rsa -N ""
```

#### Verify:
```bash
ls -la /home/student/.ssh/lab_rsa*
```

---

### Q1.4: Label Nodes (Time: 3 min)

**Task**: Add the label `datacenter=paris` on nodes `worker01` and `worker02`.

#### Discovery:
```bash
oc --help | grep -i label
oc label --help | head -10
```

#### Solution:
```bash
oc label nodes worker01 datacenter=paris
oc label nodes worker02 datacenter=paris
```

#### Verify:
```bash
oc get nodes --show-labels | grep datacenter
# or more precisely:
oc describe node worker01 | grep -A10 Labels | grep datacenter
```

---

## Topic 2: Install OpenShift Virtualization Operator

**Estimated total time: 10-15 minutes**

---

### Q2.1: Deploy OpenShift Virtualization Operator (Time: 10 min)

**Task**: Deploy the OpenShift Virtualization operator in the `openshift-cnv` namespace. Create a HyperConverged CR named `kubevirt-hyperconverged`.

#### Discovery:
```bash
# Find operator-related commands
oc --help | grep -i operator
oc get packagemanifest --help | head -5

# Check if operator namespace exists
oc get ns | grep cnv

# Find the channel name
oc get packagemanifest kubevirt-hyperconverged -n openshift-marketplace \
  -o jsonpath='{.status.defaultChannel}{"\n"}'
```

#### Solution (mostly via Web Console, but verify via CLI):
```bash
# This is typically done via OperatorHub in the web console:
# 1. Go to Operators -> OperatorHub
# 2. Search for "virtualization"
# 3. Install with defaults (namespace: openshift-cnv)
# 4. After install, click "Create HyperConverged"
# 5. Name it: kubevirt-hyperconverged

# Wait for it to be ready:
oc wait hco/kubevirt-hyperconverged -n openshift-cnv \
  --for=condition=Available --timeout=20m
```

#### Verify:
```bash
oc get csv -n openshift-cnv
oc get pods -n openshift-cnv
oc get hco kubevirt-hyperconverged -n openshift-cnv
```

---

## Topic 3: User Access & RBAC

**Estimated total time: 20-30 minutes**

---

### Q3.1: Create Groups and Assign Users (Time: 5 min)

**Task**: Create groups `leaders`, `developers`, `qa`. Add `suraj` to `leaders`, `raja` to `developers`, `punit` and `rajan` to `qa`.

#### Discovery:
```bash
# Find group commands
oc adm --help | grep -i group
oc adm groups --help
```

#### Solution:
```bash
oc adm groups new leaders
oc adm groups new developers
oc adm groups new qa
oc adm groups add-users leaders suraj
oc adm groups add-users developers raja
oc adm groups add-users qa punit rajan
```

#### Verify:
```bash
oc get groups
```

---

### Q3.2: Assign Roles to Groups and Users (Time: 10 min)

**Task**: For project `banana`:
- Group `leaders` gets admin rights
- Group `qa` gets view permission
- User `raja` can create and manage VMs (admin)
- User `suraj` can view VMs and start/stop/restart/pause them
- User `punit` can view VMs

#### Discovery:
```bash
# Find rolebinding commands
oc create rolebinding --help | head -15

# Find kubevirt-specific roles
oc get clusterrole | grep -i kubevirt

# Key roles to know:
# admin         = full project control
# edit           = create/modify resources
# view           = read-only
# kubevirt.io:admin = full VM management
# kubevirt.io:edit  = start/stop/restart/pause VMs
# kubevirt.io:view  = view VMs and metrics
```

#### Solution:
```bash
# Group roles
oc create rolebinding leaders-admin --clusterrole=admin --group=leaders -n banana
oc create rolebinding qa-view --clusterrole=view --group=qa -n banana

# User roles
oc create rolebinding raja-admin --clusterrole=admin --user=raja -n banana
oc create rolebinding suraj-view --clusterrole=view --user=suraj -n banana
oc create rolebinding suraj-vm-edit --clusterrole=kubevirt.io:edit --user=suraj -n banana
oc create rolebinding punit-view --clusterrole=view --user=punit -n banana
```

#### Verify:
```bash
oc get rolebinding -n banana
oc auth can-i create virtualmachines.kubevirt.io -n banana --as=raja
oc auth can-i update virtualmachines/start -n banana --as=suraj
oc auth can-i get virtualmachines -n banana --as=punit
```

---

### Q3.3: Assign Roles for Another Project (Time: 8 min)

**Task**: For project `apple`:
- Group `developers` gets admin rights
- Group `qa` gets edit permission
- User `suraj` can create and manage VMs
- User `raja` can view VMs and metrics
- User `punit` can start/stop/restart/pause VMs

#### Solution:
```bash
oc create rolebinding dev-admin --clusterrole=admin --group=developers -n apple
oc create rolebinding qa-edit --clusterrole=edit --group=qa -n apple
oc create rolebinding suraj-admin --clusterrole=admin --user=suraj -n apple
oc create rolebinding raja-view --clusterrole=view --user=raja -n apple
oc create rolebinding punit-vm-edit --clusterrole=kubevirt.io:edit --user=punit -n apple
```

---

## Topic 4: Create Virtual Machines

**Estimated total time: 25-35 minutes per VM**

---

### Q4.1: Create a VM from Template (Time: 25 min)

**Task**: Create VM `myvm-lan1` in `banana` project using Red Hat Enterprise Linux 9 VM template.
- PVC URL: `http://utility.lab.example.com:8080/openshift4/images/rhel9-helloworld.qcow2`
- StorageClass: `ocs-external-storagecluster-ceph-rbd-virtualization`
- PVC size: 30GiB, Volume mode: Block
- Workload: server, Flavor: small
- Cloud-init user: `raja` with password `anishrana2001`
- SSH key from `/home/student/.ssh/lab_rsa.pub`

#### Discovery:
```bash
# Find VM creation options
virtctl create vm --help | grep -iE "memory|volume|cloud-init|instancetype|ssh"

# Find available templates
oc get template -n openshift | grep -i rhel9

# Find available data sources
oc get datasource -n openshift-virtualization-os-images

# Find storage classes
oc get sc
```

#### Solution:
This is best done via the **Web Console** (the exam allows both CLI and GUI):
1. Login as `raja` -> Select project `banana`
2. Virtualization -> Catalog -> Select "Red Hat Enterprise Linux 9 VM"
3. Set name: `myvm-lan1`
4. Customize VirtualMachine:
   - **Disks**: Set boot source URL, StorageClass, size 30GiB
   - **Scripts**: Add cloud-init user `raja`/`anishrana2001`
   - **Scripts**: Add SSH authorized key from `/home/student/.ssh/lab_rsa.pub`
5. Click Create

#### Verify:
```bash
oc project banana
oc get vm,vmi
virtctl console myvm-lan1
# Login with raja/anishrana2001
# Or SSH:
virtctl ssh raja@myvm-lan1 --identity-file=/home/student/.ssh/lab_rsa
```

---

### Q4.2: Create a Multihomed VM with Two Network Interfaces (Time: 30 min)

**Task**: Create VM `mariadb-server` in `apple` project with 2 network interfaces:
- 1st NIC: `default` (pod network, masquerade, virtio)
- 2nd NIC: `nic-0` (attached to `apple/database-network`, bridge)

**Pre-requisite**: Install NMState operator and create NetworkAttachmentDefinition.

#### Discovery:
```bash
# Find NMState resources
oc get crd | grep -i nmstate
oc get nncp    # NodeNetworkConfigurationPolicy
oc get nnce    # NodeNetworkConfigurationEnactment

# Find network attachment definitions
oc get net-attach-def -n apple

# Find what fields go in a NNCP
oc explain nncp.spec.desiredState
```

#### Solution:
```bash
# Step 1: Label worker nodes for external network
oc label nodes worker01 external-network=true
oc label nodes worker02 external-network=true

# Step 2: Create NodeNetworkConfigurationPolicy (via console or YAML)
# Step 3: Create NetworkAttachmentDefinition in apple project (via console)
# Step 4: Create VM with 2 NICs via Web Console
#   - Login as suraj -> project apple
#   - Create VM from RHEL 9 template
#   - Add second network interface (nic-0, bridge, apple/database-network)
```

#### Verify:
```bash
oc project apple
oc get vm,vmi
virtctl console mariadb-server
# Inside VM: ip a   (should show eth0 and eth1)
```

---

## Topic 5: Networking & Network Policies

**Estimated total time: 20-30 minutes**

---

### Q5.1: Create a ClusterIP Service for a VM (Time: 8 min)

**Task**: Create a ClusterIP service allowing web traffic (port 80) to VM `myvm-lan1` in `banana` project.

#### Discovery:
```bash
# Find how to expose a VM
virtctl expose --help | head -20
virtctl expose --help | grep -iE "type|port|name"

# Or create service manually
oc create service clusterip --help | head -10

# Find VM labels to use as selector
oc get vmi myvm-lan1 --show-labels
```

#### Solution:
```bash
# Option A: Using virtctl (recommended)
virtctl expose vmi myvm-lan1 --name svc-web --type=ClusterIP --port 80 --target-port=80

# Option B: Manual service creation + edit selector
oc create service clusterip my-svc --tcp=80:80
# Then edit to set selector to match VM label:
oc edit service my-svc
# Change selector to: kubevirt.io/domain: myvm-lan1
```

#### Verify:
```bash
oc get svc,endpoints
# Endpoints should show the VM's IP
oc describe svc svc-web
```

---

### Q5.2: Create a Route (Time: 5 min)

**Task**: Create route `banana-web-route` to expose the service at `anishrana2001-la-banana.apps.ocp4.example.com`.

#### Discovery:
```bash
oc expose --help | grep -iE "hostname|route|service"
```

#### Solution:
```bash
oc expose service svc-web --name=banana-web-route \
  --hostname=anishrana2001-la-banana.apps.ocp4.example.com
```

#### Verify:
```bash
oc get routes
curl anishrana2001-la-banana.apps.ocp4.example.com
```

---

### Q5.3: Create a Network Policy (Time: 10 min)

**Task**: Create network policy `netpol-http` in `banana` project that:
- Only allows members of `banana` project to access VM on TCP port 80
- Other projects cannot reach the VM on port 80

#### Discovery:
```bash
# Find network policy fields
oc explain networkpolicy.spec
oc explain networkpolicy.spec.ingress.from
oc explain networkpolicy.spec.podSelector

# Find VM labels
oc get vmi myvm-lan1 --show-labels
# Find namespace labels
oc get namespace banana --show-labels
```

#### Solution:
```bash
cat <<'EOF' | oc apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: netpol-http
  namespace: banana
spec:
  podSelector:
    matchLabels:
      kubevirt.io/domain: myvm-lan1
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: banana
      ports:
        - protocol: TCP
          port: 80
EOF
```

#### Verify:
```bash
oc get netpol -n banana
oc describe netpol netpol-http -n banana

# Test from within banana project (should work):
oc run tester -n banana --image=registry.access.redhat.com/ubi9/ubi --restart=Never -- sleep infinity
oc exec -n banana tester -- curl -sm3 http://<VM_IP>:80

# Test from another project (should FAIL):
oc run tester -n default --image=registry.access.redhat.com/ubi9/ubi --restart=Never -- sleep infinity
oc exec -n default tester -- curl -sm3 http://<VM_IP>:80
```

---

### Q5.4: Cross-Project Network Policy (Time: 8 min)

**Task**: Create network policy `kiwi-access-netpol` in project `kiwi` that allows only requests from `banana` project on port 80.

#### Discovery:
```bash
# Find namespace labels
oc get ns banana --show-labels
# Key label: kubernetes.io/metadata.name=banana
```

#### Solution:
```bash
cat <<'EOF' | oc apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: kiwi-access-netpol
  namespace: kiwi
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: banana
      ports:
        - protocol: TCP
          port: 80
EOF
```

---

## Topic 6: VM Configuration (Inside the Guest)

**Estimated total time: 15-20 minutes per VM**

---

### Q6.1: Install httpd and Configure Web Server (Time: 15 min)

**Task**: On VM `myvm-lan1` in `banana`:
- Install httpd, enable it to survive reboot
- Download and place HTML file
- Set ServerName to `devops-wala.com`

#### Discovery:
```bash
# How to access VM console
virtctl --help | grep -i console
```

#### Solution:
```bash
# Step 1: Connect to VM
virtctl console myvm-lan1
# Login: raja / anishrana2001
sudo su -

# Step 2: Set up repo and install httpd
curl -o /etc/yum.repos.d/yum.repo-file.repo \
  https://raw.githubusercontent.com/anishrana2001/Openshift/refs/heads/main/DO316/yum.repo-file.repo
yum install -y httpd

# Step 3: Enable and start httpd
systemctl enable httpd
systemctl start httpd

# Step 4: Download HTML content
cd /var/www/html/
curl -o anish.html \
  https://raw.githubusercontent.com/anishrana2001/Openshift/refs/heads/main/DO316/anish.html

# Step 5: Set ServerName
# Edit /etc/httpd/conf/httpd.conf
# Uncomment and change: ServerName devops-wala.com:80
vi /etc/httpd/conf/httpd.conf

# Step 6: Verify and restart
httpd -t        # Check syntax
systemctl restart httpd
curl localhost/anish.html

# Exit VM: Ctrl+]
```

#### Verify:
```bash
# From outside the VM:
curl anishrana2001-la-banana.apps.ocp4.example.com/anish.html
```

---

### Q6.2: Install MariaDB on a VM (Time: 15 min)

**Task**: On VM `myvm-lan3` in `kiwi`:
- Install mariadb and php packages
- Enable mariadb service to survive reboot

#### Solution:
```bash
virtctl console myvm-lan3
# Login with credentials, sudo su -

curl -o /etc/yum.repos.d/yum.repo-file.repo \
  https://raw.githubusercontent.com/anishrana2001/Openshift/refs/heads/main/DO316/yum.repo-file.repo

yum install -y mariadb mariadb-server php
systemctl enable mariadb
systemctl start mariadb
systemctl status mariadb
# Exit: Ctrl+]
```

---

## Topic 7: Services & Load Balancing

**Estimated total time: 15-20 minutes**

---

### Q7.1: Create a NodePort Service (Time: 8 min)

**Task**: Create service `ex316-kiwi-svc` in `kiwi` project:
- Type: NodePort
- Pod Selector: `mydb=mariadb-kiwi`
- TCP port 22, NodePort 30022

#### Discovery:
```bash
oc create service nodeport --help | head -15
oc create service nodeport --help | grep -iE "tcp|node-port"
```

#### Solution:
```bash
# Step 1: Add label to VMs
oc label vmi web1 mydb=mariadb-kiwi -n kiwi
oc label vmi web2 mydb=mariadb-kiwi -n kiwi
# (Also add to VM spec so it persists across restarts)
oc patch vm web1 -n kiwi --type='json' \
  -p='[{"op":"add","path":"/spec/template/metadata/labels/mydb","value":"mariadb-kiwi"}]'
oc patch vm web2 -n kiwi --type='json' \
  -p='[{"op":"add","path":"/spec/template/metadata/labels/mydb","value":"mariadb-kiwi"}]'

# Step 2: Create the service
oc create service nodeport ex316-kiwi-svc --tcp=22:22 --node-port=30022 -n kiwi

# Step 3: Edit selector to match VM label
oc edit service ex316-kiwi-svc -n kiwi
# Change selector to: mydb: mariadb-kiwi
```

#### Verify:
```bash
oc describe service ex316-kiwi-svc -n kiwi
# Check Endpoints shows VM IPs
oc get endpoints ex316-kiwi-svc -n kiwi
```

---

### Q7.2: Expose Service with Route and Custom Hostname (Time: 5 min)

**Task**: Create route `web-route` at `anishrana2001-lb.apps.ocp4.example.com`.

#### Discovery:
```bash
oc expose --help | grep -i hostname
oc create route --help
```

#### Solution:
```bash
oc expose service ex316-kiwi-svc --name=web-route \
  --hostname=anishrana2001-lb.apps.ocp4.example.com -n kiwi
```

#### Verify:
```bash
oc get routes -n kiwi
telnet anishrana2001-lb.apps.ocp4.example.com 22
```

---

### Q7.3: Create an Edge TLS Route (Time: 5 min)

**Task**: Create an edge-terminated TLS route with a custom hostname.

#### Discovery:
```bash
oc create route edge --help | head -15
```

#### Solution:
```bash
oc create route edge front --service front \
  --hostname front-review.apps.ocp4.example.com \
  --insecure-policy=Redirect -n <namespace>
```

---

## Topic 8: VM Templates

**Estimated total time: 20-30 minutes**

---

### Q8.1: Create a Custom VM Template (Time: 25 min)

**Task**: Create template `tmprhl9small` in `mango` project:
- Clone of built-in `rhel9-server-small` template
- 1 CPU, 2Gi RAM, 10Gi disk
- Disk source: `http://utility.lab.example.com:8080/openshift4/images/rhel9-helloworld.qcow2`
- StorageClass: `ocs-external-storagecluster-ceph-rbd-virtualization`
- Cloud-init user: `rahul` with password `anishrana2001`
- SSH key for passwordless access

#### Discovery:
```bash
# Find existing templates
oc get template -n openshift | grep -i rhel9

# Export a template to use as base
oc get template rhel9-server-small -n openshift -o yaml > /tmp/my-template.yaml

# Find template parameters
oc process --parameters -n openshift rhel9-server-small
```

#### Solution:
```bash
# Step 1: Export the base template
oc get template rhel9-server-small -n openshift -o yaml > /tmp/tmprhl9small.yaml

# Step 2: Edit the template
# Change:
#   - metadata.name: tmprhl9small
#   - metadata.namespace: mango
#   - Remove resourceVersion, uid, creationTimestamp
#   - Set CPU cores: 1, memory: 2Gi
#   - Set disk source URL
#   - Set storageClassName
#   - Set storage size: 10Gi
#   - Add cloud-init with user rahul
#   - Add SSH key via accessCredentials
vi /tmp/tmprhl9small.yaml

# Step 3: Apply
oc apply -f /tmp/tmprhl9small.yaml -n mango

# Step 4: Create VM from template
oc process -n mango tmprhl9small -p NAME=database-kiwi | oc apply -n mango -f -
```

#### Verify:
```bash
oc get template -n mango
oc get vm -n mango
```

---

### Q8.2: Create VMs from a Template (Time: 10 min)

**Task**: Using template `tmprhl9small`, create VMs `web1` and `web2` in project `mango`.

#### Discovery:
```bash
oc process --help | head -10
oc process --parameters -n mango tmprhl9small
```

#### Solution:
```bash
oc process -n mango tmprhl9small -p NAME=web1 | oc apply -n mango -f -
oc process -n mango tmprhl9small -p NAME=web2 | oc apply -n mango -f -
virtctl start web1 -n mango
virtctl start web2 -n mango
```

#### Verify:
```bash
oc get vm,vmi -n mango
```

---

## Topic 9: Health Probes (Liveness & Readiness)

**Estimated total time: 15-20 minutes**

---

### Q9.1: Configure a Liveness Probe (Time: 15 min)

**Task**: Configure liveness probe for VM `mariadb-server` in `apple` project:
- TCP port 3306
- initialDelaySeconds: 100
- periodSeconds: 5

#### Discovery:
```bash
# Find probe-related fields on a VM
oc explain vm.spec.template.spec --recursive | grep -i probe

# Use a dummy deployment to generate probe YAML
oc set probe --help | grep -iE "tcp|liveness|initial|period"
```

#### Solution:
```bash
# Step 1: Create a dummy deployment to discover probe YAML format
oc create deployment test --image=nginx -n apple
oc set probe deployment/test --liveness --open-tcp=3306 \
  --initial-delay-seconds=100 --period-seconds=5 -n apple

# Step 2: Extract the probe YAML
oc get deployment test -n apple -o yaml | grep -iA 10 liveness
#   livenessProbe:
#     failureThreshold: 3
#     initialDelaySeconds: 100
#     periodSeconds: 5
#     successThreshold: 1
#     tcpSocket:
#       port: 3306
#     timeoutSeconds: 1

# Step 3: Create a patch file
cat > /tmp/liveness.yaml << 'EOF'
spec:
  template:
    spec:
        livenessProbe:
          failureThreshold: 3
          initialDelaySeconds: 100
          periodSeconds: 5
          successThreshold: 1
          tcpSocket:
            port: 3306
          timeoutSeconds: 1
EOF

# Step 4: Patch the VM
oc patch vm/mariadb-server --type=merge --patch-file=/tmp/liveness.yaml -n apple

# Step 5: Restart VM to apply
virtctl restart mariadb-server -n apple

# Step 6: Cleanup
oc delete deployment test -n apple
```

#### Verify:
```bash
oc get vm mariadb-server -n apple -o yaml | grep -iA 10 liveness
oc get vmi mariadb-server -n apple -o yaml | grep -iA 10 liveness
```

---

### Q9.2: Configure a Readiness Probe (Time: 10 min)

**Task**: Configure readiness probe for a VM with HTTP GET check:
- Path: `/health`, Port: 80
- initialDelaySeconds: 10, periodSeconds: 5, failureThreshold: 2

#### Discovery:
```bash
oc set probe --help | grep -i get-url
oc explain vm.spec.template.spec.readinessProbe
```

#### Solution:
```bash
cat > /tmp/readiness.yaml << 'EOF'
spec:
  template:
    spec:
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
          successThreshold: 1
          timeoutSeconds: 2
          failureThreshold: 2
EOF

oc patch vm/<vm-name> --type=merge --patch-file=/tmp/readiness.yaml -n <namespace>
virtctl restart <vm-name> -n <namespace>
```

---

## Topic 10: VM Snapshots

**Estimated total time: 10-15 minutes**

---

### Q10.1: Create a VM Snapshot (Time: 10 min)

**Task**: Create volume snapshot `web2-snap-maria` of VM `web2` in project `kiwi`.

#### Discovery:
```bash
# Find snapshot-related resources
oc api-resources | grep -i snapshot

# Check VolumeSnapshotClass exists
oc get volumesnapshotclass

# Find the right YAML fields
oc explain virtualmachinesnapshot.spec
```

#### Solution:
```bash
# Ensure VM is running and accessible first
oc get vm web2 -n kiwi
virtctl ssh <user>@web2 -n kiwi   # verify it works

# Create snapshot via Web Console:
# Virtualization -> VirtualMachines -> web2 -> Snapshots -> Take Snapshot
# Name: web2-snap-maria

# OR via CLI YAML:
cat <<'EOF' | oc apply -n kiwi -f -
apiVersion: snapshot.kubevirt.io/v1beta1
kind: VirtualMachineSnapshot
metadata:
  name: web2-snap-maria
  namespace: kiwi
spec:
  source:
    apiGroup: kubevirt.io
    kind: VirtualMachine
    name: web2
EOF
```

#### Verify:
```bash
oc get vmsnapshot -n kiwi
oc get vmsnapshot web2-snap-maria -n kiwi -o jsonpath='{.status.readyToUse}{"\n"}'
```

---

## Topic 11: VM Cloning

**Estimated total time: 10-15 minutes**

---

### Q11.1: Clone a Root Disk Using DataVolume (Time: 10 min)

**Task**: Clone the root disk of VM `web1` in project `kiwi` as `web1-copy` using DataVolumes.

#### Discovery:
```bash
# Find the PVC name of the VM's root disk
oc get vm web1 -n kiwi -o yaml | grep -A5 dataVolume
oc get pvc -n kiwi

# Find DataVolume spec fields
oc explain datavolume.spec.source.pvc

# Find the storage class of the original PVC
oc get pvc <pvc-name> -n kiwi -o jsonpath='{.spec.storageClassName}{"\n"}'
oc get pvc <pvc-name> -n kiwi -o jsonpath='{.spec.resources.requests.storage}{"\n"}'
```

#### Solution:
```bash
# Get info about the source PVC
oc get pvc -n kiwi
# Note the PVC name (usually same as VM name: web1)

cat <<'EOF' | oc apply -n kiwi -f -
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: web1-copy
  namespace: kiwi
spec:
  source:
    pvc:
      namespace: kiwi
      name: web1
  storage:
    resources:
      requests:
        storage: 11Gi
    storageClassName: ocs-external-storagecluster-ceph-rbd-virtualization
EOF
```

#### Verify:
```bash
oc get dv,pvc -n kiwi
oc get dv web1-copy -n kiwi
# Wait for PHASE: Succeeded
```

---

### Q11.2: Clone a VM (Time: 5 min)

**Task**: Create a clone of VM `myvm-lan3` named `myvm-lan3-copy` in project `kiwi`.

#### Discovery:
```bash
oc api-resources | grep -i clone
oc explain virtualmachineclone.spec
```

#### Solution (via Web Console):
```
Virtualization -> VirtualMachines -> myvm-lan3 -> Actions -> Clone
Name: myvm-lan3-copy
```

#### Verify:
```bash
oc get vm -n kiwi
oc get vmclone -n kiwi
```

---

## Topic 12: VM Migration & Node Affinity

**Estimated total time: 15-20 minutes**

---

### Q12.1: Configure VM to Migrate Between Specific Nodes (Time: 15 min)

**Task**: Configure VM `mariadb-server` in `apple` to:
- Migrate only between nodes with label `datacenter: paris`
- Not migrate to any other nodes

#### Discovery:
```bash
# Find scheduling fields on VM
oc explain vm.spec.template.spec.nodeSelector
oc explain vm.spec.template.spec.affinity

# Check which nodes have the label
oc get nodes -l datacenter=paris
```

#### Solution:
```bash
# Via Web Console:
# 1. Go to VM -> Configuration -> Scheduling
# 2. Confirm evictionStrategy is LiveMigrate
# 3. Add Node Selector: datacenter = paris

# Via CLI:
oc patch vm mariadb-server -n apple --type merge -p '{
  "spec": {
    "template": {
      "spec": {
        "nodeSelector": {
          "datacenter": "paris"
        },
        "evictionStrategy": "LiveMigrate"
      }
    }
  }
}'

virtctl restart mariadb-server -n apple
```

#### Verify:
```bash
# Cordon one worker, restart VM, check it moves to the other
oc get vmi mariadb-server -n apple  # note which node
oc adm cordon worker02
virtctl restart mariadb-server -n apple
oc get vmi mariadb-server -n apple  # should be on worker01
oc adm uncordon worker02
```

---

### Q12.2: Trigger Live Migration (Time: 5 min)

**Task**: Live-migrate a VM from one node to another.

#### Discovery:
```bash
virtctl --help | grep -i migrat
```

#### Solution:
```bash
# Check current node
oc get vmi mariadb-server -n apple -o wide

# Trigger migration
virtctl migrate mariadb-server -n apple

# Watch migration
oc get vmim -n apple -w
```

#### Verify:
```bash
oc get vmi mariadb-server -n apple
# Node should have changed
```

---

## Topic 13: Node Maintenance

**Estimated total time: 5-10 minutes**

---

### Q13.1: Remove Node from Maintenance Mode (Time: 5 min)

**Task**: A node is in SchedulingDisabled state. Bring it back to Ready.

#### Discovery:
```bash
oc adm --help | grep -iE "cordon|uncordon|drain"
```

#### Solution:
```bash
# Step 1: Find the node in maintenance
oc get nodes
# Look for: Ready,SchedulingDisabled

# Step 2: Uncordon it
oc adm uncordon worker01
```

#### Verify:
```bash
oc get nodes
# Should show: Ready (without SchedulingDisabled)
```

---

### Q13.2: Drain a Node (Time: 5 min)

**Task**: Safely drain a node running VMs for maintenance.

#### Discovery:
```bash
oc adm drain --help | grep -iE "ignore|delete|force|timeout"
```

#### Solution:
```bash
oc adm drain worker01 --ignore-daemonsets --delete-emptydir-data --force --timeout=10m
```

---

## Topic 14: Prepare for Node Failure

**Estimated total time: 15-20 minutes**

---

### Q14.1: Configure VM for High Availability (Time: 15 min)

**Task**: Create VM `ha-node-vm1` from template `ha-node-template` in `ha-node` project:
- Schedule on either master01 or master02 only
- Auto-restart on the other node if one fails

#### Discovery:
```bash
# Find run strategy options
oc explain vm.spec.runStrategy

# Find eviction strategy
oc explain vm.spec.template.spec.evictionStrategy

# Find node selector fields
oc explain vm.spec.template.spec.nodeSelector
```

#### Solution:
```bash
# Step 1: Label the target nodes
oc label nodes master01 ha-node=true
oc label nodes master02 ha-node=true

# Step 2: Create VM from template
oc process -n ha-node ha-node-template -p NAME=ha-node-vm1 | oc apply -n ha-node -f -

# Step 3: Configure scheduling
oc patch vm ha-node-vm1 -n ha-node --type merge -p '{
  "spec": {
    "runStrategy": "RerunOnFailure",
    "template": {
      "spec": {
        "nodeSelector": {
          "ha-node": "true"
        },
        "evictionStrategy": "LiveMigrate"
      }
    }
  }
}'

# Step 4: Start the VM
virtctl start ha-node-vm1 -n ha-node
```

#### Verify:
```bash
oc get vm ha-node-vm1 -n ha-node -o yaml | grep -E "runStrategy|evictionStrategy|nodeSelector" -A2
oc get vmi ha-node-vm1 -n ha-node   # should be on master01 or master02
```

---

## Topic 15: Storage Management

**Estimated total time: 15-20 minutes**

---

### Q15.1: Hot-plug a Disk to a Running VM (Time: 10 min)

**Task**: Add a persistent disk to a running VM.

#### Discovery:
```bash
virtctl addvolume --help
virtctl addvolume --help | grep -iE "persist|serial|volume"
```

#### Solution:
```bash
# Create a blank DataVolume first
cat <<'EOF' | oc apply -n <ns> -f -
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: extra-disk
spec:
  source:
    blank: {}
  storage:
    resources:
      requests:
        storage: 5Gi
    storageClassName: ocs-external-storagecluster-ceph-rbd-virtualization
EOF

# Wait for DV to be ready
oc get dv extra-disk -n <ns> -w

# Hot-plug the disk
virtctl addvolume <vm-name> --volume-name=extra-disk --serial=DISK1 --persist -n <ns>
```

#### Verify (inside guest):
```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,SERIAL
# Should see a new disk with serial DISK1
```

---

### Q15.2: Format and Mount a Disk Inside a VM (Time: 8 min)

**Task**: Format a new disk as XFS, mount at `/var/www/html`, make it persistent.

#### Solution (inside the guest VM):
```bash
# Find the new disk
lsblk

# Format it
sudo mkfs.xfs /dev/vdb

# Create mount point and mount
sudo mkdir -p /var/www/html
sudo mount /dev/vdb /var/www/html

# Make it persistent in fstab
sudo blkid /dev/vdb   # copy the UUID
echo "UUID=<uuid-from-above>  /var/www/html  xfs  defaults  0 0" | sudo tee -a /etc/fstab

# Verify
df -h /var/www/html
```

---

## Topic 16: OADP Backup & Restore

**Estimated total time: 30-40 minutes**

---

### Q16.1: Install OADP and Create ObjectBucketClaim (Time: 15 min)

**Task**: Install OADP operator and create ObjectBucketClaim named `backup` in `openshift-adp`.

#### Discovery:
```bash
oc get packagemanifest -n openshift-marketplace | grep -i oadp
oc explain objectbucketclaim.spec
```

#### Solution:
```bash
# Step 1: Install OADP via OperatorHub (Web Console)
# Operators -> OperatorHub -> Search "OADP" -> Install

# Step 2: Create ObjectBucketClaim
cat <<'EOF' | oc apply -f -
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: backup
  namespace: openshift-adp
spec:
  storageClassName: openshift-storage.noobaa.io
  generateBucketName: backup
EOF

# Step 3: Wait for it to bind
oc get obc -n openshift-adp

# Step 4: Extract bucket info
oc extract --to=- cm/backup -n openshift-adp
oc extract --to=- secret/backup -n openshift-adp

# Step 5: Get CA cert
oc get cm/openshift-service-ca.crt -n openshift-adp \
  -o jsonpath='{.data.service-ca\.crt}' | base64 -w0; echo

# Step 6: Create cloud credentials secret
cat > /tmp/cloud-credentials << 'EOF'
[default]
aws_access_key_id=<ACCESS_KEY_FROM_STEP_4>
aws_secret_access_key=<SECRET_KEY_FROM_STEP_4>
EOF

oc create secret generic cloud-credentials -n openshift-adp \
  --from-file cloud=/tmp/cloud-credentials

# Step 7: Label VolumeSnapshotClasses
oc label volumesnapshotclass velero.io/csi-volumesnapshot-class=true --all

# Step 8: Create DataProtectionApplication (edit bucket name and caCert)
cat <<'EOF' | oc apply -f -
apiVersion: oadp.openshift.io/v1alpha1
kind: DataProtectionApplication
metadata:
  name: oadp-backup
  namespace: openshift-adp
spec:
  configuration:
    nodeAgent:
      enable: true
      uploaderType: kopia
    velero:
      defaultPlugins:
        - aws
        - openshift
        - csi
      defaultSnapshotMoveData: true
  backupLocations:
    - velero:
        config:
          profile: "default"
          region: "us-east-1"
          s3Url: https://s3.openshift-storage.svc
          s3ForcePathStyle: "true"
          insecureSkipTLSVerify: "true"
        provider: aws
        default: true
        credential:
          key: cloud
          name: cloud-credentials
        objectStorage:
          bucket: <BUCKET_NAME_FROM_STEP_4>
          prefix: oadp
          caCert: <BASE64_CA_CERT_FROM_STEP_5>
EOF
```

#### Verify:
```bash
oc get dpa -n openshift-adp
oc get backupstoragelocation -n openshift-adp
# Should show: Phase: Available
```

---

### Q16.2: Create a Backup and Restore (Time: 15 min)

**Task**: Backup namespace `database` and restore to `database-crash`.

#### Solution:
```bash
# Create backup
cat <<'EOF' | oc apply -f -
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: db-manual
  namespace: openshift-adp
spec:
  includedNamespaces:
  - database
  includedResources:
  - namespace
  - deployments
  - configmaps
  - secrets
  - pvc
  - pv
  - services
EOF

# Check backup status
alias velero='oc -n openshift-adp exec deployment/velero -c velero -it -- ./velero'
velero get backup db-manual

# Create restore to different namespace
cat <<'EOF' | oc apply -f -
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: db-crash
  namespace: openshift-adp
spec:
  backupName: db-manual
  namespaceMapping:
    database: database-crash
EOF
```

#### Verify:
```bash
velero get restore db-crash
oc get all -n database-crash
```

---

## Topic 17: Import VMs from vSphere/OVA

**Estimated total time: 20-30 minutes**

---

### Q17.1: Import a VM Using MTV Operator (Time: 25 min)

**Task**: Import VM `rhel9-web` from OVA into `vms-import` project.

#### Discovery:
```bash
# Check MTV operator
oc get pods -n openshift-mtv
oc get provider,plan,migration -n openshift-mtv
```

#### Solution:
```bash
# Step 1: Install MTV operator via OperatorHub
# Search "Migration Toolkit for Virtualization"
# Install and create ForkliftController

# Step 2: Create provider, network map, storage map, and plan
# (Mostly via Web Console: Migration -> Providers -> Add Provider)

# Step 3: Start migration
# Migration -> Plans -> Start
```

#### Verify:
```bash
oc get vm -n vms-import
virtctl start rhel9-web -n vms-import
oc get vmi -n vms-import
```

---

## Quick Reference: CLI Help Discovery Cheat Sheet

### Finding the Right Command

| What You Want | Discovery Command |
|:---|:---|
| **Any oc subcommand** | `oc --help \| grep -i <keyword>` |
| **Any virtctl subcommand** | `virtctl --help \| grep -i <keyword>` |
| **oc adm subcommands** | `oc adm --help \| grep -i <keyword>` |
| **Available API resources** | `oc api-resources \| grep -i <keyword>` |
| **YAML field structure** | `oc explain <resource>.spec.<path>` |
| **All fields recursively** | `oc explain <resource>.spec --recursive` |
| **ClusterRoles for kubevirt** | `oc get clusterrole \| grep -i kubevirt` |
| **Available templates** | `oc get template -n openshift \| grep -i <os>` |
| **Storage classes** | `oc get sc` |
| **DataSources (golden images)** | `oc get datasource -n openshift-virtualization-os-images` |

### Finding the Right Flags

| What You Want | Discovery Command |
|:---|:---|
| **VM creation flags** | `virtctl create vm --help \| grep -iE "memory\|volume\|cloud-init"` |
| **VM lifecycle** | `virtctl --help \| grep -iE "start\|stop\|restart\|console\|ssh"` |
| **Expose/service flags** | `virtctl expose --help \| grep -iE "type\|port\|name"` |
| **Probe flags** | `oc set probe --help \| grep -iE "tcp\|liveness\|readiness"` |
| **Role creation** | `oc create rolebinding --help \| head -15` |
| **Secret creation** | `oc create secret generic --help \| grep -i from-file` |

### Finding YAML Paths

| What You Need | oc explain Path |
|:---|:---|
| **VM domain (CPU, memory)** | `oc explain vm.spec.template.spec.domain` |
| **VM resources** | `oc explain vm.spec.template.spec.domain.resources` |
| **VM disks** | `oc explain vm.spec.template.spec.domain.devices.disks` |
| **VM networks** | `oc explain vm.spec.template.spec.networks` |
| **VM probes** | `oc explain vm.spec.template.spec.readinessProbe` |
| **VM scheduling** | `oc explain vm.spec.template.spec.nodeSelector` |
| **VM affinity** | `oc explain vm.spec.template.spec.affinity` |
| **VM eviction** | `oc explain vm.spec.template.spec.evictionStrategy` |
| **DataVolume storage** | `oc explain datavolume.spec.storage` |
| **NetworkPolicy rules** | `oc explain networkpolicy.spec.ingress.from` |
| **NNCP desired state** | `oc explain nncp.spec.desiredState` |

---

## 15-Day Study Schedule

### Week 1: Learn Each Topic (Days 1-7)

| Day | Topics | Questions to Practice | Time |
|-----|--------|----------------------|------|
| **Day 1** | Basics + Operator | Q1.1-Q1.4, Q2.1 | 60 min |
| **Day 2** | RBAC & Users | Q3.1-Q3.3 | 60 min |
| **Day 3** | Create VMs | Q4.1-Q4.2 | 90 min |
| **Day 4** | VM Config (Guest) | Q6.1-Q6.2 | 60 min |
| **Day 5** | Networking & NetPol | Q5.1-Q5.4 | 60 min |
| **Day 6** | Services & Routes | Q7.1-Q7.3 | 45 min |
| **Day 7** | Templates + Probes | Q8.1-Q8.2, Q9.1-Q9.2 | 90 min |

### Week 2: Deep Practice (Days 8-14)

| Day | Topics | Questions to Practice | Time |
|-----|--------|----------------------|------|
| **Day 8** | Snapshots + Cloning | Q10.1, Q11.1-Q11.2 | 60 min |
| **Day 9** | Migration + Maintenance | Q12.1-Q12.2, Q13.1-Q13.2 | 60 min |
| **Day 10** | Node Failure + Storage | Q14.1, Q15.1-Q15.2 | 60 min |
| **Day 11** | OADP + OVA Import | Q16.1-Q16.2, Q17.1 | 90 min |
| **Day 12** | **FULL MOCK**: Do ALL questions end-to-end, timed | All | 4 hrs |
| **Day 13** | Review weak topics, redo failed questions | Weak areas | 90 min |
| **Day 14** | **2nd MOCK**: Speed run all questions | All | 3.5 hrs |

### Day 15: Exam Day

- Light review only: skim the Quick Reference tables above
- **Do NOT cram** new material
- Remember: read every task fully before typing anything

---

## Critical Commands to Practice Until Automatic

These are the 20 commands you will use most frequently. Practice until they require zero thought:

```bash
# 1. Login
oc login -u admin -p redhatocp https://api.ocp4.example.com:6443

# 2. Switch project
oc project <name>

# 3. Create project
oc new-project <name>

# 4. Check VM status
oc get vm,vmi -n <ns>

# 5. Start/stop/restart VM
virtctl start <vm> -n <ns>
virtctl stop <vm> -n <ns>
virtctl restart <vm> -n <ns>

# 6. Access VM console
virtctl console <vm> -n <ns>          # Exit: Ctrl+]

# 7. SSH into VM
virtctl ssh <user>@<vm> -n <ns>

# 8. Create rolebinding
oc create rolebinding <name> --clusterrole=<role> --user=<user> -n <ns>

# 9. Create service
oc create service clusterip <name> --tcp=<port>:<port>
oc create service nodeport <name> --tcp=<port>:<port> --node-port=<nodeport>

# 10. Expose service as route
oc expose service <svc> --name=<route> --hostname=<hostname>

# 11. Patch a VM
oc patch vm <vm> --type merge -p '<json>' -n <ns>
oc patch vm <vm> --type merge --patch-file=<file> -n <ns>

# 12. Find kubevirt roles
oc get clusterrole | grep kubevirt

# 13. Label resources
oc label nodes <node> <key>=<value>

# 14. Get VM labels
oc get vmi <vm> --show-labels -n <ns>

# 15. Expose VM as service (via virtctl)
virtctl expose vmi <vm> --name <svc> --port <port> --target-port <port> -n <ns>

# 16. Check endpoints
oc get svc,endpoints -n <ns>

# 17. Cordon/uncordon nodes
oc adm cordon <node>
oc adm uncordon <node>

# 18. Get DataVolumes and PVCs
oc get dv,pvc -n <ns>

# 19. Trigger live migration
virtctl migrate <vm> -n <ns>

# 20. Check auth permissions
oc auth can-i <verb> <resource> -n <ns> --as=<user>
```

---

## Common Pitfalls & Exam Tips

1. **Always restart the VM** after patching probes, nodeSelector, or evictionStrategy: `virtctl restart <vm>`
2. **Service selector must match VM labels** - check with `oc get vmi <vm> --show-labels`
3. **Edit the VM (not VMI)** for persistent changes - VMI is the running instance
4. **Cloud-init changes require VM recreation** - they apply only at first boot
5. **`systemctl enable` vs `systemctl start`** - enable makes it survive reboot, start runs it now; use both
6. **DataVolume clone size** should be the source PVC size + 1Gi
7. **Network policy**: `podSelector: {}` means ALL pods in the namespace
8. **runStrategy: RerunOnFailure** is needed for auto-restart on node failure
9. **evictionStrategy: LiveMigrate** is needed for graceful migration during drain
10. **Labels on VM spec** (under `/spec/template/metadata/labels/`) persist across restarts; labels on VMI don't
