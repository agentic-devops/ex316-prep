# Lab 13: Load balancing with Kubernetes networking resources

Objective 13. Reuses the lab 03 VMs and Services in `net-lab`. Run lab 03 files `00`, `01`, `04` first.

## Tasks
1. Expose the web VMs with a NodePort Service on 30080. Curl it repeatedly and show responses from both `web1` and `web2`.
2. Expose SSH of `web1` externally with a NodePort Service on 30022 and connect from outside the cluster.
3. Create a Route to the web Service with an auto-generated host (`oc expose svc`) and curl it.
4. Create an edge-TLS Route with a custom hostname and HTTP-to-HTTPS redirect (`oc create route edge`).
5. Explain when to use ClusterIP, NodePort, LoadBalancer and Route for VM workloads, and why Routes cannot carry SSH.
6. With `deny-all-ingress` active, make the Route work by adding the correct NetworkPolicy.

## Gotchas
- Route traffic reaches the VM from the router pods; NetworkPolicy must allow `policy-group.network.openshift.io/ingress`.
- Routes are HTTP/HTTPS/TLS-SNI only. For SSH or other TCP, use NodePort or LoadBalancer (MetalLB or a cloud provider).
- `virtctl expose` creates the Service selector from the VM's labels; check it with `oc get svc -o yaml`.
- Port names on the Service must match the Route `targetPort` if you use a name.
- NodePorts default to the 30000-32767 range.

## Must-know commands
```bash
virtctl expose vm web1 --name web1-nodeport --port 80 --target-port 8080 --type NodePort -n net-lab
virtctl expose vm web1 --name vm-ssh-nodeport --port 22 --type NodePort -n net-lab

oc expose svc web-clusterip --name web-vm -n net-lab
oc create route edge web-vm-custom --service web-clusterip --hostname web.apps.<domain> \
  --insecure-policy Redirect -n net-lab
oc get route -n net-lab
oc get route web-vm -n net-lab -o jsonpath='{.spec.host}{"\n"}'
oc get svc,endpoints -n net-lab
oc get nodes -o wide
for i in $(seq 1 6); do curl -s http://<node-ip>:30080; done
ssh -p 30022 cloud-user@<node-ip>
oc explain route.spec.tls
```
