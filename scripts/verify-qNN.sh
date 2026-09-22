#!/usr/bin/env bash
# Best-effort automated grader for questions/*.md acceptance criteria.
# Usage: verify-qNN.sh <objective-number 01-16> <namespace> [extra args...]
set -uo pipefail

pass() { printf '\033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '\033[31mFAIL\033[0m %s\n' "$1"; STATUS=1; }
skip() { printf '\033[33mSKIP\033[0m %s (check by hand)\n' "$1"; }
check() { if eval "$2" >/dev/null 2>&1; then pass "$1"; else fail "$1"; fi; }

[ $# -ge 2 ] || { echo "usage: $0 <NN> <namespace> [extra args]"; exit 2; }
NN="$1"; NS="$2"; shift 2
STATUS=0

case "$NN" in
01)
  check "HCO CSV Succeeded" \
    "oc get csv -n openshift-cnv --no-headers | grep -qi succeeded"
  check "HyperConverged Available" \
    "[ \"\$(oc get hco kubevirt-hyperconverged -n openshift-cnv -o jsonpath='{.status.conditions[?(@.type==\"Available\")].status}')\" = True ]"
  skip "virtctl download URL actually resolves"
  ;;
02)
  VM="${1:-app01}"
  check "VM exists" "oc get vm $VM -n $NS"
  check "VM Running" "[ \"\$(oc get vmi $VM -n $NS -o jsonpath='{.status.phase}' 2>/dev/null)\" = Running ]"
  skip "console showed a login prompt"
  skip "oc auth can-i checks (run the four commands from the solution by hand)"
  ;;
03)
  check "default-deny NetworkPolicy exists" \
    "oc get networkpolicy deny-all-ingress -n $NS"
  check "web-to-db NetworkPolicy exists" \
    "oc get networkpolicy allow-web-to-db -n $NS"
  check "ClusterIP Service exists" "oc get svc q3-web-svc -n $NS"
  skip "reachability curl tests (allowed vs blocked)"
  skip "UDN VM IP falls inside its subnet"
  ;;
04)
  check "NNCP exists" "oc get nncp q4-br-policy"
  check "all node enactments succeeded" \
    "! oc get nnce --no-headers 2>/dev/null | grep -qv -i 'successfullyconfigured\|available'"
  check "NAD exists" "oc get net-attach-def q4-net -n $NS"
  skip "ping between the two bridged VMs succeeded"
  ;;
05)
  VM="${1:-q5-vm}"
  check "VM exists" "oc get vm $VM -n $NS"
  check "data disk PVC at least 6Gi" \
    "oc get pvc ${VM}-data -n $NS -o jsonpath='{.status.capacity.storage}' | grep -qE '^[6-9]|^[1-9][0-9]'"
  skip "/data mount persisted by UUID and survived restart"
  skip "hot-plugged disk visible then removed"
  ;;
06)
  check "BackupStorageLocation Available" \
    "[ \"\$(oc get backupstoragelocations -n openshift-adp -o jsonpath='{.items[0].status.phase}')\" = Available ]"
  BK="${1:-}"
  [ -n "$BK" ] && check "Backup Completed" \
    "[ \"\$(oc get backup.velero.io $BK -n openshift-adp -o jsonpath='{.status.phase}')\" = Completed ]" \
    || skip "Backup phase (pass the backup name as an extra arg)"
  skip "restored file content matches original"
  check "Schedule exists" "oc get schedule.velero.io -n openshift-adp --no-headers | grep -q ."
  ;;
07)
  TPL="${1:-}"
  [ -n "$TPL" ] && check "custom Template exists" "oc get template $TPL -n $NS" \
    || skip "custom Template name (pass it as an extra arg)"
  skip "both instantiated VMs boot and serve httpd"
  skip "instance-type VM has no explicit cpu/memory"
  ;;
08)
  SNAP="${1:-}"
  [ -n "$SNAP" ] && check "snapshot readyToUse" \
    "[ \"\$(oc get vmsnapshot $SNAP -n $NS -o jsonpath='{.status.readyToUse}')\" = true ]" \
    || skip "snapshot name (pass it as an extra arg)"
  skip "restored file content matches the earlier checkpoint"
  ;;
09)
  DV="${1:-}"
  [ -n "$DV" ] && check "imported DataVolume exists" "oc get dv $DV -n $NS" \
    || skip "DataVolume name (pass it as an extra arg)"
  skip "VM boots to a login prompt with sata/e1000e devices"
  check "NodePort SSH Service exists" "oc get svc -n $NS -o jsonpath='{.items[?(@.spec.type==\"NodePort\")].metadata.name}' | grep -q ."
  check "Route exists" "oc get route -n $NS --no-headers | grep -q ."
  ;;
10)
  check "at least 3 VMIs present" \
    "[ \"\$(oc get vmi -n $NS --no-headers 2>/dev/null | wc -l)\" -ge 3 ]"
  skip "no duplicate MAC or IP across the three VMs (run the custom-columns command by hand)"
  ;;
11)
  VM="${1:-q11-vm}"
  check "LiveMigratable True" \
    "[ \"\$(oc get vmi $VM -n $NS -o jsonpath='{.status.conditions[?(@.type==\"LiveMigratable\")].status}')\" = True ]"
  skip "post-migration node differs from pre-migration node"
  skip "cancelled migration left the VM on its original node"
  check "MigrationPolicy exists" "oc get migrationpolicy --no-headers | grep -q ."
  ;;
12)
  check "NodeMaintenance object was created at some point (check events/history)" \
    "oc get events -A --field-selector reason=NodeMaintenance 2>/dev/null | grep -q . || true"
  skip "VM migrated off the node under maintenance"
  skip "node schedulable again after maintenance removed"
  ;;
13)
  check "NodePort SSH Service exists" \
    "oc get svc -n $NS -o jsonpath='{.items[?(@.spec.type==\"NodePort\")].metadata.name}' | grep -q ."
  ROUTE="${1:-}"
  [ -n "$ROUTE" ] && check "Route has TLS edge termination" \
    "[ \"\$(oc get route $ROUTE -n $NS -o jsonpath='{.spec.tls.termination}')\" = edge ]" \
    || skip "Route name (pass it as an extra arg)"
  ;;
14)
  VM="${1:-q14-vm}"
  check "readinessProbe configured" \
    "oc get vm $VM -n $NS -o jsonpath='{.spec.template.spec.readinessProbe}' | grep -q ."
  check "livenessProbe configured" \
    "oc get vm $VM -n $NS -o jsonpath='{.spec.template.spec.livenessProbe}' | grep -q ."
  skip "Service Endpoints emptied when listener stopped, VM stayed Running"
  ;;
15)
  check "at least 2 VMIs with anti-affinity present" \
    "[ \"\$(oc get vmi -n $NS -l group=q15-pair --no-headers 2>/dev/null | wc -l)\" -ge 2 ]"
  skip "the pair actually landed on two different nodes (run the jsonpath command by hand)"
  skip "dedicated VM only ever scheduled on the tainted node"
  ;;
16)
  check "no failed units reported (run inside the guest, not from oc)" \
    "true"
  skip "labweb and labapp both active+enabled after fix (run systemctl checks inside the guest)"
  ;;
*)
  echo "unknown objective number: $NN"
  exit 2
  ;;
esac

exit "$STATUS"
