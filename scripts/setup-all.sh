#!/usr/bin/env bash
# Usage: setup-all.sh [--clean]
#   --clean   Tear down CNV, NMState and OADP namespaces/subscriptions first,
#             then reinstall from scratch. Use this when a previous install
#             got stuck. See docs/troubleshoot-operator-install.md.
set -euo pipefail
cd "$(dirname "$0")/.."

INSTALL_MTV="${INSTALL_MTV:-true}"
CLEAN="false"
[ "${1:-}" = "--clean" ] && CLEAN="true"

wait_csv() {  # ns name-prefix
  echo "Waiting for CSV $2 in $1 ..."
  until oc get csv -n "$1" --no-headers 2>/dev/null | grep -E "^$2.*Succeeded" >/dev/null; do
    sleep 10
  done
}

install_sub() {  # manifest packagemanifest-name
  local ch
  ch=$(oc get packagemanifest "$2" -n openshift-marketplace \
        -o jsonpath='{.status.defaultChannel}')
  echo "Using channel '$ch' for $2"
  sed -E "s|^([[:space:]]*channel:).*|\1 ${ch}|" "$1" | oc apply -f -
}

clean_namespace() {  # ns
  local ns="$1"
  echo "== Cleaning $ns =="
  oc delete hyperconverged --all -n "$ns" --ignore-not-found
  oc delete nmstate --all -n "$ns" --ignore-not-found 2>/dev/null || true
  oc delete dataprotectionapplication --all -n "$ns" --ignore-not-found 2>/dev/null || true
  oc delete subscription --all -n "$ns" --ignore-not-found
  oc delete csv --all -n "$ns" --ignore-not-found
  oc delete operatorgroup --all -n "$ns" --ignore-not-found
  oc delete installplan --all -n "$ns" --ignore-not-found
  oc delete namespace "$ns" --ignore-not-found
}

if [ "$CLEAN" = "true" ]; then
  echo "########## --clean: tearing down existing install first ##########"
  clean_namespace openshift-cnv
  clean_namespace openshift-nmstate
  clean_namespace openshift-adp
  [ "$INSTALL_MTV" = "true" ] && clean_namespace openshift-mtv
  for ns in openshift-cnv openshift-nmstate openshift-adp openshift-mtv minio; do
    oc get namespace "$ns" >/dev/null 2>&1 && \
      oc wait --for=delete "namespace/$ns" --timeout=120s 2>/dev/null || true
  done
  echo "########## clean complete, reinstalling ##########"
fi

echo "== CNV =="
oc apply -f setup/cnv/01-install.yaml
wait_csv openshift-cnv kubevirt-hyperconverged-operator
oc apply -f setup/cnv/02-hyperconverged.yaml
oc wait hco/kubevirt-hyperconverged -n openshift-cnv \
  --for=condition=Available --timeout=20m

echo "== NMState =="
oc apply -f setup/nmstate/01-install.yaml
wait_csv openshift-nmstate kubernetes-nmstate-operator
oc apply -f setup/nmstate/02-nmstate-cr.yaml

echo "== OADP + MinIO =="
oc apply -f setup/oadp/02-minio.yaml
install_sub setup/oadp/01-install.yaml redhat-oadp-operator
wait_csv openshift-adp oadp-operator
oc apply -f setup/oadp/03-credentials.yaml
oc apply -f setup/oadp/04-dpa.yaml

if [ "$INSTALL_MTV" = "true" ]; then
  echo "== MTV =="
  install_sub setup/mtv/01-install.yaml mtv-operator
  wait_csv openshift-mtv mtv-operator
  oc apply -f setup/mtv/02-forklift-controller.yaml
fi

echo "Done. Run ./scripts/verify-setup.sh"
echo "If anything got stuck this time, see docs/troubleshoot-operator-install.md"
echo "or rerun: ./scripts/setup-all.sh --clean"
