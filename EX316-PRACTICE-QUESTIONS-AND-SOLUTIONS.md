# EX316 Practice Questions & CLI-First Solutions

> **15-Day Exam Prep Guide** | Every question includes CLI help discovery steps so you never need to memorize commands.
>
> **Strategy for beginners**: On every question, start with `<command> --help | grep -i <keyword>`, then `<command> --help | grep <command-name>` for complete copy-paste examples, then `oc explain <resource.spec.field>` to find YAML paths. Build commands interactively, never from memory.
>
> **Companion file**: `EX316-COMPLETE-PRACTICE-GUIDE.md` has the same techniques in Part 1, plus the 15-day study schedule. Keep both in sync.
>
> **Validator**: `ex316-validate.sh` -- copy it to a machine with cluster access and run it to check every command, flag, field path and manifest in these guides against the live cluster. It is read-only (dry-run only; nothing is created, changed or deleted).

---

## How to Use This Guide

| Symbol | Meaning |
|--------|---------|
| **Discovery** | How to find the command using `--help` and `grep` |
| **Solution** | The actual commands to execute |
| **Verify** | How to confirm your work is correct |
| **Troubleshoot & Reset** | At the end of each topic: what breaks, the fast checks, and the exact commands to wipe and start over |
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

## The 3-Minute Rule: Troubleshoot, Then Wipe

**The rule:** when something does not work, start a timer. Spend **at most 3 minutes**
diagnosing. If it is not fixed by then, **delete it and redo it from scratch.** Recreating
most resources takes under a minute; chasing a broken one can eat 20 minutes you do not have.

### First: is it broken, or just slow?

Some things are **slow by nature**. Deleting these makes it worse, not better -- let them run
and watch them:

| Thing | Normal wait | Watch it with |
|:---|:---|:---|
| Operator install / HyperConverged | 10-20 min | `oc get csv,pods -n openshift-cnv -w` |
| DataVolume import from URL | 2-15 min (image size) | `oc get dv -n <ns> -w` |
| DataVolume clone | 2-10 min | `oc get dv -n <ns> -w` |
| Auth operator after secret change | 1-3 min | `oc get co authentication -w` |
| VM first boot | 1-3 min | `oc get vmi -n <ns> -w` |
| OADP backup / restore | 5-20 min | `oc get backup,restore -n openshift-adp -w` |

If it is in the table and the status is still *progressing/importing*, **wait**. The 3-minute
rule starts only once it is clearly **stuck or failed** (phase `Failed`, `Error`,
`CrashLoopBackOff`, `Pending` for minutes, or no change at all).

### The 60-second triage (works for ANY resource)

Run these three, in this order. The answer is in one of them more than 90% of the time:

```bash
# 1. Events -- by far the most useful command in OpenShift
oc get events -n <namespace> --sort-by=.lastTimestamp | tail -20

# 2. Describe the thing -- Conditions and Events are at the BOTTOM of the output
oc describe <kind>/<name> -n <namespace> | tail -30

# 3. If a pod is involved, read its logs
oc get pods -n <namespace>
oc logs <pod-name> -n <namespace>
```

### The universal wipe

```bash
# Normal delete
oc delete <kind> <name> -n <namespace>

# Stuck in "Terminating"? Force it
oc delete <kind> <name> -n <namespace> --force --grace-period=0

# STILL stuck? A finalizer is holding it. Strip the finalizer
oc patch <kind> <name> -n <namespace> --type=merge -p '{"metadata":{"finalizers":null}}'

# Nuclear option for one task's project (slow -- 1-2 min to fully delete)
oc delete project <name>
oc get project <name>          # repeat until "NotFound"
oc new-project <name>
```

> **Before you wipe, always check you are in the right namespace.** Most "it didn't work"
> moments are actually "I ran it in the wrong project":
> `oc project` shows the current one, `oc project <name>` switches.

Each topic below ends with its own **Troubleshoot & Reset** block: the specific symptoms for
that task, the fast checks, and the exact commands to wipe and start over.

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

### Troubleshoot & Reset -- Topic 1 (3-Minute Rule)

**Symptom: you replaced `htpasswd-secret` but `oc login -u raja` still fails.**
This is normal for the first 1-3 minutes -- the OAuth pods have to redeploy. Check in order:

```bash
# 1. Is the auth operator still rolling out? (this is usually the whole answer -- WAIT)
oc get co authentication
#    Want: AVAILABLE=True, PROGRESSING=False. If PROGRESSING=True, wait.
oc get pods -n openshift-authentication
#    Old pods terminating + new ones starting = it is working, give it 60s

# 2. Is the secret correct? The key MUST be named "htpasswd"
oc get secret htpasswd-secret -n openshift-config -o jsonpath='{.data.htpasswd}' | base64 -d
#    Should list your users. Nothing / wrong key name = recreate the secret.

# 3. Does the OAuth config actually point at that secret?
oc get oauth cluster -o yaml | grep -A10 identityProviders
#    fileData.name must be: htpasswd-secret
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| Login fails, `co/authentication` PROGRESSING=True | Pods still rolling out | Wait 60-90s |
| `base64 -d` shows old users only | Secret never replaced | Recreate the secret |
| Secret key is `htpasswd.txt` not `htpasswd` | Wrong `--from-file` syntax | Must be `--from-file=htpasswd=/tmp/htpasswd.txt` |
| `oc get users` is empty | Normal -- a User object is only created on first successful login | Not a problem |
| Pods never redeploy | Operator wedged | `oc delete pod -n openshift-authentication --all` |

**Still broken after 3 minutes -- wipe and redo:**
```bash
# Rebuild the htpasswd file from scratch.
# WARNING: -c CREATES a new file and wipes existing users (including any the lab pre-made).
# Safer: extract the current one first, then only add.
oc -n openshift-config get secret htpasswd-secret \
  -o jsonpath='{.data.htpasswd}' | base64 -d > /tmp/htpasswd.txt

