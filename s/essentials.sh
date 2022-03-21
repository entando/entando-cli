#!/bin/bash
# ESSENTIALS

! ${ENT_ESSENTIALS_ALREADY_RUN:-false} && {
  ENT_ESSENTIALS_ALREADY_RUN=true

  # TTY DETECT
  SYS_IS_STDIN_A_TTY=true;SYS_IS_STDOUT_A_TTY=true
  perl -e 'print -t STDIN ? exit 0 : exit 1' || {
    # shellcheck disable=SC2034
    SYS_IS_STDIN_A_TTY=false
  }
  perl -e 'print -t STDOUT ? exit 0 : exit 1' || {
    # shellcheck disable=SC2034
    SYS_IS_STDOUT_A_TTY=false
  }

  # OS DETECT
  OS_LINUX=false
  OS_MAC=false
  OS_WIN=false
  OS_BSD=false
  SYS_GNU_LIKE=false
  SYS_OS_UNKNOWN=false
  ENT_KUBECTL_CMD=""
  ENTANDO_KUBECTL_MODE=""
  ENTANDO_KUBECTL_AUTO_DETECTED=""
  DESIGNATED_KUBECONFIG=""
  KUBECTL_ONCE_OPTIONS=""
  # shellcheck disable=SC2034
  FORCE_URL_SCHEME=""
  C_DEF_ARCHIVE_FORMAT=""
  # shellcheck disable=SC2034
  CTRACE=""

  # shellcheck disable=SC2034
  case "$(perl -MConfig -e 'print $Config{longsize}*8 . "\n";')" in
    32) SYS_CPU_ARCH="x86";;
    *) SYS_CPU_ARCH="x86-64";;
  esac

  if [ "$1" = "--with-state" ]; then
    DESIGNATED_KUBECONFIG=$(grep DESIGNATED_KUBECONFIG "$ENT_WORK_DIR/.cfg" | sed "s/DESIGNATED_KUBECONFIG=//")
    ENT_KUBECTL_CMD=$(grep ENT_KUBECTL_CMD "$ENT_WORK_DIR/.cfg" | sed "s/ENT_KUBECTL_CMD=//")
  fi

  if [[ -z "$ENTANDO_DEV_TTY" ]]; then
    if "$SYS_IS_STDIN_A_TTY"; then
      ENTANDO_DEV_TTY="$(tty)"
      # shellcheck disable=SC2034
      ENTANDO_TTY_QUALIFIER="${ENTANDO_DEV_TTY//\//_}"
    fi
  fi

  # shellcheck disable=SC2034
  case "$OSTYPE" in
    linux*)
      SYS_OS_TYPE="linux"
      SYS_GNU_LIKE=true
      OS_LINUX=true
      [ -z "$ENTANDO_DEV_TTY" ] && ENTANDO_DEV_TTY="/dev/tty"
      C_HOSTS_FILE="/etc/hosts"
      C_DEF_ARCHIVE_FORMAT="tar.gz"
      ;;
    darwin*)
      SYS_OS_TYPE="darwin"
      SYS_GNU_LIKE=true
      OS_MAC=true
      [ -z "$ENTANDO_DEV_TTY" ] && ENTANDO_DEV_TTY="-"
      C_HOSTS_FILE="/private/etc/hosts"
      C_DEF_ARCHIVE_FORMAT="tar.gz"
      ;;
    "cygwin" | "msys")
      SYS_OS_TYPE="windows"
      SYS_GNU_LIKE=true
      OS_WIN=true
      [ -z "$ENTANDO_DEV_TTY" ] && ENTANDO_DEV_TTY="/dev/tty"
      C_HOSTS_FILE="/etc/hosts"
      C_DEF_ARCHIVE_FORMAT="zip"
      ;;
    win*)
      SYS_OS_TYPE="windows"
      SYS_GNU_LIKE=false
      OS_WIN=true
      [ -z "$ENTANDO_DEV_TTY" ] && ENTANDO_DEV_TTY="/dev/tty"
      C_HOSTS_FILE="%SystemRoot%\System32\drivers\etc\hosts"
      C_DEF_ARCHIVE_FORMAT="zip"
      ;;
    "freebsd" | "openbsd")
      SYS_OS_TYPE="bsd"
      SYS_GNU_LIKE=true
      OS_BSD=true
      [ -z "$ENTANDO_DEV_TTY" ] && ENTANDO_DEV_TTY="/dev/tty"
      C_HOSTS_FILE="/etc/hosts"
      C_DEF_ARCHIVE_FORMAT="tar.gz"
      ;;
    *)
      SYS_OS_TYPE="UNKNOWN"
      SYS_OS_UNKNOWN=true
      ;;
  esac

  # shellcheck disable=SC2155
  [ -z "$ENTANDO_DEBUG_TTY" ] && {
    perl -e 'print -t STDIN ? exit 0 : exit 1;'
    if [ $? -eq 0 ]; then
      if command -v "tty" >/dev/null; then
        export ENTANDO_DEBUG_TTY="$(tty)"
      fi
    fi
  }

  # SUDO
  IS_SUDO_PRESENT=false; command -v "sudo" > /dev/null && IS_SUDO_PRESENT=true

  privileged_commands_needs_sudo() {
    ! $IS_SUDO_PRESENT && echo 255
    $OS_WIN && return 255
    [ $UID -eq 0 ] && return 255
    return 0
  }

  _sudo() {
    if privileged_commands_needs_sudo; then
      sudo "$@"
    else
      "$@"
    fi
  }
  
  check_kubectl() { :; }

  prepare_for_privileged_commands() {
    # NB: not using "sudo -v" because misbehaves with password-less sudoers
    _sudo true
    local RES="$?"
    [[ "$1" = "-m" && "$RES" -ne 0 ]] && _FATAL "Unable to obtain the required privileges"
    return "$RES"
  }

  # Overwritten by utils.sh
  kubectl_update_once_options() { KUBECTL_ONCE_OPTIONS=""; }
  kubectl_mode() { :; }

  # KUBECTL
  # shellcheck disable=SC2034
  setup_kubectl() {
    [ -n "$ENT_KUBECTL_CMD" ] && {
      ENTANDO_KUBECTL="$ENT_KUBECTL_CMD"
    }
    
    if [ -n "$ENTANDO_KUBECTL" ]; then
      ENTANDO_KUBECTL_MODE="COMMAND"
      _kubectl() {
        kubectl_update_once_options "$@"
        # shellcheck disable=SC2086
        if [  -z  "$DESIGNATED_KUBECONFIG" ]; then 
          _trace "kubectl" $ENTANDO_KUBECTL $KUBECTL_ONCE_OPTIONS "$@"
        else
          KUBECONFIG="$DESIGNATED_KUBECONFIG" _trace "kubectl" $ENTANDO_KUBECTL $KUBECTL_ONCE_OPTIONS "$@"
        fi
      }
      if echo "$ENTANDO_KUBECTL" | grep -q "^sudo "; then
        _kubectl-pre-sudo() { prepare_for_privileged_commands "$1"; }
      else
        _kubectl-pre-sudo() { :; }
      fi
    elif [ -n "$DESIGNATED_KUBECONFIG" ]; then
      ENTANDO_KUBECTL_MODE="CONFIG"
      _kubectl() {
        kubectl_update_once_options "$@"
        # shellcheck disable=SC2086
        KUBECONFIG="$DESIGNATED_KUBECONFIG" _trace "kubectl" kubectl $KUBECTL_ONCE_OPTIONS "$@"
      }
      _kubectl-pre-sudo() { :; }
    else
      # shellcheck disable=SC2034
      ENTANDO_KUBECTL_MODE="AUTODETECT"
      
      if $OS_WIN || [[ -n "$DESIGNATED_KUBECTX" || -n "$DESIGNATED_KUBECONFIG" ]]; then
        ENTANDO_KUBECTL_AUTO_DETECTED="BASE-KUBECTL"
        _kubectl() {
          kubectl_update_once_options "$@"
          # shellcheck disable=SC2086
          _trace "kubectl" kubectl $KUBECTL_ONCE_OPTIONS "$@"
        }
        _kubectl-pre-sudo() { :; }
      else
        ENTANDO_KUBECTL_AUTO_DETECTED="BASE-KUBECTL-PRIVILEGED"
        _kubectl() {
          kubectl_update_once_options "$@"
          # shellcheck disable=SC2086
          if $ENT_KUBECTL_NO_AUTO_SUDO; then
            _trace "kubectl" kubectl $KUBECTL_ONCE_OPTIONS "$@"
          else
            _trace "kubectl" sudo kubectl $KUBECTL_ONCE_OPTIONS "$@"
          fi
        }
        _kubectl-pre-sudo() { prepare_for_privileged_commands "$1"; }
      fi
    fi

    check_kubectl
  }

  setup_kubectl

  # NOP
  nop() {
    :
  }

  # Alignment a <left><sep><right> value sequence given the separator and the left column size
  _align_by_sep() {
    local sep="$1"
    local alg="$2"
    perl -ne 'printf "%-'"$alg"'s %-5s\n", "$1", "$2" while /([^'"$sep"']+)'"$sep"'(.+)/g;'
  }

  # sed multiplatform and limited reimplementation
  # - implies "-E"
  # - doesn't support file operations
  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # $@ the sed in place args *without* the "-i
  #
  _perl_sed() {
    perl -pe "$@"
  }

  # helper function to print the file help
  # shellcheck disable=SC2001
  # shellcheck disable=SC2155
  print_ent_module_help() {
    script="$1"; shift

    if [ "$1" = "--short" ]; then
      local short_help=$(grep '#''H::' "bin/$script" | _perl_sed 's/^[[:space:]]*#H::[[:space:]]{0,1}//' | grep -v "^[[:space:]]*$" | head -n 1)
      echo "$short_help"
      return
    fi

    grep '#''H::' "$script" | _perl_sed 's/^[[:space:]]*#H::\h{0,1}//' \
      | _perl_sed 's/^([[:space:]]*)>/\1➤/' | _perl_sed "s/\{\{TOOL-NAME\}\}/${script##*/}/"

    grep '#''H:' "$script" | while IFS= read -r var; do
      if [[ "$var" =~ "#H::" || "$var" =~ "#H:%" ]]; then
        :
      elif [[ "$var" =~ "#H:>" ]]; then
        echo ""
        echo "$var" | _perl_sed 's/^[[:space:]]*#H:>[[:space:]]{0,1}/➤ /' | _perl_sed 's/"//g'
      elif [[ "$var" =~ "#H:-" ]]; then
        echo "$var" | _perl_sed 's/#H:-/ :  -/' | _align_by_sep ":" 22
      else
        echo "$var" | _perl_sed 's/[[:space:]]*(.*)\)[[:space:]]*#''H:(.*)/  - \1: \2/' | _perl_sed 's/"//g' | _perl_sed 's/\|[[:space:]]*([^:]*)/ [\1]/' | _align_by_sep ":" 22
      fi
    done

    echo ""

    local NOTE="Notes:\n"
    while IFS= read -r ln; do
      for var in $ln; do
        case "$var" in
          CHAINED) echo -e "$NOTE  - This command supports chained execution (${0##*/} subcmd1 --AND subcmd2)" ;;
          OPTPAR) echo -e "$NOTE  - Some of the parameters can be omitted or set to \"\", in which case the command would interactively ask to enter the value if required" ;;
          SHORTS) echo -e "$NOTE  - Shorthands are reported in square brackets just after the main sub-command" ;;
          *) false ;;
        esac && NOTE=""
      done
    done < <(grep '#''H:%' "$0" | _perl_sed "s/^[[:space:]]*#H:%[[:space:]]{0,1}//")

    [ -z "$NOTE" ] && echo ""
  }

  print_ent_module_sub-commands() {
    grep '#''H: ' "$1" | _perl_sed 's/[[:space:]]*([^|) ]*).*/\1/' | _perl_sed 's/"//g' | grep -v '\*'
  }

  var_to_param() {
    FLAG=false
    [ "$1" == "-f" ] && FLAG=true && shift
    DASHABLE=false
    [ "$1" == "-d" ] && DASHABLE=true && shift
    SEP="="
    [ "$1" == "-s" ] && SEP=" " && shift
    [ -z "$2" ] && return

    local par_name="$1"

    if $FLAG; then
      local par_value="$2"
      if [ "$par_value" = "true" ]; then
        echo "--${par_name}"
      elif [ "$par_value" = "false" ]; then
        echo "--${par_name}=false"
      fi
    else
      if $DASHABLE && [ "$2" = "-" ]; then
        echo "--${par_name}"
      else
        local par_value="${2//\\/\\\\}"
        par_value="'${par_value//\'/\'\\\'\'}'"
        echo "--${par_name}${SEP}${par_value}"
      fi
    fi
  }

  _edit() {
    if [ -n "$EDITOR" ]; then
      "$EDITOR" "$@"
    elif type editor &>/dev/null; then
      editor "$@"
    else
      vim "$@"
    fi
  }

  #~ END OF FILE ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  return 0
}
