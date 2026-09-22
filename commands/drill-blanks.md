# Command drill: fill in the blank

For each task, type or say the full command from memory before checking
`drill-answers.md`. Namespaces and names are yours to fill in; the point is
the verb, the flags, and the object type.

## 1. Operator
1. Find the default install channel for the HyperConverged operator.
2. List CSVs in the CNV namespace.
3. Wait for the HyperConverged CR to become Available (with a 20-minute timeout).
4. Download the URL for the `virtctl` CLI plugin from the cluster.

## 2. VM access
1. Create a VM from an instance type and preference, piped straight into `oc apply`.
2. Pause a running VM, then unpause it.
3. Set a VM's runStrategy to Halted without editing the file.
4. Open the serial console of a VM (and recall the escape sequence).
5. SSH into a VM as `cloud-user` using `virtctl`.
6. Grant a user edit rights on VMs in one namespace using a built-in ClusterRole.
7. Check, as a specific user, whether they can start a VM (a subresource action, not a verb like "update" alone).

## 3. Networking
1. Get the pod-network IP address of a VMI via `oc get vmi ... -o jsonpath`.
2. Start a temporary UBI pod that sleeps forever, for use as a network test client.
3. Explain (via `oc explain`) what fields go under `networkpolicy.spec.ingress.from`.
4. Expose a VM as a Service directly from `virtctl` (not by writing a Service YAML).
5. List `UserDefinedNetwork` objects in a namespace.

## 4. External networks
1. List `NodeNetworkState` objects, then show the interface names on one node.
2. List `NodeNetworkConfigurationPolicy` objects and their enactments.
3. Describe a specific node's enactment of a policy (to read a failure reason).
4. Check the interfaces inside a VM guest over SSH, in one line, without opening a console session.

## 5. Storage
1. Mark a StorageClass as the default class specifically for virtualization.
2. Explain the `datavolume.spec.storage` field.
3. Hot-plug a PVC into a running VM, persistently, with a serial number.
4. Detach that same hot-plugged disk, persistently.
5. Upload a local qcow2 file into a new DataVolume, ignoring TLS errors.
6. Expand a PVC to 8Gi via a merge patch (not editing the whole file).
7. Inside the guest: grow an XFS filesystem after the underlying disk grew.

## 6. OADP
1. List BackupStorageLocations in the OADP namespace.
2. Label a VolumeSnapshotClass so OADP's CSI plugin will use it.
3. Check a Backup's phase via `-o jsonpath`.
4. Set up a shell alias that runs the `velero` binary inside the Velero deployment pod.
5. Show a Backup's details, including validation errors.

## 7. Templates and cloud-init
1. List only the VM-type templates in the `openshift` namespace.
2. Show the parameters of a template without creating anything.
3. Process a template with one parameter override, and pipe it into `oc apply` in a target namespace.
4. List cluster instance types and cluster preferences.

## 8. Snapshots
1. Check whether a VMSnapshot is ready to use, via jsonpath.
2. List VolumeSnapshot and VolumeSnapshotContent objects in a namespace.
3. Check whether a VMRestore has completed, via jsonpath.

## 9. Migration/import
1. List the contents of an OVA file without extracting it.
2. Get information about a VMDK disk image.
3. Convert a VMDK to qcow2.
4. List Forklift/MTV Plans, Migrations, NetworkMaps and StorageMaps in one command.

## 10. Cloning
1. Reset a guest's machine-id to empty before cloning it (one command).
2. Remove all SSH host keys from a guest before cloning it.
3. Clean cloud-init's state and logs inside a guest.
4. Check which API resource group serves `VirtualMachineClone` on this cluster.
5. Check a VirtualMachineClone's phase via jsonpath.

## 11. Live migration
1. Check, via jsonpath, whether a VMI's LiveMigratable condition is True.
2. Trigger a live migration with `virtctl`.
3. Cancel an in-progress migration with `virtctl`.
4. Read a VMI's current migration state via jsonpath.
5. Patch the HyperConverged CR to allow 10 parallel migrations per cluster (one command).

## 12. Node maintenance
1. Cordon a node.
2. Drain a node the right way for a node running VMs (three flags matter).
3. Uncordon a node.
4. Confirm from the API whether a node is currently unschedulable.

## 13. Load balancing
1. Expose a VM as a NodePort Service directly with `virtctl`.
2. Create an edge-TLS Route with a custom hostname and an HTTP-to-HTTPS redirect policy, in one command.
3. Get a Route's hostname via jsonpath.

## 14. Health probes
1. Explain the `readinessProbe` field on a VM spec.
2. Check a VMI's Ready condition via jsonpath.
3. Change a VM's runStrategy to Always via a merge patch.

## 15. Node failure
1. Taint a node so nothing schedules there unless it tolerates the taint.
2. Remove that taint.
3. Explain the `evictionStrategy` field on a VM spec.
4. List NodeHealthCheck objects.

## 16. Guest sysadmin
1. Enable and immediately start a systemd unit in one command.
2. Check whether a unit is enabled and whether it's currently active (two commands).
3. List every failed systemd unit.
4. Open an editable drop-in override for a unit.
5. Tail the last 20 lines of a unit's journal since the last boot.
6. Find which package owns a given file on disk.
7. Disable a specific dnf repo without removing it.
8. Inspect a stopped VM's filesystem from the CLI without booting it.
