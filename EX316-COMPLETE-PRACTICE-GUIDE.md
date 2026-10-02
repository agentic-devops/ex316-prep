# EX316 Complete Practice Guide: CLI-First Approach

**Exam:** Red Hat Certified Specialist in OpenShift Virtualization (EX316)
**Time limit:** 4 hours | **Format:** Performance-based (CLI only, no multiple choice)
**Available during exam:** `oc explain`, `--help`, product docs. NO internet, NO personal notes.
**Companion file:** `EX316-PRACTICE-QUESTIONS-AND-SOLUTIONS.md` -- same techniques up front, then
practice questions by topic. Keep both in sync.
**Validator:** `ex316-validate.sh` -- copy it to a machine with cluster access and run it to
check every command, flag, field path and manifest in these guides against the live cluster.
It is read-only (dry-run only; nothing is created, changed or deleted).

---

## Part 1: CLI Discovery Strategy for Beginners

Before diving into topics, master these six techniques. They are your lifeline during the exam.

### Technique 1: `--help` + `grep` (Finding the right flags)
```bash
# Pattern: <command> --help | grep -iE "keyword1|keyword2"
virtctl --help | grep -iE "start|stop|console|ssh"
virtctl create vm --help | grep -iE "memory|volume|cloud-init"
oc create --help | grep -i secret
oc adm --help | grep -i drain
```

### Technique 1b: Get complete example commands (copy-paste ready)
`grep -i memory` shows you flag lines with no context. But every help page also has an
`Examples:` section full of **complete, working commands**. To see only those, grep for the
name of the command itself -- every example line starts with it.

**The one thing to remember: `grep` the command's own name.**

```bash
virtctl create vm --help | grep virtctl
```
That prints ~25 full commands, one per line, ready to copy.

**Too many? Add a second `grep` for your keyword.** No new syntax -- just `grep` again:
```bash
virtctl create vm --help | grep virtctl | grep memory
virtctl create vm --help | grep virtctl | grep volume-import
oc create secret generic --help | grep "oc create secret" | grep from-literal
```
Read it left to right: *show the help -> keep the example lines -> keep the ones about memory.*

**Want the description too?** Add `-B1` ("1 line Before" -- the `#` comment sits above each example):
```bash
virtctl create vm --help | grep -B1 memory
```
```
  # Create a manifest for a VirtualMachine with specified memory and an ephemeral containerdisk volume
  virtctl create vm --memory=1Gi --volume-containerdisk=src:my.registry/my-image:my-tag
```

**If you forget all of the above**, just page through the help and search inside it:
```bash
virtctl create vm --help | less
```
Then type `/memory` + Enter to jump to the next match, `n` for the match after that, `q` to quit.

Then copy the closest example and edit the values -- far faster than composing flags from scratch.

### Technique 2: `oc explain` (Finding YAML field paths)
> **What this is for:** you already have a YAML file (generated -- see Technique 5) and the
> question asks for *one more thing* ("make it not migrate", "add a readiness probe").
> `oc explain` tells you the **exact field name and where it nests**. It does not write YAML for you.

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
> **What this is for:** the **first two lines of every YAML file** -- `apiVersion:` and `kind:`.
> You cannot guess these and getting the version wrong makes `oc apply` reject the file.
> The output columns are `NAME | SHORTNAMES | APIVERSION | NAMESPACED | KIND`, so you read
> `apiVersion` and `kind` straight off the matching line.

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

### Technique 5: Getting a FULL YAML file (never type one from scratch)

This is the one that actually produces a file. Techniques 2 and 3 are the *helpers* you use
on top of it. The exam workflow is always the same four steps:

> **1. Generate a skeleton -> 2. `oc explain` the extra field -> 3. edit -> 4. apply**

**Step 1 -- generate. Pick whichever source exists, in this order:**

```bash
# a) VMs -- virtctl writes the whole manifest. Redirect it into a file with >
virtctl create vm --name=db --memory=4Gi \
  --volume-import=type:ds,src:openshift-virtualization-os-images/rhel9 > db.yaml

# b) Common k8s objects -- oc generates them with --dry-run=client -o yaml
oc create secret generic my-keys --from-literal=key1=abc --dry-run=client -o yaml > secret.yaml
oc create rolebinding bob-vm --role=vm-operator --user=bob --dry-run=client -o yaml > rb.yaml
oc create role vm-operator --verb=get,list --resource=virtualmachines.kubevirt.io --dry-run=client -o yaml
oc create serviceaccount my-sa --dry-run=client -o yaml
oc expose vm/my-vm --port=22 --dry-run=client -o yaml

# c) Copy something that already exists in the cluster, then edit the copy
oc get vm existing-vm -o yaml > new-vm.yaml      # delete the status: block and uid/resourceVersion
oc get networkpolicy allow-same-ns -o yaml > np.yaml

# d) Red Hat's shipped VM templates
oc get template -n openshift -l template.kubevirt.io/type=vm
oc process -n openshift rhel9-server-small -p NAME=myvm -o yaml > vm.yaml
```

