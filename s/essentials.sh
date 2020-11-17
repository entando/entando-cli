# ESSENTIALS

if [ "$1" = "--with-state" ]; then
  DESIGNATED_KUBECONFIG=$(grep DESIGNATED_KUBECONFIG "$ENTANDO_ENT_ACTIVE/w/.cfg" | sed "s/DESIGNATED_KUBECONFIG=//")
  DESIGNATED_KUBECTL_CMD=$(grep DESIGNATED_KUBECTL_CMD "$ENTANDO_ENT_ACTIVE/w/.cfg" | sed "s/DESIGNATED_KUBECTL_CMD=//")
fi

! ${ENT_ESSENTIALS_ALREADY_RUN:-false} && {
  ENT_ESSENTIALS_ALREADY_RUN=true
  # OS DETECT
  OS_LINUX=false
  OS_MAC=false
  OS_WIN=false
  OS_BSD=false
  SYS_GNU_LIKE=false
  SYS_OS_UNKNOWN=false
  DESIGNATED_KUBECTL_CMD=""
  ENTANDO_KUBECTL_MODE=""
  DESIGNATED_KUBECONFIG=""


  if [[ -z "$ENTANDO_DEV_TTY" && -t 0 ]]; then
    ENTANDO_DEV_TTY="$(tty)"
  fi

  # shellcheck disable=SC2034
  case "$OSTYPE" in
    linux*)
      SYS_OS_TYPE="linux"
      SYS_GNU_LIKE=true
      OS_LINUX=true
      [ -z "$ENTANDO_DEV_TTY" ] && ENTANDO_DEV_TTY="/dev/tty"
      C_HOSTS_FILE="/etc/hosts"
      ;;
    darwin*)
      SYS_OS_TYPE="mac"
      SYS_GNU_LIKE=true
      OS_MAC=true
      [ -z "$ENTANDO_DEV_TTY" ] && ENTANDO_DEV_TTY="-"
      C_HOSTS_FILE="/private/etc/hosts"
      ;;
    "cygwin" | "msys")
      SYS_OS_TYPE="win"
      SYS_GNU_LIKE=true
      OS_WIN=true
      [ -z "$ENTANDO_DEV_TTY" ] && ENTANDO_DEV_TTY="/dev/tty"
      C_HOSTS_FILE="/etc/hosts"
      ;;
    win*)
      SYS_OS_TYPE="win"
      SYS_GNU_LIKE=false
      OS_WIN=true
      [ -z "$ENTANDO_DEV_TTY" ] && ENTANDO_DEV_TTY="/dev/tty"
      C_HOSTS_FILE="%SystemRoot%\System32\drivers\etc\hosts"
      ;;
    "freebsd" | "openbsd")
      SYS_OS_TYPE="bsd"
      SYS_GNU_LIKE=true
      OS_BSD=true
      [ -z "$ENTANDO_DEV_TTY" ] && ENTANDO_DEV_TTY="/dev/tty"
      C_HOSTS_FILE="/etc/hosts"
      ;;
    *)
      SYS_OS_TYPE="UNKNOWN"
      SYS_OS_UNKNOWN=true
      ;;
  esac

  # SUDO
  if command -v "sudo" > /dev/null; then
    _sudo() {
      # NB: not using "sudo -v" because misbehaves with password-less sudoers
      $OS_WIN && return 0
      [ $UID -eq 0 ] && return 0
      sudo "$@"
    }
    prepare_for_sudo() {
      _sudo true
    }
  else
    _sudo() {
      "$@"
    }
    prepare_for_sudo() {
      :;
    }
  fi

  # KUBECTL
  setup_kubectl() {
    [ -n "$DESIGNATED_KUBECTL_CMD" ] && {
      ENTANDO_KUBECTL="$DESIGNATED_KUBECTL_CMD"
    }

    if [ -n "$ENTANDO_KUBECTL" ]; then
      ENTANDO_KUBECTL_MODE="COMMAND"
      _kubectl() { "$ENTANDO_KUBECTL" "$@"; }
      if echo "$ENTANDO_KUBECTL" | grep -q "^sudo "; then
        _kubectl-pre-sudo() { prepare_for_sudo; }
      else
        _kubectl-pre-sudo() { :; }
      fi
    elif [ -n "$DESIGNATED_KUBECONFIG" ]; then
      ENTANDO_KUBECTL_MODE="CONFIG"
      _kubectl() {
        KUBECONFIG="$DESIGNATED_KUBECONFIG" kubectl "$@"
      }
      _kubectl-pre-sudo() { :; }
    else
      ENTANDO_KUBECTL_MODE="AUODETECT"
      if command -v "k3s" > /dev/null; then
        if $OS_WIN; then
          _kubectl() { k3s kubectl "$@"; }
          _kubectl-pre-sudo() { :; }
        else
          _kubectl() { sudo k3s kubectl "$@"; }
          _kubectl-pre-sudo() { prepare_for_sudo true; }
        fi
      else
        if $OS_WIN; then
          _kubectl() { kubectl "$@"; }
          _kubectl-pre-sudo() { :; }
        else
          _kubectl() { sudo kubectl "$@"; }
          _kubectl-pre-sudo() { prepare_for_sudo true; }
        fi
      fi
    fi
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
  print_ent_tool_help() {

    if [ "$1" = "--short" ]; then
      local short_help=$(grep '#''H::' "$0" | _perl_sed 's/^[[:space:]]*#H::[[:space:]]{0,1}//' | grep -v "^[[:space:]]*$" | head -n 1)
      short_help+=" | Syntax: (run ${0##*/} -h)"
      echo "$short_help"
      return
    fi

    grep '#''H::' "$0" | _perl_sed 's/^[[:space:]]*#H::\h{0,1}//' \
      | _perl_sed 's/^([[:space:]]*)>/\1⮞/' | _perl_sed "s/{{TOOL-NAME}}/${0##*/}/"

    grep '#''H:' "$0" | while IFS= read -r var; do
      if [[ "$var" =~ "#H::" || "$var" =~ "#H:%" ]]; then
        :
      elif [[ "$var" =~ "#H:>" ]]; then
        echo ""
        echo "$var" | _perl_sed 's/^[[:space:]]*#H:>[[:space:]]{0,1}/⮞ /' | _perl_sed 's/"//g'
      elif [[ "$var" =~ "#H:-" ]]; then
        echo "$var" | _perl_sed 's/#H:-/ :  -/' | _align_by_sep ":" 22
      else
        echo "$var" | _perl_sed 's/[[:space:]]*(.*)\)[[:space:]]*#''H:(.*)/  - \1: \2/' | _perl_sed 's/"//g' | _perl_sed 's/\|[[:space:]]*([^:]*)/[\1]/' | _align_by_sep ":" 22
      fi
    done

    echo ""

    local NOTE="Notes:\n"
    while IFS= read -r ln; do
      for var in $ln; do
        case "$var" in
          CHAINED) echo -e "$NOTE  - This command supports chained execution (${0##*/} subcmd1 --AND subcmd2)" ;;
          OPTPAR) echo -e "$NOTE  - Some of the parameters can be omitted or set to \"\", in which case the tool would interactively ask to enter the value if required" ;;
          SHORTS) echo -e "$NOTE  - Shorthands are reported in square brackets just after the main sub-command" ;;
          *) false ;;
        esac && NOTE=""
      done
    done < <(grep '#''H:%' "$0" | _perl_sed "s/^[[:space:]]*#H:%[[:space:]]{0,1}//")

    [ -z "$NOTE" ] && echo ""
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

  #~ END OF FILE ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  return 0
}
