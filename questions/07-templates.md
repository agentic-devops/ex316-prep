# Questions: VM templates and cloud-init (Objective 7)

**Time budget: 20 minutes**

## Scenario
The team wants a repeatable way to stamp out small Fedora "app server" VMs
with a consistent user, an extra package, and a running web service, without
hand-writing a VM manifest every time.

## Tasks
1. (3 min) List the preconfigured VM templates available in the `openshift`
   namespace, and show the full parameter list of one Fedora-based template.
2. (2 min) Instantiate that template once, naming the resulting VM `q7-from-rht`.
3. (6 min) Write your own custom `Template` object, `q7-appserver`, containing
   a VM definition. It must accept parameters for the VM name and the memory
   request (with a sensible default), and must configure cloud-init to: set
   the `cloud-user` password, install `httpd`, write a custom index page, and
   enable the `httpd` service at boot.
4. (3 min) Instantiate `q7-appserver` twice, as `q7-app01` (default memory)
   and `q7-app02` (memory explicitly overridden to 3Gi).
5. (3 min) Confirm both VMs are running, and that `q7-app02` actually has
   3Gi requested (not the default).
6. (3 min) Create one more VM using a `VirtualMachineClusterInstancetype` and
   `VirtualMachineClusterPreference` instead of explicit CPU/memory.

## Acceptance criteria
- `q7-appserver` is a valid, reusable `Template` object with at least two
  parameters.
- Both instantiated VMs boot, and `httpd` responds on port 80 inside each
  guest without further manual configuration.
- The instance-type VM has no explicit `domain.cpu` or
  `resources.requests.memory` set.
