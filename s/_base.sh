#!/bin/bash
[ -z "$ZSH_VERSION" ] && [ -z "$BASH_VERSION" ] && echo "Unsupported shell, user either bash or zsh" 1>&2 && exit 99

[ "$ENTANDO_ENT_HOME" = "" ] && echo "No ent instance is currently active" && exit 99

${ENTANDO_BASE_EXECUTED:-false} && return 0
ENTANDO_BASE_EXECUTED=true

# ----------------------------------------------------------------------------------------------------------------------
# ESSENTIAL ENVIRONMENT
. s/essentials.sh

# ----------------------------------------------------------------------------------------------------------------------
# BASE FUNCTIONS

DDD() {
  local FULLTRACE=false
  [ "$1" = "-t" ] && {
    FULLTRACE=true
    shift
  }
  {
    echo "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁"
    echo "▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒"
    if $FULLTRACE; then
      print_calltrace -n 1 5
    else
      print_calltrace -n 1 1
    fi
    echo "$@"
    echo "▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒"
    echo "▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
  } >"${ENTANDO_DEBUG_TTY:-/dev/stderr}"
}

_pp_var() {
  local PRE="$1"
  shift
  (echo "$PRE $1: ${!1}")
}

# Pretty Prints a list of vars given their names
#
_pp() {
  if [[ "$1" == "-d" && -n "$ENTANDO_DEBUG_TTY" ]]; then
    shuft
    _pp "$@" >"$ENTANDO_DEBUG_TTY"
  fi

  if [ "$1" == "-t" ]; then
    local TITLE=" [$2]"
    shift 2
  fi
  echo "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁"
  echo "▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒$TITLE"
  for var_name in "$@"; do
    _pp_var "▕-" "$var_name"
  done
  echo "▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒"
  echo "▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
}

# Adjust a variable for pretty printing
#
# Params:
# $1: the variable to cut
# $2: the max len
#
_pp_adjust_var() {
  local _tmp_="${!1}"

  local B='\033[44m\033[1;37m'
  local A='\033[0;39m'

  if [ ${#_tmp_} -gt "$2" ]; then
    _tmp_="${_tmp_:0:$2}${B}[[CUTTED]]${A}"
  fi
  _set_var "$1" "$_tmp_"
}

function print_calltrace() {
  if [[ "$1" == "-d" && -n "$ENTANDO_DEBUG_TTY" ]]; then
    shuft
    print_calltrace "$@" >"$ENTANDO_DEBUG_TTY"
  fi
  local NOFRAME=false
  [ "$1" = "-n" ] && {
    NOFRAME=true
    shift
  }

  local start=0
  local steps=999
  local title=""
  [ -n "$1" ] && start="$1"
  [ -n "$2" ] && steps="$2"
  [ -n "$3" ] && title=" $3 "
  ((start++))

  local frame=0 fn ln fl
  if [ -n "$4" ]; then
    ! $NOFRAME && {
      echo ""
      [ -n "$title" ] && echo " ▕ $title ▏"
      echo "▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
    }
    cmd="$4"
    shift 4
    "$cmd" "$@"
  else
    ! $NOFRAME && {
      echo "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁"
      [ -n "$title" ] && echo " ▕ $title ▏"
    }
  fi
  ! $NOFRAME && echo "▁"
  while read -r ln fn fl < <(caller "$frame"); do
    ((frame++))
    [ "$frame" -lt "$start" ] && continue
    printf "▒- %s @ %s:%s\n" "${fn}" "${fl}" "${ln}" 2>&1
    ((steps--))
    [ "$steps" -eq 0 ] && break
  done
  echo "▔"
  ! $NOFRAME && {
    echo "▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
  }
}

function print_current_function_name() {
  if [[ "$1" == "-d" && -n "$ENTANDO_DEBUG_TTY" ]]; then
    shuft
    print_current_function_name "$@" >"$ENTANDO_DEBUG_TTY"
  fi

  echo "${1}${FUNCNAME[1]}${2}"
}

# activates the default workdir of the current ent installation
#
# the default workdir is not related t any profile
# and it's located the ent installation directory
activate_ent_default_workdir() {
  if [[ -z "$DESIGNATED_PROFILE" || "$DESIGNATED_PROFILE" = "-" ]]; then
    # shellcheck disable=SC2034
    THIS_PROFILE=""
    PROFILE_ORIGIN=""
    DESIGNATED_PROFILE_HOME=""
    ENT_WORK_DIR="$ENTANDO_ENT_HOME/w"
    # shellcheck disable=SC2034
    CFG_FILE="$ENT_WORK_DIR/.cfg"
    mkdir -p "$ENT_WORK_DIR"
  fi
}

# activates application workdir
#
# the application workdir is the specific ent app directory
# and can be potentially used by more that on ent installation
activate_application_workdir() {
  if [ -n "$DESIGNATED_PROFILE" ]; then
    if [ -d "$DESIGNATED_PROFILE_HOME/w" ]; then
      ENT_WORK_DIR="$DESIGNATED_PROFILE_HOME/w"
      # shellcheck disable=SC2034
      CFG_FILE="$ENT_WORK_DIR/.cfg"
      return 0
    else
      _log_e \
        "Unable to load the profile \"$DESIGNATED_PROFILE\", falling back to the default profile"
      DESIGNATED_PROFILE_HOME=""
      DESIGNATED_PROFILE=""
      return 1
    fi
  fi
}

# activates the current execution context
# shellcheck disable=SC2034
activate_designated_workdir() {
  TEMPORARY=false
  [ "$1" = "--temporary" ] && TEMPORARY=true
  ! $TEMPORARY && reload_cfg "$ENTANDO_GLOBAL_CFG"
  if [[ -n "$DESIGNATED_PROFILE" && "$DESIGNATED_PROFILE" != "-" ]]; then
    activate_application_workdir
  else
    activate_ent_default_workdir
  fi
  ! $TEMPORARY && save_cfg_value "THIS_PROFILE" "${DESIGNATED_PROFILE}"
  ENT_KUBECTL_CMD=""
  ENABLE_AUTOLOGIN=""
  reload_cfg
  setup_kubectl
}

set_curr_profile() {
  local TEMP=false;[ "$1" = "--temporary" ] && { TEMP=true; shift; }
  [ -z "$1" ] && _FATAL "Illegal profile name detected"
  DESIGNATED_PROFILE="$1"
  DESIGNATED_PROFILE_HOME="$2"
  [ -z "$DESIGNATED_PROFILE_HOME" ] && DESIGNATED_PROFILE_HOME="$ENTANDO_PROFILES/$DESIGNATED_PROFILE"
  ! $TEMP && {
    save_cfg_value "DESIGNATED_PROFILE" "$DESIGNATED_PROFILE" "$ENTANDO_GLOBAL_CFG"
    save_cfg_value "DESIGNATED_PROFILE_HOME" "$DESIGNATED_PROFILE_HOME" "$ENTANDO_GLOBAL_CFG"
  }
}

# ----------------------------------------------------------------------------------------------------------------------
# ERROR AND EXIT MANAGEMENT

# PROGRAM STATUS
xu_clear_status() {
  [ "$XU_STATUS_FILE" != "" ] && [ -f "$XU_STATUS_FILE" ] && rm -- "$XU_STATUS_FILE"
}

xu_set_status() {
  [ "$XU_STATUS_FILE" != "" ] && echo "$@" >"$XU_STATUS_FILE"
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

# overrides the essential.sh base
kubectl_update_once_options() {
  KUBECTL_ONCE_OPTIONS=""
  
  determine_namespace NS "$@"

  local NS="${NS//$'\n'/}"
  # shellcheck disable=SC2034
  case "$NS" in
  "*") KUBECTL_ONCE_OPTIONS+="--all-namespaces " ;;
  "") ;;
  *) KUBECTL_ONCE_OPTIONS+="--namespace=$NS " ;;
  esac

  local CTX="${DESIGNATED_KUBECTX//$'\n'/}"

  if [ -n "$CTX" ]; then
    KUBECTL_ONCE_OPTIONS+="--context=$CTX "
  fi
}

