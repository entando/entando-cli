#!/bin/bash
[ -z "$ZSH_VERSION" ] && [ -z "$BASH_VERSION" ] && echo "Unsupported shell, user either bash or zsh" 1>&2 && exit 99

[ "$ENTANDO_ENT_HOME" = "" ] && echo "No ent instance is currently active" && exit 99

${ENTANDO_BASE_EXECUTED:-false} && return 0
ENTANDO_BASE_EXECUTED=true

trace_var() {
  local PRE="$1"
  shift
  (echo "$PRE $1: ${!1}")
}

trace_vars() {
  if [ "$1" == "-t" ]; then
    local TITLE=" [$2]"
    shift 2
  fi
  echo "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁"
  echo "▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒$TITLE"
  for var_name in "$@"; do
    trace_var "▕-" "$var_name"
  done
  echo "▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒"
  echo "▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
}

function print_calltrace() {
  local start=0
  local steps=999
  local title=""
  [ -n "$1" ] && start="$1"
  [ -n "$2" ] && steps="$2"
  [ -n "$3" ] && title=" $3 "
  ((start++))

  local frame=0 fn ln fl
  if [ -n "$4" ]; then
    echo ""
    [ -n "$title" ] && echo " ▕ $title ▏"
    echo "▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
    cmd="$4"
    shift 4
    "$cmd" "$@"
  else
    echo "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁"
    [ -n "$title" ] && echo " ▕ $title ▏"
  fi
  echo "▁"
  while read -r ln fn fl < <(caller "$frame"); do
    ((frame++))
    [ "$frame" -lt "$start" ] && continue
    printf "▒- %s @ %s:%s\n" "${fn}" "${fl}" "${ln}" 2>&1
    ((steps--))
    [ "$steps" -eq 0 ] && break
  done
  echo "▔"
  echo "▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
}

function print_current_function_name() {
  echo "${1}${FUNCNAME[1]}${2}"
}

#function error-trap() {
#  trap - ERR
#  xu_get_status
#  exec >&2
#  XU_BACKTRACE=""
#  case "$XU_RES" in
#    "FATAL" | "USER-ERROR" | "EXIT")
#      ;;
#    *)
#      ind="  "
#      i=0
#      while true; do
#        c="$(caller $i)"
#        i="$((i + 1))"
#        [ -z "$c" ] && break
#        IFS=' ' read -r -a arr <<< "$c"
#        XU_BACKTRACE+="${ind}at: ${arr[2]}, line ${arr[0]} -- ${arr[1]}()\n"
#      done
#
#      xu_set_status "EXIT-ERR"
#      ;;
#  esac
#
#  echo -e "~~~\n"
#  return 1
#}
#trap error-trap ERR
#set -o errtrace
#
#exit-trap() {
#  [ "$?" == 0 ] && return $?
#  trap - ERR EXIT
#
#  xu_get_status
#  sz=$(stat -c "%s" "$ENT_RUN_TMP_DIR")
#
#  if [[ "$sz" -eq 0 ]] || [[ "$XU_RES" != "FATAL" && "$XU_RES" != "USER-ERROR" ]]; then
#    [ -n "$XU_BACKTRACE" ] && {
#      echo ""
#      echo "> Callers:"
#      echo -e "$XU_BACKTRACE"
#    }
#
#    [[ ! "$ENT_RUN_TMP_DIR" =~ /tmp/ ]] && {
#      # keep this as simple as possible, only native commands
#      echo "Internal Error: Detected invalid tmp dir" 2>&1
#      exit 99
#    }
#
#    rm -rf "$ENT_RUN_TMP_DIR"
#  else
#    echo "---"
#    echo "[EXIT-TRAP] Execution info are available under: \"$ENT_RUN_TMP_DIR\""
#    echo ""
#  fi
#}
#trap exit-trap EXIT

# ----------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT
. s/essentials.sh
. s/sys-utils.sh

$SYS_OS_UNKNOWN && {
  echo "Unsupported operating system" 1>&2
  exit 99
}

mkdir -p "$ENTANDO_ENT_HOME/d"
mkdir -p "$ENTANDO_ENT_HOME/lib"
. s/_conf.sh

# ----------------------------------------------------------------------------------------------------------------------
# UTILS

. s/utils.sh
. s/var-utils.sh
. s/logger.sh

DESIGNATED_VM=""
DESIGNATED_VM_NAMESPACE=""
DEFAULT_NAMESPACE=""
# shellcheck disable=SC2034
{
  ENT_KUBECTL_CMD=""
  ENABLE_AUTOLOGIN=""
}

if [ -n "$ENTANDO_CURRENT_APP_CTX" ]; then
  if assert_ext_ic_id "" "$ENTANDO_CURRENT_APP_CTX" "silent"; then
    ENTANDO_CURRENT_APP_CTX_HOME="$ENTANDO_HOME/apps/$ENTANDO_CURRENT_APP_CTX"
  else
    FATAL "Illegal value provided in environment var ENTANDO_CURRENT_APP_CTX"
  fi
fi

reload_cfg "$ENTANDO_GLOBAL_CFG"

activate_application_workdir() {
  if [ -n "$ENTANDO_CURRENT_APP_CTX" ]; then
    if [ -d "$ENTANDO_CURRENT_APP_CTX_HOME/w" ]; then
      ENT_WORK_DIR="$ENTANDO_CURRENT_APP_CTX_HOME/w/"
      # shellcheck disable=SC2034
      CFG_FILE="$ENT_WORK_DIR/.cfg"
      return 0
    else
      _log_e 0 \
        "Unable to load the application context \"$ENTANDO_CURRENT_APP_CTX\", falling back to the default context"
        echo XXXXXXXXXX "$ENTANDO_CURRENT_APP_CTX_HOME"
      ENTANDO_CURRENT_APP_CTX_HOME=""
      ENTANDO_CURRENT_APP_CTX=""
      return 1
    fi
  fi
}

