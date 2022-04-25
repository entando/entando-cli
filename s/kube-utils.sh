#!/bin/bash
# KUBERNETESTOOLS


kube.oc.namespace.suspend() {
  local ns="$1" tmo="$2"
  NONNULL ns tmo
  _log_d "Suspending the namespace: \"$ns\""
  export -f _kubectl
  timeout "$tmo" _kubectl scale statefulset,deployment -n "$ns" --all --replicas=0
}

kube.utils.url_path_to_identifier() {
  local res="$1"
  res="${res//_/-}"
  res="${res//:/-}"
  res="${res//./-}"
  res="${res//\//-}"
  echo "$res"
}
