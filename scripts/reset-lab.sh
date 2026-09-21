#!/usr/bin/env bash
# Usage: scripts/reset-lab.sh <lab-number>   e.g. scripts/reset-lab.sh 03
# Deletes objects listed in labs/NN-*/RESET_OBJECTS, then namespaces in labs/NN-*/NAMESPACES.
set -euo pipefail
cd "$(dirname "$0")/.."

[ $# -eq 1 ] || { echo "usage: $0 <lab-number>"; exit 1; }
dir=$(ls -d labs/"$1"-* 2>/dev/null | head -1 || true)
[ -n "$dir" ] || { echo "no lab folder for '$1'"; exit 1; }

if [ -s "$dir/RESET_OBJECTS" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac
    # shellcheck disable=SC2086
    oc delete $line --ignore-not-found --wait=false
  done < "$dir/RESET_OBJECTS"
fi

if [ -s "$dir/NAMESPACES" ]; then
  while IFS= read -r ns; do
    [ -z "$ns" ] && continue
    oc delete namespace "$ns" --ignore-not-found --wait=false
  done < "$dir/NAMESPACES"
fi
echo "Reset of $dir requested."
