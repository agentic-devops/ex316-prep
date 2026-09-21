# Lab 03: Kubernetes networking for VMs

Objective 3. Namespaces: `net-lab` (pod network), `udn-lab` (primary UDN).
Apply order: `00`, `01`, wait for VMs, then `04`, then the policies. Break things on purpose.

## Tasks
1. Deploy `web1`, `web2`, `db1` in `net-lab` and find each VM's pod-network IP (`oc get vmi`).
2. From a temporary pod, reach `web1:8080` by IP and by Service name.
3. Apply `02-netpol-default-deny.yaml`. Confirm web access is now blocked.
4. Write a policy that allows `web1` and `web2` to talk to each other on 8080 only. Write it from scratch.
5. Allow only `tier=web` VMs to reach `db1` on 5432 (see `03-netpol-allow.yaml`) and prove `db1` is unreachable from a non-web pod.
6. Create ClusterIP Services for the web tier and the db tier. Confirm both web VMs are Endpoints of the web Service.
7. Create namespace `udn-lab` with the primary-UDN label, create a Layer2 primary `UserDefinedNetwork` (10.100.0.0/24), and start a VM on it. Show its IP is in that subnet.
8. Attach a VM to a secondary network via a NAD (`13`/`14`), and show the second NIC inside the guest.

## Gotchas
- `virtctl console`, `vnc` and `ssh` go through the API server, not the pod network, so NetworkPolicies do not affect them.
- NetworkPolicy `podSelector` matches the labels under `spec.template.metadata.labels` of the VM, not the VM object's own labels.
- Routes need a policy allowing `policy-group.network.openshift.io/ingress` in.
- The primary-UDN namespace label must exist at namespace creation.
- VMs in a primary-UDN namespace use `binding: {name: l2bridge}`; masquerade is for the default pod network.
- Guest port 8080 or 5432 must actually be listening: `virtctl ssh` in and run `ss -ltnp`.

## Must-know commands
```bash
oc get vmi -n net-lab -o wide
oc get vmi web1 -n net-lab -o jsonpath='{.status.interfaces[*].ipAddress}{"\n"}'
oc get pods -n net-lab -o wide -l tier=web
oc run tester -n net-lab --image=registry.access.redhat.com/ubi9/ubi --restart=Never -- sleep infinity
oc exec -n net-lab tester -- curl -sm3 http://<vm-ip>:8080
oc exec -n net-lab tester -- curl -sm3 http://web-clusterip

oc get networkpolicy -n net-lab
oc describe networkpolicy allow-web-to-db -n net-lab
oc explain networkpolicy.spec.ingress.from

oc get svc,endpoints -n net-lab
virtctl expose vm web1 --name web1-svc --port 80 --target-port 8080 -n net-lab
oc create service clusterip web-clusterip --tcp=80:8080 -n net-lab --dry-run=client -o yaml

oc get userdefinednetwork -n udn-lab
oc get userdefinednetwork udn-primary -n udn-lab -o yaml
oc explain userdefinednetwork.spec.layer2
oc get net-attach-def -n net-lab
```

## Time targets
Default-deny plus one allow policy: 3 min. ClusterIP plus test: 2 min. UDN namespace, UDN and VM: 6 min.
