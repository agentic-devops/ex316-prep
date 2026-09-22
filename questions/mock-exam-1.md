# Mock exam 1 — full length

**Total time budget: 4 hours.** Set one timer for the whole thing; don't time
each task individually, exactly like the real exam. Work in order or skip
around — your choice, also like the real exam. Use only `oc explain`,
`--help`, and product documentation. No labs/, no commands/, no questions/
from this repo.

Reset everything first: `for n in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16; do ./scripts/reset-lab.sh $n; done`
(some will report "no lab folder" or "skipped" — that's fine, ignore those).

All namespaces below are prefixed `mock1-` so they can't collide with
anything from `labs/` or the per-objective `questions/` files.

---

## Task 1 — Operator (Objective 1)
Install the OpenShift Virtualization operator from the CLI, using the
package's actual default channel (look it up, don't guess). Wait for the
HyperConverged CR to report `Available`.

## Task 2 — VM access and RBAC (Objective 2)
In namespace `mock1-access`: create a VM `t2-vm` (2 vCPU, 4Gi). Grant user
`mock1-editor` full VM edit rights and user `mock1-reader` view-only rights,
scoped to this namespace. Create a custom Role that allows starting,
stopping and viewing VMs but not editing or deleting them, and bind it to
user `mock1-operator`.

## Task 3 — Networking (Objective 3)
In namespace `mock1-net`: deploy VMs `t3-web` (tier: web, port 8080) and
`t3-db` (tier: db, port 5432). Apply default-deny ingress. Allow only
`tier: web` sources to reach `t3-db` on 5432. Create a ClusterIP Service for
`t3-web`.

## Task 4 — External networks (Objective 4)
Build a Linux bridge (`mock1-br`) on every worker via an NNCP, using a spare
NIC. Create a NAD in namespace `mock1-net` on that bridge. Attach a second
NIC on it to `t3-web` with a static address `192.168.160.10/24`.

## Task 5 — Storage (Objective 5)
In namespace `mock1-store`: create VM `t5-vm` with a 10Gi DataVolume root
disk and a second 4Gi blank data disk. Format, mount at `/data`, and persist
the mount by UUID. Expand the data disk to 6Gi and grow the filesystem.

## Task 6 — OADP (Objective 6)
Back up namespace `mock1-store` (from Task 5) with OADP, using CSI data
movement. Delete `t5-vm` entirely. Restore it and confirm `/data`'s content
survived.

## Task 7 — Templates and cloud-init (Objective 7)
Write a custom Template, `mock1-tmpl`, parameterized by VM name and memory,
that boots Fedora, sets the `cloud-user` password via cloud-init, installs
`httpd`, and enables it at boot. Instantiate it twice with different names.

## Task 8 — Snapshots (Objective 8)
In namespace `mock1-snap`: create a DataVolume-backed VM, write a marker
file, snapshot it, change the guest, snapshot again, then restore to the
first snapshot and confirm the marker file is back.

## Task 9 — Migration/import (Objective 9)
Convert a provided (or self-made) OVA's disk to qcow2, upload it into a
DataVolume in namespace `mock1-import`, and boot a VM from it using a disk
bus and NIC model appropriate for a legacy, non-virtio-aware guest.

## Task 10 — Cloning (Objective 10)
In namespace `mock1-clone`: prepare a source VM for cloning (machine-id, SSH
host keys, cloud-init state), then produce one DataVolume-based clone and
one whole-VM clone via `VirtualMachineClone`. Confirm no MAC or IP
collisions between all three VMs.

## Task 11 — Live migration (Objective 11)
In namespace `mock1-migr`: create a VM with RWX/Block storage and
`evictionStrategy: LiveMigrate`. Migrate it and confirm it landed on a
different node without downtime. Start a second migration and cancel it.
Create a `MigrationPolicy` limiting bandwidth for this namespace.

## Task 12 — Node maintenance (Objective 12)
Put the node running the Task 11 VM into maintenance using a
`NodeMaintenance` object. Confirm the VM migrates off. Remove the
`NodeMaintenance` object afterward.

## Task 13 — Load balancing (Objective 13)
Expose a VM's HTTP port via ClusterIP + edge-TLS Route with a custom
hostname and HTTP-to-HTTPS redirect. Expose its SSH port via NodePort.

## Task 14 — Health probes (Objective 14)
Add a readiness HTTP probe and a liveness TCP probe to a VM serving on port
8080. Prove the readiness probe removes it from Service Endpoints when the
guest's listener is stopped, without restarting the VM.

## Task 15 — Node failure preparation (Objective 15)
Create two VMs with required pod anti-affinity so they can never share a
node. Taint and label a node, then create a third VM that only schedules
there and tolerates the taint. Clean up the taint and label afterward.

## Task 16 — Guest sysadmin (Objective 16)
Inside any running guest: fix a broken systemd unit (diagnose with
`systemctl status` / `journalctl`, correct it, reload, start, enable), and
create a drop-in override for a different unit that sets `Restart=always`.

---

## After time is up
Grade yourself against `solutions/` (section 9), score each task pass/fail,
and log every miss in `docs/miss-log.md` with the objective number. Anything
you missed twice across two mock exams should get its own extra drill in
`commands/drill-blanks.md` before you book the real thing.