activate_application_workdir

reload_cfg
rescan-sys-env
reload_cfg
mkdir -p "$ENT_WORK_DIR"

# shellcheck disable=SC2034
[ -n "$LOG_LEVEL" ] && XU_LOG_LEVEL="$LOG_LEVEL"
[ -n "$DESIGNATED_JAVA_HOME" ] && export JAVA_HOME="$DESIGNATED_JAVA_HOME"

setup_kubectl

#ENT_RUN_TMP_DIR=$(mktemp /tmp/ent.run.XXXXXXXXXXXX)
#[[ ! "$ENT_RUN_TMP_DIR" =~ /tmp/ ]] && {
#  # keep this as simple as possible, only native commands
#  echo "Internal Error: Unable to create the tmp dir" 2>&1
#  exit 99
#}

mkdir -p "$ENT_WORK_DIR"

# ----------------------------------------------------------------------------------------------------------------------
# ERROR AND EXIT MANAGEMENT

XU_STATUS_FILE="$ENT_WORK_DIR/.status"

# PROGRAM STATUS
xu_clear_status() {
  [ "$XU_STATUS_FILE" != "" ] && [ -f "$XU_STATUS_FILE" ] && rm -- "$XU_STATUS_FILE"
}

xu_set_status() {
  [ "$XU_STATUS_FILE" != "" ] && echo "$@" > "$XU_STATUS_FILE"
}

xu_get_status() {
  XU_RES=""
  if [ "$XU_STATUS_FILE" != "" ] && [ -f "$XU_STATUS_FILE" ]; then
    # shellcheck disable=SC2034
    XU_RES="$(cut "$XU_STATUS_FILE" -d':' -f1)"
  fi
  return 0
}

xu_set_status "-"

# ----------------------------------------------------------------------------------------------------------------------

nvm_activate() {
  NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1090
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || return
  export NVM_DIR
}

activate_designated_node() {
  $OS_WIN && {
    # npm-windows always shows the UAC privilege escalation screen, so we try to not invoke it when possible
    # this is sub-optimal as we may end-up using the system node
    [[ "$(node -v)" == "$DESIGNATED_NODE_VERSION" ]] && return 0
  }
  nvm_activate
  [ -z "$ACTIVATED_NODE_VERSION" ] && ACTIVATED_NODE_VERSION="$(node -v)"

  [[ -z "$ACTIVATED_NODE_VERSION" || "$ACTIVATED_NODE_VERSION" != "$DESIGNATED_NODE_VERSION" ]] && {
    check_ver "node" "$DESIGNATED_NODE_VERSION" "--version" "quiet" || {
      local ERRMSG="Unable to select the proper node version (\"$DESIGNATED_NODE_VERSION\"): "
      ERRMSG+="The required node version is not present anymore or it's corrupted,"
      ERRMSG+="you may try to reinstall it using nvm."
      nvm use "$DESIGNATED_NODE_VERSION" > /dev/null
      if [[ "$(node -v)" != "$DESIGNATED_NODE_VERSION" ]]; then
        _log_e 1 "$ERRMSG"
        return 1
      fi
    }
    ACTIVATED_NODE_VERSION="$DESIGNATED_NODE_VERSION"
  }
  return 0
}

# overrides the essential.sh base
kubectl_update_once_options() {
  local NS
  determine_namespace NS "$@"

  # shellcheck disable=SC2034
  case "$NS" in
    "*") KUBECTL_ONCE_OPTIONS="--all-namespaces";;
    "") KUBECTL_ONCE_OPTIONS="";;
    *) KUBECTL_ONCE_OPTIONS="--namespace=$NS";;
  esac
}

determine_namespace() {
  local var_name="$1"; shift
  local ns

  HH="$(parse_help_option "$@")"

  if args_or_ask ${HH:+"$HH"} -n ns "--namespace/ext_ic_id//" "$@" ||
    args_or_ask ${HH:+"$HH"} -n -s ns "-n/ext_ic_id//" "$@"; then
    if args_or_ask ${HH:+"$HH"} -n -f "--all-namespaces///" "$@" ||
       args_or_ask ${HH:+"$HH"}-n -f dummy "-A///" "$@"; then
      ns="*"
    fi
    _set_var "$var_name" "$ns"
    return 0
  fi

  # shellcheck disable=SC2034
  local dummy
  if [ -n "$DESIGNATED_VM" ]; then
    ns="${DESIGNATED_VM_NAMESPACE:-$DEFAULT_NAMESPACE}"
  else
    ns="${DEFAULT_NAMESPACE}"
  fi
  if [[ -z "$ns" && -n "$ENTANDO_NAMESPACE" ]]; then
    ns="$ENTANDO_NAMESPACE"
  fi

  if [ -n "$ns" ]; then
    # Use the configured namespace
    assert_ext_ic_id "" "$ns" "silent" || {
      FATAL "The configured default namespace is not valid"
    }
    _log_i 3 "Assuming namespace \"$ns\"" 1>&2
    # shellcheck disable=SC2034 disable=SC2027
    _set_var "$var_name" "$ns"
    return 0
  fi

  return 1
}
