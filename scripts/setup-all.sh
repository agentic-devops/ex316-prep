#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

INSTALL_MTV="${INSTALL_MTV:-true}"

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