kubectl_mode() {
  while [ -n "$1" ]; do
    case "$1" in
    "--export")
      export DESIGNATED_KUBECONFIG
      export DESIGNATED_VM
      export DESIGNATED_VM_NAMESPACE
      export DESIGNATED_KUBECTX
      export ENT_KUBECTL_CMD
      ;;
    "--reset-mem")
      DESIGNATED_KUBECONFIG=""
      DESIGNATED_VM=""
      DESIGNATED_VM_NAMESPACE=""
      DESIGNATED_KUBECTX=""
      # shellcheck disable=SC2034
      ENT_KUBECTL_CMD=""
      ;;
    "--reset-cfg")
      kubeconfig-detach
      managed-vm-detach --preserve-config-file
      save_cfg_value "DESIGNATED_KUBECTX" ""
      save_cfg_value "ENT_KUBECTL_CMD" ""
      ;;
    esac
    shift
  done
}

check_kubectl() { 
  true
#   if [ "$WARN_KUBECTL" != "false" ]; then
#     local VER="$(
#       KUBECTL_SKIP_SUDO=true _kubectl version --client --short 2>/dev/null | cut -d ':' -f 2 | xargs
#     )"
#     if [ -n "$VER" ]; then
#       if check_ver_ge "$VER" "1.23.0" 2>/dev/null; then
#         _log_w "this version of kubectl ($VER) is not yet supported, replace it with a version < 1.23" \
#                  "or try running \"ent auto-align-kubectl\" against a kubernetes server." \
#                  "To suppress this message execute \"ent config --set WARN_KUBECTL false\"" \
#                  > /dev/stderr
#       fi
#     fi
#   fi
}