htpasswd -b /tmp/htpasswd.txt raja  anishrana2001
htpasswd -b /tmp/htpasswd.txt suraj anishrana2001
htpasswd -b /tmp/htpasswd.txt punit anishrana2001
htpasswd -b /tmp/htpasswd.txt rajan anishrana2001
cat /tmp/htpasswd.txt            # eyeball it -- one line per user

# Replace the secret (note the key name "htpasswd=" -- this is the #1 mistake)
oc -n openshift-config delete secret htpasswd-secret
oc -n openshift-config create secret generic htpasswd-secret \
  --from-file=htpasswd=/tmp/htpasswd.txt

# Force the OAuth pods to redeploy instead of waiting for the operator
oc delete pod -n openshift-authentication --all

# Watch until AVAILABLE=True and PROGRESSING=False, then log in
oc get co authentication -w        # Ctrl+C when ready
oc login -u raja -p anishrana2001 https://api.ocp4.example.com:6443
```

**Other Topic 1 resets (all instant -- just redo them):**
```bash
# Projects
oc delete project banana apple kiwi mango
oc get projects | grep -E "banana|apple|kiwi|mango"   # repeat until empty, then recreate

# SSH keys -- delete both files and regenerate
rm -f /home/student/.ssh/lab_rsa /home/student/.ssh/lab_rsa.pub
ssh-keygen -t rsa -f /home/student/.ssh/lab_rsa -N ""

# Node labels -- remove with a trailing minus sign
oc label nodes worker01 datacenter-
oc label nodes worker02 datacenter-
oc label nodes worker01 datacenter=paris
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

### Troubleshoot & Reset -- Topic 2 (3-Minute Rule)

> **The 3-minute rule does NOT apply to the operator install.** A healthy install takes
> 10-20 minutes. Wiping it costs you another 15. Only wipe if the CSV says `Failed`.

```bash
# Where is it stuck? Run all four
oc get csv -n openshift-cnv                 # want: PHASE=Succeeded
oc get installplan -n openshift-cnv         # APPROVED=false means it is WAITING FOR YOU
oc get pods -n openshift-cnv                # want: all Running/Completed
oc get hco kubevirt-hyperconverged -n openshift-cnv -o yaml | tail -30   # Conditions
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| `installplan` shows `APPROVED=false` | Install plan set to Manual approval | `oc patch installplan <name> -n openshift-cnv --type merge -p '{"spec":{"approved":true}}'` |
| CSV stuck `Installing` for <15 min | Normal | Wait |
| CSV `Failed` | Bad subscription/channel | Wipe (below) |
| No `hco` resource exists | You installed the operator but never created the HyperConverged CR | Create it (console: "Create HyperConverged") |
| Pods `Pending` | Node capacity | `oc describe pod <name> -n openshift-cnv \| tail -20` |

**Still broken after 3 minutes of being clearly Failed -- wipe and reinstall (budget 15 min):**
```bash
# Order matters: CR first, then operator, then namespace
oc delete hco kubevirt-hyperconverged -n openshift-cnv --ignore-not-found
oc delete subscription --all -n openshift-cnv
oc delete csv --all -n openshift-cnv
oc delete namespace openshift-cnv
oc get ns openshift-cnv            # repeat until "NotFound"

# Reinstall via OperatorHub, then:
oc wait hco/kubevirt-hyperconverged -n openshift-cnv --for=condition=Available --timeout=20m
```

> If the namespace hangs in `Terminating`, a finalizer is stuck:
> `oc get hco -n openshift-cnv -o name | xargs -r -I{} oc patch {} -n openshift-cnv --type=merge -p '{"metadata":{"finalizers":null}}'`

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

### Troubleshoot & Reset -- Topic 3 (3-Minute Rule)

> RBAC is **instant**. Nothing here is ever "still rolling out". If `oc auth can-i` says no,
> the binding is genuinely wrong -- do not wait, fix or wipe immediately.

```bash
# The one command that tells you the truth
oc auth can-i create virtualmachines.kubevirt.io -n banana --as=raja
oc auth can-i --list -n banana --as=raja | head -20     # everything they CAN do

# What bindings actually exist?
oc get rolebinding -n banana -o wide     # -o wide shows ROLE and USERS/GROUPS columns
oc describe rolebinding leaders-admin -n banana
oc get groups                             # check membership
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| `can-i` says no, binding exists | Bound in the **wrong namespace** | `oc get rolebinding -A \| grep raja` |
| `can-i` says no, role name looks right | Used `--role` (namespaced Role) instead of `--clusterrole` | Recreate with `--clusterrole=` |
| Group binding has no effect | Typo in group name, or user not in the group | `oc get group leaders -o yaml` |
| `oc get users` does not list raja | Normal -- User objects appear only after first login | Not a problem; bindings still work |
| User can see VMs but not start them | Needs `kubevirt.io:edit`, not `edit` | Add a second rolebinding |

**Still broken after 3 minutes -- wipe all bindings for that project and redo:**
```bash
# Nuke every rolebinding in the project (fast, safe -- they are cheap to recreate)
oc delete rolebinding --all -n banana
oc get rolebinding -n banana        # should be empty

# Recreate from scratch
oc create rolebinding leaders-admin   --clusterrole=admin             --group=leaders -n banana
oc create rolebinding qa-view         --clusterrole=view              --group=qa      -n banana
oc create rolebinding raja-admin      --clusterrole=admin             --user=raja     -n banana
oc create rolebinding suraj-view      --clusterrole=view              --user=suraj    -n banana
oc create rolebinding suraj-vm-edit   --clusterrole=kubevirt.io:edit  --user=suraj    -n banana
oc create rolebinding punit-view      --clusterrole=view              --user=punit    -n banana

# Re-verify every single one
oc auth can-i create virtualmachines.kubevirt.io -n banana --as=raja
oc auth can-i update virtualmachines/start       -n banana --as=suraj
oc auth can-i get    virtualmachines             -n banana --as=punit
```

