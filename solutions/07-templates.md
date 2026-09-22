# Solution: Objective 7 (matches questions/07-templates.md)

## Task 1-2: inspect and instantiate a Red Hat template
```bash
oc get template -n openshift -l template.kubevirt.io/type=vm
oc process --parameters -n openshift fedora-server-small
oc process -n openshift fedora-server-small -p NAME=q7-from-rht | oc apply -n <ns> -f -
```
(Substitute the exact Fedora template name available on your cluster; list
it first, names vary by version.)

## Task 3: custom Template
```yaml
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
                    - {path: /var/www/html/index.html, content: "q7 app server\n"}
                  runcmd:
                    - [systemctl, enable, --now, httpd]
parameters:
  - {name: NAME, required: true}
  - {name: MEMORY, value: 2Gi}
```
```bash
oc apply -f q7-appserver-template.yaml -n <ns>
```

## Task 4-5: instantiate twice
```bash
oc process -n <ns> q7-appserver -p NAME=q7-app01 | oc apply -n <ns> -f -
oc process -n <ns> q7-appserver -p NAME=q7-app02 -p MEMORY=3Gi | oc apply -n <ns> -f -
oc get vm q7-app02 -n <ns> -o jsonpath='{.spec.template.spec.domain.resources.requests.memory}{"\n"}'
```

## Task 6: instance type + preference
```bash
oc get virtualmachineclusterinstancetype
oc get virtualmachineclusterpreference
# VM: instancetype {kind: VirtualMachineClusterInstancetype, name: u1.medium}
#     preference   {kind: VirtualMachineClusterPreference, name: fedora}
# no domain.cpu / resources.requests.memory anywhere in the spec
```
