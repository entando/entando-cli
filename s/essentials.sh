# ESSENTIALS

! ${ENT_ESSENTIALS_ALREADY_RUN:-false} && {
  ENT_ESSENTIALS_ALREADY_RUN=true
  # OS DETECT
  OS_LINUX=false
  OS_MAC=false
  OS_WIN=false
  OS_BSD=false
  SYS_GNU_LIKE=false
  SYS_OS_UNKNOWN=false

  # shellcheck disable=SC2034
  case "$OSTYPE" in
    linux*)
      SYS_OS_TYPE="linux"
      SYS_GNU_LIKE=true
      OS_LINUX=true
      DEV_TTY="/dev/tty"
      C_HOSTS_FILE="/etc/hosts"
      ;;
    darwin*)
      SYS_OS_TYPE="mac"
      SYS_GNU_LIKE=true
      OS_MAC=true
      DEV_TTY="/dev/ttys000"
      C_HOSTS_FILE="/private/etc/hosts"
      ;;
    "cygwin" | "msys")
      SYS_OS_TYPE="win"
      SYS_GNU_LIKE=true
      OS_WIN=true
      DEV_TTY="/dev/tty"
      C_HOSTS_FILE="/etc/hosts"
      ;;
    win*)
      SYS_OS_TYPE="win"
      SYS_GNU_LIKE=false
      OS_WIN=true
      DEV_TTY="/dev/tty"
      C_HOSTS_FILE="%SystemRoot%\System32\drivers\etc\hosts"
      ;;
    "freebsd" | "openbsd")
      SYS_OS_TYPE="bsd"
      SYS_GNU_LIKE=true
      OS_BSD=true
      ;;
    *)
      SYS_OS_TYPE="UNKNOWN"
      SYS_OS_UNKNOWN=true
      ;;
  esac

  # SUDO
  ensure_sudo() {
    sudo true # NB: not using "sudo -v" because misbehaves with password-less sudoers
  }

  # KUBECTL
  if [ -n "$ENTANDO_KUBECTL" ]; then
    _kubectl() { "$ENTANDO_KUBECTL" "$@"; }
  else
    if command -v "k3s" > /dev/null; then
      if $OS_WIN; then
        _kubectl() { k3s kubectl "$@"; }
      else
        _kubectl() { sudo k3s kubectl "$@"; }
      fi
    else
      _kubectl() { kubectl "$@"; }
    fi
  fi

  # NOP
  nop() {
    :
  }

  # COLUMNS
  if command -V column 1> /dev/null 2>&1; then
    _column() {
      column "$@"
    }
  else
    _column() {
      xargs -L 1 -0
    }
  fi

  # helper function to print the file help
  # shellcheck disable=SC2001
    # shellcheck disable=SC2155
  print_ent_tool_help() {

    if [ "$1" = "--short" ]; then
      local short_help=$(grep '#''H::' "$0" | sed 's/^[[:space:]]*#H::[[:space:]]\{0,1\}//' | grep -v "^[[:space:]]*$" | head -n 1)
      short_help+=" | Syntax: (run ${0##*/} -h)"
      echo "$short_help"
      return
    fi

    grep '#''H::' "$0" | sed 's/^[[:space:]]*#H::[[:space:]]\{0,1\}//' \
    | sed 's/^\([[:space:]]*\)>/\1⮞/' | sed "s/{{TOOL-NAME}}/${0##*/}/"

    grep '#''H:' "$0" | while IFS= read -r var; do
      if [[ "$var" =~ "#H::" || "$var" =~ "#H:%" ]]; then
        :;
      elif [[ "$var" =~ "#H:>" ]]; then
        echo ""
        echo "$var" | sed 's/^[[:space:]]*#H:>[[:space:]]\{0,1\}/⮞ /' | sed 's/"//g' | sed 's/:$/###/'
      else
        echo "$var" | sed 's/[[:space:]]*\(.*\))[[:space:]]*#''H:\(.*\)/  - \1: \2/' | sed 's/"//g'  | sed 's/|[[:space:]]*\([^:]*\)/[\1]/'
      fi
    done | _column -t -s ":" -e | sed 's/###$/:/'

    echo ""

    local NOTE="Notes:\n"
    while IFS= read -r ln; do
      for var in $ln; do
        case "$var" in
        CHAINED) echo -e "$NOTE  - This command supports chained execution (${0##*/} subcmd1 --AND subcmd2)";;
        OPTPAR) echo -e "$NOTE  - Some of the parameters can be omitted or set to \"\", in which case the tool would interactively ask to enter the value if required";;
        SHORTS) echo -e "$NOTE  - Shorthands are reported in square brackets just after the main sub-command";;
        *) false;;
        esac && NOTE=""
      done
    done < <(grep '#''H:%' "$0" | sed "s/^[[:space:]]*#H:%[[:space:]]\{0,1\}//")

    [ -z "$NOTE" ] && echo ""
  }

#~ END OF FILE ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  return 0
}
