# setup/

One-time cluster preparation. Order: CNV -> NMState -> OADP -> (optional) MTV.

## Prerequisites
- OCP 4.18 cluster with `cluster-admin`
- Bare-metal workers, or nested virtualization. If neither is available, use the lab-only emulation switch below.
- A default StorageClass. For live migration, use one that supports RWX + Block volumes (ODF `ocs-storagecluster-ceph-rbd` is ideal).

## Quick start
```bash
./scripts/setup-all.sh
./scripts/verify-setup.sh
```

## Look up channels manually (exam skill)
```bash
oc get packagemanifest kubevirt-hyperconverged -n openshift-marketplace \
  -o jsonpath='{.status.defaultChannel}{"\n"}'
oc get packagemanifest redhat-oadp-operator -n openshift-marketplace \
  -o jsonpath='{range .status.channels[*]}{.name}{"\n"}{end}'
```

## Lab-only: software emulation (no nested virt)
Never use this in the real exam. VMs will be very slow.
```bash
oc annotate hyperconverged kubevirt-hyperconverged -n openshift-cnv --overwrite \
  kubevirt.kubevirt.io/jsonpatch='[{"op":"add","path":"/spec/configuration/developerConfiguration","value":{"useEmulation":true}}]'
```

## Useful HyperConverged tweaks
```bash
# view live migration settings
oc get hco kubevirt-hyperconverged -n openshift-cnv -o jsonpath='{.spec.liveMigrationConfig}{"\n"}'
# raise parallel migrations per cluster
oc patch hco kubevirt-hyperconverged -n openshift-cnv --type merge \
  -p '{"spec":{"liveMigrationConfig":{"parallelMigrationsPerCluster":10}}}'
```

## Drill: install the operator from the CLI, from memory
Objective 1. Target time: under 3 minutes.
1. Namespace `openshift-cnv`
2. OperatorGroup targeting that namespace
3. Subscription (`kubevirt-hyperconverged`, `stable`, `redhat-operators`)
4. Wait for the CSV: `oc get csv -n openshift-cnv -w`
5. Create the `HyperConverged` CR named `kubevirt-hyperconverged`
6. Wait: `oc wait hco kubevirt-hyperconverged -n openshift-cnv --for=condition=Available --timeout=15m`
