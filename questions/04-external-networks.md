# Questions: External networks (Objective 4)

**Time budget: 20 minutes**

## Scenario
Namespace `q4-ext` needs VMs with a second NIC bridged onto a physical network
segment, for connectivity outside the cluster's default pod network. Assume
each worker has a spare NIC named `ens224` (substitute the real name from
`NodeNetworkState` if different).

## Tasks
1. (5 min) Using the NMState operator, create a `NodeNetworkConfigurationPolicy`
   that builds a Linux bridge named `q4-br` on every worker node, using the
   spare NIC as its port.
2. (2 min) Confirm the policy applied successfully on every worker (not just
   that the policy object exists).
3. (3 min) Create namespace `q4-ext` and a `NetworkAttachmentDefinition`
   named `q4-net` that connects to bridge `q4-br`.
4. (6 min) Create two VMs, `q4-vm1` and `q4-vm2`, each with the default pod
   network NIC plus a second NIC on `q4-net`, with static addresses
   `192.168.150.11/24` and `192.168.150.12/24`.
5. (4 min) From inside `q4-vm1`, ping `q4-vm2` across the bridged network and
   capture the result.

## Acceptance criteria
- `oc get nnce` shows every worker's enactment of the policy as successful.
- Both VMs have exactly two interfaces in the guest, and the bridged NIC has
  the correct static address.
- The ping between the two VMs over the bridged network succeeds.
