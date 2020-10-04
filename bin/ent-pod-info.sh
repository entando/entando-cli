#!/bin/bash

[ "$1" = "-h" ] && echo -e "Displays infomations related to a set of pods | Syntax: ${0##*/} namespace pod-name-pattern" && exit 0

ENTANDO_NAMESPACE="$1"
[ "$ENTANDO_NAMESPACE" == "" ] && echo "please provide the namespace name" 1>&2 && exit 1
shift

POD_PATT="$1"
[ "$POD_PATT" == "" ] && echo "please provide the pod pattern" 1>&2 && exit 1
shift

KUBECTL="sudo k3s kubectl"
ensure_sudo

for pod in $($KUBECTL get pods -n "$ENTANDO_NAMESPACE" | awk 'NR>1' | awk '{print $1}' | grep "$POD_PATT"); do
  echo -e "===\n====================================================================================================\n==="
  echo "> POD: $pod"
  $KUBECTL describe pods/"$pod" -n "$ENTANDO_NAMESPACE"
  for co in $($KUBECTL get pods/"$pod" -o jsonpath='{.spec.containers[*].name}{"\n"}' -n "$ENTANDO_NAMESPACE"); do
    echo -e "~~~\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n~~~"
    echo -e ">\tCONTAINER: $co"
    $KUBECTL logs pods/"$pod" -c "$co" -n "$ENTANDO_NAMESPACE"
  done
done
