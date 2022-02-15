#!/bin/bash
# KUBERNETESTOOLS


kube.oc.namespace.suspend() {
  local ns="$1" tmo="$2"
  NONNULL ns tmo
  _log_d "Suspending the namespace: \"$ns\""
  export -f _kubectl
  timeout "$tmo" _kubectl scale statefulset,deployment -n "$ns" --all --replicas=0
}
