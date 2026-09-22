# Questions: OpenShift Virtualization operator (Objective 1)

**Time budget: 8 minutes**

## Scenario
A fresh OCP 4.18 cluster has no virtualization capability installed yet.

## Tasks
1. (4 min) Install the OpenShift Virtualization operator from the CLI only: create the
   `openshift-cnv` namespace, an OperatorGroup targeting it, and a Subscription to
   `kubevirt-hyperconverged` from `redhat-operators` using the package's default channel.
   Do not hard-code a channel name; look it up first.
2. (2 min) Create the `HyperConverged` custom resource named `kubevirt-hyperconverged`
   in `openshift-cnv`, then wait for it to report `Available`.
3. (2 min) Without using the web console, find and print the download URL for the
   `virtctl` binary that matches this cluster.

## Acceptance criteria
- `oc get csv -n openshift-cnv` shows the HCO CSV in phase `Succeeded`.
- `oc get hco kubevirt-hyperconverged -n openshift-cnv` shows condition `Available=True`.
- A working `virtctl` download URL was printed (not guessed from memory).
