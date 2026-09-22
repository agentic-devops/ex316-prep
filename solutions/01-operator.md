# Solution: Objective 1 (matches questions/01-operator.md)

## Task 1: install from the CLI
```bash
CH=$(oc get packagemanifest kubevirt-hyperconverged -n openshift-marketplace \
      -o jsonpath='{.status.defaultChannel}')
echo "channel: $CH"

oc create namespace openshift-cnv
oc label namespace openshift-cnv openshift.io/cluster-monitoring=true

cat <<EOF2 | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: kubevirt-hyperconverged-group
  namespace: openshift-cnv
spec:
  targetNamespaces:
    - openshift-cnv
EOF2

cat <<EOF2 | oc apply -f -
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

oc get csv -n openshift-cnv -w   # Ctrl+C once it shows Succeeded
```

## Task 2: HyperConverged CR
```bash
cat <<EOF2 | oc apply -f -
apiVersion: hco.kubevirt.io/v1beta1
kind: HyperConverged
metadata:
  name: kubevirt-hyperconverged
  namespace: openshift-cnv
spec: {}
EOF2

oc wait hco/kubevirt-hyperconverged -n openshift-cnv \
  --for=condition=Available --timeout=20m
```

## Task 3: virtctl download URL
```bash
oc get consoleclidownload virtctl-clidownload-kubevirt-hyperconverged \
  -o jsonpath='{.spec.links[*].href}{"\n"}'
```

## Grading yourself
```bash
oc get csv -n openshift-cnv | grep -i succeeded
oc get hco kubevirt-hyperconverged -n openshift-cnv \
  -o jsonpath='{.status.conditions[?(@.type=="Available")].status}{"\n"}'
```
Both should be affirmative (`Succeeded`, `True`) before you consider the task done.
