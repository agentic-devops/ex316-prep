# Questions: Kubernetes networking for VMs (Objective 3)

**Time budget: 25 minutes**

## Scenario
Namespace `q3-app` runs a two-tier application on VMs: `q3-web` (a web-tier
VM listening on 8080) and `q3-db` (a db-tier VM listening on 5432). Both boot
the Fedora container disk. A separate namespace, `q3-udn`, needs an isolated
primary network for a different team.

## Tasks
1. (5 min) Create namespace `q3-app`. Deploy `q3-web` and `q3-db`, each with a
   label `tier: web` or `tier: db` on the VM's pod template. Configure each
   guest, via cloud-init, to run a simple Python HTTP listener on its port
   (systemd unit, enabled).
2. (3 min) Confirm from a temporary test pod that you can reach `q3-web` by
   its pod IP on port 8080.
3. (4 min) Apply a default-deny ingress NetworkPolicy to `q3-app`. Confirm
   the temporary pod can no longer reach `q3-web`.
4. (4 min) Write a NetworkPolicy that allows only pods labelled `tier: web` to
   reach `q3-db` on port 5432, and nothing else can. Prove it both ways
   (an allowed connection succeeds, a disallowed one is refused).
5. (3 min) Create a ClusterIP Service named `q3-web-svc` in front of `q3-web`
   on port 80 → 8080, and confirm it resolves and responds by name from the
   test pod.
6. (6 min) Create namespace `q3-udn` with a primary `UserDefinedNetwork`
   using Layer2 topology and subnet `10.200.0.0/24`. Start a VM in it and
   confirm its IP falls inside that subnet.

## Acceptance criteria
- Default-deny policy blocks the test pod; the web-to-db policy allows only
  `tier: web` sources on 5432.
- `q3-web-svc` has `q3-web`'s pod as an Endpoint.
- The UDN VM's IP is inside `10.200.0.0/24`, and the namespace has the
  primary-UDN label from the moment it was created (not added after).