determine_namespace() {
  local var_name="$1"
  shift
  local ns

  HH="$(parse_help_option "$@")"
  
  if args_or_ask -n ns "--namespace/ext_ic_id//" "$@" ||
    args_or_ask -n -s ns "-n/ext_ic_id//" "$@"; then
    if args_or_ask -n -f "--all-namespaces///" "$@" ||
      args_or_ask -f dummy "-A///" "$@"; then
      ns="*"
    fi
    _set_var "$var_name" "$ns"
    return 0
  fi

  # shellcheck disable=SC2034
  local dummy
  if [ -n "$DESIGNATED_VM" ]; then
    ns="${DESIGNATED_VM_NAMESPACE:-$ENTANDO_NAMESPACE}"
  else
    ns="${ENTANDO_NAMESPACE}"
  fi
  if [[ -z "$ns" && -n "$ENTANDO_NAMESPACE" ]]; then
    ns="$ENTANDO_NAMESPACE"
  fi

  if [ -n "$ns" ]; then
    # Use the configured namespace
    assert_ext_ic_id "" "$ns" "silent" || {
      FATAL "The configured default namespace is not valid"
    }

    # shellcheck disable=SC2034 disable=SC2027
    _set_var "$var_name" "$ns"
    return 0
  fi

  return 1
}

########################################################################################################################
#
# BASE INITIALIZATION
#
########################################################################################################################

# ----------------------------------------------------------------------------------------------------------------------
# BASE ENVIRONMENT SETUP

# shellcheck disable=1094 disable=2154 disable=2115
. s/sys-utils.sh

$SYS_OS_UNKNOWN && {
  echo "Unsupported operating system" 1>&2
  exit 99
}

[ ! -d "$ENTANDO_ENT_HOME/w" ] && {
  mkdir -p "$ENTANDO_ENT_HOME/w"
  chmod 700 "$ENTANDO_ENT_HOME/w"
  find "$ENTANDO_ENT_HOME/w" -maxdepth 1 -mindepth 1 -exec chmod 600 {} \;
}

. s/_conf.sh

mkdir -p "$ENTANDO_PROFILES"
mkdir -p "$ENTANDO_BINS"
mkdir -p "$ENT_OPTS"
mkdir -p "$ENT_WORK_DIR"

DESIGNATED_VM=""
DESIGNATED_VM_NAMESPACE=""
ENTANDO_NAMESPACE=""
# shellcheck disable=SC2034
{
  ENT_KUBECTL_CMD=""
  ENABLE_AUTOLOGIN=""
}

parse_global_args() {
  ENTANDO_CONSUMED_ARGS=0
  while [ $# -gt 0 ]; do
    case "$1" in
    "--no-profile"|"-P")
      shift;((ENTANDO_CONSUMED_ARGS++))
      ENTANDO_ENT_FORCE_PROFILE="--none"
      ;;
    "-p" | "--profile")
      shift;((ENTANDO_CONSUMED_ARGS++))
      ENTANDO_ENT_FORCE_PROFILE="$1"
      shift;((ENTANDO_CONSUMED_ARGS++))
      ;;
    "--color")
      shift;((ENTANDO_CONSUMED_ARGS++))
      ENTANDO_CLI_FORCE_COLORS=true
      ;;
    "-d" | "--debug")
      shift;((ENTANDO_CONSUMED_ARGS++))
      ENTANDO_ENT_DEBUG=true
      ;;
    *)
      break
      ;;
    esac
  done
  
  export ENTANDO_ENT_DEBUG
  export ENTANDO_ENT_FORCE_PROFILE
}

# ----------------------------------------------------------------------------------------------------------------------
# ALL LIRARIES

. s/utils.sh
. s/pkg.sh
. s/var-utils.sh
. s/logger.sh
. s/ecr-utils.sh
. s/attach-utils.sh
. s/node-utils.sh
. s/kube-utils.sh

# ----------------------------------------------------------------------------------------------------------------------
# PROFILE ACTIVATION

reload_cfg "$ENTANDO_GLOBAL_CFG"

handle_forced_profile "$@"
parse_global_args "$@"
shift "$ENTANDO_CONSUMED_ARGS"

case "$ENTANDO_ENT_FORCE_PROFILE" in
  "--none") DESIGNATED_PROFILE="";DESIGNATED_PROFILE_HOME="";;
  "") ;;
  *) set_curr_profile --temporary "$ENTANDO_ENT_FORCE_PROFILE";;
esac

if [ -n "$DESIGNATED_PROFILE" ]; then
  if assert_ext_ic_id "" "$DESIGNATED_PROFILE" "silent"; then
    DESIGNATED_PROFILE_HOME="$ENTANDO_PROFILES/$DESIGNATED_PROFILE"
  else
    FATAL "Illegal value provided in environment var DESIGNATED_PROFILE"
  fi
fi

if [ -n "$DESIGNATED_PROFILE" ]; then
  activate_application_workdir
else
  activate_ent_default_workdir
fi

reload_cfg "$ENT_DEFAULT_CFG_FILE"
reload_cfg
rescan-sys-env
reload_cfg

mkdir -p "$ENT_WORK_DIR"

# shellcheck disable=SC2034
XU_STATUS_FILE="$ENT_WORK_DIR/.status"
[ -n "$LOG_LEVEL" ] && XU_LOG_LEVEL="$LOG_LEVEL"
[ -n "$DESIGNATED_JAVA_HOME" ] && export JAVA_HOME="$DESIGNATED_JAVA_HOME"

kubectl_update_once_options "$@"
setup_kubectl
