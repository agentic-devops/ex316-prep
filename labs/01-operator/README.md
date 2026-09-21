# Lab 01: OpenShift Virtualization operator

Objective 1: know the components, deploy the operator via OLM.

## Component map (know what each one does)
| Component | Role |
|-----------|------|
| `hco-operator` / HyperConverged CR | Top-level operator; one CR (`kubevirt-hyperconverged`) configures everything below |
| `virt-operator` | Installs and updates KubeVirt components |
| `virt-api` | API server extension: VM subresources (console, vnc, start, stop, migrate), validation webhooks |
| `virt-controller` | Watches VM/VMI objects and creates `virt-launcher` pods |
| `virt-handler` (DaemonSet) | Node agent; manages VMIs on its node, drives migrations |
| `virt-launcher` (pod per VMI) | Runs libvirt + QEMU for one VM |
| CDI (`cdi-*`) | Containerized Data Importer: DataVolumes, imports, uploads, clones |
| SSP operator | Common templates, instance types, preferences, golden images |
| cluster-network-addons | Multus, linux bridge CNI, macvtap and related |

## Task drills
1. Install the operator from the CLI (namespace, OperatorGroup, Subscription, HyperConverged CR). Target: under 3 minutes. Reference: `setup/README.md`.
2. Identify which component is responsible when: a VM will not schedule, a live migration hangs, a DataVolume import stalls.
3. Locate and download `virtctl` from the cluster.

## Must-know commands
```bash
oc get packagemanifest kubevirt-hyperconverged -n openshift-marketplace \
  -o jsonpath='{.status.defaultChannel}{"\n"}'
oc get csv -n openshift-cnv
oc get pods -n openshift-cnv
oc get hco kubevirt-hyperconverged -n openshift-cnv -o yaml
oc get kubevirt,cdi,ssp -A
oc get crd | grep -E 'kubevirt|cdi'
oc explain hyperconverged.spec
oc get consoleclidownload virtctl-clidownload-kubevirt-hyperconverged \
  -o jsonpath='{.spec.links[*].href}{"\n"}'
oc get vm,vmi -A
oc get nodes -l kubevirt.io/schedulable=true
```