**Reset groups:**
```bash
oc delete group leaders developers qa
oc adm groups new leaders
oc adm groups add-users leaders suraj
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

### Troubleshoot & Reset -- Topic 4 (3-Minute Rule)

> **Disk import is slow (2-15 min).** `oc get dv -n banana -w` showing `ImportInProgress`
> with a rising percentage is **working** -- do not delete it. The 3-minute timer starts only
> when the phase is `Failed`, or a pod is `Pending`/`Error`, or nothing changes at all.

```bash
# Walk the chain: VM -> VMI -> DataVolume -> PVC -> pod
oc get vm,vmi,dv,pvc -n banana
oc get events -n banana --sort-by=.lastTimestamp | tail -20

# Disk import stuck? Read the importer pod's log -- it names the exact failure
oc get pods -n banana | grep importer
oc logs -n banana importer-<dv-name>

# VM won't start? The launcher pod explains why
oc get pods -n banana | grep virt-launcher
oc describe pod -n banana virt-launcher-<vm-name>-xxxxx | tail -25
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| DV phase `Pending`, PVC `Pending` | StorageClass name typo, or no default SC | `oc get sc` and compare exactly |
| Importer log: 404 / connection refused | Bad image URL | Re-check the URL from the task text |
| DV `Failed`, "no space" | PVC too small for the image | Recreate with a bigger size |
| `virt-launcher` pod `Pending` | Node selector / insufficient memory | `oc describe pod` -> Events at the bottom |
| VM Running but console shows nothing | Still booting | Wait 60s, press Enter |
| Cloud-init user/password does not work | cloud-init only runs on **first** boot of a fresh disk | Must wipe the disk, not just restart |

**Still broken after 3 minutes -- wipe the VM and its disk, then redo:**
```bash
# 1. Stop the VM hard
virtctl stop myvm-lan1 -n banana --force --grace-period=0

# 2. Delete the VM (this does NOT always remove the disk)
oc delete vm myvm-lan1 -n banana

# 3. Delete the leftover disk -- cloud-init will NOT re-run unless the disk is gone
oc get dv,pvc -n banana
oc delete dv myvm-lan1 -n banana --ignore-not-found
oc delete pvc myvm-lan1 -n banana --ignore-not-found

# 4. Confirm nothing is left before recreating
oc get vm,vmi,dv,pvc,pods -n banana

# 5. Recreate (console, or generate the YAML -- see "full YAML" section above)
```

> **PVC stuck `Terminating`?** Something still has it mounted. Check for a leftover pod
> (`oc get pods -n banana`), delete it, then:
> `oc patch pvc myvm-lan1 -n banana --type=merge -p '{"metadata":{"finalizers":null}}'`

**Full project reset (when several VMs are tangled):**
```bash
oc delete project banana
oc get project banana      # repeat until "NotFound" (1-2 min)
oc new-project banana
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

### Troubleshoot & Reset -- Topic 5 (3-Minute Rule)

> Services, routes and NetworkPolicies apply **instantly**. Nothing here needs waiting.
> **The #1 failure by far: empty endpoints = the service selector does not match the VM labels.**

```bash
# THE check. If ENDPOINTS is <none>, your selector is wrong -- nothing else matters
oc get svc,endpoints -n banana

# Compare the two sides
oc get svc svc-web -n banana -o jsonpath='{.spec.selector}{"\n"}'
oc get vmi myvm-lan1 -n banana --show-labels

# Route
oc get route -n banana
curl -v anishrana2001-la-banana.apps.ocp4.example.com

# NetworkPolicy
oc get netpol -n banana
oc describe netpol netpol-http -n banana
oc get ns banana --show-labels      # namespaceSelector needs kubernetes.io/metadata.name=banana
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| `ENDPOINTS: <none>` | Selector mismatch | Set selector to `kubevirt.io/domain: <vm-name>` |
| Endpoints appear, then vanish after VM restart | Label was on the **VMI** only | Also patch `vm.spec.template.metadata.labels` |
| Route returns 503 | Service has no endpoints | Fix the selector first |
| NetworkPolicy blocks everything, including allowed traffic | `podSelector` matches nothing, or wrong port | `oc describe netpol` and compare to VM labels |
| NetworkPolicy has no effect at all | Created in the wrong namespace | NetPol is namespaced -- check `-n` |

**Still broken after 3 minutes -- wipe the networking objects and redo:**
```bash
# These are instant to recreate -- delete freely
oc delete netpol --all -n banana
oc delete route --all -n banana
oc delete svc svc-web -n banana --ignore-not-found

# Recreate the service with virtctl (it sets the correct selector FOR you -- fewer mistakes)
virtctl expose vmi myvm-lan1 --name svc-web --type=ClusterIP --port 80 --target-port=80 -n banana
oc get svc,endpoints -n banana        # endpoints must show the VM IP before going further

# Then the route
oc expose service svc-web --name=banana-web-route \
  --hostname=anishrana2001-la-banana.apps.ocp4.example.com -n banana

# Then the NetworkPolicy (re-apply the YAML from the solution above)
```

> **Make the label survive a VM restart** -- patch the VM template, not just the VMI:
> ```bash
> oc patch vm myvm-lan1 -n banana --type merge \
>   -p '{"spec":{"template":{"metadata":{"labels":{"kubevirt.io/domain":"myvm-lan1"}}}}}'
> ```

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

### Troubleshoot & Reset -- Topic 6 (3-Minute Rule)

> Here "wipe and start over" usually means **restart the VM**, not delete it. Only delete the
> VM if you broke the boot (bad `/etc/fstab`, bad SELinux, deleted a system package).

