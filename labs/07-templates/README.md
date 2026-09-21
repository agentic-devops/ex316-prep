# Lab 07: VM templates and cloud-init

Objective 7. Namespace: `tmpl-lab`. Red Hat common templates live in namespace `openshift`.

## Tasks
1. List the preconfigured VM templates and show the parameters of one (for example a RHEL 9 server template).
2. Create a VM from a preconfigured template using `oc process`, overriding NAME.
3. Create a custom template from a working VM (export the VM, wrap it in a Template, add parameters).
4. Instantiate the custom template twice with different parameters.
5. Write cloud-init that sets the user and password, adds a yum repo, installs and starts `httpd`, and writes a file.
6. Create a VM from an instance type and preference (no explicit CPU/memory).
7. In the console: Catalog > Template catalog, create from a template, then edit its cloud-init in the wizard.

## Gotchas
- Parameter substitution happens at `oc process`; a template that is not processed creates nothing.
- Console-visible templates need labels such as `template.kubevirt.io/type: vm`.
- Template objects go in the target namespace via `oc apply -n`, or via `-n` on create.
- With instance types, setting `domain.cpu` or `resources.requests.memory` is rejected.
- cloud-init `packages:` runs late; `runcmd` runs after packages. Repos must be reachable.
- Cloud-init runs on first boot only. Re-running requires a new instance ID.

## Must-know commands
```bash
oc get template -n openshift -l template.kubevirt.io/type=vm
oc get template rhel9-server-small -n openshift -o yaml | less
oc process --parameters -n openshift rhel9-server-small
oc process -n openshift rhel9-server-small -p NAME=rhel-vm1 | oc apply -n tmpl-lab -f -
oc get datasource -n openshift-virtualization-os-images      # boot sources

oc get virtualmachineclusterinstancetype
oc get virtualmachineclusterpreference
oc get vm it-vm -n tmpl-lab -o yaml | grep -A4 -E 'instancetype|preference'

oc apply -f labs/07-templates/01-template-custom.yaml
oc process -n tmpl-lab lab-fedora-server -p NAME=web01 -p MEMORY=3Gi | oc apply -n tmpl-lab -f -
oc get template -n tmpl-lab
oc explain template.parameters
oc get vm web01 -n tmpl-lab -o jsonpath='{.spec.template.spec.volumes[?(@.name=="cloudinitdisk")].cloudInitNoCloud.userData}'
```
