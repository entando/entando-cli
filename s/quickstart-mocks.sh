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
  if $ENTANDO_IS_TTY; then
    B() { echo -e '\033[101;37m'; }
    E() { echo -e '\033[0;39m'; }
  else
    B() { true; }
    E() { true; }
  fi

  echo -e "$(B)######## MOCK: [$MOCK_CALL_ID]\n$1$(E)" 1>&2
  echo -e "######## MOCK: [$MOCK_CALL_ID]\n$1" >> "$TEST_WORKDIR/mock.log"
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

  case "$1::$2" in
    "create::-f")
      mock-log "## Kubectl executing Create of resource(s) from source file/dir \"$3\""
      cp -r "$3" "$TEST_WORKDIR/kubectl-create-${MOCK_CALL_NUM}"
      ;;
    "apply::-f")
      mock-log "## Kubectl executing Apply of resource(s) from source file/dir \"$3\""
      cp -r "$3" "$TEST_WORKDIR/kubectl-apply-${MOCK_CALL_NUM}"
      ;;
    "create::namespace")
      mock-log "## Kubectl executing Create of namespace \"$3\""
      ;;
    "delete::namespace")
      mock-log "## Kubectl executing Delete of namespace \"$3\""
      ;;
  esac
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
  mock-log "## Run ent app-info params: $*"
  true;
}

ent-attach-vm() {
  new-mock-call-id
  VMNAME="$1"
  mock-log "## Attaching VM \"$VMNAME\""
  multipass info "$VMNAME" || FATAL "Unable to attach nonexistent VM \"$VMNAME\""
  true;
}

net_is_address_present() {
  new-mock-call-id
  mock-log "## Run net_is_address_present params: $*"
  true;
}