```bash
# Can't get a console?
oc get vmi -n banana                       # VM must be Running, not Pending/Scheduling
virtctl console myvm-lan1 -n banana
#   Blank screen = press Enter. Exit the console with Ctrl + ]  (NOT Ctrl+C)

# Can't SSH?
virtctl ssh raja@myvm-lan1 -n banana --identity-file=/home/student/.ssh/lab_rsa
oc get vmi myvm-lan1 -n banana -o wide     # does it have an IP yet?
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| Console hangs at a blank screen | Nothing has printed since you attached | Press Enter |
| Ctrl+C does not exit the console | Wrong key | Use **Ctrl + ]** |
| Login rejected with the cloud-init password | cloud-init did not run (disk was reused) | Recreate the VM with a fresh disk (Topic 4 reset) |
| `yum install` fails, no repos | Repo file missing | Re-run the `curl -o /etc/yum.repos.d/...` step |
| `curl` inside VM fails, no DNS | VM has no pod-network NIC or no IP | `ip a` inside; `oc get vmi -o wide` outside |
| `systemctl enable` done but service dead after reboot | Used `start` without `enable`, or config error | `systemctl is-enabled httpd`; `httpd -t` |
| httpd will not start | Config syntax | `httpd -t` names the bad line |

**Still broken after 3 minutes -- escalate in this order:**
```bash
# Level 1: restart the guest (keeps the disk, ~60s)
virtctl restart myvm-lan1 -n banana
oc get vmi myvm-lan1 -n banana -w

# Level 2: force it off and on (when the guest is hung)
virtctl stop myvm-lan1 -n banana --force --grace-period=0
virtctl start myvm-lan1 -n banana

# Level 3: the guest OS is unbootable -- restore a snapshot if you took one
oc get vmsnapshot -n banana
# (see Topic 10 for the VirtualMachineRestore object)

# Level 4: rebuild the VM from scratch -- use the Topic 4 reset block,
#          then redo the guest configuration
```

> **Before you ever reboot after editing `/etc/fstab`, run `mount -a`.** If it errors, fix the
> line now. A bad fstab entry drops the VM into emergency mode on next boot and costs you the
> whole question.

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

### Troubleshoot & Reset -- Topic 7 (3-Minute Rule)

> Same rule as Topic 5: instant to apply, and **empty endpoints is still the #1 problem.**

```bash
oc get svc,endpoints -n kiwi
oc describe service ex316-kiwi-svc -n kiwi | tail -15
oc get svc ex316-kiwi-svc -n kiwi -o jsonpath='{.spec.selector}{"\n"}'
oc get vmi -n kiwi --show-labels                  # must contain mydb=mariadb-kiwi

oc get route -n kiwi
curl -v anishrana2001-lb.apps.ocp4.example.com
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| `ENDPOINTS: <none>` | `oc create service` wrote `app=<name>` as the selector, not your VM label | `oc edit service` and set the real label |
| NodePort rejected on create | Port outside 30000-32767, or already taken | `oc get svc -A \| grep 30022` |
| Labels disappear after VM restart | Labelled the VMI only | Patch `vm.spec.template.metadata.labels` too |
| Route 503 | No endpoints behind the service | Fix the selector |
| `telnet <route> 22` fails | Routes are **HTTP/TLS only** -- they cannot carry raw SSH | Use NodePort for port 22 |

**Still broken after 3 minutes -- wipe and redo:**
```bash
oc delete route --all -n kiwi
oc delete service ex316-kiwi-svc -n kiwi --ignore-not-found

# Re-label BOTH the running VMI (takes effect now) and the VM template (survives restart)
for vm in web1 web2; do
  oc label vmi $vm mydb=mariadb-kiwi -n kiwi --overwrite
  oc patch vm $vm -n kiwi --type merge \
    -p '{"spec":{"template":{"metadata":{"labels":{"mydb":"mariadb-kiwi"}}}}}'
done

# Recreate the service, then immediately fix the selector
oc create service nodeport ex316-kiwi-svc --tcp=22:22 --node-port=30022 -n kiwi
oc patch svc ex316-kiwi-svc -n kiwi --type merge \
  -p '{"spec":{"selector":{"mydb":"mariadb-kiwi"}}}'

# Endpoints MUST be populated before you move on
oc get endpoints ex316-kiwi-svc -n kiwi
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

### Troubleshoot & Reset -- Topic 8 (3-Minute Rule)

> Creating the template is instant. Creating a **VM from** the template triggers a disk
> import, which is slow (Topic 4 rules apply to that part).

```bash
oc get template -n mango
oc process --parameters -n mango tmprhl9small     # lists required params
oc process -n mango tmprhl9small -p NAME=web1     # prints YAML; errors show here, before apply

# Did the VM actually get created?
oc get vm,dv,pvc -n mango
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| `oc apply` rejects the template: "resourceVersion should not be set" | You exported with `oc get -o yaml` and left the live-object fields in | Delete `resourceVersion`, `uid`, `creationTimestamp`, `selfLink`, and the whole `status:` block |
| "namespace does not match" | `metadata.namespace` still says `openshift` | Change it to `mango` |
| `oc process` errors "parameter required" | Template declares a param with no default | Pass it: `-p NAME=web1 -p <OTHER>=value` |
| VM created but wrong size/disk | You edited the wrong copy of the YAML | Re-export and redo |
| `oc process` works, `oc apply` creates nothing | Forgot to pipe | `oc process ... \| oc apply -f -` |

