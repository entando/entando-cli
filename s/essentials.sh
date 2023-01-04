#!/bin/bash
# ESSENTIALS

! ${ENT_ESSENTIALS_ALREADY_RUN:-false} && {
  ENT_ESSENTIALS_ALREADY_RUN=true
  _ESS_FATAL_EXIT_CODE=""

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
  KUBECTL_CMD_SUDO=false
  KUBECTL_SKIP_SUDO=false
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
  
  kubectl_must_be_ok() {
    local a b c d
    read -r a b c d <<< "$1"
    (${a:+"$a"}${b:+ "$b"}${c:+ "$c"}${d:+ "$d"} version --client &> /dev/null) || {
      _FATAL -s 'Unable to execute "'"$1"'", please run "ent k ent-auto-align"' 1>&2
    }
  }

  # KUBECTL
  # shellcheck disable=SC2034
  setup_kubectl() {
    [ -n "$ENT_KUBECTL_CMD" ] && {
      ENTANDO_KUBECTL="$ENT_KUBECTL_CMD"
    }
    
    if [ -n "$ENTANDO_KUBECTL" ]; then
      ENTANDO_KUBECTL_MODE="COMMAND"
      
      if echo "$ENTANDO_KUBECTL" | grep -q "^sudo "; then
        # shellcheck disable=SC2001
        ENTANDO_KUBECTL_BASE="$(sed "s/^sudo //" <<<"$ENTANDO_KUBECTL")"
        KUBECTL_CMD_SUDO=true
        _kubectl-pre-sudo() { prepare_for_privileged_commands "$1"; }
      else
        ENTANDO_KUBECTL_BASE="$ENTANDO_KUBECTL"
        KUBECTL_CMD_SUDO=false
        _kubectl-pre-sudo() { :; }
      fi

      _kubectl() {
        kubectl_must_be_ok "$ENTANDO_KUBECTL_BASE"
        kubectl_update_once_options "$@"
        local CMD
        if "$KUBECTL_CMD_SUDO" && ! "$KUBECTL_SKIP_SUDO"; then
          CMD="sudo $ENTANDO_KUBECTL_BASE"
        else
          CMD="$ENTANDO_KUBECTL_BASE"
        fi
        
        local a b c d
        read -r a b c d <<< "$CMD"
        if [  -z  "$DESIGNATED_KUBECONFIG" ]; then 
          # shellcheck disable=SC2086
          _trace "kubectl" ${a:+"$a"}${b:+ "$b"}${c:+ "$c"}${d:+ "$d"} $KUBECTL_ONCE_OPTIONS "$@"
        else
          # shellcheck disable=SC2086
          KUBECONFIG="$DESIGNATED_KUBECONFIG" \
            _trace "kubectl" ${a:+"$a"}${b:+ "$b"}${c:+ "$c"}${d:+ "$d"} $KUBECTL_ONCE_OPTIONS "$@"
        fi
        _kubectl_handle_error "$?"
      }
    elif [ -n "$DESIGNATED_KUBECONFIG" ]; then
      ENTANDO_KUBECTL_MODE="CONFIG"
      _kubectl() {
        kubectl_must_be_ok kubectl
        kubectl_update_once_options "$@"
        # shellcheck disable=SC2086
        KUBECONFIG="$DESIGNATED_KUBECONFIG" _trace "kubectl" kubectl $KUBECTL_ONCE_OPTIONS "$@"
        _kubectl_handle_error "$?"
      }
      _kubectl-pre-sudo() { :; }
    else
      # shellcheck disable=SC2034
      ENTANDO_KUBECTL_MODE="AUTODETECT"
      
      if $OS_WIN || [[ -n "$DESIGNATED_KUBECTX" || -n "$DESIGNATED_KUBECONFIG" ]]; then
        ENTANDO_KUBECTL_AUTO_DETECTED="BASE-KUBECTL"
        _kubectl() {
          kubectl_must_be_ok kubectl
          kubectl_update_once_options "$@"
          # shellcheck disable=SC2086
          _trace "kubectl" kubectl $KUBECTL_ONCE_OPTIONS "$@"
          _kubectl_handle_error "$?"
        }
        _kubectl-pre-sudo() { :; }
      else
        ENTANDO_KUBECTL_AUTO_DETECTED="BASE-KUBECTL-PRIVILEGED"
        _kubectl() {
          kubectl_must_be_ok kubectl
          kubectl_update_once_options "$@"
          # shellcheck disable=SC2086
          if $ENT_KUBECTL_NO_AUTO_SUDO; then
            _trace "kubectl" kubectl $KUBECTL_ONCE_OPTIONS "$@"
          else
            _trace "kubectl" sudo kubectl $KUBECTL_ONCE_OPTIONS "$@"
          fi
          _kubectl_handle_error "$?"
        }
        _kubectl-pre-sudo() { prepare_for_privileged_commands "$1"; }
      fi
    fi

    _kubectl_handle_error() {
      local RV="$1"
      if [[ "$RV" != "0" && "$ENT_KUBECTL_NO_CUSTOM_ERROR_MANAGEMENT" != "true" ]]; then
        kube.require_kube_reachable
      fi
      return "$RV"
    }

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
  
  _ess.log() {
    local level="$1";shift
    printf "➤ %-5s | %s | %s\n" "$level" "$(date +'%Y-%m-%d %H-%M-%S')" "$*" 1>&2
    return 0
  }
  
  # Prints the current callstack
  #
  # Options
  # [-d] to debug tty
  # [-n] doesn't print the decoration frame
  #
  # Params:
  # $1  start from this element of the start
  # $2  number of start
  # $3  title
  # $4  print command to use
  #
  _sys.print_callstack() {
    if [[ "$1" == "-d" && -n "$ENTANDO_DEBUG_TTY" ]]; then
      shift
      _sys.print_callstack "$@" >"$ENTANDO_DEBUG_TTY"
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
        echo -e "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁"
        [ -n "$title" ] && echo " ▕ $title ▏"
      }
    fi
    ! $NOFRAME && echo "▁"
    while read -r ln fn fl < <(caller "$frame"); do
      ((frame++))
      [ "$frame" -lt "$start" ] && continue
      printf "▒- %s in %s on line %s\n" "${fn}" "${fl}" "${ln}" 2>&1
      ((steps--))
      [ "$steps" -eq 0 ] && break
    done
    echo "▔"
    ! $NOFRAME && {
      echo "▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
    }
  }

  # Stops the execution with a fatal error
  # and prints the callstack
  #
  # Options
  # [-s]  simple: omits the stacktrace
  # [-S n] skips n levels of the call stack
  # [-99] uses 99 as exit code, which indicates test assertion
  #
  # Params:
  # $1  error message
  #
  # Alias: 
  # _FATAL() { ... }
  #
  _sys.fatal() {
    set +x
    local SKIP=1;[ "$1" = "-S" ] && { ((SKIP+=$2)); shift 2; }
    local rv=77
    
    if [ "$_ESS_SILENCE_ERRORS" != "true" ]; then
      {
        # shellcheck disable=SC2076
        if [[ -n "$XDEV_TEST_EXPECTED_ERROR" && "$*" =~ "$XDEV_TEST_EXPECTED_ERROR" ]]; then
          LOGGER() { _ess.log "DEBUG" "==== EXPECTED ERROR DETECTED ====: $*" 1>&2; }
        else
          LOGGER() { _ess.log "ERROR" "$*" 1>&2; }
        fi
        
        if [ "$1" != "-s" ]; then
          [ "$1" = "-99" ] && shift && rv=99
          _sys.print_callstack "$SKIP" 5 "" LOGGER "$@"  1>&2
        else
          shift
          [ "$1" = "-99" ] && shift && rv=99
          LOGGER "$@"
        fi
      }
    fi
    
    _ESS_FATAL_EXIT_CODE="$rv"
    _exit "$rv"
  }

  _FATAL() {
    local SKIP=1;[ "$1" = "-S" ] && { ((SKIP+=$2)); shift 2; }
    _sys.fatal -S "$SKIP" "$@"
  }

  FATAL() {
    local SKIP=1;[ "$1" = "-S" ] && { ((SKIP+=$2)); shift 2; }
    _sys.fatal -S "$SKIP" -s "$@"
  }
    
  # Loads a shell module and avoid reloading it
  #
  # Params:
  # $1:   the module file path
  #
  # Options:
  # -s    module file path is relative to the script path
  #
  # Alias: 
  # _require() { ... }
  #
  _sys.require() {
    local SKIP=1;[ "$1" = "-S" ] && { ((SKIP+=$2)); shift 2; }
    local BASEDIR="$PWD";[ "$1" = "--base" ] && { BASEDIR="$2"; shift 2; }

    local module="$1"

    if [ "${module:0:1}" != "/" ]; then
      # This is a devex trick.
      # It's required to make calltraces clickable, in particular when running tests.
      # It also work with relative formats like "./mypath" although it can be improved in this regard.
      module="$BASEDIR/$module"
    fi
    
    [ ! -f "$module" ] && _sys.fatal -S "$SKIP" "Unable to find script \"$module\""

    # shellcheck disable=SC2012
    local module_inode="$(ls -li "$module" | cut -d' ' -f 1)"
    [[ "$_SYS_LOADED_MODULES" == *"|$module_inode|"* ]] && return 0
    _SYS_LOADED_MODULES+="|$module_inode|"
    
    # shellcheck disable=SC1090
    . "$module"
    
    return 0
  }
  
  # Stops the execution of the program
  # In normal conditions is just equivalent to exit
  # but if XDEV_STOP_ON_EXIT is true it uses a SIGING
  #
  _sys.exit() {
    if [ "$XDEV_STOP_ON_EXIT" == "true" ]; then
      kill -INT $$
    else
      exit "$@"
    fi
  }
  
  _exit() {
    _sys.exit "$@"
  }

  #~ END OF FILE ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  return 0
}
