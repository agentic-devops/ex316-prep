# Master command reference (EX316, OCP 4.18)

Grouped by objective. This is the condensed drill list; the labs' READMEs have
the full context and gotchas. Practice each block until it takes no thought.

## 1. Deploy the OpenShift Virtualization operator
```bash
oc get packagemanifest kubevirt-hyperconverged -n openshift-marketplace -o jsonpath='{.status.defaultChannel}{"\n"}'
oc get csv -n openshift-cnv
oc get pods -n openshift-cnv
oc get hco kubevirt-hyperconverged -n openshift-cnv -o yaml
oc wait hco/kubevirt-hyperconverged -n openshift-cnv --for=condition=Available --timeout=20m
oc get kubevirt,cdi,ssp -A
oc get consoleclidownload virtctl-clidownload-kubevirt-hyperconverged -o jsonpath='{.spec.links[*].href}{"\n"}'
oc get crd | grep -E 'kubevirt|cdi'
```

## 2. Run and access virtual machines
```bash
virtctl create vm --name <n> --instancetype u1.medium --preference fedora \
  --volume-containerdisk src:quay.io/containerdisks/fedora:latest | oc apply -n <ns> -f -
oc get vm,vmi -n <ns>
virtctl start <vm> -n <ns>
virtctl stop <vm> -n <ns>
virtctl restart <vm> -n <ns>
virtctl pause vm <vm> -n <ns>
virtctl unpause vm <vm> -n <ns>
oc patch vm <vm> -n <ns> --type merge -p '{"spec":{"runStrategy":"Halted"}}'
virtctl console <vm> -n <ns>                 # exit: Ctrl+]
virtctl vnc <vm> -n <ns>
virtctl ssh cloud-user@vmi/<vm> -n <ns>
virtctl port-forward vmi/<vm> 2222:22 -n <ns>
oc adm policy add-role-to-user kubevirt.io:edit <user> -n <ns>
oc adm policy add-role-to-user kubevirt.io:view <user> -n <ns>
oc auth can-i create virtualmachines.kubevirt.io -n <ns> --as=<user>
oc auth can-i update virtualmachines.subresources.kubevirt.io --subresource=start -n <ns> --as=<user>
```

## 3. Kubernetes networking for VMs
```bash
oc get vmi -n <ns> -o wide
oc get vmi <vm> -n <ns> -o jsonpath='{.status.interfaces[*].ipAddress}{"\n"}'
oc run tester -n <ns> --image=registry.access.redhat.com/ubi9/ubi --restart=Never -- sleep infinity
oc exec -n <ns> tester -- curl -sm3 http://<ip>:8080
oc get networkpolicy -n <ns>
oc describe networkpolicy <name> -n <ns>
oc explain networkpolicy.spec.ingress.from
virtctl expose vm <vm> --name <svc> --port 80 --target-port 8080 -n <ns>
oc get svc,endpoints -n <ns>
oc get userdefinednetwork -n <ns>
oc explain userdefinednetwork.spec.layer2
oc get net-attach-def -n <ns>
```

## 4. External networks (Multus, NMState)
```bash
oc get nmstate
oc get nns
oc get nns <node> -o jsonpath='{.status.currentState.interfaces[*].name}{"\n"}'
oc get nncp
oc get nnce
oc describe nnce <node>.<policy>
oc get nncp <policy> -o jsonpath='{.status.conditions[*].type}{"\n"}'
oc get net-attach-def -n <ns>
oc describe net-attach-def <name> -n <ns>
oc explain nncp.spec.desiredState
virtctl ssh cloud-user@vmi/<vm> -n <ns> -c 'ip -br a'
```

## 5. Kubernetes storage for VMs
```bash
oc get sc
oc annotate sc <name> storageclass.kubevirt.io/is-default-virt-class=true --overwrite
oc get storageprofile <sc> -o yaml
oc get dv,pvc -n <ns>
oc describe dv <name> -n <ns>
oc explain datavolume.spec.storage
virtctl addvolume <vm> --volume-name=<pvc> --serial=<s> --persist -n <ns>
virtctl removevolume <vm> --volume-name=<pvc> --persist -n <ns>
virtctl image-upload dv <name> --size=2Gi --image-path=<file> --insecure -n <ns>
oc patch pvc <pvc> -n <ns> --type merge -p '{"spec":{"resources":{"requests":{"storage":"8Gi"}}}}'
# in guest:
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,SERIAL
sudo mkfs.xfs /dev/vdb && sudo mkdir /data && sudo mount /dev/vdb /data
sudo blkid /dev/vdb   # then add to /etc/fstab by UUID
sudo xfs_growfs /data
```

## 6. OADP backup and restore
```bash
oc get dpa,backupstoragelocation -n openshift-adp
oc get volumesnapshotclass
oc label volumesnapshotclass <name> velero.io/csi-volumesnapshot-class=true
oc get backup.velero.io -n openshift-adp
oc get backup.velero.io <name> -n openshift-adp -o jsonpath='{.status.phase}{"\n"}'
oc get restore.velero.io -n openshift-adp
alias velero='oc -n openshift-adp exec deployment/velero -c velero -it -- ./velero'
velero backup describe <name> --details
velero backup logs <name>
velero restore describe <name>
oc explain dpa.spec.configuration.velero.defaultPlugins
```

## 7. VM templates and cloud-init
```bash
oc get template -n openshift -l template.kubevirt.io/type=vm
oc process --parameters -n openshift <template>
oc process -n openshift <template> -p NAME=<n> | oc apply -n <ns> -f -
oc get datasource -n openshift-virtualization-os-images
oc get virtualmachineclusterinstancetype
oc get virtualmachineclusterpreference
oc apply -f <custom-template.yaml>
oc process -n <ns> <custom-template> -p NAME=<n> -p MEMORY=3Gi | oc apply -n <ns> -f -
oc explain template.parameters
```