**Still broken after 3 minutes -- wipe the template and re-export:**
```bash
# Remove anything made from it, then the template itself
oc delete vm --all -n mango
oc delete dv,pvc --all -n mango
oc delete template tmprhl9small -n mango --ignore-not-found

# Re-export a clean base
oc get template rhel9-server-small -n openshift -o yaml > /tmp/tmprhl9small.yaml

# Strip the live-object fields that block re-apply (do this EVERY time you copy a resource)
# Delete these lines in the editor: resourceVersion, uid, creationTimestamp, selfLink, status:
vi /tmp/tmprhl9small.yaml
#   also set: metadata.name: tmprhl9small, metadata.namespace: mango

oc apply -f /tmp/tmprhl9small.yaml -n mango
oc get template -n mango

# Rebuild the VMs
oc process -n mango tmprhl9small -p NAME=web1 | oc apply -n mango -f -
oc process -n mango tmprhl9small -p NAME=web2 | oc apply -n mango -f -
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

### Troubleshoot & Reset -- Topic 9 (3-Minute Rule)

> **A probe only takes effect after `virtctl restart`.** If you patched and nothing changed,
> you almost certainly just forgot the restart.
>
> **Danger:** a liveness probe pointing at a port nothing is listening on will reboot the VM
> every `periodSeconds`. If your VM suddenly restarts in a loop, this is why -- remove the
> probe first, then fix the service inside the guest.

```bash
# Is the probe in the VM spec?
oc get vm mariadb-server -n apple -o yaml | grep -A10 -i livenessprobe

# Is it in the RUNNING instance? (if not -> you did not restart)
oc get vmi mariadb-server -n apple -o yaml | grep -A10 -i livenessprobe

# Is the VM reboot-looping?
oc get vmi -n apple -w
oc describe vmi mariadb-server -n apple | tail -25
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| Probe in `vm` but not in `vmi` | VM not restarted | `virtctl restart mariadb-server -n apple` |
| Patch rejected: "unknown field" | Probe nested under `domain:` | It belongs at `spec.template.spec`, a sibling of `domain` |
| VM restarts every ~2 min | Liveness probe failing (nothing on that port) | Remove the probe, start the service in the guest, re-add |
| Probe accepted but VM stays NotReady | `initialDelaySeconds` too short for boot | Raise it (100s is a safe exam value) |
| `oc patch` says "not patched" | Same content already applied | Not an error |

**Still broken after 3 minutes -- strip the probe out and redo:**
```bash
# Remove the probe entirely (json patch -- the "remove" op)
oc patch vm mariadb-server -n apple --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/livenessProbe"}]'

# Readiness probe uses the same path with a different name
oc patch vm mariadb-server -n apple --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/readinessProbe"}]'

# Confirm it is gone, then restart to stop any reboot loop
oc get vm mariadb-server -n apple -o yaml | grep -i probe      # expect no output
virtctl restart mariadb-server -n apple

# Make sure something is actually LISTENING before you re-add a liveness probe
virtctl console mariadb-server -n apple
#   inside the guest:  ss -tlnp | grep 3306
#   exit with Ctrl + ]

# Re-apply the probe, then restart again
oc patch vm/mariadb-server --type=merge --patch-file=/tmp/liveness.yaml -n apple
virtctl restart mariadb-server -n apple
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

### Troubleshoot & Reset -- Topic 10 (3-Minute Rule)

```bash
# The one field that matters
oc get vmsnapshot web2-snap-maria -n kiwi -o jsonpath='{.status.readyToUse}{"\n"}'

# If it is not true, the reason is here
oc describe vmsnapshot web2-snap-maria -n kiwi | tail -25
oc get volumesnapshot -n kiwi
oc get volumesnapshotclass            # must exist, and match your SC's CSI driver
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| `readyToUse` empty/false for <2 min | Normal, still snapshotting | Wait |
| No VolumeSnapshotClass exists | Storage backend has no CSI snapshot support configured | `oc get volumesnapshotclass`; pick a storage class that has one |
| "source does not exist" | VM name or namespace wrong in `spec.source` | Fix the YAML; `apiGroup: kubevirt.io`, `kind: VirtualMachine` |
| Snapshot stuck `InProgress` forever | Guest agent quiescing a frozen guest | Restart the VM, retake |
| Wrong apiVersion rejected | Version drift | `oc api-resources \| grep -i snapshot` and use what it prints |

**Still broken after 3 minutes -- wipe and retake:**
```bash
oc delete vmsnapshot web2-snap-maria -n kiwi
oc get volumesnapshot -n kiwi                    # delete orphans if any remain
oc get vmsnapshot,volumesnapshot -n kiwi         # confirm clean

# Confirm the VM is healthy FIRST -- you cannot snapshot a broken VM
oc get vm,vmi web2 -n kiwi

# Retake, using the version the cluster reports (not one from memory)
oc api-resources | grep -i virtualmachinesnapshot
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

oc get vmsnapshot web2-snap-maria -n kiwi -w      # wait for readyToUse: true
```

**To restore from a snapshot** (stop the VM first -- restore fails on a running VM):
```bash
virtctl stop web2 -n kiwi
cat <<'EOF' | oc apply -n kiwi -f -
apiVersion: snapshot.kubevirt.io/v1beta1
kind: VirtualMachineRestore
metadata:
  name: web2-restore
  namespace: kiwi
spec:
  target:
    apiGroup: kubevirt.io
    kind: VirtualMachine
    name: web2
  virtualMachineSnapshotName: web2-snap-maria
EOF
oc get vmrestore -n kiwi -w
virtctl start web2 -n kiwi
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

### Troubleshoot & Reset -- Topic 11 (3-Minute Rule)

> **Cloning is slow (2-10 min).** `CloneInProgress` with a rising percentage is working.
> The timer starts only at `Failed`, or `Pending` with no movement.

```bash
oc get dv -n kiwi                      # PHASE: CloneInProgress -> Succeeded
oc describe dv web1-copy -n kiwi | tail -25
oc get pods -n kiwi | grep -E "clone|cdi"
oc logs -n kiwi <clone-source-or-target-pod>