**Step 2 -- find the extra field** the question asks for (this is Technique 2's whole job):
```bash
oc explain vm.spec.template.spec --recursive | grep -i eviction
oc explain vm.spec.template.spec.evictionStrategy
```

**Step 3 -- edit the file**, adding the field at the path `explain` just showed you.

**Step 4 -- check before you commit to it:**
```bash
oc apply -f db.yaml --dry-run=server   # real API validation, changes nothing
oc apply -f db.yaml
```

#### When there is NO generator (NetworkPolicy, NNCP, DataVolume, Backup, Snapshot)
A handful of resources have no `oc create` shortcut. Build them from Techniques 3 + 2:

```bash
# 1. apiVersion + kind:
oc api-resources | grep -i snapshot
#    -> virtualmachinesnapshots  snapshot.kubevirt.io/v1beta1  true  VirtualMachineSnapshot

# 2. what goes under spec:
oc explain virtualmachinesnapshot.spec
```
```yaml
# 3. type the ~8 lines:
apiVersion: snapshot.kubevirt.io/v1beta1   # from step 1
kind: VirtualMachineSnapshot               # from step 1
metadata:
  name: db-snap
  namespace: vm-project
spec:                                      # fields from step 2
  source:
    apiGroup: kubevirt.io
    kind: VirtualMachine
    name: db
```
Faster alternative: if **any** example of that resource already exists in the cluster
(or you can create one with a `virtctl`/`oc` command), use `oc get ... -o yaml` and edit it.
The product documentation is available during the exam too -- copy YAML from there and
verify the version with `oc api-resources`, since docs sometimes lag the cluster.

### Technique 6: The 3-Minute Rule (troubleshoot, then wipe)

**The rule:** when something does not work, start a timer. Spend **at most 3 minutes**
diagnosing. If it is not fixed by then, **delete it and redo it from scratch.** Recreating
most resources takes under a minute; chasing a broken one can eat 20 minutes you do not have.

**First: is it broken, or just slow?** These are slow by nature -- deleting them makes it
worse. Let them run and watch:

| Thing | Normal wait | Watch it with |
|:---|:---|:---|
| Operator install / HyperConverged | 10-20 min | `oc get csv,pods -n openshift-cnv -w` |
| DataVolume import from URL | 2-15 min (image size) | `oc get dv -n <ns> -w` |
| DataVolume clone | 2-10 min | `oc get dv -n <ns> -w` |
| Auth operator after secret change | 1-3 min | `oc get co authentication -w` |
| VM first boot | 1-3 min | `oc get vmi -n <ns> -w` |
| OADP backup / restore | 5-20 min | `oc get backup,restore -n openshift-adp -w` |

The 3-minute timer starts only once it is clearly **stuck or failed** -- phase `Failed`,
`Error`, `CrashLoopBackOff`, `Pending` for minutes, or no change at all.

**The 60-second triage (works for ANY resource).** The answer is in one of these three more
than 90% of the time:

```bash
# 1. Events -- by far the most useful command in OpenShift
oc get events -n <namespace> --sort-by=.lastTimestamp | tail -20

# 2. Describe it -- Conditions and Events are at the BOTTOM of the output
oc describe <kind>/<name> -n <namespace> | tail -30

# 3. If a pod is involved, read its logs
oc get pods -n <namespace>
oc logs <pod-name> -n <namespace>
```

**The universal wipe:**
```bash
oc delete <kind> <name> -n <namespace>

# Stuck in "Terminating"? Force it
oc delete <kind> <name> -n <namespace> --force --grace-period=0

# STILL stuck? A finalizer is holding it
oc patch <kind> <name> -n <namespace> --type=merge -p '{"metadata":{"finalizers":null}}'

# Nuclear option for one task's project (slow -- 1-2 min)
oc delete project <name>
oc get project <name>          # repeat until "NotFound"
oc new-project <name>
```

> **Before you wipe, check you are in the right namespace.** Most "it didn't work" moments are
> really "I ran it in the wrong project": `oc project` shows the current one.

Every topic in Part 3 ends with its own **Troubleshoot & Reset** block for that specific task.

### Speed Tips for the Exam
1. **Don't write YAML from scratch** -- generate it (see Technique 5), then pipe or redirect
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

#### Troubleshoot & Reset (3-Minute Rule)

> **The 3-minute rule does NOT apply here.** A healthy operator install takes 10-20 minutes.
> Wiping costs another 15. Only wipe if the CSV actually says `Failed`.

```bash
oc get csv -n openshift-cnv                 # want PHASE=Succeeded
oc get installplan -n openshift-cnv         # APPROVED=false means it is WAITING FOR YOU
oc get pods -n openshift-cnv
oc get hco kubevirt-hyperconverged -n openshift-cnv -o yaml | tail -30
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| `installplan` `APPROVED=false` | Subscription set to Manual approval | `oc patch installplan <name> -n openshift-cnv --type merge -p '{"spec":{"approved":true}}'` |
| CSV `Installing` <15 min | Normal | Wait |
| CSV `Failed` | Wrong channel in the Subscription | Wipe (below); get the real channel from the packagemanifest |
| No `hco` resource | Operator installed, HyperConverged CR never created | Create it |
| Pods `Pending` | Node capacity | `oc describe pod <name> -n openshift-cnv \| tail -20` |

**Wipe and reinstall (budget 15 min) -- CR first, then operator, then namespace:**
```bash
oc delete hco kubevirt-hyperconverged -n openshift-cnv --ignore-not-found
oc delete subscription --all -n openshift-cnv
oc delete csv --all -n openshift-cnv
oc delete namespace openshift-cnv
oc get ns openshift-cnv                     # repeat until "NotFound"

# Reinstall, taking the channel from the cluster rather than memory
oc get packagemanifest kubevirt-hyperconverged -n openshift-marketplace \
  -o jsonpath='{.status.defaultChannel}{"\n"}'
# ...re-apply Namespace + OperatorGroup + Subscription, then:
oc wait hco/kubevirt-hyperconverged -n openshift-cnv --for=condition=Available --timeout=20m
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

#### Troubleshoot & Reset (3-Minute Rule)

> VM boot is slow (1-3 min); RBAC is instant. Treat them separately -- if `oc auth can-i`
> says no, do not wait, it is genuinely wrong.

```bash
# VM side -- walk the chain
oc get vm,vmi,pods -n q2-vmops
oc get events -n q2-vmops --sort-by=.lastTimestamp | tail -20
oc describe pod -n q2-vmops virt-launcher-app01-xxxxx | tail -25

# RBAC side -- the one command that tells the truth
oc auth can-i --list -n q2-vmops --as=q2-dev | head -20
oc get rolebinding -n q2-vmops -o wide
oc describe role vm-operator -n q2-vmops
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| VMI `Pending` | Node capacity or nodeSelector | `oc describe pod virt-launcher-*` -> Events |
| Console blank | Still booting, or nothing printed | Wait 60s, press Enter; exit with **Ctrl + ]** |
| cloud-user password rejected | cloud-init runs only on a **fresh** disk | Delete the VM *and* its disk, recreate |
| `can-i` no, binding looks right | Wrong namespace, or `--role` used where `--clusterrole` was needed | `oc get rolebinding -A \| grep q2-dev` |
| Custom role cannot start VMs | Missing the subresource | Verbs on `virtualmachines/start`, `/stop`, `/restart` in group `subresources.kubevirt.io` |

**Still broken after 3 minutes -- wipe:**
```bash
# VM (delete the disk too, or cloud-init will not re-run)
virtctl stop app01 -n q2-vmops --force --grace-period=0 2>/dev/null
oc delete vm app01 -n q2-vmops --ignore-not-found
oc delete dv,pvc --all -n q2-vmops
oc get vm,vmi,dv,pvc,pods -n q2-vmops        # confirm clean
virtctl create vm --name=app01 --memory=4Gi \
  --volume-containerdisk=src:quay.io/containerdisks/fedora:latest \
  --user=cloud-user --password-file=/tmp/pw > /tmp/app01.yaml
oc apply -f /tmp/app01.yaml -n q2-vmops

# RBAC (instant to rebuild -- delete all and redo)
oc delete rolebinding --all -n q2-vmops
oc delete role vm-operator -n q2-vmops --ignore-not-found
oc create rolebinding q2-dev-edit    --clusterrole=edit --user=q2-dev    -n q2-vmops
oc create rolebinding q2-viewer-view --clusterrole=view --user=q2-viewer -n q2-vmops
oc auth can-i create virtualmachines.kubevirt.io -n q2-vmops --as=q2-dev
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

#### Troubleshoot & Reset (3-Minute Rule)

> NetworkPolicies and Services apply **instantly** -- no waiting, ever. A UserDefinedNetwork
> is different: it only takes effect on VMs created **after** it exists.
>
> **#1 failure: empty endpoints = the Service selector does not match the VM labels.**

```bash
oc get svc,endpoints -n q3-app                  # ENDPOINTS <none> = selector is wrong
oc get svc q3-web -n q3-app -o jsonpath='{.spec.selector}{"\n"}'
oc get vmi -n q3-app --show-labels

oc get netpol -n q3-app
oc describe netpol <name> -n q3-app
oc get ns q3-app --show-labels                  # namespaceSelector needs kubernetes.io/metadata.name

oc get userdefinednetwork -n q3-udn
oc get vmi -n q3-udn -o wide                    # is the IP in 10.200.0.0/24?
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| `ENDPOINTS: <none>` | Selector mismatch | Use the VM's own label, e.g. `kubevirt.io/domain: q3-web` |
| Endpoints vanish after restart | Label was on the VMI only | Patch `vm.spec.template.metadata.labels` |
| Default-deny blocks allowed traffic too | Allow-rule `podSelector` matches nothing | `oc describe netpol` and compare to real labels |
| NetworkPolicy has no effect | Created in the wrong namespace | NetPol is namespaced |
| VM IP not in the UDN subnet | UDN created **after** the VM | Delete and recreate the VM |
| UDN not applied at all | Namespace missing the required label, or UDN not Ready | `oc describe userdefinednetwork <name> -n q3-udn` |

**Still broken after 3 minutes -- wipe:**
```bash
# Networking objects are instant to recreate -- delete freely
oc delete netpol --all -n q3-app
oc delete svc --all -n q3-app
# then re-apply the default-deny, the allow rule, and the Service

# Let virtctl build the Service so the selector is correct for you
virtctl expose vm q3-web --name=q3-web-svc --port=8080 --target-port=8080 -n q3-app
oc get endpoints q3-web-svc -n q3-app      # must be populated before moving on

# UDN: the network must exist BEFORE the VM
oc delete vm --all -n q3-udn
oc delete userdefinednetwork --all -n q3-udn
# re-apply the UDN, wait for it, THEN create the VM
oc get userdefinednetwork -n q3-udn
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

#### Troubleshoot & Reset (3-Minute Rule)

> An NNCP takes 30-60 seconds to roll out across nodes. Watch the **NNCE** objects (one per
> node) -- they carry the real error message, not the NNCP.

```bash
oc get nncp                                  # want: Available
oc get nnce                                  # PER NODE -- this is where failures show up
oc describe nnce <node>.<policy-name> | tail -30

oc get net-attach-def -n q4-ext
oc get vmi -n q4-ext -o wide
oc describe vmi <vm> -n q4-ext | tail -25
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| NNCE `Failed`, "interface not found" | The spare NIC name differs on that node | `oc get nns <node> -o yaml \| grep -A3 name:` to list real NICs |
| NNCP `Degraded` | Config applied then auto-rolled back (lost connectivity) | Never put the primary NIC in the bridge |
| NAD exists but VM will not start | NAD name/namespace mismatch in the VM spec | Must be `<namespace>/<nad-name>` |
| VMI `Pending`, "network not found" | NAD in a different namespace | Recreate the NAD in `q4-ext` |
| VMs up but ping fails | Static IPs not applied by cloud-init, or different subnets | `ip a` in both guests |
| No `nncp` resource type | NMState operator not installed | Install it, then create the `NMState` CR |

**Still broken after 3 minutes -- wipe:**
```bash
# 1. VMs first (they hold the NAD)
oc delete vm --all -n q4-ext
oc get vmi -n q4-ext                       # wait until empty

# 2. The NAD
oc delete net-attach-def --all -n q4-ext

# 3. The bridge -- do NOT just delete the NNCP: that leaves the bridge on the node.
#    Set the interface state to absent so it is cleanly removed first.
oc get nncp
#    edit the policy: state: absent  (on the bridge interface), apply, wait for Available
oc get nnce -w
#    then remove the policy object
oc delete nncp q4-br-policy

# 4. Confirm the node is clean, then rebuild NNCP -> NAD -> VMs in that order
oc get nns <node> -o yaml | grep -A3 "name: q4-br"     # expect nothing
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

#### Troubleshoot & Reset (3-Minute Rule)

> **The dangerous part is `/etc/fstab`.** A bad line drops the VM into emergency mode on next
> boot. **Always run `mount -a` before rebooting** -- if it errors, fix it while you still
> have a shell.

```bash
oc get dv,pvc -n q5-store
oc describe dv <name> -n q5-store | tail -20
oc get vmi <vm> -n q5-store -o yaml | grep -A6 -i hotplug
oc get sc                                   # which one is marked default?
oc get storageprofile <sc-name> -o yaml | grep -A5 claimPropertySets

# Inside the guest
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,SERIAL
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| `virtctl addvolume` "not found" | DataVolume not `Succeeded` yet | `oc get dv -n q5-store -w`, retry |
| Hot-plugged disk gone after restart | Missing `--persist` | Re-add with `--persist` |
| PVC expanded but guest still shows old size | Filesystem not grown | `xfs_growfs /data` (XFS) after the PVC resizes |
| PVC will not expand | StorageClass has `allowVolumeExpansion: false` | `oc get sc <name> -o yaml \| grep allowVolumeExpansion` |
| `mkfs` says device busy | You targeted the root disk | Root is usually `vda` -- re-check `lsblk` |
| VM boots to emergency mode | Bad fstab | Rescue steps below |
| Two default StorageClasses | Both annotated default | Remove the annotation from one |

**Still broken after 3 minutes -- detach and start the disk over:**
```bash
# 1. Unmount in the guest FIRST and remove the fstab line, or detach hangs
virtctl console <vm> -n q5-store
#   umount /data ; remove the line from /etc/fstab ; mount -a   (must be silent)
#   exit with Ctrl + ]

# 2. Detach, then delete the disk
virtctl removevolume <vm> --volume-name=<dv-name> -n q5-store
oc delete dv,pvc <dv-name> -n q5-store --ignore-not-found

# 3. Recreate, WAIT for Succeeded, re-attach
oc get dv <dv-name> -n q5-store -w
virtctl addvolume <vm> --volume-name=<dv-name> --serial=DISK1 --persist -n q5-store
```

**Rescue a VM stuck in emergency mode:**
```bash
virtctl console <vm> -n q5-store
#   enter the root password, then:
#   mount -o remount,rw /
#   vi /etc/fstab      -> fix or delete the bad line
#   mount -a           -> must produce NO output
#   reboot
# No prompt at all? Rebuilding the VM is faster than rescuing it.
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

#### Troubleshoot & Reset (3-Minute Rule)

> OADP has the most moving parts of any topic. **Diagnose in dependency order** -- there is no
> point debugging a backup if the BackupStorageLocation is not `Available`:
>
> **secret correct -> DPA created -> BSL Available -> backup -> restore**

```bash
oc get dpa -n openshift-adp
oc get backupstoragelocation -n openshift-adp     # want PHASE=Available  <-- the key one
oc get pods -n openshift-adp                      # velero + node-agent Running
oc logs -n openshift-adp deployment/velero -c velero | tail -40

alias velero='oc -n openshift-adp exec deployment/velero -c velero -it -- ./velero'
velero backup describe <name> --details
velero backup logs <name>
velero restore describe <name> --details
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| BSL `Unavailable` | Wrong bucket, credentials, or caCert in the DPA | Re-extract the real values and re-apply the DPA |
| Log: "SignatureDoesNotMatch" | Access key/secret mis-copied | Re-extract the secret |
| Backup `PartiallyFailed` | A listed resource type does not exist, or a PVC could not be snapshotted | `velero backup logs <name>` names it |
| Backup `Completed`, restore empty | `namespaceMapping` typo | `oc get all -n <target-ns>` |
| VM definition restored but disk empty | CSI data movement not enabled | `defaultSnapshotMoveData: true` + label the VolumeSnapshotClasses |
| Schedule never fires | Cron expression wrong, or schedule paused | `oc get schedule -n openshift-adp -o yaml` |
| `velero: command not found` | It is an alias into the pod | Re-run the alias line |

**Still broken after 3 minutes -- reset at the right level (do NOT reinstall the operator):**
```bash
# Level 1: the backup/restore objects (seconds) -- try this first
oc delete backup <name> -n openshift-adp --ignore-not-found
oc delete restore <name> -n openshift-adp --ignore-not-found
oc delete namespace <restore-target-ns> --ignore-not-found
# re-apply the Backup YAML

# Level 2: the DPA / storage location (1-2 min) -- when BSL is not Available
oc delete dpa <dpa-name> -n openshift-adp
oc get backupstoragelocation -n openshift-adp     # should disappear

#   Re-read the REAL values rather than retyping from memory
oc extract --to=- cm/<obc-name>     -n openshift-adp     # bucket name
oc extract --to=- secret/<obc-name> -n openshift-adp     # access + secret key
oc label volumesnapshotclass velero.io/csi-volumesnapshot-class=true --all

oc delete secret cloud-credentials -n openshift-adp --ignore-not-found
oc create secret generic cloud-credentials -n openshift-adp --from-file cloud=/tmp/cloud-credentials
# re-apply the DPA, then:
oc get backupstoragelocation -n openshift-adp -w   # wait for Available
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

#### Troubleshoot & Reset (3-Minute Rule)

> **cloud-init runs only on the FIRST boot of a fresh disk.** If your cloud-init change did
> not take effect, restarting will never help -- you must delete the VM *and its disk*.

```bash
oc get template -n <ns>
oc process --parameters -n <ns> q7-appserver        # lists the params and defaults
oc process -n <ns> q7-appserver -p NAME=web1 -p MEMORY=2Gi    # errors appear here, pre-apply

# Did cloud-init actually run inside the guest?
virtctl console <vm> -n <ns>
#   sudo cloud-init status --long
#   sudo cat /var/log/cloud-init-output.log | tail -30      <-- the real error is here
#   exit with Ctrl + ]
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| `oc apply` rejects the template: "resourceVersion should not be set" | Exported a live object and left its fields in | Delete `resourceVersion`, `uid`, `creationTimestamp`, `selfLink`, `status:` |
| `oc process` "parameter required" | Param has no default | Pass it with `-p` |
| `oc process` runs but nothing is created | Forgot to pipe | `oc process ... \| oc apply -f -` |
| cloud-init password does not work | Disk was reused | Delete the VM **and** the DV/PVC, recreate |
| httpd not installed by cloud-init | YAML indentation wrong, or no network for the package repo | `cloud-init-output.log` |
| cloud-init userdata not valid | Missing the `#cloud-config` first line | It must be the literal first line |
| Instance type not found | Namespaced vs cluster-scoped | `oc get virtualmachineclusterinstancetype` |

**Still broken after 3 minutes -- wipe:**
```bash
# Template
oc delete vm --all -n <ns>
oc delete dv,pvc --all -n <ns>              # required, or cloud-init will not re-run
oc delete template q7-appserver -n <ns> --ignore-not-found

# Re-export a clean base and strip the live-object fields
oc get template rhel9-server-small -n openshift -o yaml > /tmp/q7.yaml
vi /tmp/q7.yaml     # remove resourceVersion/uid/creationTimestamp/selfLink/status:, set name+namespace
oc apply -f /tmp/q7.yaml -n <ns>

# Re-instantiate
oc process -n <ns> q7-appserver -p NAME=web1 -p MEMORY=2Gi | oc apply -n <ns> -f -
oc get vm,dv -n <ns>

# Validate cloud-init YAML BEFORE building a VM around it
virtctl create vm --name=tmp --memory=1Gi \
  --volume-containerdisk=src:quay.io/containerdisks/fedora:latest \
  --user=cloud-user --password-file=/tmp/pw | tee /tmp/tmp-vm.yaml | head -40
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

#### Troubleshoot & Reset (3-Minute Rule)

> **A restore requires the VM to be stopped.** That is the most common failure in this topic.

```bash
oc get vmsnapshot <name> -n <ns> -o jsonpath='{.status.readyToUse}{"\n"}'
oc describe vmsnapshot <name> -n <ns> | tail -25
oc get volumesnapshot -n <ns>
oc get volumesnapshotclass                 # must exist and match the SC's CSI driver

oc get vmrestore -n <ns>
oc describe vmrestore <name> -n <ns> | tail -20
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| `readyToUse` false for <2 min | Normal | Wait |
| No VolumeSnapshotClass | Storage backend has no CSI snapshot support | `oc get volumesnapshotclass`; use a SC that has one |
| "source does not exist" | Wrong VM name/namespace in `spec.source` | `apiGroup: kubevirt.io`, `kind: VirtualMachine` |
| Restore stuck / rejected | VM is still running | `virtctl stop <vm> -n <ns>` first |
| Restored but the marker file is missing | Restored the wrong snapshot | `oc get vmsnapshot -n <ns>` and check creation times |
| Deleting a snapshot leaves a VolumeSnapshot behind | Orphan | Delete it directly |
| Wrong apiVersion rejected | Version drift | `oc api-resources \| grep -i snapshot` |

**Still broken after 3 minutes -- wipe and retake:**
```bash
oc delete vmrestore --all -n <ns>
oc delete vmsnapshot --all -n <ns>
oc get volumesnapshot -n <ns>              # delete any orphans
oc get vmsnapshot,vmrestore,volumesnapshot -n <ns>    # confirm clean

# The VM must be healthy before you can snapshot it
oc get vm,vmi -n <ns>

# Retake using the version the cluster reports
oc api-resources | grep -i virtualmachinesnapshot
# ...apply the VirtualMachineSnapshot YAML...
oc get vmsnapshot <name> -n <ns> -w        # wait for readyToUse: true

# Restore: STOP first, restore, then start
virtctl stop <vm> -n <ns>
# ...apply the VirtualMachineRestore YAML...
oc get vmrestore -n <ns> -w
virtctl start <vm> -n <ns>
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

#### Troubleshoot & Reset (3-Minute Rule)

> **The upload is slow** (whole disk, converted). `UploadScheduled` -> `UploadReady` ->
> `Succeeded` with a moving percentage is working. Start the timer only on `Failed`.

```bash
oc get dv -n <ns>                              # phase + progress
oc describe dv <name> -n <ns> | tail -25
oc get pods -n <ns> | grep -E "importer|uploader|cdi"
oc logs -n <ns> <importer-or-uploader-pod>

# Legacy-guest boot problems
oc get vmi <vm> -n <ns> -o wide
virtctl console <vm> -n <ns>                   # watch where the boot stops
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| `virtctl image-upload` hangs at "Waiting for PVC to be ready" | No default StorageClass, or PVC Pending | `oc get sc`; `oc describe pvc <name>` |
| Upload fails on TLS | Upload proxy cert not trusted | Add `--insecure` |
| `qemu-img convert` fails | Wrong VMDK extracted from the OVA | `tar tvf <ova>` then re-extract the right file |
| VM created but will not boot | Legacy guest needs SATA bus / e1000e NIC | Set `disk: bus: sata` and `interface: model: e1000e` |
| Boots to "no bootable device" | Disk attached as the wrong bus, or empty | Check the DV actually has data: `oc get pvc -n <ns>` size used |
| NodePort unreachable | Port outside 30000-32767, or selector wrong | `oc get endpoints <svc> -n <ns>` |

**Still broken after 3 minutes -- wipe and re-upload:**
```bash
# 1. Remove the VM and the half-uploaded disk
oc delete vm <vm> -n <ns> --ignore-not-found
oc delete dv,pvc <dv-name> -n <ns> --ignore-not-found
oc get pods -n <ns>                            # kill leftover uploader/importer pods
oc get dv,pvc -n <ns>                          # confirm clean

# 2. Re-verify the image on disk BEFORE uploading again (cheap, catches most failures)
tar tvf /tmp/<file>.ova
qemu-img info /tmp/<disk>.qcow2                # format must say qcow2, size must be sane

# 3. Re-upload and watch
virtctl image-upload dv <dv-name> --size=20Gi --image-path=/tmp/<disk>.qcow2 \
  --insecure -n <ns>
oc get dv <dv-name> -n <ns> -w                 # Succeeded

# 4. Only then build the VM around it
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

#### Troubleshoot & Reset (3-Minute Rule)

> **Cloning is slow (2-10 min).** `CloneInProgress` with a rising percentage is working.
> The timer starts at `Failed`, or `Pending` with no movement.

```bash
oc get dv -n <ns>                              # CloneInProgress -> Succeeded
oc describe dv <clone-name> -n <ns> | tail -25
oc get pods -n <ns> | grep -E "clone|cdi"

oc get vmclone -n <ns>
oc describe vmclone <name> -n <ns> | tail -20
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| DV `Pending`, no clone pod | StorageClass name wrong | `oc get sc`, copy exactly |
| "target is smaller than source" | Requested size < source PVC | `oc get pvc <src> -n <ns> -o jsonpath='{.spec.resources.requests.storage}{"\n"}'` |
| Clone hangs at 0% | Source PVC in use, SC cannot live-clone | `virtctl stop <source-vm>` then retry |
| "source pvc not found" | PVC name is not always the VM name | `oc get pvc -n <ns>` |
| Clones share a MAC or IP | Golden image not cleaned | Reset `machine-id`, remove SSH host keys, `cloud-init clean` **before** cloning |
| Clone boots with the source's hostname | Same cause | Same fix -- re-prepare the golden VM |

**Still broken after 3 minutes -- wipe:**
```bash
# Remove the half-finished clone
oc delete vmclone --all -n <ns>
oc delete vm <clone-vm> -n <ns> --ignore-not-found
oc delete dv,pvc <clone-name> -n <ns> --ignore-not-found
oc get dv,pvc,pods -n <ns>                     # no leftover clone pods

# Read the REAL source values instead of guessing
oc get pvc -n <ns>
oc get pvc <src> -n <ns> -o jsonpath='{.spec.storageClassName}{"\n"}'
oc get pvc <src> -n <ns> -o jsonpath='{.spec.resources.requests.storage}{"\n"}'

# Stop the source -- removes the whole "in use" class of failures
virtctl stop <source-vm> -n <ns>

# Re-prepare the golden image if clones collided (inside the guest):
#   sudo truncate -s 0 /etc/machine-id
#   sudo rm -f /etc/ssh/ssh_host_*
#   sudo cloud-init clean --logs
#   sudo shutdown -h now

# Re-apply the clone and watch
oc get dv <clone-name> -n <ns> -w              # Succeeded
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

#### Troubleshoot & Reset (3-Minute Rule)

> **Live migration needs RWX (ReadWriteMany) storage.** Check this before debugging anything
> else -- with RWO it will never work, no matter how you configure the VM.

```bash
# Capability check -- do this FIRST
oc get pvc -n <ns> -o custom-columns=NAME:.metadata.name,MODE:.spec.accessModes
oc get vmi <vm> -n <ns> -o yaml | grep -A5 -i livemigratable
#   LiveMigratable: False -> the "reason" field names the blocker

oc get vmim -n <ns>
oc describe vmim <name> -n <ns> | tail -25
oc get vmi <vm> -n <ns> -o wide                # which node now?
oc get migrationpolicy
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| `LiveMigratable: False` | RWO disk, or a non-migratable device | `oc describe vmi` gives the exact reason |
| `virtctl migrate` "already running" | A previous VMIM still exists | `oc delete vmim --all -n <ns>` |
| Migration starts then fails repeatedly | Target node short on memory | `oc describe node <target>` |
| Migration never completes | Guest dirtying memory faster than the link copies | Raise bandwidth in the MigrationPolicy, or stop/start instead |
| Cancel does nothing | Cancel = delete the VMIM object | `oc delete vmim <name> -n <ns>` |
| MigrationPolicy ignored | Its selector matches no VM/namespace | `oc get migrationpolicy <name> -o yaml` and compare labels |

**Still broken after 3 minutes -- clear migrations and reset:**
```bash
# 1. Migration objects are just records -- safe to delete
oc delete vmim --all -n <ns>

# 2. Un-cordon anything left over from testing
oc get nodes                                   # look for SchedulingDisabled
oc adm uncordon <node>

# 3. Hard restart the VM so it reschedules cleanly
virtctl stop <vm> -n <ns> --force --grace-period=0
virtctl start <vm> -n <ns>
oc get vmi <vm> -n <ns> -o wide -w

# 4. Re-apply evictionStrategy, then restart so it takes effect
oc patch vm <vm> -n <ns> --type merge \
  -p '{"spec":{"template":{"spec":{"evictionStrategy":"LiveMigrate"}}}}'
virtctl restart <vm> -n <ns>
oc get vmi <vm> -n <ns> -o yaml | grep -A5 -i livemigratable    # must be True

# 5. If the storage is RWO, the VM is simply not live-migratable.
#    Rebuild it on an RWX StorageClass -- there is no config that works around this.
oc get sc
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

#### Troubleshoot & Reset (3-Minute Rule)

> Cordon/uncordon is instant. A **drain** is not -- it can legitimately take minutes while VMs
> migrate off. Watch it rather than killing it.

```bash
oc get nodes                                   # Ready,SchedulingDisabled
oc get nodemaintenance                         # if using the NodeMaintenance CR
oc describe nodemaintenance <name> | tail -20
oc get vmi -A -o wide                          # what is still on that node?
oc get pods -A --field-selector spec.nodeName=<node> | head -20
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| No `nodemaintenance` resource type | Node Maintenance Operator not installed | Install it, or use `oc adm cordon/drain` instead |
| NodeMaintenance stuck in `Running` | A pod/VM will not evict | `oc describe nodemaintenance <name>` names it |
| Node still `SchedulingDisabled` after deleting the CR | Cordon left behind | `oc adm uncordon <node>` |
| `oc adm drain` hangs on a VM | No `evictionStrategy: LiveMigrate`, or RWO storage | Patch the VM, or stop it and drain again |
| Drain refuses: local storage / daemonsets | Missing flags | `--ignore-daemonsets --delete-emptydir-data --force` |
| VMs died instead of migrating | RWO storage | Expected with RWO |

**Still stuck after 3 minutes -- reset the node state:**
```bash
# Remove the maintenance CR, then clear the cordon by hand
oc delete nodemaintenance --all
oc adm uncordon <node>
oc get nodes                                   # every node should read just "Ready"

# A wedged drain: Ctrl+C, uncordon, stop the blocking VM, retry
oc adm uncordon <node>
oc get vmi -A -o wide | grep <node>
virtctl stop <vm> -n <ns>                      # stopping is always allowed
oc adm drain <node> --ignore-daemonsets --delete-emptydir-data --force --timeout=10m

# Make VMs drain-friendly BEFORE the next attempt
oc patch vm <vm> -n <ns> --type merge \
  -p '{"spec":{"template":{"spec":{"evictionStrategy":"LiveMigrate"}}}}'
virtctl restart <vm> -n <ns>
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

#### Troubleshoot & Reset (3-Minute Rule)

> Instant to apply. **Empty endpoints is still the #1 problem** -- fix that before touching
> the Route.

```bash
oc get svc,endpoints -n <ns>                   # ENDPOINTS <none> = selector wrong
oc get svc <name> -n <ns> -o jsonpath='{.spec.selector}{"\n"}'
oc get vmi -n <ns> --show-labels

oc get route -n <ns> -o wide
oc describe route <name> -n <ns> | tail -20
curl -vk https://<hostname>
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| `ENDPOINTS: <none>` | Selector does not match the VM labels | Use `kubevirt.io/domain: <vm-name>` |
| Route returns 503 | No endpoints behind the Service | Fix the selector first |
| HTTP not redirecting to HTTPS | Missing insecure policy | `--insecure-policy=Redirect` on `oc create route edge` |
| Route hostname rejected | Already used by another route | `oc get route -A \| grep <hostname>` |
| `telnet <route> 22` fails | **Routes are HTTP/TLS only -- they cannot carry SSH** | Use a NodePort for 22 |
| NodePort rejected | Outside 30000-32767, or taken | `oc get svc -A \| grep <port>` |
| Labels lost after VM restart | Labelled the VMI only | Patch `vm.spec.template.metadata.labels` |

**Still broken after 3 minutes -- wipe and redo:**
```bash
oc delete route --all -n <ns>
oc delete svc --all -n <ns>

# Let virtctl set the selector for you -- removes the most common mistake
virtctl expose vm <vm> --name=<vm>-svc --port=8080 --target-port=8080 -n <ns>
oc get endpoints <vm>-svc -n <ns>              # MUST be populated before continuing

# Then the edge route
oc create route edge <vm>-route --service=<vm>-svc \
  --hostname=<host>.apps.ocp4.example.com --insecure-policy=Redirect -n <ns>
curl -vk https://<host>.apps.ocp4.example.com

# SSH is a separate NodePort service -- not a route
oc create service nodeport <vm>-ssh --tcp=22:22 --node-port=30022 -n <ns>
oc patch svc <vm>-ssh -n <ns> --type merge \
  -p '{"spec":{"selector":{"kubevirt.io/domain":"<vm>"}}}'
oc get endpoints <vm>-ssh -n <ns>
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

#### Troubleshoot & Reset (3-Minute Rule)

> **A probe only takes effect after `virtctl restart`.** If nothing changed, you probably just
> forgot the restart.
>
> **Danger:** a liveness probe on a port nothing is listening on reboots the VM every
> `periodSeconds`. If the VM is restart-looping, remove the probe first, then fix the guest.

```bash
oc get vm  <vm> -n <ns> -o yaml | grep -A10 -i probe      # is it in the spec?
oc get vmi <vm> -n <ns> -o yaml | grep -A10 -i probe      # is it in the RUNNING instance?
oc get vmi -n <ns> -w                                     # restart-looping?
oc get endpoints <svc> -n <ns>                            # readiness controls this
oc describe vmi <vm> -n <ns> | tail -25
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| Probe in `vm` but not `vmi` | Not restarted | `virtctl restart <vm> -n <ns>` |
| Patch rejected "unknown field" | Nested under `domain:` | Probes live at `spec.template.spec`, a sibling of `domain` |
| VM restarts every ~2 min | Liveness probe failing | Remove the probe, start the listener, re-add |
| VM NotReady but service is up | `initialDelaySeconds` shorter than boot | Raise it (100s is safe) |
| Endpoint never returns after restarting the listener | Readiness probe path/port wrong | `curl localhost:8080/...` inside the guest |
| Watchdog does nothing | Device added but no guest daemon | Install/enable the watchdog daemon in the guest |

**Still broken after 3 minutes -- strip the probes and rebuild:**
```bash
# Remove both probes (json "remove" op) -- stops any reboot loop
oc patch vm <vm> -n <ns> --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/livenessProbe"}]'
oc patch vm <vm> -n <ns> --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/readinessProbe"}]'
oc get vm <vm> -n <ns> -o yaml | grep -i probe      # expect no output
virtctl restart <vm> -n <ns>

# Confirm something is ACTUALLY listening before re-adding a liveness probe
virtctl console <vm> -n <ns>
#   ss -tlnp | grep 8080
#   curl -s localhost:8080/ >/dev/null && echo OK
#   exit with Ctrl + ]

# Re-apply, then restart again
oc patch vm/<vm> --type=merge --patch-file=/tmp/probes.yaml -n <ns>
virtctl restart <vm> -n <ns>
oc get endpoints <svc> -n <ns> -w
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

#### Troubleshoot & Reset (3-Minute Rule)

> Scheduling rules only apply **when the VM starts**. Patching a running VM changes nothing
> until you restart it.
>
> **Clean up taints and labels when you are done** -- a leftover taint silently breaks every
> later question on that node.

```bash
oc get vmi -n <ns> -o wide                     # are the two VMs on different nodes?
oc describe pod -n <ns> virt-launcher-<vm>-xxxxx | tail -25    # names the failed constraint

oc get nodes --show-labels
oc describe node <node> | grep -i -A3 taint
oc get vm <vm> -n <ns> -o yaml | grep -A10 -E "affinity|toleration|nodeSelector"
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| VMI `Pending`, "didn't match pod anti-affinity" | Only one schedulable node left | `oc get nodes`; uncordon, or accept it with 2 workers |
| VMI `Pending`, "had untolerated taint" | Toleration key/value/effect does not match exactly | Compare all three against `oc describe node` |
| VMI `Pending`, "didn't match node selector" | Label missing on the node | `oc get nodes -l <key>=<value>` -- empty means fix the label |
| Anti-affinity ignored | Used `preferred` instead of `required` | `requiredDuringSchedulingIgnoredDuringExecution` |
| Anti-affinity matches nothing | `labelSelector` does not match the VM's own pod labels | Label must be in `vm.spec.template.metadata.labels` |
| Everything breaks in later questions | Taint left on a node | Remove it (below) |

**Still broken after 3 minutes -- wipe:**
```bash
# 1. Remove the VMs
oc delete vm --all -n <ns>
oc get vmi -n <ns>                             # wait until empty

# 2. Clean the node back to neutral -- trailing "-" removes a label or taint
oc adm taint nodes <node> <key>-
oc label nodes <node> <key>-
oc describe node <node> | grep -i -A3 taint    # expect <none>
oc get nodes --show-labels | grep <key>        # expect nothing

# 3. Re-apply label + taint and PROVE they took before recreating VMs
oc label nodes <node> <key>=<value> --overwrite
oc adm taint nodes <node> <key>=<value>:NoSchedule
oc get nodes -l <key>=<value>                  # must list the node

# 4. Recreate the VMs, then verify placement
oc get vmi -n <ns> -o wide
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

#### Troubleshoot & Reset (3-Minute Rule)

> Here "start over" means **restart the VM**, not delete it. Only rebuild the VM if you broke
> the boot (bad `/etc/fstab`, removed a system package, broke SELinux).
>
> **`systemctl status` is only the headline. `journalctl -xeu <unit>` is the actual error.**

```bash
# Getting in
oc get vmi -n <ns>                             # must be Running
virtctl console <vm> -n <ns>                   # blank? press Enter. Exit: Ctrl + ]

# Inside the guest -- the real diagnostic order
systemctl status <unit>
journalctl -xeu <unit> | tail -30              # <-- the actual error lives here
systemd-analyze verify /etc/systemd/system/<unit>.service
systemctl list-units --failed
ss -tlnp
df -h
```

| Symptom | Cause | Fix |
|:---|:---|:---|
| Ctrl+C will not exit the console | Wrong key | **Ctrl + ]** |
| Service "active" but dead after reboot | `start` without `enable` | `systemctl enable --now <unit>`; check `systemctl is-enabled` |
| Edited a unit file, nothing changed | systemd has not re-read it | `systemctl daemon-reload` first |
| Unit fails instantly, status unhelpful | Typo in `ExecStart` | `journalctl -xeu <unit>` prints the bad path |
| Drop-in override ignored | Wrong location or name | `/etc/systemd/system/<unit>.service.d/override.conf`, then `daemon-reload` |
| `yum`/`dnf` fails, no repos | Repo file missing | Re-add the repo file |
| VM boots to emergency mode | Bad `/etc/fstab` | Rescue below |

**Still broken after 3 minutes -- escalate in this order:**
```bash
# Level 1: reload systemd and retry (most "it didn't take" problems)
systemctl daemon-reload
systemctl restart <unit>
systemctl status <unit>

# Level 2: reset the unit's failure state
systemctl reset-failed <unit>
systemctl enable --now <unit>

# Level 3: throw away your override and start from the shipped unit
rm -rf /etc/systemd/system/<unit>.service.d/
systemctl daemon-reload
systemctl restart <unit>

# Level 4: reinstall the package (restores the original unit file and config)
dnf reinstall -y <package>

# Level 5: restart the whole guest
exit                                           # Ctrl + ] to leave the console
virtctl restart <vm> -n <ns>

# Level 6: the guest is unbootable -- rebuild the VM (Topic 2 reset block)
```

**Rescue a VM stuck in emergency mode:**
```bash
virtctl console <vm> -n <ns>
#   enter the root password, then:
#   mount -o remount,rw /
#   vi /etc/fstab      -> fix or delete the bad line
#   mount -a           -> must produce NO output
#   reboot
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
