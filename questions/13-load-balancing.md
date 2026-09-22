# Questions: Load balancing with Kubernetes networking (Objective 13)

**Time budget: 15 minutes**

## Scenario
Namespace `q13-lb` runs a VM, `q13-web`, serving HTTP on guest port 8080, and
needs both external HTTP access and external SSH access, without exposing
raw node IPs for the HTTP path.

## Tasks
1. (3 min) Create namespace `q13-lb` and VM `q13-web` with a working HTTP
   listener on 8080 (via cloud-init).
2. (3 min) Expose SSH externally with a NodePort Service on node port 30222.
3. (2 min) Create a ClusterIP Service in front of the VM's HTTP port.
4. (4 min) Create a Route to that Service with a custom hostname, edge TLS
   termination, and HTTP requests redirected to HTTPS.
5. (3 min) Explain, in a short comment in your notes, why the Route
   approach could not be used for the SSH requirement.

## Acceptance criteria
- SSH is reachable via the NodePort from outside the cluster network.
- The Route serves HTTPS on the custom hostname and redirects plain HTTP to
  HTTPS.
- No NodePort or LoadBalancer Service was used for the HTTP path.