## 8. VM snapshots
```bash
oc get volumesnapshotclass
oc get vmsnapshot -n <ns>
oc get vmsnapshot <name> -n <ns> -o jsonpath='{.status.readyToUse}{"\n"}'
oc get volumesnapshot,volumesnapshotcontent -n <ns>
virtctl stop <vm> -n <ns>
oc get vmrestore -n <ns>
oc get vmrestore <name> -n <ns> -o jsonpath='{.status.complete}{"\n"}'
virtctl start <vm> -n <ns>
oc delete vmsnapshot <name> -n <ns>
```

## 9. Migrate from other hypervisors
```bash
tar -tvf vm.ova
qemu-img info disk1.vmdk
qemu-img convert -f vmdk -O qcow2 disk1.vmdk disk1.qcow2
virtctl image-upload dv <name> --size=20Gi --image-path=disk1.qcow2 --insecure -n <ns>
oc get dv,pvc -n <ns>
oc get pods -n openshift-mtv
oc get provider,plan,migration,networkmap,storagemap -n openshift-mtv
oc describe plan <name> -n openshift-mtv
```

## 10. Clone VMs
```bash
# inside guest before cloning:
sudo truncate -s 0 /etc/machine-id
sudo rm -f /etc/ssh/ssh_host_*
sudo cloud-init clean --logs
virtctl stop <src-vm> -n <ns>
oc get dv,pvc -n <ns>
oc describe dv <clone-dv> -n <ns>
oc api-resources | grep clone.kubevirt.io
oc get vmclone -n <ns>
oc get vmclone <name> -n <ns> -o jsonpath='{.status.phase}{"\n"}'
oc get vmi -n <ns> -o custom-columns=NAME:.metadata.name,IP:.status.interfaces[0].ipAddress,MAC:.status.interfaces[0].mac
```

## 11. Live migration
```bash
oc get vmi <vm> -n <ns> -o jsonpath='{.status.conditions[?(@.type=="LiveMigratable")].status}{"\n"}'
virtctl migrate <vm> -n <ns>
virtctl migrate-cancel <vm> -n <ns>
oc get vmim -n <ns>
oc get vmi <vm> -n <ns> -o jsonpath='{.status.migrationState}{"\n"}'
oc label node <node> lab/zone=a
oc get hco kubevirt-hyperconverged -n openshift-cnv -o jsonpath='{.spec.liveMigrationConfig}{"\n"}'
oc patch hco kubevirt-hyperconverged -n openshift-cnv --type merge \
  -p '{"spec":{"liveMigrationConfig":{"parallelMigrationsPerCluster":10}}}'
oc get migrationpolicy
```

## 12. Node maintenance and updates
```bash
oc get nodes
oc get crd | grep nodemaintenance
oc get nodemaintenance
oc describe nodemaintenance <name>
oc adm cordon <node>
oc adm drain <node> --ignore-daemonsets --delete-emptydir-data --force --timeout=10m
oc adm uncordon <node>
oc get node <node> -o jsonpath='{.spec.unschedulable}{"\n"}'
oc get vmi -A -o wide
```

## 13. Load balancing with Kubernetes networking
```bash
virtctl expose vm <vm> --name <svc> --port 80 --target-port 8080 --type NodePort -n <ns>
oc expose svc <svc> --name <route> -n <ns>
oc create route edge <route> --service <svc> --hostname <host> --insecure-policy Redirect -n <ns>
oc get route -n <ns>
oc get route <route> -n <ns> -o jsonpath='{.spec.host}{"\n"}'
oc get svc,endpoints -n <ns>
oc explain route.spec.tls
```

## 14. Health probes
```bash
oc explain vm.spec.template.spec.readinessProbe
oc explain vm.spec.template.spec.domain.devices.watchdog
oc get vmi <vm> -n <ns> -o jsonpath='{.status.conditions[?(@.type=="Ready")]}{"\n"}'
oc get vm <vm> -n <ns> -o jsonpath='{.spec.runStrategy}{"\n"}'
oc patch vm <vm> -n <ns> --type merge -p '{"spec":{"runStrategy":"Always"}}'
oc get events -n <ns> --sort-by=.lastTimestamp
```

## 15. Prepare for node failure
```bash
oc label node <node> lab/dedicated=vm
oc adm taint node <node> lab/dedicated=vm:NoSchedule
oc adm taint node <node> lab/dedicated=vm:NoSchedule-
oc label node <node> lab/dedicated-
oc describe node <node> | grep -A3 Taints
oc explain vm.spec.template.spec.affinity.podAntiAffinity
oc explain vm.spec.template.spec.evictionStrategy
oc get nodehealthcheck
oc get selfnoderemediationtemplate -A
```

## 16. Basic system administration (guest)
```bash
systemctl status <unit>
sudo systemctl enable --now <unit>
systemctl is-enabled <unit> ; systemctl is-active <unit>
systemctl list-units --failed
sudo systemctl daemon-reload
sudo systemctl edit <unit>
journalctl -u <unit> -b --no-pager | tail -20
sudo dnf install -y <pkg> ; rpm -q <pkg> ; rpm -ql <pkg>
sudo dnf remove -y <pkg>
dnf repolist ; sudo dnf config-manager --set-disabled <repoid>
sudo hostnamectl set-hostname <name>
sudo timedatectl set-timezone UTC
sudo useradd -m -G wheel <user> ; sudo passwd <user>
ss -ltnp ; df -h ; free -m
virtctl guestfs <pvc-or-dv> -n <ns>          # VM must be stopped
```
