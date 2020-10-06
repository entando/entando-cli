#!/bin/bash

[ "$1" = "-h" ] && echo -e "Automatically execute the quickstart deployment | Syntax: ${0##*/} --destroy | --config | addr-mode namespace appname" && exit 0

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
cd "$DIR/.." || { echo "Internal error: unable to find the script source dir"; exit; }

. s/_base.sh

if [ "$1" == "--destroy" ]; then
  reload_cfg
  ensure_sudo
  ask "Should I destroy namespace \"$ENTANDO_NAMESPACE\" and contained app \"$ENTANDO_APPNAME\" ?" && {
    $KUBECTL delete namespace "$ENTANDO_NAMESPACE"
  }
  exit
fi

if [ "$1" == "--with-vm" ]; then
  WITH_VM=true
  [ -z "$ENTANDO_VM_NAME" ] && ENTANDO_VM_NAME="entando-test"
  shift
else
  WITH_VM=false
fi

JUST_SET_CFG=false
if [ "$1" == "--config" ]; then
  JUST_SET_CFG=true
  shift
fi

! $JUST_SET_CFG && {
  case "$1" in
    "--simple" | --simple=*)
      AUTO_ADD_ADDR=false
      if [[ $1 =~ --addr=(.*) ]]; then
        set_nn_ip ADDR "${BASH_REMATCH[1]}"
      else
        ADDR="$(hostname -I | awk '{print $1}')"
      fi
      shift
      ;;
    "--dedicated" | --dedicated=*)
      AUTO_ADD_ADDR=true
      if [[ $1 =~ --dedicated=(.*) ]]; then
        set_nn_dn ADDR "${BASH_REMATCH[1]}"
      else
        ADDR=$C_DEF_CUSTOM_IP
      fi
      shift
      ;;
    *)
      echo -e "Please provide a valid \"addr-mode\" mode option:" 1>&2
      echo "  --simple=[ADDR]   => standard installation with an existing ip" 1>&2
      echo "  --dedicated=[ADDR] => automatically adds an IP on the OS (only netplan)" 1>&2
      echo "" 1>&2
      echo "NOTE: if \"ADDR\" is not provided one is automatically determined" 1>&2
      echo "" 1>&2
      exit 1
      ;;
  esac
}

ENTANDO_NAMESPACE="$1"
[ "$ENTANDO_NAMESPACE" == "" ] && echo "please provide the namespace name" 1>&2 && exit 1
shift

ENTANDO_APPNAME="$1"
[ "$ENTANDO_APPNAME" == "" ] && echo "please provide the app name" 1>&2 && exit 1
shift

_log_i 2 "> Checking environment"

$JUST_SET_CFG || $WITH_VM || {
  . bin/ent-check-env.sh runtime
}

save_cfg_value "ENTANDO_NAMESPACE" "$ENTANDO_NAMESPACE"
save_cfg_value "ENTANDO_APPNAME" "$ENTANDO_APPNAME"
save_cfg_value "ENTANDO_SUFFIX" "$ADDR.nip.io"

$JUST_SET_CFG && echo "Config has been written" && exit 0

ensure_sudo

$WITH_VM && {
  _log_i 2 "> Generating the base VM"
  multipass launch --name "$ENTANDO_VM_NAME" --cpus 4 --mem 8G --disk 12G

  _log_i 2 "> Installing Ent on the VM"
  multipass exec "$ENTANDO_VM_NAME" -- bash -c \
    "curl \"https://raw.githubusercontent.com/entando/entando-cli/$ENTANDO_CLI_VERSION/auto-install\" \
        | ENTANDO_CLI_VERSION=\"$ENTANDO_CLI_VERSION\" \
          ENTANDO_RELEASE=\"$ENTANDO_RELEASE\" \
          bash"

  _log_i 2 "> Running the entando quickstart from the VM"
  multipass exec "$ENTANDO_VM_NAME" -- bash -c \
    "cd && . \".entando/ent/$ENTANDO_RELEASE/cli/\"$ENTANDO_CLI_VERSION\"/activate\" && \
    ENTANDO_WITH_VM=\"\" ent-quickstart.sh --simple \"$ENTANDO_NAMESPACE\" \"$ENTANDO_APPNAME\""

  exit 0
}

_log_i 2 "> Generating the kubernetes specification file for the deployment"

$AUTO_ADD_ADDR && {
  net_is_address_present "$ADDR" || {
    netplan_add_custom_ip "$ADDR/24"
    sudo netplan generate
    sudo netplan apply
    sleep 1
  }
}

net_is_address_present "$ADDR" || {
  FATAL "The designated ip address is not present on the system"
}

_log_d 5 "> Using ip address: $ADDR"

FQADDR="$ADDR.nip.io"

cat "dist/$DEPL_SPEC_YAML_FILE.tpl" \
  | sed "s/PLACEHOLDER_ENTANDO_NAMESPACE/$ENTANDO_NAMESPACE/" \
  | sed "s/PLACEHOLDER_ENTANDO_APPNAME/$ENTANDO_APPNAME/" \
  | sed "s/your\\.domain\\.suffix\\.com/$FQADDR/" \
    > "w/$DEPL_SPEC_YAML_FILE"

_log_i 3 "File \"w/$DEPL_SPEC_YAML_FILE\" generated"

ask "Should I register the CRDs?" && {
  $KUBECTL apply -f "dist/crd"
}

ask "Should I start the deployment?" && {
  $KUBECTL create namespace "$ENTANDO_NAMESPACE"
  $KUBECTL create -f "w/$DEPL_SPEC_YAML_FILE"
}

ask "Should I start the monitor?" && {
  ent-app-info.sh watch || true
} || {
  echo -e "\n~~~\nUse the command:\n  - ent-app-info.sh watch\nto check the status of the app"
}
