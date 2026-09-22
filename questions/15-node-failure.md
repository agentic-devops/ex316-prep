# Questions: Preparing for node failure (Objective 15)

**Time budget: 20 minutes**

## Scenario
Namespace `q15-ha` runs a pair of redundant VMs that must never land on the
same node, plus a dedicated VM that must only run on specially-labelled
hardware.

## Tasks
1. (5 min) Create namespace `q15-ha` and two VMs, `q15-a` and `q15-b`, each
   labelled `group: q15-pair` on their pod template, with required
   pod anti-affinity keyed on `kubernetes.io/hostname` so they can never
   share a node. Set both to migrate (not restart) on node drain.
2. (2 min) Confirm both VMs are running and on different nodes.
3. (5 min) Label one node `q15/dedicated=vm` and taint it
   `q15/dedicated=vm:NoSchedule`. Create a third VM, `q15-dedicated`, that
   only schedules on that node (via a matching node selector) and tolerates
   the taint.
4. (3 min) Confirm a VM without the toleration cannot be scheduled onto the
   tainted node.
5. (3 min) Remove the taint and label from the node afterward.
6. (2 min) In a short comment, describe what a `NodeHealthCheck` combined
   with Self Node Remediation would do if the node running `q15-dedicated`
   became `NotReady` for several minutes, and why that matters for a VM with
   `runStrategy: Always`.

## Acceptance criteria
- `q15-a` and `q15-b` are confirmed to run on two different nodes at the
  same time.
- `q15-dedicated` only ever schedules on the tainted, labelled node.
- The taint and label are cleaned up at the end so the node returns to
  normal scheduling.
