#!/bin/bash
# shellcheck disable=SC2155

XDEV_TEST_WORK_DIR="/tmp/entando-test-u$UID/ent/mocks-state"
[ -f "$XDEV_TEST_WORK_DIR" ] && rm -r "$XDEV_TEST_WORK_DIR"
mkdir -p "$XDEV_TEST_WORK_DIR"
# shellcheck disable=SC2034
CFG_FILE="$XDEV_TEST_WORK_DIR/ent-cfg"
MOCK_CALL_NUM=0
MOCK_CALL_ID=""

mock-log() {
  debug-print --title "######## MOCK: [$MOCK_CALL_ID]" "$1"
  echo -e "######## MOCK: [$MOCK_CALL_ID]\n$1" >> "$XDEV_TEST_WORK_DIR/mock.log"
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
      if [ -d "$XDEV_TEST_WORK_DIR/multipass/$VMNAME" ]; then
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
      local VMMK="$XDEV_TEST_WORK_DIR/multipass/$VMNAME"
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
      local VMMK="$XDEV_TEST_WORK_DIR/multipass/$DST_VMNAME"
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
      cp -r "$3" "$XDEV_TEST_WORK_DIR/kubectl-create-${MOCK_CALL_NUM}"
      ;;
    "apply::-f")
      mock-log "## $KD executing \"Apply\" on resource(s) from source file/dir \"$3\"\n## ($*)"
      mock-log "($*)"
      cp -r "$3" "$XDEV_TEST_WORK_DIR/kubectl-apply-${MOCK_CALL_NUM}"
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
