# Lab 14: Health probes, run strategies and watchdog

Objective 14. Namespace: `probes-lab`.

## Tasks
1. Deploy `probe-vm` with a readiness HTTP probe and a liveness TCP probe on port 8080.
2. Create a ClusterIP Service for it. Stop the guest web server (`sudo systemctl stop labhttp`) and show the VM leaves the Service endpoints (readiness) and later restarts (liveness).
3. Write both probes yourself from memory, then compare with `oc explain vm.spec.template.spec.readinessProbe`.
4. Show how `Always`, `RerunOnFailure`, `Manual`, `Halted` and `Once` behave: shut the guest down from inside, crash it, stop it from `virtctl`.
5. Add an `i6300esb` watchdog device, run the watchdog daemon in the guest, then simulate a hang and watch the action fire.
6. Use `guestAgentPing` as a probe and explain what it needs in the guest.

## Gotchas
- Probes go under `spec.template.spec` (the VMI spec), not on the VM object's top level.
- Set a generous `initialDelaySeconds` (about 120): VMs boot slowly and liveness will otherwise restart them in a loop.
- Readiness only affects Service endpoints. Liveness restarts the guest.
- `RerunOnFailure` reruns after a failure, not after a clean guest shutdown; `Always` reruns in both.
- The watchdog device does nothing without a guest daemon feeding `/dev/watchdog`.
- Probe types available: `httpGet`, `tcpSocket` and `guestAgentPing`. Confirm the full list with `oc explain vm.spec.template.spec.readinessProbe`.

## Must-know commands
```bash
oc explain vm.spec.template.spec.readinessProbe
oc explain vm.spec.template.spec.domain.devices.watchdog
oc apply -f labs/14-health-probes/01-vm-probes.yaml
oc get vmi probe-vm -n probes-lab -o jsonpath='{.status.conditions[?(@.type=="Ready")]}{"\n"}'
oc create service clusterip probe-svc --tcp=80:8080 -n probes-lab --dry-run=client -o yaml
oc get endpoints -n probes-lab
oc get events -n probes-lab --sort-by=.lastTimestamp | tail

virtctl ssh cloud-user@vmi/probe-vm -n probes-lab -c 'sudo systemctl stop labhttp'
virtctl ssh cloud-user@vmi/probe-vm -n probes-lab -c 'sudo systemctl start labhttp'

oc get vm rerun-vm -n probes-lab -o jsonpath='{.spec.runStrategy}{"\n"}'
oc patch vm rerun-vm -n probes-lab --type merge -p '{"spec":{"runStrategy":"Always"}}'

virtctl console wd-vm -n probes-lab
# in guest: systemctl status watchdog ; ls -l /dev/watchdog ; sudo sh -c 'echo c > /proc/sysrq-trigger'
oc get vmi wd-vm -n probes-lab -w
```
