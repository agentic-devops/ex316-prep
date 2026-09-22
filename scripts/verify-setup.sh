#!/usr/bin/env bash
set -uo pipefail

ok()   { printf '\033[32mPASS\033[0m %s\n' "$1"; }
bad()  { printf '\033[31mFAIL\033[0m %s\n' "$1"; }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

check "CNV CSV succeeded" \
  "oc get csv -n openshift-cnv --no-headers | grep -q Succeeded"
check "HyperConverged available" \
  "[ \"\$(oc get hco kubevirt-hyperconverged -n openshift-cnv -o jsonpath='{.status.conditions[?(@.type==\"Available\")].status}')\" = True ]"
check "NMState CSV succeeded" \
  "oc get csv -n openshift-nmstate --no-headers | grep -q Succeeded"
check "NMState CR exists" "oc get nmstate nmstate"
check "OADP CSV succeeded" \
  "oc get csv -n openshift-adp --no-headers | grep -q Succeeded"
check "BackupStorageLocation available" \
  "[ \"\$(oc get backupstoragelocations -n openshift-adp -o jsonpath='{.items[0].status.phase}')\" = Available ]"
check "Default StorageClass present" \
  "oc get sc -o jsonpath='{.items[*].metadata.annotations}' | grep -q is-default-class"
check "At least one node schedulable for VMs" \
  "oc get nodes -l kubernetes.io/arch --no-headers | grep -q Ready"
oc get csv -n openshift-mtv --no-headers 2>/dev/null | grep -q Succeeded \
  && ok "MTV CSV succeeded (optional)" || echo "SKIP MTV not installed (optional)"
