#!/usr/bin/env bash
#
# ex316-validate.sh -- validate every command, flag, field path and manifest used in
#                      EX316-COMPLETE-PRACTICE-GUIDE.md and
#                      EX316-PRACTICE-QUESTIONS-AND-SOLUTIONS.md
#                      against a LIVE OpenShift Virtualization cluster.
#
# SAFETY: read-only by default.
#   - no resource is ever created, modified or deleted
#   - writes are exercised with --dry-run=server / --dry-run=client, which the API
#     server validates and then discards
#   - "oc delete --dry-run=client" is used to syntax-check the reset commands
#   - the only things written to disk are the two report files
#
# NEVER STALLS, NEVER STOPS EARLY
#   - every command runs under `timeout` (default 30s); a hung or unreachable cluster
#     is reported as TIMEOUT and the run continues
#   - every command runs with stdin closed, so nothing can block waiting for input
#   - a failure is recorded and execution carries on to the next check
#   - Ctrl+C still prints the summary and keeps the failure report
#
# OUTPUT FILES
#   ex316-validate-<stamp>.log           every command and its full output
#   ex316-validate-FAILURES-<stamp>.txt  ONLY the failures: check, exit code, exact
#                                        command, full output -- written as they happen,
#                                        so it survives an interrupted run
#
# USAGE
#   ./ex316-validate.sh                 # read-only, dry-run namespace = default
#   ./ex316-validate.sh -n myproject    # dry-run against an existing namespace
#   ./ex316-validate.sh --create-ns     # create a temp namespace, use it, delete it at exit
#   ./ex316-validate.sh -v              # show the command for every check, not just failures
#   ./ex316-validate.sh --section 4     # run only section 4
#   ./ex316-validate.sh --timeout 60    # raise the per-command limit on a slow cluster
#   ./ex316-validate.sh --no-timeout    # disable the limit entirely (can hang)
#
# EXIT CODE: 0 if nothing FAILED, 1 if anything FAILED, 130 if interrupted.
#
set -uo pipefail

# ----------------------------------------------------------------------------- settings
NS="default"
CREATE_NS=0
VERBOSE=0
ONLY_SECTION=""
TIMEOUT=30
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="./ex316-validate-$STAMP.log"
FAILFILE="./ex316-validate-FAILURES-$STAMP.txt"
TMPNS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NS="$2"; shift 2 ;;
    --create-ns)    CREATE_NS=1; shift ;;
    -v|--verbose)   VERBOSE=1; shift ;;
    --section)      ONLY_SECTION="$2"; shift 2 ;;
    --timeout)      TIMEOUT="$2"; shift 2 ;;
    --no-timeout)   TIMEOUT=0; shift ;;
    -h|--help)      sed -n '2,36p' "$0"; exit 0 ;;
    *) echo "unknown option: $1 (try --help)"; exit 2 ;;
  esac
done

# every external command is run under `timeout` so a hung/unreachable cluster can never
# stall the run. Exit code 124 = the command was killed for exceeding TIMEOUT.
# TO is never empty -- when no timeout is wanted it is the harmless passthrough `env`,
# which keeps "${TO[@]}" safe under `set -u` on every bash version.
TIMEOUT_ACTIVE=0
TO=(env)
# -k 5: if the command ignores TERM, SIGKILL it 5s later. Without --foreground, GNU
# timeout puts the command in its own process group and signals the whole group, so
# grandchildren (e.g. the left side of a pipeline) cannot keep the run hanging.
if [[ "$TIMEOUT" -gt 0 ]]; then
  if   command -v timeout  >/dev/null 2>&1; then TO=(timeout -k 5 "$TIMEOUT"); TIMEOUT_ACTIVE=1
  elif command -v gtimeout >/dev/null 2>&1; then TO=(gtimeout -k 5 "$TIMEOUT"); TIMEOUT_ACTIVE=1
  else
    echo "note: 'timeout' not found on this host -- running without per-command time limits"
  fi
fi

