# Troubleshooting a stuck operator install (CNV / HyperConverged)

Use this when a Subscription or CSV sits without progressing, or the
HyperConverged CR never reports `Available`. Budget about 3 minutes of
diagnosis before falling back to the clean-slate reinstall in Section 5 —
under exam time pressure, rebuilding is usually faster than root-causing.

## 1. Find what's actually stuck
```bash
oc get subscription kubevirt-hyperconverged -n openshift-cnv -o yaml | grep -A5 conditions
oc get installplan -n openshift-cnv
oc get csv -n openshift-cnv
```

| Symptom | Likely cause | Where to look |
|---|---|---|
| Subscription has no `installPlanRef` | Bad channel/package name, or CatalogSource unhealthy | Section 2 |
| InstallPlan phase `Failed` | Resource conflict, quota, or RBAC issue | `oc describe installplan <name> -n openshift-cnv` |
| CSV stuck `Pending`/`InstallReady` | InstallPlan not approved (Manual approval) | `oc patch installplan <name> -n openshift-cnv --type merge -p '{"spec":{"approved":true}}'` |
| CSV stuck `Installing` | A deployment inside the CSV isn't coming up | `oc get pods -n openshift-cnv` then `oc describe pod <pending-pod>` |
| CSV `Failed` with a message | Usually literal — read it | `oc get csv <name> -n openshift-cnv -o jsonpath='{.status.message}'` |

## 2. Check the CatalogSource — the #1 cause
```bash
oc get catalogsource -n openshift-marketplace
oc get pods -n openshift-marketplace | grep redhat-operators
oc logs -n openshift-marketplace <redhat-operators-pod> | tail -30
```
If that pod is `CrashLoopBackOff` or not `Running`, nothing downstream will
ever resolve — packagemanifests can still look present while subscriptions
silently never progress. Fix: `oc delete pod -n openshift-marketplace <pod>`
and let it restart, or delete/recreate the CatalogSource if it doesn't
recover.

## 3. Check for a leftover OperatorGroup — the #2 cause
Only one OperatorGroup is allowed per namespace. A leftover or
wrongly-scoped one from a previous attempt causes a Subscription to sit
with no clear error.
```bash
oc get operatorgroup -n openshift-cnv
```
More than one, or the wrong `targetNamespaces` → delete and recreate.

## 4. Check for resource or webhook issues
```bash
oc get events -n openshift-cnv --sort-by=.lastTimestamp | tail -20
oc get validatingwebhookconfiguration | grep -i kubevirt
```
A stuck webhook left over from a half-removed previous install can silently
reject the CSV's own objects.

## 5. Fastest clean-slate reinstall
```bash
oc delete hyperconverged --all -n openshift-cnv --ignore-not-found
oc delete subscription kubevirt-hyperconverged -n openshift-cnv --ignore-not-found
oc delete csv -n openshift-cnv -l operators.coreos.com/kubevirt-hyperconverged.openshift-cnv --ignore-not-found
oc delete operatorgroup --all -n openshift-cnv --ignore-not-found
oc delete installplan --all -n openshift-cnv --ignore-not-found
oc delete namespace openshift-cnv --ignore-not-found
oc wait --for=delete namespace/openshift-cnv --timeout=120s

oc create namespace openshift-cnv
oc label namespace openshift-cnv openshift.io/cluster-monitoring=true

CH=$(oc get packagemanifest kubevirt-hyperconverged -n openshift-marketplace -o jsonpath='{.status.defaultChannel}')

cat <<EOF2 | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: kubevirt-hyperconverged-group
  namespace: openshift-cnv
spec:
  targetNamespaces: ["openshift-cnv"]
---
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
EOF2

oc get csv -n openshift-cnv -w
```
Watch the CSV move `Pending → InstallReady → Installing → Succeeded`
(typically 2-4 minutes). If it sits at `Pending` for more than ~60 seconds
with no InstallPlan appearing, go back to Section 2 rather than waiting.

Equivalent one-liner using the setup script: `./scripts/setup-all.sh --clean`
(runs this same teardown before reinstalling everything, not just CNV).

## 6. Once the CSV is Succeeded, create the HCO — and watch it, don't fire-and-forget
```bash
cat <<EOF2 | oc apply -f -
apiVersion: hco.kubevirt.io/v1beta1
kind: HyperConverged
metadata:
  name: kubevirt-hyperconverged
  namespace: openshift-cnv
spec: {}
EOF2

oc wait hco/kubevirt-hyperconverged -n openshift-cnv --for=condition=Available --timeout=15m
```
If this hangs, it's usually one specific component pod, not the HCO object
itself:
```bash
oc get pods -n openshift-cnv --field-selector=status.phase!=Running
oc describe pod <the-one-that's-not-ready> -n openshift-cnv
```
`virt-operator`, `cdi-operator`, and `ssp-operator` are the three most
likely holdups — describe whichever isn't `Running`/`Ready` and check its
events for an image pull issue or a resource limit.

## The one habit that prevents most of this
Never hand-type or half-remember the channel. Look it up every time:
```bash
oc get packagemanifest kubevirt-hyperconverged -n openshift-marketplace -o jsonpath='{.status.defaultChannel}{"\n"}'
```
