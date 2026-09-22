# Command drill: answers

Matches the numbering in `drill-blanks.md`. Minor flag variations are fine as
long as the object type and verb are right.

## 1. Operator
1. `oc get packagemanifest kubevirt-hyperconverged -n openshift-marketplace -o jsonpath='{.status.defaultChannel}{"\n"}'`
2. `oc get csv -n openshift-cnv`
3. `oc wait hco/kubevirt-hyperconverged -n openshift-cnv --for=condition=Available --timeout=20m`
4. `oc get consoleclidownload virtctl-clidownload-kubevirt-hyperconverged -o jsonpath='{.spec.links[*].href}{"\n"}'`

## 2. VM access
1. `virtctl create vm --name <n> --instancetype u1.medium --preference fedora --volume-containerdisk src:quay.io/containerdisks/fedora:latest | oc apply -n <ns> -f -`
2. `virtctl pause vm <vm> -n <ns>` then `virtctl unpause vm <vm> -n <ns>`
3. `oc patch vm <vm> -n <ns> --type merge -p '{"spec":{"runStrategy":"Halted"}}'`
4. `virtctl console <vm> -n <ns>` — exit with `Ctrl+]`
5. `virtctl ssh cloud-user@vmi/<vm> -n <ns>`
6. `oc adm policy add-role-to-user kubevirt.io:edit <user> -n <ns>`
7. `oc auth can-i update virtualmachines.subresources.kubevirt.io --subresource=start -n <ns> --as=<user>`

## 3. Networking
1. `oc get vmi <vm> -n <ns> -o jsonpath='{.status.interfaces[*].ipAddress}{"\n"}'`
2. `oc run tester -n <ns> --image=registry.access.redhat.com/ubi9/ubi --restart=Never -- sleep infinity`
3. `oc explain networkpolicy.spec.ingress.from`
4. `virtctl expose vm <vm> --name <svc> --port 80 --target-port 8080 -n <ns>`
5. `oc get userdefinednetwork -n <ns>`

## 4. External networks
1. `oc get nns` then `oc get nns <node> -o jsonpath='{.status.currentState.interfaces[*].name}{"\n"}'`
2. `oc get nncp` and `oc get nnce`
3. `oc describe nnce <node>.<policy>`
4. `virtctl ssh cloud-user@vmi/<vm> -n <ns> -c 'ip -br a'`

## 5. Storage
1. `oc annotate sc <name> storageclass.kubevirt.io/is-default-virt-class=true --overwrite`
2. `oc explain datavolume.spec.storage`
3. `virtctl addvolume <vm> --volume-name=<pvc> --serial=<s> --persist -n <ns>`
4. `virtctl removevolume <vm> --volume-name=<pvc> --persist -n <ns>`
5. `virtctl image-upload dv <name> --size=2Gi --image-path=<file> --insecure -n <ns>`
6. `oc patch pvc <pvc> -n <ns> --type merge -p '{"spec":{"resources":{"requests":{"storage":"8Gi"}}}}'`
7. `sudo xfs_growfs /data` (mount point, not device)

## 6. OADP
1. `oc get backupstoragelocation -n openshift-adp`
2. `oc label volumesnapshotclass <name> velero.io/csi-volumesnapshot-class=true`
3. `oc get backup.velero.io <name> -n openshift-adp -o jsonpath='{.status.phase}{"\n"}'`
4. `alias velero='oc -n openshift-adp exec deployment/velero -c velero -it -- ./velero'`
5. `velero backup describe <name> --details`

## 7. Templates and cloud-init
1. `oc get template -n openshift -l template.kubevirt.io/type=vm`
2. `oc process --parameters -n openshift <template>`
3. `oc process -n openshift <template> -p NAME=<n> | oc apply -n <ns> -f -`
4. `oc get virtualmachineclusterinstancetype` and `oc get virtualmachineclusterpreference`

## 8. Snapshots
1. `oc get vmsnapshot <name> -n <ns> -o jsonpath='{.status.readyToUse}{"\n"}'`
2. `oc get volumesnapshot,volumesnapshotcontent -n <ns>`
3. `oc get vmrestore <name> -n <ns> -o jsonpath='{.status.complete}{"\n"}'`

## 9. Migration/import
1. `tar -tvf vm.ova`
2. `qemu-img info disk1.vmdk`
3. `qemu-img convert -f vmdk -O qcow2 disk1.vmdk disk1.qcow2`
4. `oc get plan,migration,networkmap,storagemap -n openshift-mtv`

## 10. Cloning
1. `sudo truncate -s 0 /etc/machine-id`
2. `sudo rm -f /etc/ssh/ssh_host_*`
3. `sudo cloud-init clean --logs`
4. `oc api-resources | grep clone.kubevirt.io`
5. `oc get vmclone <name> -n <ns> -o jsonpath='{.status.phase}{"\n"}'`

## 11. Live migration
1. `oc get vmi <vm> -n <ns> -o jsonpath='{.status.conditions[?(@.type=="LiveMigratable")].status}{"\n"}'`
2. `virtctl migrate <vm> -n <ns>`
3. `virtctl migrate-cancel <vm> -n <ns>`
4. `oc get vmi <vm> -n <ns> -o jsonpath='{.status.migrationState}{"\n"}'`
5. `oc patch hco kubevirt-hyperconverged -n openshift-cnv --type merge -p '{"spec":{"liveMigrationConfig":{"parallelMigrationsPerCluster":10}}}'`

## 12. Node maintenance
1. `oc adm cordon <node>`
2. `oc adm drain <node> --ignore-daemonsets --delete-emptydir-data --force`
3. `oc adm uncordon <node>`
4. `oc get node <node> -o jsonpath='{.spec.unschedulable}{"\n"}'`

## 13. Load balancing
1. `virtctl expose vm <vm> --name <svc> --port 80 --target-port 8080 --type NodePort -n <ns>`
2. `oc create route edge <route> --service <svc> --hostname <host> --insecure-policy Redirect -n <ns>`
3. `oc get route <route> -n <ns> -o jsonpath='{.spec.host}{"\n"}'`

## 14. Health probes
1. `oc explain vm.spec.template.spec.readinessProbe`
2. `oc get vmi <vm> -n <ns> -o jsonpath='{.status.conditions[?(@.type=="Ready")]}{"\n"}'`
3. `oc patch vm <vm> -n <ns> --type merge -p '{"spec":{"runStrategy":"Always"}}'`

## 15. Node failure
1. `oc adm taint node <node> lab/dedicated=vm:NoSchedule`
2. `oc adm taint node <node> lab/dedicated=vm:NoSchedule-`
3. `oc explain vm.spec.template.spec.evictionStrategy`
4. `oc get nodehealthcheck`

## 16. Guest sysadmin
1. `sudo systemctl enable --now <unit>`
2. `systemctl is-enabled <unit>` and `systemctl is-active <unit>`
3. `systemctl list-units --failed`
4. `sudo systemctl edit <unit>`
5. `journalctl -u <unit> -b --no-pager | tail -20`
6. `rpm -qf /path/to/file`
7. `sudo dnf config-manager --set-disabled <repoid>`
8. `virtctl guestfs <pvc-or-dv-name> -n <ns>` (VM must be stopped first)