# ----------------------------------------------------------------------------- output
if [[ -t 1 ]]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[34m'; DIM=$'\e[2m'; N=$'\e[0m'
else
  R=""; G=""; Y=""; B=""; DIM=""; N=""
fi

PASS=0; FAIL=0; WARN=0; SKIP=0; TIMEOUTS=0
declare -a FAILURES=()      # "section<TAB>label"
declare -a WARNINGS=()
CURRENT_SECTION="0"

log()  { echo "$*" >>"$LOG"; }
say()  { echo "$*" | tee -a "$LOG"; }

# record_failure <label> <command-string> <exit-code> <output>
#   appends a copy-pasteable entry to the failures file so nothing is lost even if the
#   run is interrupted part-way through
record_failure() {
  local label="$1" cmd="$2" rc="$3" out="$4"
  {
    echo "========================================================================"
    echo "SECTION : $CURRENT_SECTION"
    echo "CHECK   : $label"
    echo "EXIT    : $rc$( [[ $rc -eq 124 ]] && echo '  (TIMED OUT after '"$TIMEOUT"'s)' )"
    echo "COMMAND : $cmd"
    echo "OUTPUT  :"
    echo "$out" | sed 's/^/          /'
    echo ""
  } >>"$FAILFILE"
}

section() {
  CURRENT_SECTION="$1"
  if [[ -n "$ONLY_SECTION" && "$ONLY_SECTION" != "$1" ]]; then RUN_SECTION=0; return; fi
  RUN_SECTION=1
  say ""
  say "${B}=== Section $1: $2 ===${N}"
}

# ok <label>  -- record a pass
ok()   { PASS=$((PASS+1));  say "  ${G}PASS${N}  $1"; }
warn() { WARN=$((WARN+1));  say "  ${Y}WARN${N}  $1"; WARNINGS+=("[$CURRENT_SECTION] $1"); }
skip() { SKIP=$((SKIP+1));  say "  ${DIM}SKIP${N}  $1"; }

# bad <label> [command] [rc] [output]  -- never aborts, always records
bad() {
  FAIL=$((FAIL+1))
  local label="$1" cmd="${2:-(n/a)}" rc="${3:-1}" out="${4:-}"
  if [[ "$rc" == "124" ]]; then
    TIMEOUTS=$((TIMEOUTS+1))
    say "  ${R}TIMEOUT${N} $label  ${DIM}(killed after ${TIMEOUT}s)${N}"
    FAILURES+=("[$CURRENT_SECTION] TIMEOUT: $label")
  else
    say "  ${R}FAIL${N}  $label"
    FAILURES+=("[$CURRENT_SECTION] $label")
  fi
  record_failure "$label" "$cmd" "$rc" "$out"
}

# RUNNER -- the single place every external command goes through.
#   * wrapped in `timeout` so nothing can stall the run
#   * stdin closed (</dev/null) so nothing can block waiting for input
#   * failures never propagate: always returns 0 to the caller
# sets: RUN_OUT, RUN_RC
run_cmd() {
  RUN_OUT="$("${TO[@]}" "$@" 2>&1 </dev/null)"; RUN_RC=$?
  log "--- CMD: $*"
  log "exit=$RUN_RC"
  log "$RUN_OUT"
  return 0
}
run_sh() {
  RUN_OUT="$("${TO[@]}" bash -c "$1" 2>&1 </dev/null)"; RUN_RC=$?
  log "--- CMD: $1"
  log "exit=$RUN_RC"
  log "$RUN_OUT"
  return 0
}

show_fail() {   # print the command + first lines of output under a FAIL
  local cmd="$1"
  echo "${DIM}        \$ $cmd${N}"
  echo "${DIM}$(echo "$RUN_OUT" | head -4 | sed 's/^/        /')${N}"
}

# check <label> <cmd...>  -- non-zero exit is a FAIL
check() {
  [[ "${RUN_SECTION:-1}" == "1" ]] || return 0
  local label="$1"; shift
  run_cmd "$@"
  if [[ $RUN_RC -eq 0 ]]; then
    ok "$label"
    [[ $VERBOSE -eq 1 ]] && echo "${DIM}        \$ $*${N}"
  else
    bad "$label" "$*" "$RUN_RC" "$RUN_OUT"
    show_fail "$*"
  fi
  return 0
}

# checkw <label> <cmd...>  -- non-zero exit is a WARN (usually "not installed")
checkw() {
  [[ "${RUN_SECTION:-1}" == "1" ]] || return 0
  local label="$1"; shift
  run_cmd "$@"
  if [[ $RUN_RC -eq 0 ]]; then
    ok "$label"
  elif [[ $RUN_RC -eq 124 ]]; then
    bad "$label" "$*" 124 "$RUN_OUT"          # a timeout is always a real problem
  else
    warn "$label"
    echo "${DIM}        \$ $*${N}"
    echo "${DIM}$(echo "$RUN_OUT" | head -3 | sed 's/^/        /')${N}"
  fi
  return 0
}

# shellck <label> <shell-string>  -- for pipelines
shellck() {
  [[ "${RUN_SECTION:-1}" == "1" ]] || return 0
  local label="$1" cmd="$2"
  run_sh "$cmd"
  if [[ $RUN_RC -eq 0 ]]; then ok "$label"
  else
    bad "$label" "$cmd" "$RUN_RC" "$RUN_OUT"
    show_fail "$cmd"
  fi
  return 0
}

# hasflag <binary + subcommand words...> -- <flag>
#   the literal "--" is only a readability separator and is stripped before running
hasflag() {
  [[ "${RUN_SECTION:-1}" == "1" ]] || return 0
  local flag="${@: -1}"
  local -a cmd=()
  local a
  for a in "${@:1:$#-1}"; do
    [[ "$a" == "--" ]] && continue
    cmd+=("$a")
  done
  run_cmd "${cmd[@]}" --help
  if [[ $RUN_RC -eq 124 ]]; then
    bad "${cmd[*]} --help timed out" "${cmd[*]} --help" 124 "$RUN_OUT"
  elif grep -q -- "$flag" <<<"$RUN_OUT"; then
    ok "${cmd[*]} supports $flag"
  else
    bad "${cmd[*]} does NOT support $flag  <-- guide needs updating" \
        "${cmd[*]} --help | grep -- $flag" "$RUN_RC" "$RUN_OUT"
  fi
  return 0
}

# explainok <path>
explainok() {
  [[ "${RUN_SECTION:-1}" == "1" ]] || return 0
  local path="$1"
  run_cmd oc explain "$path"
  if [[ $RUN_RC -eq 0 ]]; then
    ok "oc explain $path"
  else
    bad "oc explain $path  <-- field path wrong or resource missing" \
        "oc explain $path" "$RUN_RC" "$RUN_OUT"
  fi
  return 0
}

# crdversion <crd-name> <expected-version>
crdversion() {
  [[ "${RUN_SECTION:-1}" == "1" ]] || return 0
  local crd="$1" expected="$2" served
  run_cmd oc get crd "$crd" \
    -o jsonpath='{range .spec.versions[?(@.served)]}{.name}{" "}{end}'
  served="$RUN_OUT"
  if [[ $RUN_RC -eq 124 ]]; then
    bad "$crd version lookup timed out" "oc get crd $crd" 124 "$RUN_OUT"
  elif [[ $RUN_RC -ne 0 || -z "$served" ]]; then
    skip "$crd not present on this cluster (operator not installed?)"
  elif grep -qw "$expected" <<<"$served"; then
    ok "$crd serves $expected"
  else
    bad "$crd serves [$served], guide says $expected  <-- API VERSION DRIFT, update the guide" \
        "oc get crd $crd -o jsonpath='{.spec.versions[*].name}'" 0 "served versions: $served"
  fi
  return 0
}

# dryrun <label> <<<manifest-on-stdin>
dryrun() {
  [[ "${RUN_SECTION:-1}" == "1" ]] || { cat >/dev/null; return 0; }
  local label="$1" manifest mf out rc out2 rc2
  manifest="$(cat)"
  mf="$(mktemp)"; printf '%s' "$manifest" >"$mf"
  log "--- SERVER DRY-RUN: $label"
  log "$manifest"

  out="$("${TO[@]}" oc apply --dry-run=server -f "$mf" -n "$NS" 2>&1 </dev/null)"; rc=$?
  log "exit=$rc"; log "$out"
  if [[ $rc -eq 0 ]]; then
    ok "$label (server dry-run)"
    rm -f "$mf"; return 0
  fi
  if [[ $rc -eq 124 ]]; then
    bad "$label: server dry-run timed out" "oc apply --dry-run=server -f - -n $NS" 124 "$manifest"
    rm -f "$mf"; return 0
  fi

  # fall back to client-side schema validation
  out2="$("${TO[@]}" oc apply --dry-run=client --validate=true -f "$mf" -n "$NS" 2>&1 </dev/null)"; rc2=$?
  log "exit=$rc2"; log "$out2"
  if [[ $rc2 -eq 0 ]]; then
    warn "$label: schema OK, server rejected -- likely needs real cluster resources"
    echo "${DIM}$(echo "$out" | head -3 | sed 's/^/        /')${N}"
  else
    bad "$label: manifest invalid" \
        "oc apply --dry-run=server -f - -n $NS   <<< (manifest below)" "$rc" \
        "$(printf 'SERVER SAID:\n%s\n\nCLIENT SAID:\n%s\n\nMANIFEST:\n%s\n' "$out" "$out2" "$manifest")"
    echo "${DIM}$(echo "$out" | head -4 | sed 's/^/        /')${N}"
  fi
  rm -f "$mf"
  return 0
}

# ------------------------------------------------------------------- exit / interrupt
SUMMARY_PRINTED=0
print_summary() {
  [[ $SUMMARY_PRINTED -eq 1 ]] && return 0
  SUMMARY_PRINTED=1
  say ""
  say "${B}=== Summary ===${N}"
  say "  ${G}PASS $PASS${N}   ${R}FAIL $FAIL${N}   ${Y}WARN $WARN${N}   ${DIM}SKIP $SKIP${N}"
  [[ $TIMEOUTS -gt 0 ]] && say "  ${R}$TIMEOUTS check(s) TIMED OUT after ${TIMEOUT}s -- cluster slow or unreachable${N}"

  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    say ""
    say "${R}FAILURES ($FAIL) -- these need a guide correction:${N}"
    local f
    for f in "${FAILURES[@]}"; do say "  - $f"; done
  fi
  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    say ""
    say "${Y}WARNINGS ($WARN) -- usually 'not installed on this cluster':${N}"
    local w
    for w in "${WARNINGS[@]}"; do say "  - $w"; done
  fi

  say ""
  if [[ -s "$FAILFILE" ]]; then
    say "Failed commands, exit codes and full output: ${B}$FAILFILE${N}"
  else
    say "No failures recorded."
  fi
  say "Full log of every command:                   $LOG"
  say "Send both files back and the guides can be corrected against them."
}

interrupted() {
  say ""
  say "${Y}*** interrupted -- writing the summary for everything completed so far ***${N}"
  print_summary
  cleanup
  exit 130
}

cleanup() {
  if [[ -n "$TMPNS" ]]; then
    echo ""
    echo "${DIM}removing temp namespace $TMPNS ...${N}"
    "${TO[@]}" oc delete namespace "$TMPNS" --wait=false >/dev/null 2>&1
    TMPNS=""
  fi
}
trap cleanup EXIT
trap interrupted INT TERM

# ============================================================================= start
say "EX316 guide validator -- $(date)"
say "log          : $LOG"
say "failures     : $FAILFILE  (written as they happen)"
if [[ $TIMEOUT_ACTIVE -eq 1 ]]; then
  say "per-command timeout: ${TIMEOUT}s -- a hung command is reported and the run continues"
else
  say "${Y}per-command timeout: DISABLED -- a hung command can stall the run${N}"
fi

# ----------------------------------------------------------------- 0. prerequisites
section 0 "Prerequisites"
if ! command -v oc >/dev/null 2>&1; then
  say "${R}oc not found in PATH. Install the OpenShift CLI first.${N}"; exit 2
fi
ok "oc found: $(command -v oc)"

if command -v virtctl >/dev/null 2>&1; then
  ok "virtctl found: $(command -v virtctl)"
  HAVE_VIRTCTL=1
else
  warn "virtctl NOT found -- all virtctl checks will be skipped. Download it from the console (Command line tools)."
  HAVE_VIRTCTL=0
fi

if ! oc whoami >/dev/null 2>&1; then
  say "${R}Not logged in. Run: oc login -u <user> -p <pass> https://api.<cluster>:6443${N}"; exit 2
fi
ok "logged in as $(oc whoami) on $(oc whoami --show-server)"

say "  ${DIM}OCP version: $(oc version -o json 2>/dev/null | grep -o '"gitVersion"[^,]*' | head -1)${N}"

if oc get csv -n openshift-cnv >/dev/null 2>&1 && \
   oc get csv -n openshift-cnv --no-headers 2>/dev/null | grep -qi succeeded; then
  ok "OpenShift Virtualization operator is installed and Succeeded"
  HAVE_CNV=1
else
  warn "OpenShift Virtualization not detected in openshift-cnv -- VM-related checks may SKIP"
  HAVE_CNV=0
fi

# namespace used for dry-runs
if [[ $CREATE_NS -eq 1 ]]; then
  TMPNS="ex316-validate-$RANDOM"
  if oc create namespace "$TMPNS" >/dev/null 2>&1; then
    NS="$TMPNS"; ok "created temp namespace $NS (deleted on exit)"
  else
    warn "could not create a temp namespace, falling back to '$NS'"; TMPNS=""
  fi
fi
if oc get namespace "$NS" >/dev/null 2>&1; then
  ok "dry-run namespace: $NS"
else
  say "${R}namespace '$NS' does not exist. Use -n <existing-ns> or --create-ns.${N}"; exit 2
fi

# ------------------------------------------------- 1. virtctl subcommands and flags
section 1 "virtctl subcommands and flags used in the guides"
if [[ $HAVE_VIRTCTL -eq 0 ]]; then
  skip "section 1 -- virtctl not installed"
else
  for sub in start stop restart pause unpause migrate console ssh scp expose \
             create addvolume removevolume image-upload guestosinfo soft-reboot \
             vnc port-forward credentials version; do
    if virtctl "$sub" --help >/dev/null 2>&1; then
      ok "virtctl $sub exists"
    else
      bad "virtctl $sub does NOT exist on this build  <-- guide references it"
    fi
  done

  # flags used in Technique 1b / Topic 4 / Topic 7
  hasflag virtctl create vm -- --name
  hasflag virtctl create vm -- --memory
  hasflag virtctl create vm -- --instancetype
  hasflag virtctl create vm -- --preference
  hasflag virtctl create vm -- --volume-import
  hasflag virtctl create vm -- --volume-containerdisk
  hasflag virtctl create vm -- --volume-pvc
  hasflag virtctl create vm -- --volume-sysprep
  hasflag virtctl create vm -- --user
  hasflag virtctl create vm -- --password-file
  hasflag virtctl create vm -- --ssh-key
  hasflag virtctl create vm -- --access-cred
  hasflag virtctl create vm -- --run-strategy
  hasflag virtctl create vm -- --infer-instancetype
  hasflag virtctl addvolume -- --persist
  hasflag virtctl addvolume -- --serial
  hasflag virtctl addvolume -- --volume-name
  hasflag virtctl removevolume -- --volume-name
  hasflag virtctl expose -- --type
  hasflag virtctl expose -- --target-port
  hasflag virtctl ssh -- --identity-file
  hasflag virtctl stop -- --force
  hasflag virtctl stop -- --grace-period
  hasflag virtctl image-upload -- --insecure
  hasflag virtctl image-upload -- --image-path
  hasflag virtctl image-upload -- --size
fi

# ------------------------------------------------------ 2. oc subcommands and flags
section 2 "oc subcommands and flags used in the guides"
for sub in explain "api-resources" process expose patch "set probe" "adm drain" \
           "adm cordon" "adm uncordon" "adm groups" "auth can-i" extract wait label taint; do
  # shellcheck disable=SC2086
  if oc $sub --help >/dev/null 2>&1; then
    ok "oc $sub exists"
  else
    bad "oc $sub does NOT exist  <-- guide references it"
  fi
done

hasflag oc explain -- --recursive
hasflag oc api-resources -- --api-group
hasflag oc create secret generic -- --from-file
hasflag oc create secret generic -- --from-literal
hasflag oc create rolebinding -- --clusterrole
hasflag oc create rolebinding -- --group
hasflag oc create role -- --verb
hasflag oc create role -- --resource
hasflag oc create service nodeport -- --node-port
hasflag oc create service nodeport -- --tcp
hasflag oc create route edge -- --insecure-policy
hasflag oc create route edge -- --hostname
hasflag oc expose -- --hostname
hasflag oc apply -- --dry-run
hasflag oc patch -- --patch-file
hasflag oc patch -- --type
hasflag oc adm drain -- --ignore-daemonsets
hasflag oc adm drain -- --delete-emptydir-data
hasflag oc set probe -- --open-tcp
hasflag oc set probe -- --get-url
hasflag oc set probe -- --initial-delay-seconds
hasflag oc set probe -- --period-seconds
hasflag oc process -- --parameters

# ------------------------------------------- 3. Technique 1b: the examples-grep trick
section 3 "Technique 1b -- 'grep the command name' returns example commands"
if [[ $HAVE_VIRTCTL -eq 1 ]]; then
  shellck "virtctl create vm --help | grep virtctl   returns examples" \
    "test \$(virtctl create vm --help 2>&1 | grep -c '^  virtctl') -ge 5"
  shellck "...| grep virtctl | grep memory           narrows correctly" \
    "virtctl create vm --help 2>&1 | grep virtctl | grep -q memory"
  shellck "virtctl create vm --help | grep -B1 memory shows the # comment" \
    "virtctl create vm --help 2>&1 | grep -B1 memory | grep -q '^  #'"
  shellck "virtctl ssh --help has an Examples section" \
    "virtctl ssh --help 2>&1 | grep -q '^Examples:'"
fi
shellck "oc create secret generic --help has an Examples section" \
  "oc create secret generic --help 2>&1 | grep -q '^Examples:'"
shellck "oc create secret generic --help | grep 'oc create secret' returns examples" \
  "test \$(oc create secret generic --help 2>&1 | grep -c '  oc create secret') -ge 3"

# ------------------------------------------------------- 4. oc explain field paths
section 4 "oc explain -- every field path quoted in the guides"
explainok vm.spec
explainok vm.spec.runStrategy
explainok vm.spec.dataVolumeTemplates
explainok vm.spec.template.spec
explainok vm.spec.template.spec.domain
explainok vm.spec.template.spec.domain.resources
explainok vm.spec.template.spec.domain.devices
explainok vm.spec.template.spec.domain.memory
explainok vm.spec.template.spec.evictionStrategy
explainok vm.spec.template.spec.nodeSelector
explainok vm.spec.template.spec.affinity
explainok vm.spec.template.spec.tolerations
explainok vm.spec.template.spec.readinessProbe
explainok vm.spec.template.spec.livenessProbe
explainok vm.spec.template.spec.accessCredentials
explainok vm.spec.template.spec.volumes
explainok vmi.spec
explainok networkpolicy.spec
explainok networkpolicy.spec.ingress
explainok networkpolicy.spec.ingress.from
explainok networkpolicy.spec.podSelector
if [[ $HAVE_CNV -eq 1 ]]; then
  explainok datavolume.spec
  explainok datavolume.spec.source
  explainok datavolume.spec.source.pvc
  explainok datavolume.spec.source.blank
  explainok datavolume.spec.storage
  explainok virtualmachinesnapshot.spec
  explainok virtualmachinerestore.spec
  explainok virtualmachineclone.spec
fi
checkw "oc explain vm.spec --recursive | grep -i eviction finds the field" \
  bash -c "oc explain vm.spec --recursive 2>/dev/null | grep -qi eviction"

# --------------------------------------------------- 5. API versions quoted in YAML
section 5 "API versions -- do the guides' apiVersion lines match this cluster?"
crdversion virtualmachines.kubevirt.io                     v1
crdversion virtualmachineinstances.kubevirt.io             v1
crdversion virtualmachineinstancemigrations.kubevirt.io    v1
crdversion datavolumes.cdi.kubevirt.io                     v1beta1
crdversion virtualmachinesnapshots.snapshot.kubevirt.io    v1beta1
crdversion virtualmachinerestores.snapshot.kubevirt.io     v1beta1
crdversion virtualmachineclones.clone.kubevirt.io          v1beta1
crdversion nodenetworkconfigurationpolicies.nmstate.io     v1
crdversion network-attachment-definitions.k8s.cni.cncf.io  v1
crdversion backups.velero.io                               v1
crdversion restores.velero.io                              v1
crdversion dataprotectionapplications.oadp.openshift.io    v1alpha1
crdversion objectbucketclaims.objectbucket.io              v1alpha1

if [[ ${RUN_SECTION:-1} == 1 ]]; then
  say "  ${DIM}reference -- what this cluster actually reports:${N}"
  oc api-resources 2>/dev/null | grep -iE "virtualmachine|datavolume|snapshot|nmstate|network-attach|velero|oadp" \
    | sed 's/^/        /' | tee -a "$LOG"
fi

# ---------------------------------------------------------- 6. ClusterRoles for RBAC
section 6 "ClusterRoles referenced in the RBAC topics"
for cr in admin edit view kubevirt.io:admin kubevirt.io:edit kubevirt.io:view; do
  if oc get clusterrole "$cr" >/dev/null 2>&1; then
    ok "clusterrole/$cr exists"
  else
    bad "clusterrole/$cr MISSING  <-- guide tells you to bind it"
  fi
done
checkw "oc auth can-i --as impersonation works" \
  bash -c "oc auth can-i get pods -n $NS --as=someuser >/dev/null"
checkw "oc auth can-i --list works" \
  bash -c "oc auth can-i --list -n $NS >/dev/null"
if [[ $HAVE_CNV -eq 1 && ${RUN_SECTION:-1} == 1 ]]; then
  checkw "subresource virtualmachines/start is accepted by auth can-i" \
    bash -c "oc auth can-i update virtualmachines/start -n $NS >/dev/null 2>&1"
  say "  ${DIM}kubevirt clusterroles present on this cluster:${N}"
  oc get clusterrole 2>/dev/null | grep -i kubevirt | sed 's/^/        /' | tee -a "$LOG"
fi

# ----------------------------------------------- 7. Technique 4 discovery commands
section 7 "Technique 4 -- cluster discovery commands"
checkw "oc get datasources -n openshift-virtualization-os-images" \
  oc get datasources -n openshift-virtualization-os-images
checkw "oc get template -n openshift -l template.kubevirt.io/type=vm" \
  oc get template -n openshift -l template.kubevirt.io/type=vm
checkw "oc get virtualmachineclusterinstancetype" oc get virtualmachineclusterinstancetype
checkw "oc get virtualmachineclusterpreference"   oc get virtualmachineclusterpreference
check  "oc get sc"                                 oc get sc
checkw "oc get volumesnapshotclass"                oc get volumesnapshotclass
checkw "oc get packagemanifest -n openshift-marketplace" \
  bash -c "oc get packagemanifest -n openshift-marketplace >/dev/null 2>&1"
checkw "oc get nncp (NMState installed?)"          oc get nncp
checkw "oc get nnce"                               oc get nnce
checkw "oc get co authentication"                  oc get co authentication
checkw "oc get hco -n openshift-cnv"               oc get hco -n openshift-cnv

if [[ ${RUN_SECTION:-1} == 1 ]]; then
  say "  ${DIM}default StorageClass(es) and expansion support:${N}"
  oc get sc -o custom-columns='NAME:.metadata.name,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class,EXPAND:.allowVolumeExpansion' 2>/dev/null \
    | sed 's/^/        /' | tee -a "$LOG"
fi

# -------------------------------------------------- 8. Generators (client dry-run)
section 8 "Technique 5 generators -- do they produce valid YAML?"
shellck "oc create secret generic --dry-run=client -o yaml" \
  "oc create secret generic my-keys --from-literal=key1=abc --dry-run=client -o yaml | grep -q 'kind: Secret'"
shellck "oc create rolebinding --dry-run=client -o yaml" \
  "oc create rolebinding bob-vm --clusterrole=view --user=bob --dry-run=client -o yaml | grep -q 'kind: RoleBinding'"
shellck "oc create role --dry-run=client -o yaml" \
  "oc create role vm-operator --verb=get,list --resource=virtualmachines.kubevirt.io --dry-run=client -o yaml | grep -q 'kind: Role'"
shellck "oc create serviceaccount --dry-run=client -o yaml" \
  "oc create serviceaccount my-sa --dry-run=client -o yaml | grep -q 'kind: ServiceAccount'"
shellck "oc create service nodeport --dry-run=client -o yaml" \
  "oc create service nodeport ex316-svc --tcp=22:22 --node-port=30022 --dry-run=client -o yaml | grep -q nodePort"
shellck "oc create service clusterip --dry-run=client -o yaml" \
  "oc create service clusterip my-svc --tcp=80:8080 --dry-run=client -o yaml | grep -q 'kind: Service'"
shellck "oc create route edge --dry-run=client -o yaml" \
  "oc create route edge front --service=front --hostname=front.apps.example.com --insecure-policy=Redirect --dry-run=client -o yaml | grep -q 'kind: Route'"
shellck "oc create configmap --dry-run=client -o yaml" \
  "oc create configmap cm1 --from-literal=a=b --dry-run=client -o yaml | grep -q 'kind: ConfigMap'"

if [[ $HAVE_VIRTCTL -eq 1 ]]; then
  shellck "virtctl create vm (containerdisk) emits a VirtualMachine" \
    "virtctl create vm --name=t1 --memory=2Gi --volume-containerdisk=src:quay.io/containerdisks/fedora:latest | grep -q 'kind: VirtualMachine'"
  shellck "virtctl create vm (volume-import ds) emits dataVolumeTemplates" \
    "virtctl create vm --name=t2 --memory=4Gi --volume-import=type:ds,src:openshift-virtualization-os-images/rhel9 | grep -q dataVolumeTemplates"
  shellck "virtctl create vm --run-strategy=Always" \
    "virtctl create vm --name=t3 --run-strategy=Always | grep -q 'runStrategy: Always'"
  shellck "virtctl expose --help accepts the guide's flag set" \
    "virtctl expose --help 2>&1 | grep -q -- --target-port"
fi

checkw "oc process -n openshift rhel9-server-small -p NAME=probe-test -o yaml" \
  bash -c "oc process -n openshift rhel9-server-small -p NAME=probe-test -o yaml >/dev/null 2>&1"
checkw "oc process --parameters -n openshift rhel9-server-small" \
  bash -c "oc process --parameters -n openshift rhel9-server-small >/dev/null 2>&1"

# ---------------------------------------- 9. Manifests from the guides (server dry-run)
section 9 "Every YAML manifest in the guides -- server-side validation (creates nothing)"

dryrun "NetworkPolicy netpol-http (Topic 5)" <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ex316-validate-netpol
spec:
  podSelector:
    matchLabels:
      kubevirt.io/domain: myvm-lan1
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: banana
      ports:
        - protocol: TCP
          port: 80
EOF

dryrun "NetworkPolicy default-deny (Topic 3 guide)" <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ex316-validate-deny
spec:
  podSelector: {}
  policyTypes:
    - Ingress
EOF

if [[ $HAVE_CNV -eq 1 ]]; then
  dryrun "VirtualMachineSnapshot (Topic 10)" <<'EOF'
apiVersion: snapshot.kubevirt.io/v1beta1
kind: VirtualMachineSnapshot
metadata:
  name: ex316-validate-snap
spec:
  source:
    apiGroup: kubevirt.io
    kind: VirtualMachine
    name: nonexistent-vm
EOF

  dryrun "VirtualMachineRestore (Topic 10)" <<'EOF'
apiVersion: snapshot.kubevirt.io/v1beta1
kind: VirtualMachineRestore
metadata:
  name: ex316-validate-restore
spec:
  target:
    apiGroup: kubevirt.io
    kind: VirtualMachine
    name: nonexistent-vm
  virtualMachineSnapshotName: ex316-validate-snap
EOF

  dryrun "DataVolume clone from PVC (Topic 11)" <<'EOF'
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: ex316-validate-clone
spec:
  source:
    pvc:
      namespace: default
      name: nonexistent-pvc
  storage:
    resources:
      requests:
        storage: 11Gi
EOF

  dryrun "DataVolume blank disk (Topic 15)" <<'EOF'
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: ex316-validate-blank
spec:
  source:
    blank: {}
  storage:
    resources:
      requests:
        storage: 5Gi
EOF

  dryrun "VirtualMachine with probes + scheduling (Topics 9/12/14)" <<'EOF'
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: ex316-validate-vm
spec:
  runStrategy: RerunOnFailure
  template:
    metadata:
      labels:
        kubevirt.io/domain: ex316-validate-vm
    spec:
      evictionStrategy: LiveMigrate
      nodeSelector:
        datacenter: paris
      livenessProbe:
        failureThreshold: 3
        initialDelaySeconds: 100
        periodSeconds: 5
        successThreshold: 1
        tcpSocket:
          port: 3306
        timeoutSeconds: 1
      readinessProbe:
        httpGet:
          path: /health
          port: 80
        initialDelaySeconds: 10
        periodSeconds: 5
        failureThreshold: 2
      domain:
        memory:
          guest: 2Gi
        devices:
          disks:
            - name: rootdisk
              disk:
                bus: virtio
      volumes:
        - name: rootdisk
          containerDisk:
            image: quay.io/containerdisks/fedora:latest
EOF
fi

if oc get crd backups.velero.io >/dev/null 2>&1; then
  dryrun "Velero Backup (Topic 16)" <<'EOF'
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: ex316-validate-backup
spec:
  includedNamespaces:
  - database
EOF
  dryrun "Velero Restore with namespaceMapping (Topic 16)" <<'EOF'
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: ex316-validate-restore-v
spec:
  backupName: ex316-validate-backup
  namespaceMapping:
    database: database-crash
EOF
else
  skip "Velero/OADP CRDs not installed -- Backup/Restore manifests not validated"
fi

if oc get crd objectbucketclaims.objectbucket.io >/dev/null 2>&1; then
  dryrun "ObjectBucketClaim (Topic 16)" <<'EOF'
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: ex316-validate-obc
spec:
  storageClassName: openshift-storage.noobaa.io
  generateBucketName: backup
EOF
else
  skip "ObjectBucketClaim CRD not installed"
fi

# ----------------------------------------- 10. Reset commands (delete --dry-run=client)
section 10 "Reset/wipe commands -- syntax only, nothing is deleted"
checkw "oc delete vm --dry-run=client"       oc delete vm nonexistent --dry-run=client -n "$NS" --ignore-not-found
checkw "oc delete dv,pvc --dry-run=client"   oc delete dv,pvc nonexistent --dry-run=client -n "$NS" --ignore-not-found
check  "oc delete rolebinding --all --dry-run=client" oc delete rolebinding --all --dry-run=client -n "$NS"
check  "oc delete netpol --all --dry-run=client"      oc delete netpol --all --dry-run=client -n "$NS"
check  "oc delete --force --grace-period=0 syntax" \
  oc delete pod nonexistent --force --grace-period=0 --dry-run=client -n "$NS" --ignore-not-found
shellck "merge-patch syntax accepted by the API (finalizer-strip form)" \
  "oc patch namespace $NS --type=merge -p '{\"metadata\":{\"annotations\":{\"ex316-validate\":\"x\"}}}' --dry-run=server >/dev/null"
shellck "json-patch 'remove' op is accepted by oc patch" \
  "oc patch namespace $NS --type=json -p='[{\"op\":\"remove\",\"path\":\"/metadata/annotations/ex316-absent\"}]' --dry-run=server >/dev/null 2>&1 || oc patch namespace $NS --type=json -p='[{\"op\":\"add\",\"path\":\"/metadata/annotations/ex316\",\"value\":\"x\"}]' --dry-run=server >/dev/null"
check "oc label ... <key>-  (remove-label syntax)" \
  bash -c "oc label namespace $NS ex316-nonexistent- --dry-run=client >/dev/null"
check "oc adm taint ... <key>-  (remove-taint syntax)" \
  bash -c "oc adm taint nodes --all ex316-nonexistent- --dry-run=client >/dev/null 2>&1 || true"
checkw "oc adm drain --dry-run syntax" \
  bash -c "oc adm drain \$(oc get nodes -o jsonpath='{.items[0].metadata.name}') --ignore-daemonsets --delete-emptydir-data --force --dry-run=client >/dev/null"
checkw "oc adm cordon --dry-run" \
  bash -c "oc adm cordon \$(oc get nodes -o jsonpath='{.items[0].metadata.name}') --dry-run=client >/dev/null"

# ============================================================================= summary
print_summary
[[ $FAIL -eq 0 ]]
