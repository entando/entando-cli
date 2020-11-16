[ -z $ZSH_VERSION ] && [ -z $BASH_VERSION ] && echo "Unsupported shell, user either bash or zsh" 1>&2 && exit 99

[ "$ENTANDO_ENT_ACTIVE" = "" ] && echo "No ent instance is currently active" && exit 99

ENT_HOME="$PWD"
mkdir -p "$ENTANDO_ENT_ACTIVE/w"

# ----------------------------------------------------------------------------------------------------------------------
# ERROR AND EXIT MANAGEMENT

XU_STATUS_FILE="$ENTANDO_ENT_ACTIVE/w/.status"
XU_BACKTRACE=""

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
    XU_RES="$(cut "$XU_STATUS_FILE" -d':' -f1)"
  fi
  return 0
}

xu_set_status "-"

trace_var() {
  local PRE="$1";shift
  (echo "$PRE $1: ${!1}")
}

trace_vars() {
  if [ "$1" == "-t" ]; then
    local TITLE=" [$2]";shift 2
  fi
  echo "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁"
  echo "▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒$TITLE"
  for varname in "$@"; do
    trace_var "▕-" "$varname"
  done
  echo "▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒"
  echo "▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
}

function trace_position() {
  local pre=""
  local title=""
  [ -n "$1" ] && title=" $1 "
  [ -n "$2" ] && pre=" -- "
  local n1="${3:-1}"
  local n0="$((n1-1))"
  shift 3

  local fn="${FUNCNAME[n1]}"
  local ln="${BASH_LINENO[n0]}"
  local fl="${BASH_SOURCE[n0]}"

  echo ">${title}$fl, line $ln -- $fn()${pre}$*" 2>&1
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

$SYS_OS_UNKNOWN && { echo "Unsupported operating system" 1>&2; exit 99; }

mkdir -p "$ENTANDO_ENT_ACTIVE/w"
mkdir -p "$ENTANDO_ENT_ACTIVE/d"
mkdir -p "$ENTANDO_ENT_ACTIVE/lib"
. s/_conf.sh

# ----------------------------------------------------------------------------------------------------------------------
# UTILS

. s/utils.sh
. s/var-utils.sh
. s/logger.sh

reload_cfg
rescan-sys-env
reload_cfg

[ -n "$DESIGNATED_JAVA_HOME" ] && export JAVA_HOME="$DESIGNATED_JAVA_HOME"

setup_kubectl

ENT_RUN_TMP_DIR=$(mktemp /tmp/ent.run.XXXXXXXXXXXX)
[[ ! "$ENT_RUN_TMP_DIR" =~ /tmp/ ]] && {
  # keep this as simple as possible, only native commands
  echo "Internal Error: Unable to create the tmp dir" 2>&1
  exit 99
}

# ----------------------------------------------------------------------------------------------------------------------

nvm_activate() {
  NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || return
  export NVM_DIR
}

activate_designated_node() {
  $OS_WIN && {
    # npm-windows always shows the UAC privilege escalation screen, so we try to not invoke it when possible
    # this is sub-optimal as we may end-up using the system node
    [[ "$(node -v)" = "$DESIGNATED_NODE_VERSION" ]] && return 0
  }
  nvm_activate
  [ -z "$ACTIVATED_NODE_VERSION" ] && ACTIVATED_NODE_VERSION="$(node -v)"

  [[ -z "$ACTIVATED_NODE_VERSION" || "$ACTIVATED_NODE_VERSION" != "$DESIGNATED_NODE_VERSION" ]] && {
    check_ver "node" "$DESIGNATED_NODE_VERSION" "--version" "quiet" || {
      nvm use "$DESIGNATED_NODE_VERSION" > /dev/null || {
        _log_w 1 "Unable to select the proper node version (\"$DESIGNATED_NODE_VERSION\")"
        return 1
      }
    }
    ACTIVATED_NODE_VERSION="$DESIGNATED_NODE_VERSION"
  }
  return 0
}