# For VirtualMachineClone objects
oc get vmclone -n kiwi
oc describe vmclone <name> -n kiwi | tail -20
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| DV `Pending`, no clone pod | StorageClass name wrong | `oc get sc`, copy the exact name |
| "target is smaller than source" | Requested size < source PVC | Match or exceed the source: `oc get pvc web1 -n kiwi -o jsonpath='{.spec.resources.requests.storage}{"\n"}'` |
| Clone hangs at 0% | Source PVC in use and the SC cannot do a live clone | `virtctl stop web1 -n kiwi`, then retry |
| "source pvc not found" | Wrong PVC name -- it is not always the VM name | `oc get pvc -n kiwi` and use the real name |
| Clone succeeds but new VM will not boot | A DataVolume is a disk, not a VM | Create a VM that references the cloned DV |

**Still broken after 3 minutes -- wipe the clone and restart it:**
```bash
# Delete the half-finished clone and its PVC
oc delete dv web1-copy -n kiwi --ignore-not-found
oc delete pvc web1-copy -n kiwi --ignore-not-found
oc get dv,pvc,pods -n kiwi           # confirm no leftover clone pods

# Get the REAL source values instead of guessing
oc get pvc -n kiwi
oc get pvc web1 -n kiwi -o jsonpath='{.spec.storageClassName}{"\n"}'
oc get pvc web1 -n kiwi -o jsonpath='{.spec.resources.requests.storage}{"\n"}'

# Stop the source VM -- removes the "in use" class of failures entirely
virtctl stop web1 -n kiwi

# Re-apply the DataVolume with the exact values you just read, then watch
oc get dv web1-copy -n kiwi -w       # Succeeded = done
```

**For a stuck `VirtualMachineClone`:**
```bash
oc delete vmclone <name> -n kiwi
oc delete vm myvm-lan3-copy -n kiwi --ignore-not-found
oc delete dv,pvc -l kubevirt.io/created-by -n kiwi   # check first with: oc get dv,pvc -n kiwi
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

### Troubleshoot & Reset -- Topic 12 (3-Minute Rule)

> **Live migration needs RWX (ReadWriteMany) storage.** If the VM's PVC is RWO, migration will
> never work no matter what you configure -- check this before debugging anything else.

```bash
# Is the storage even capable of live migration?
oc get pvc -n apple -o custom-columns=NAME:.metadata.name,MODE:.spec.accessModes
#   Need ReadWriteMany. ReadWriteOnce = live migration not possible.

# Migration status
oc get vmim -n apple
oc describe vmim <name> -n apple | tail -25
oc get vmi mariadb-server -n apple -o wide        # which node is it on?

# VM stuck Pending after a nodeSelector change?
oc get nodes -l datacenter=paris                   # do any nodes actually have the label?
oc describe pod -n apple virt-launcher-mariadb-server-xxxxx | tail -20
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| `virtctl migrate` errors "not migratable" | RWO storage, or a non-migratable device | `oc describe vmi` -> LiveMigratable condition gives the reason |
| VMI `Pending` after adding nodeSelector | No node carries the label | `oc get nodes --show-labels`; label a node or fix the key |
| Migration starts then fails repeatedly | Target node lacks capacity | Try the other worker; `oc describe node` |
| nodeSelector patch "worked" but VM unchanged | Patch applied to the VM, not the running VMI | `virtctl restart` -- scheduling only applies at start |
| Drain hangs on a VM | No `evictionStrategy: LiveMigrate` | Patch it, then drain again |

**Still broken after 3 minutes -- clear the migrations and reset scheduling:**
```bash
# 1. Remove stuck migration objects (they are just records -- safe to delete)
oc delete vmim --all -n apple

# 2. Undo the scheduling config so the VM can run anywhere again
oc patch vm mariadb-server -n apple --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]'

# 3. Make sure no node is left cordoned from your testing
oc get nodes                       # look for SchedulingDisabled
oc adm uncordon worker01
oc adm uncordon worker02

# 4. Hard restart the VM so it reschedules cleanly
virtctl stop mariadb-server -n apple --force --grace-period=0
virtctl start mariadb-server -n apple
oc get vmi mariadb-server -n apple -o wide -w       # wait for Running

# 5. Re-apply the config, then restart again so it takes effect
oc patch vm mariadb-server -n apple --type merge -p '{
  "spec":{"template":{"spec":{
    "nodeSelector":{"datacenter":"paris"},
    "evictionStrategy":"LiveMigrate"}}}}'
virtctl restart mariadb-server -n apple
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

### Troubleshoot & Reset -- Topic 13 (3-Minute Rule)

> Cordon/uncordon is instant. A **drain** is not -- it can legitimately take several minutes
> while VMs migrate off. Watch it rather than killing it.

```bash
oc get nodes                                   # look for Ready,SchedulingDisabled
oc get vmi -A -o wide                          # what is still running on that node?
oc get pods -A --field-selector spec.nodeName=worker01 | head -20
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| Node still `SchedulingDisabled` after uncordon | Uncordoned the wrong node | `oc get nodes` and copy the exact name |
| `oc adm drain` hangs on a VM | VM has no `evictionStrategy: LiveMigrate`, or RWO storage | Patch the VM, or stop the VM and drain again |
| Drain refuses: "cannot delete Pods with local storage" | Missing flags | Add `--delete-emptydir-data --ignore-daemonsets --force` |
| Drain "succeeded" but VMs died instead of migrating | RWO storage -- they were killed, not migrated | Expected with RWO; note it and move on |
| Node `NotReady` | Not a cordon problem at all | `oc describe node worker01 \| tail -30` |

