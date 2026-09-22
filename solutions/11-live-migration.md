# Solution: Objective 11 (matches questions/11-live-migration.md)

## Task 1: namespace, migratable VM
```bash
oc create namespace q11-migr
```
VM `q11-vm` needs `dataVolumeTemplates[0].spec.storage.accessModes: [ReadWriteMany]`,
`volumeMode: Block`, and `spec.template.spec.evictionStrategy: LiveMigrate`
(see `labs/11-live-migration/01-vm-rwx-block.yaml`). If the default
StorageClass is not RWX, add `storageClassName: <rwx-class>`.

## Task 2: confirm LiveMigratable
```bash
oc get vmi q11-vm -n q11-migr \
  -o jsonpath='{.status.conditions[?(@.type=="LiveMigratable")].status}{"\n"}'
```

## Task 3-4: migrate and confirm
```bash
NODE_BEFORE=$(oc get vmi q11-vm -n q11-migr -o jsonpath='{.status.nodeName}')
# in another terminal: continuous ping/curl against the VM to watch for drops
virtctl migrate q11-vm -n q11-migr
oc get vmim -n q11-migr -w    # watch until Succeeded
NODE_AFTER=$(oc get vmi q11-vm -n q11-migr -o jsonpath='{.status.nodeName}')
[ "$NODE_BEFORE" != "$NODE_AFTER" ] && echo "moved: $NODE_BEFORE -> $NODE_AFTER"
```

## Task 5: cancel a migration
```bash
virtctl migrate q11-vm -n q11-migr
virtctl migrate-cancel q11-vm -n q11-migr
oc get vmi q11-vm -n q11-migr -o jsonpath='{.status.nodeName}{"\n"}'   # unchanged
```

## Task 6: MigrationPolicy
```bash
oc label namespace q11-migr migration-policy=q11
cat <<EOF2 | oc apply -f -
apiVersion: migrations.kubevirt.io/v1alpha1
kind: MigrationPolicy
metadata: {name: q11-policy}
spec:
  allowPostCopy: false
  bandwidthPerMigration: 32Mi
  selectors:
    namespaceSelector: {migration-policy: q11}
EOF2
```

## Task 7: cluster-wide parallel migrations
```bash
oc patch hco kubevirt-hyperconverged -n openshift-cnv --type merge \
  -p '{"spec":{"liveMigrationConfig":{"parallelMigrationsPerCluster":8}}}'
```
