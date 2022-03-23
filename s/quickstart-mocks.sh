#!/bin/bash
# shellcheck disable=SC2155

TEST_WORKDIR="/tmp/entando-test-u$UID/ent/mocks-state"
rm -r "$TEST_WORKDIR"
mkdir -p "$TEST_WORKDIR"
# shellcheck disable=SC2034
CFG_FILE="$TEST_WORKDIR/ent-cfg"
MOCK_CALL_NUM=0
MOCK_CALL_ID=""

mock-log() {
  debug-print --title "$(B)######## MOCK: [$MOCK_CALL_ID]" "$1"
  echo -e "######## MOCK: [$MOCK_CALL_ID]\n$1" >> "$TEST_WORKDIR/mock.log"
  print_hr 1>&2
}

mock-log-param() {
  local param="$1"; shift
  local key="$1"; shift
  local VMMK="$1"; shift
  local RES
  args_or_ask -n -s RES "$param" "$@" && {
    echo "$RES" >> "$VMMK/$key"
  }
}

multipass() {
  new-mock-call-id

  case "$1" in
    "info")
      local VMNAME="$2"
      if [ -d "$TEST_WORKDIR/multipass/$VMNAME" ]; then
        mock-log "VM \"$VMNAME\" found"
        return 0
      else
        mock-log "VM \"$VMNAME\" not found"
        return 1
      fi
      ;;
    "launch")
      local VMNAME RES
      args_or_ask -n -s VMNAME '--name' "$@"
      local VMMK="$TEST_WORKDIR/multipass/$VMNAME"
      [ -d "$VMMK" ] && FATAL "MOCK: VM \"$VMMK\" already exists"
      mkdir -p "$VMMK/_volume_/tmp" -p "$VMMK/_volume_/home/user" || FATAL "MOCK: Error creating VM \"$VMMK\""

      mock-log-param "--cpus" "cpus" "$VMMK" "$@"
      mock-log-param "--mem" "mem" "$VMMK" "$@"
      mock-log-param "--disk" "disk" "$VMMK" "$@"

      mock-log "## multipass launched VM: \"$VMNAME\""

      ;;
    "copy-files")
      local SRC="$2"
      local DST_VMNAME="${3//:*/}"
      local DST_PATH="${3//*:/}"
      local VMMK="$TEST_WORKDIR/multipass/$DST_VMNAME"
      [ -d "$VMMK" ] || FATAL "MOCK: VM \"$VMMK\" doesn't exists"
      if [ "${DST_PATH:0:1}" = "/" ]; then
        cp -r "$SRC" "$VMMK/_volume_/$DST_PATH"
      else
        cp -r "$SRC" "$VMMK/_volume_/home/user/$DST_PATH"
      fi

      mock-log "## multipass copied \"$2\" to \"$3\""
      ;;
    "exec")
      local VMNAME="$2"
      shift 2
      mock-log "## Executing in VM \"$VMNAME\" the script:\n$*"
      ;;
  esac
}

# shellcheck disable=SC2120
new-mock-call-id() {
  local i="${1:-0}"
  ((MOCK_CALL_NUM++))
  MOCK_CALL_ID=$(printf "%s🠜|%s🠜|%s🠜|%s|%02d" \
    "${FUNCNAME[$((i+1))]}" \
    "${FUNCNAME[$((i+2))]}" \
    "${FUNCNAME[$((i+3))]}" \
    "${FUNCNAME[$((i+4))]}" \
    "${MOCK_CALL_NUM}")
}

# shellcheck disable=SC2120
_kubectl() {
  new-mock-call-id

  if [ -n "$ENT_KUBECTL_CMD" ]; then
    local KD="$ENT_KUBECTL_CMD"
  else
    local KD="Kubectl"
  fi

  case "$1::$2" in
    "create::-f")
      mock-log "## $KD executing \"Create\" on resource(s) from source file/dir \"$3\"\n## ($*)"
      cp -r "$3" "$TEST_WORKDIR/kubectl-create-${MOCK_CALL_NUM}"
      ;;
    "apply::-f")
      mock-log "## $KD executing \"Apply\" on resource(s) from source file/dir \"$3\"\n## ($*)"
      mock-log "($*)"
      cp -r "$3" "$TEST_WORKDIR/kubectl-apply-${MOCK_CALL_NUM}"
      ;;
    "create::namespace")
      mock-log "## $KD executing \"Create\" of namespace \"$3\""
      ;;
    "delete::namespace")
      mock-log "## $KD executing \"Delete\" of namespace \"$3\""
      ;;
    *)
      FATAL"MOCK: not supported by the mock"
      ;;
  esac
}

ent-kubectl() {
  _kubectl "$@" 
}

setup_kubectl() {
  new-mock-call-id
  mock-log "## Ent Kubectl set up"
  true;
}
#
ask() {
  new-mock-call-id
  mock-log "## Asked \"$1\" with result: \"true\""
  true;
}