**Still stuck after 3 minutes -- reset the node state:**
```bash
# Undo everything and get back to a clean cluster
oc adm uncordon worker01
oc adm uncordon worker02
oc get nodes                        # all should read just "Ready"

# If a drain is wedged: Ctrl+C it, uncordon, then stop the blocking VM and retry
oc adm uncordon worker01
oc get vmi -A -o wide | grep worker01
virtctl stop <vm-name> -n <ns>      # stopping is always allowed; migrating may not be
oc adm drain worker01 --ignore-daemonsets --delete-emptydir-data --force --timeout=10m

# Make VMs drain-friendly BEFORE the next attempt
oc patch vm <vm-name> -n <ns> --type merge \
  -p '{"spec":{"template":{"spec":{"evictionStrategy":"LiveMigrate"}}}}'
virtctl restart <vm-name> -n <ns>
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

### Troubleshoot & Reset -- Topic 14 (3-Minute Rule)

```bash
# Did the scheduling config actually land?
oc get vm ha-node-vm1 -n ha-node -o yaml | grep -E "runStrategy|evictionStrategy|nodeSelector" -A2

# VM Pending? The launcher pod says exactly which constraint failed
oc get vmi -n ha-node
oc describe pod -n ha-node virt-launcher-ha-node-vm1-xxxxx | tail -25

# Do the target nodes really carry the label?
oc get nodes -l ha-node=true
oc get nodes --show-labels | grep ha-node
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| VMI `Pending` forever | No node matches `nodeSelector` | `oc get nodes -l ha-node=true` -- if empty, label them |
| Pod events: "node(s) didn't match node selector" | Label typo or wrong value type | Labels are strings: `"true"` in quotes inside JSON patch |
| VM does not auto-restart after failure | `runStrategy` is `Manual`/`Halted` | Set `RerunOnFailure` (or `Always`) |
| `runStrategy` patch rejected | VM also has `spec.running` set -- the two are mutually exclusive | Remove `running`: `oc patch vm ... --type=json -p='[{"op":"remove","path":"/spec/running"}]'` |
| Masters will not run VMs | Control-plane taint | `oc describe node master01 \| grep -i taint` -- needs a matching toleration |

**Still broken after 3 minutes -- wipe the VM and rebuild it:**
```bash
# 1. Remove the VM (template-created VMs are cheap to recreate)
virtctl stop ha-node-vm1 -n ha-node --force --grace-period=0 2>/dev/null
oc delete vm ha-node-vm1 -n ha-node --ignore-not-found
oc delete dv,pvc --all -n ha-node
oc get vm,vmi,dv,pvc -n ha-node          # confirm clean

# 2. Re-apply the node labels and PROVE they took
oc label nodes master01 ha-node=true --overwrite
oc label nodes master02 ha-node=true --overwrite
oc get nodes -l ha-node=true             # must list both before continuing

# 3. Recreate from the template
oc process -n ha-node ha-node-template -p NAME=ha-node-vm1 | oc apply -n ha-node -f -

# 4. Apply scheduling, then start
oc patch vm ha-node-vm1 -n ha-node --type merge -p '{
  "spec":{
    "runStrategy":"RerunOnFailure",
    "template":{"spec":{
      "nodeSelector":{"ha-node":"true"},
      "evictionStrategy":"LiveMigrate"}}}}'

virtctl start ha-node-vm1 -n ha-node
oc get vmi ha-node-vm1 -n ha-node -o wide -w
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

### Troubleshoot & Reset -- Topic 15 (3-Minute Rule)

> **The dangerous part of this topic is `/etc/fstab`.** A bad entry makes the VM drop to
> emergency mode on next boot. **Always run `mount -a` before rebooting** -- if it errors,
> fix the line now, while you still have a working shell.

```bash
# Outside: is the disk ready and attached?
oc get dv extra-disk -n <ns>                 # want Succeeded
oc get vmi <vm> -n <ns> -o yaml | grep -A6 -i hotplug
oc describe dv extra-disk -n <ns> | tail -20

# Inside the guest: is the disk visible?
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,SERIAL
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| `virtctl addvolume` errors "not found" | DataVolume not `Succeeded` yet | `oc get dv -n <ns> -w`, then retry |
| Disk attaches but vanishes after VM restart | Forgot `--persist` | `virtctl addvolume ... --persist` |
| Disk not visible in `lsblk` | Guest has not rescanned | Wait 10s, re-run `lsblk`; or restart the VM |
| `mkfs.xfs` says "device busy" | Wrong device -- you targeted the root disk | Check `lsblk` carefully; root is usually `vda` |
| VM boots to emergency mode | Bad `/etc/fstab` | Fix at the emergency prompt (below) |
| Mount lost after reboot | fstab entry missing or wrong UUID | `blkid` and compare |

**Still broken after 3 minutes -- detach and start the disk over:**
```bash
# 1. Unmount inside the guest FIRST (otherwise detach can hang)
virtctl console <vm> -n <ns>
#   umount /var/www/html
#   and REMOVE the line you added from /etc/fstab, then: mount -a   (must be silent)
#   exit with Ctrl + ]

# 2. Detach the volume
virtctl removevolume <vm> --volume-name=extra-disk -n <ns>
oc get vmi <vm> -n <ns> -o yaml | grep -i hotplug      # should be gone

# 3. Delete the disk itself
oc delete dv extra-disk -n <ns> --ignore-not-found
oc delete pvc extra-disk -n <ns> --ignore-not-found

# 4. Recreate the DataVolume, WAIT for Succeeded, then re-attach
oc get dv extra-disk -n <ns> -w
virtctl addvolume <vm> --volume-name=extra-disk --serial=DISK1 --persist -n <ns>
```

**Rescuing a VM that boots into emergency mode after a bad fstab:**
```bash
virtctl console <vm> -n <ns>
# At the emergency prompt, enter the root password, then:
#   mount -o remount,rw /
#   vi /etc/fstab        -> delete or fix the bad line
#   mount -a             -> must produce NO output
#   reboot
# If you cannot get a prompt at all, the disk is faster to rebuild than to rescue:
# delete the VM and redo it (Topic 4 reset block).
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

### Troubleshoot & Reset -- Topic 16 (3-Minute Rule)

> OADP has the most moving parts of any topic. **Diagnose in dependency order** -- there is no
> point debugging a backup if the BackupStorageLocation is not `Available`:
>
> **OBC bound -> secret correct -> DPA created -> BSL Available -> backup -> restore**

```bash
# Walk the chain top to bottom and stop at the first thing that is wrong
oc get obc -n openshift-adp                       # want: Bound
oc get dpa -n openshift-adp
oc get backupstoragelocation -n openshift-adp     # want: PHASE=Available  <-- the key one
oc get pods -n openshift-adp                      # velero + node-agent must be Running

