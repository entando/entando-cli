#!/bin/bash

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# VM MANAGEMENT

managed-vm-attach() {
  args_or_ask -n -f -- '--help' "$@" && {
    local HH="--help"
    echo "> Parameters:"
  }

  args_or_ask_from_list REMOTES -m -a ${HH:+"$HH"} VM_NAME 1 "any" \
    "remotes" "%sp VM to which ent kubectl should attach" "$@"

  [ -n "$HH" ] && return 0

  local ADDR
  ADDR="$(multipass exec "$VM_NAME" -- hostname -I | awk '{print $1}')"
  [ -z "$ADDR" ] && FATAL "Unable to determine the VM address (\"$VM_NAME\")"

  (
    set -e
    [ -f "$ENT_KUBECONF_FILE_PATH" ] && rm "$ENT_KUBECONF_FILE_PATH"
    touch "$ENT_KUBECONF_FILE_PATH"
    chmod 600 "$ENT_KUBECONF_FILE_PATH"
  ) || FATAL "Unable to prepare to KUBECONFIG file"

  multipass exec "$VM_NAME" -- bash -c "sudo cat /etc/rancher/k3s/k3s.yaml" |
    _perl_sed "s/127.0.0.1/$ADDR/" >>"$ENT_KUBECONF_FILE_PATH"

  kubectl_mode --reset-cfg
  save_cfg_value "DESIGNATED_KUBECONFIG" "$ENT_KUBECONF_FILE_PATH"
  save_cfg_value "DESIGNATED_VM" "$VM_NAME"
}

managed-vm-detach() {
  [ "$1" = "--preserve-config-file" ] || rm "$ENT_KUBECONF_FILE_PATH"
  save_cfg_value "DESIGNATED_KUBECONFIG" ""
  save_cfg_value "DESIGNATED_VM" ""
  save_cfg_value "DESIGNATED_VM_NAMESPACE" ""
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# KUBECONFIG FILE

kubeconfig-attach() {
  local KUBECONFIG
  args_or_ask ${HH:+"$HH"} -a -- KUBECONFIG '1///%sp kubeconfig file' "$@"
  #kubectl_mode --reset-cfg
  save_cfg_value "DESIGNATED_KUBECONFIG" "$KUBECONFIG"
}

kubeconfig-detach() {
  save_cfg_value "DESIGNATED_KUBECONFIG" ""
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# KUBE CONTEXT

kubectx-select() {
  local res_var="$1";shift
  local kube_context="$1";shift
  local LST
  stdin_to_arr $'\n\r' LST < <(kubectx-list "$kube_context")

  if [ "${#LST[@]}" -le 0 ]; then
    [ -n "$kube_context" ] && FATAL "No kube context was found with the provided data"
    FATAL "No kube context was found"
  fi

  # shellcheck disable=SC2076 disable=SC2199
  if [[ ! " ${LST[@]} " =~ " ${kube_context} " ]]; then
    select_one "Kube Context" "${LST[@]}"
    # shellcheck disable=SC2154
    kube_context="$select_one_res_alt"
  fi
  _set_var "$res_var" "$kube_context"
}

kubectx-attach() {
  DESIGNATED_KUBECTX="$1"
  save_cfg_value "DESIGNATED_KUBECTX" "$DESIGNATED_KUBECTX"
}

kubectx-detach() {
  save_cfg_value "DESIGNATED_KUBECTX" ""
}

kubectx-list() {
  local filter
  HH="$(parse_help_option "$@")"
  show_help_option "$HH"
  args_or_ask ${HH:+"$HH"} -n -a -- filter '1///filter' "$@"
  [ -n "$HH" ] && exit 0

  if [ -n "$filter" ]; then
    ENT_KUBECTL_NO_AUTO_SUDO=true _kubectl config view -o jsonpath='{.contexts[*].name}' \
    | tr -s ' ' $'\n' | grep "$filter"
  else
    ENT_KUBECTL_NO_AUTO_SUDO=true _kubectl config view -o jsonpath='{.contexts[*].name}' \
    | tr -s ' ' $'\n'
  fi
}
