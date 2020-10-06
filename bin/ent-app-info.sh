#!/bin/bash

[ "$1" = "-h" ] && echo -e "Displays information about an entando app | Syntax: ${0##*/} [namespace]" && exit 0

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR/.." || {
  echo "Internal error: unable to find the script source dir"
  exit
}

. s/_base.sh

WATCH=false
STATUS=false
[ "$1" == "watch" ] && {
  WATCH=true
  shift
}
[ "$1" == "status" ] && {
  STATUS=true
  shift
}

reload_cfg
[ "$1" != "" ] && ENTANDO_NAMESPACE="$1"

$WATCH && {
  watch s/check-app-status.sh "$ENTANDO_NAMESPACE" "$ENTANDO_APPNAME"
  exit
}

$STATUS && {
  s/check-app-status.sh "$ENTANDO_NAMESPACE" "$ENTANDO_APPNAME"
  exit
}

ensure_sudo

_log_i 1 "NODES:"
$KUBECTL get nodes

_log_i 1 "PODS:"
$KUBECTL get pods -A

_log_i 1 "Ingress path:"
$KUBECTL get ingress -n "$ENTANDO_NAMESPACE" \
  -o jsonpath='{.items[2].spec.rules[*].host}{.items[2].spec.rules[*].http.paths[2].path}{"\n"}' \
  2>>"$ENT_RUN_TMP_DIR" || {
  FATAL "Error determining the ingress location"
}