# BSL not Available? The reason is in the velero log
oc logs -n openshift-adp deployment/velero -c velero | tail -40

# Backup/restore detail
alias velero='oc -n openshift-adp exec deployment/velero -c velero -it -- ./velero'
velero backup describe db-manual --details
velero backup logs db-manual
velero restore describe db-crash --details
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| BSL `Unavailable` | Wrong bucket name, credentials, or caCert in the DPA | Re-extract from the OBC (step 4/5) and re-apply the DPA |
| BSL `Unavailable`, log says "SignatureDoesNotMatch" | Access key/secret mis-copied | Re-run `oc extract --to=- secret/backup -n openshift-adp` |
| OBC not `Bound` | Wrong `storageClassName` | `oc get sc \| grep noobaa` |
| Backup `PartiallyFailed` | A resource type in `includedResources` does not exist | Read `velero backup logs` |
| Backup `Completed` but restore is empty | `namespaceMapping` typo | `oc get all -n database-crash` |
| VM data not restored, only the definition | CSI snapshot plugin/labels missing | `oc label volumesnapshotclass velero.io/csi-volumesnapshot-class=true --all` |
| No `velero` command | It is an alias into the pod | Re-run the `alias velero=...` line |

**Still broken after 3 minutes -- reset at the right level (do NOT reinstall the operator):**

```bash
# Level 1: just the backup/restore objects (seconds) -- try this first
oc delete backup db-manual -n openshift-adp --ignore-not-found
oc delete restore db-crash -n openshift-adp --ignore-not-found
oc delete namespace database-crash --ignore-not-found     # clear a half-done restore
# then re-apply the Backup YAML

# Level 2: the DPA / storage location (1-2 min) -- when BSL is not Available
oc delete dpa oadp-backup -n openshift-adp
oc get backupstoragelocation -n openshift-adp     # should disappear

#   Re-read the REAL values instead of reusing what you typed before:
oc extract --to=- cm/backup     -n openshift-adp   # BUCKET_NAME
oc extract --to=- secret/backup -n openshift-adp   # ACCESS KEY / SECRET KEY
oc get cm/openshift-service-ca.crt -n openshift-adp \
  -o jsonpath='{.data.service-ca\.crt}' | base64 -w0; echo    # caCert

#   Recreate the credentials secret, then re-apply the DPA YAML
oc delete secret cloud-credentials -n openshift-adp --ignore-not-found
oc create secret generic cloud-credentials -n openshift-adp --from-file cloud=/tmp/cloud-credentials

oc get backupstoragelocation -n openshift-adp -w   # wait for Available

# Level 3: the bucket itself (only if the OBC never bound)
oc delete obc backup -n openshift-adp
# re-apply the ObjectBucketClaim YAML, then redo Level 2
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

### Troubleshoot & Reset -- Topic 17 (3-Minute Rule)

> **An OVA import is slow** -- the whole disk is copied and converted. A plan sitting at
> "Copying disks" with a rising percentage is working. Start the timer only on `Failed`.

```bash
# Is the operator itself healthy?
oc get pods -n openshift-mtv                       # forklift-controller must be Running
oc get forkliftcontroller -n openshift-mtv

# Walk the migration chain: provider -> maps -> plan -> migration
oc get provider,plan,migration -n openshift-mtv
oc describe plan <plan-name> -n openshift-mtv | tail -30     # Conditions say what is missing
oc describe migration <name> -n openshift-mtv | tail -30
oc logs -n openshift-mtv deployment/forklift-controller | tail -40

# Did anything actually land?
oc get vm,dv,pvc -n vms-import
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| Plan condition `NotReady` | Network map or storage map missing/unmapped | `oc describe plan` lists the unmapped item by name |
| Provider `ConnectionFailed` | Bad URL/credentials, or missing CA cert | Recreate the provider with the exact values from the task |
| Migration stuck "Copying disks" | Normal for a large OVA | Wait; watch the percentage move |
| Migration `Failed`, "no space left" | Target storage class out of capacity | `oc get pvc -n vms-import`; pick another SC |
| VM imported but will not boot | Guest needs virtio drivers / wrong firmware (BIOS vs UEFI) | Check the VM's boot settings in the console |
| No `provider` CRD at all | MTV operator not installed | Install it from OperatorHub first |

**Still broken after 3 minutes -- wipe the migration and redo (keep the operator):**
```bash
# 1. Delete in reverse dependency order: migration -> plan -> maps -> provider
oc delete migration --all -n openshift-mtv
oc delete plan --all -n openshift-mtv
oc delete networkmap,storagemap --all -n openshift-mtv
oc delete provider --all -n openshift-mtv       # keeps the "host" provider? re-check with: oc get provider -n openshift-mtv

# 2. Clean up anything half-imported into the target project
oc get vm,dv,pvc -n vms-import
oc delete vm rhel9-web -n vms-import --ignore-not-found
oc delete dv,pvc --all -n vms-import

# 3. Confirm the controller is healthy before retrying
oc get pods -n openshift-mtv

# 4. Rebuild via the console: Migration -> Providers -> Add Provider,
#    then network map, storage map, plan, Start.

# 5. Watch it
oc get plan,migration -n openshift-mtv -w
oc get vm,dv -n vms-import -w
```

> If the ForkliftController itself is broken, that is an operator reinstall -- 10+ minutes.
> On the exam, only do that if you have time left after every other question is done.

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
