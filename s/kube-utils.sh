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

kube.utils.is_api_server_reachable() {
  ENT_KUBECTL_NO_CUSTOM_ERROR_MANAGEMENT=true \
    _kubectl version -o yaml &>/dev/null
}

kube.require_kube_reachable() {
  kube.utils.is_api_server_reachable || _FATAL -s "Unable to connect to the designated kubernetes cluster"
}
