#!/bin/bash

H() { echo -e "Helps managing the system that hosts the quickstart VM | Syntax: ${0##*/} update-hosts-file ..."; }
[ "$1" = "-h" ] && H && exit 0

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR/.." || {
  echo "Internal error: unable to find the script source dir"
  exit
}

. s/_base.sh

case "$1" in
"update-hosts-file")
  case "$2" in
  manual)
    set_nn_dn "ADDR" "$3"
    set_nn_dn "ENTANDO_NAMESPACE" "$4"
    set_nn_dn "ENTANDO_APPNAME" "$5"
    set_nn_fdn "ENTANDO_SUFFIX" "${6:-$C_DEF_CUSTOM_IP.nip.io}"
    set_nn_fdn "NIK" "${7:-DEFAULT}"
    VM_NAME="$NIK"
    ;;
  mixed)
    set_nn_dn "VM_NAME" "$3"
    ADDR=$(multipass list | grep "Running" | grep "$VM_NAME" | awk '{print $3}')
    [ -z "$ADDR" ] && EXIT_UE "Unable to find a running multipass VM with name \"$VM_NAME\""

    set_nn_dn "ENTANDO_NAMESPACE" "$4"
    set_nn_dn "ENTANDO_APPNAME" "$5"
    set_nn_fdn "ENTANDO_SUFFIX" "${6:-$C_DEF_CUSTOM_IP.nip.io}"
    ;;
  auto)
    set_nn_dn "VM_NAME" "$3"
    ADDR=$(multipass list | grep "Running" | grep "$VM_NAME" | awk '{print $3}')
    [ -z "$ADDR" ] && EXIT_UE "Unable to find a running multipass VM with name \"$VM_NAME\""

    ENTS=$(multipass exec "$VM_NAME" -- ls .entando/ent)
    NUM_ENTS=$(echo $ENTS | wc -l)

    [ $NUM_ENTS -eq 0 ] && FATAL "No ent found in VM"
    [ $NUM_ENTS -eq 1 ] && {
      ent_dir=$ENTS
      CFG=$(multipass exec "$VM_NAME" -- bash -c '. .entando/ent/'"$ent_dir"'/w/.cfg && echo "$ENTANDO_NAMESPACE;$ENTANDO_APPNAME;$ENTANDO_SUFFIX"')

      IFS=';' read -r -a CFG_ARR <<<"$CFG"

      set_nn_dn "ENTANDO_NAMESPACE" "${CFG_ARR[0]}"
      set_nn_dn "ENTANDO_APPNAME" "${CFG_ARR[1]}"
      set_nn_fdn "ENTANDO_SUFFIX" "${CFG_ARR[2]}"

    } || FATAL "Multiple ENTS found, unable to proceed with automatic discovery"
    ;;
  *)
    FATAL "unknown option $2"
    ;;
  esac

  _log_i 1 "Setting host file entries for VM \"$VM_NAME\" with address \"$ADDR\""

  #ask "This will change you OS hosts file. Proceed?" || EXIT_UE "User Abort"
  hostsfile_clear "$VM_NAME"
  hostsfile_add_dns "$ADDR" "$ENTANDO_APPNAME-$ENTANDO_NAMESPACE.$ENTANDO_SUFFIX" "$VM_NAME"
  hostsfile_add_dns "$ADDR" "$ENTANDO_APPNAME-kc-$ENTANDO_NAMESPACE.$ENTANDO_SUFFIX" "$VM_NAME"
  ;;
*)
  H
  ;;
esac