prepare_for_privileged_commands() {
  new-mock-call-id
  mock-log "## Privileged command execution prepared"
  true;
}

ent-check-env() {
  new-mock-call-id
  mock-log "## Checked env with params: $*"
  true;
}

ent-host() {
  new-mock-call-id
  mock-log "## Run ent host with params: $*"
  true;
}

ent-app-info() {
  new-mock-call-id
  mock-log "## Run ent app-info params: $* with ENTANDO_ENT_KUBECTL_CMD=\"$ENTANDO_ENT_KUBECTL_CMD\""
  true;
}

ent-attach-vm() {
  new-mock-call-id
  local VMNAME="$1"
  mock-log "## Attaching VM \"$VMNAME\""
  multipass info "$VMNAME" || FATAL "Unable to attach nonexistent VM \"$VMNAME\""
  true;
}

qs-edit-manifest() {
  if [ "$1" = "true" ]; then
    mock-log "## Run edit-manifest of file \"$2\""
    _edit "$2"
  elif [[ "$1" != "false" && "$1" != "" ]]; then
    mock-log "## Run edit-manifest of file \"$2\" with editor \"$3\""
  fi
}

net_is_address_present() {
  new-mock-call-id
  mock-log "## Run net_is_address_present params: $*"
  true;
}

sourced-ent-profile-use() {
  new-mock-call-id
  mock-log "## Using profile \"$1\" in this tty session"
  true;
}

ent-profile-new() {
  new-mock-call-id
  name="$1"; shift
  mock-log "## Creating profile \"$name\" with data: $*"
  true;
}

ent-profile-delete() {
  new-mock-call-id
  mock-log "## Deleting profile \"$1\""
  true;
}

ent-set-kubectl-cmd() {
  new-mock-call-id
  mock-log "## Setting kubectl command to \"$1\""
  ent kubectl ent-set-cmd "sudo k3s kubectl"
}

QS.VM.SETUP-HOST-DNS-WITH-HOSTMAME-IF-REQUESTED() {
  $ENTANDO_AUTO_HOSTNAME && {
    if prepare_for_privileged_commands; then
      _log_i "> Creating the hostname DNS \"$ENTANDO_VM_NAME\" on the hosts file"
      ent-host setup-vm-hostname "$ENTANDO_VM_NAME"
    else
      _log_w "> Unable to setup the hostname DNS \"$ENTANDO_AUTO_HOSTNAME\" on the hosts file"
      _log_w "> Please run \"ent host setup-vm-hostname \"$ENTANDO_VM_NAME\" manually"
    fi
  }
}

QS.VM.ON-VM.RUN-ENT-CHECK-ENV() {
  _log_i "> Checking the environment on the VM"
  if ! $ENTANDO_NO_CHECK; then
    local YES_OPT=""
    if $ENTANDO_OPT_YES_FOR_ALL; then
      YES_OPT="--yes"
    fi

    local OPT_DNS=""
    if $WITH_HOSTNAME; then
      OPT_DNS+="--no-dns-fix "
    fi

    multipass exec "$ENTANDO_VM_NAME" -- bash -c "
      cd \
      && source \".entando/ent/$ENTANDO_RELEASE/cli/$ENTANDO_CLI_VERSION/activate\" \
      && ent which \
      && $VM_VAR ent check-env runtime \
        ${YES_OPT:+"$YES_OPT"} \
        ${OPT_DNS:+"$OPT_DNS"}"
  fi
}

QS.VM.REGISTER-VM() {
  _log_i "> Registering the VM"
  map-set REMOTES "$ENTANDO_VM_NAME" "$ENTANDO_NAMESPACE/$ENTANDO_APPNAME/$ENTANDO_RELEASE"
  
  ! $ENTANDO_NO_AUTO_ATTACH && {
    ent-attach-vm "$ENTANDO_VM_NAME"
    save_cfg_value "DESIGNATED_VM_NAMESPACE" "$ENTANDO_NAMESPACE"
    save_cfg_value "ENTANDO_NAMESPACE" "$ENTANDO_NAMESPACE"
  }
}

QS.VM.ON-VM.START-QUICKSTART() {
  multipass exec "$ENTANDO_VM_NAME" -- bash -c "
    cd \
    && source \".entando/ent/$ENTANDO_RELEASE/cli/$ENTANDO_CLI_VERSION/activate\" \
    && ent quickstart $VM_OPT \"$ENTANDO_NAMESPACE\" \"$ENTANDO_APPNAME\" \
         --in-quickstart-vm \
         --release=\"$ENTANDO_RELEASE\" \
         --cli-version=\"$ENTANDO_CLI_VERSION\" \
        ${OPT_OVERRIDE:+"$OPT_OVERRIDE"} \
    "
}
