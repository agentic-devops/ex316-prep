# Questions: Health probes (Objective 14)

**Time budget: 15 minutes**

## Scenario
Namespace `q14-probes` runs a VM that must be automatically removed from
service when its application hangs, and automatically restarted if the whole
guest becomes unresponsive.

## Tasks
1. (4 min) Create namespace `q14-probes` and VM `q14-vm` with a working HTTP
   listener on port 8080 (via cloud-init), plus a readiness probe against
   that port and path, and a liveness probe using a TCP check on the same
   port. Choose reasonable delay and threshold values for a VM (not a
   container).
2. (2 min) Create a ClusterIP Service in front of it and confirm the VM is
   listed as an Endpoint once ready.
3. (3 min) Stop the guest's HTTP listener from inside (without stopping the
   VM). Confirm the VM is removed from the Service's Endpoints, but the VM
   itself keeps running.
4. (3 min) Restart the listener and confirm the VM returns as an Endpoint.
5. (3 min) Add an `i6300esb` watchdog device to the VM with a `poweroff`
   action, and describe (in a comment) what must run inside the guest for it
   to have any effect.

## Acceptance criteria
- The readiness probe removes the VM from Service Endpoints when the
  listener is down, without restarting the VM.
- The liveness probe is configured but does not fire during this exercise
  (only the application listener was stopped, not the whole guest).
- The watchdog device is present in the VM spec with a valid action.
