# UTILS

# CFG

# Saves a key/value pair to a configuration file
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# $1: key           strict identifier
# $2: value         the value of the key
# $3: [cfg-file]    optional cfg file name; defaults to the project config file
#
save_cfg_value() {
  local config_file=${3:-$CFG_FILE}
  if [[ -f "$config_file" ]]; then
    sed --in-place='' "/^$1=.*$/d" "$config_file"
  fi
  if [ "$(echo "$2" | wc -l)" -gt 1 ]; then
    FATAL "save_cfg_value: Unsupported multiline value"
  fi
  if [ -n "$2" ]; then
    printf "$1=%s\n" "$2" >> "$config_file"
  fi

  return 0
}

# Reloads the CFG file in a safe mode
#
# prevents injections and quoting escape tricks
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# $1: [cfg-file]    optional cfg file name; defaults to the project config file
#
reload_cfg() {
  local config_file=${1:-$CFG_FILE}
  [ ! -f "$config_file" ] && return 0
  local sanitized=""
  # shellcheck disable=SC1097
  while IFS== read -r var value; do
    [[ "$var" =~ ^# ]] && continue
    printf -v sanitized "%q" "$value"
    eval "$var"="$sanitized"
  done < "$config_file"
  return 0
}

# INTERACTION

prompt() {
  ask "$1" notif
}

# set_or_F
#
# sets a var with the given source value
# if no value is provided asks it to the user
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# $1: dvar        destination var to set
# $2: sval        source value
# $3: prompt      (if required) Supports tags %sp (standard prompt) and %var (dest var name)
# $4: pdef        (for the prompt)
# $5: [asserter]  assert function (with "?" suffix allows nulls)
#
set_or_ask() {
  local dvar="$1"
  local sval="$2"
  local prompt="$3"
  local pdef="$4"
  local asserter="$5"

  _set_var "$dvar" ""

  prompt="${prompt//%sp/Please provide the}"
  prompt="${prompt//%var/$dvar}"

  local res="$sval"
  local def=""
  local nullable=false
  [[ "$asserter" =~ ^.*\?$ ]] && nullable=true

  while true; do

    [ -z "$res" ] && {
      if [ -n "$asserter" ]; then
        "$asserter" "${dvar}_DEFAULT" "$pdef" "silent"
        def="$pdef"
      else
        def="$pdef"
      fi

      if [ -n "$def" ]; then
        read -rep "$prompt ($def): " res
        [ -z "$res" ] && [ -n "$def" ] && res="$pdef"
      else
        read -rep "$prompt: " res
      fi
    }

    if [ -n "$asserter" ]; then
      if [ -n "$res" ] || ! $nullable; then
        ( "$asserter" "$dvar" "$res" ) || {
          res=""
          continue
        }
      fi
    fi

    break
  done
  _set_var "$dvar" "$res"
}

# asks a yes/no/quit question
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~
# $1: text      the text of the question
#
ask() {
  while true; do
    [ "$2" == "notif" ] && echo -ne "$1" || echo -ne "$1 (y/n/q)"
    if [ -n "$ENTANDO_OPT_YES_FOR_ALL" ] && "$ENTANDO_OPT_YES_FOR_ALL"; then
      echo " (auto-yes/ok)"
      return 0
    fi

    # shellcheck disable=SC2162
    read -rep " " res
    [ "$2" == "notif" ] && return 0

    case $res in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      [Qq]*)
        EXIT_UE "User stopped the execution"
        exit 99 ;;
      *) echo "Please answer yes, no or quit."; sleep 0.5;;
    esac
  done
}

# QUITS due to a low level fatal error
#
FATAL() {
  echo -e "---"
  _log_e 0 "FATAL: $*"
  xu_set_status "FATAL: $*"
  exit 77
}

# QUITS due to a user error
#
EXIT_UE() {
  echo -e "---"
  [ "$1" != "" ] && _log_w 0 "$@"
  xu_set_status "USER-ERROR"
  exit 1
}

# converts a snake case identifier to camel case
snake_to_camel() {
  local res="$(echo "$2" | sed -E 's/[ _-]([a-z])/\U\1/gi;s/^([A-Z])/\l\1/')"
  _set_var "$1" "$res"
}

# Returns the index of the given argument value
# if "-p" is provided as first argument performs a partial match
# return 255 if the arguments was not found
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# $1:   the argument value to look for
# $...: the remaining arguments are the array to be searched
#
index_of_arg() {
  REGEX=false
  [ "$1" == "-p" ] && REGEX=true && shift
  par="$1"
  shift
  i=1
  if $REGEX; then
    while [[ ! "$1" == ${par}* ]] && [ -n "$1" ] && [ $i -lt 100 ]; do
      i=$((i + 1))
      shift
    done
  else
    while [[ "$1" != "$par" ]] && [ -n "$1" ] && [ $i -lt 100 ]; do
      i=$((i + 1))
      shift
    done
  fi
  [ $i -eq 100 ] && return 255
  [ -n "$1" ] && return $i || return 255
}

# prints the Entando banner
#
print_entando_banner() {
  B='\033[0;34m'
  W='\033[0;37m'
  N=''
  echo -e ""
  echo -e " $B████████╗$W"
  echo -e " $B██╔═════╝$W"
  echo -e " $B██║$W $B███████╗$W  ██    █  ███████    ███    ██    █  ██████    █████ "
  echo -e " $B╚═╝$N $B█╔═════╝$W  █ █   █     █      █   █   █ █   █  █     █  █     █"
  echo -e " $N$N    $B█████╗  $W  █  █  █     █     █     █  █  █  █  █     █  █     █"
  echo -e " $N$N    $B█╔═══╝  $W  █   █ █     █     ███████  █   █ █  █     █  █     █"
  echo -e " $N$N    $B███████╗$W  █    ██     █     █     █  █    ██  ██████    █████    $B██╗$W"
  echo -e " $N$N    $B╚══════╝$W                                                         $B██║$W"
  echo -e " $N$N$N$N                                                               $B████████║$W"
  echo -e " $N$N$N$N                                                               $B╚═══════╝$W"
}

# requires that the system environment was checked for development mode
#
require_develop_checked() {
  [ "$WAS_DEVELOP_CHECKED" != "true" ] && FATAL "Run \"ent-check-env.sh develop\" before this command"
}

# requires that the project dir is properly initialized
#
require_initialized_dir() {
  [ ! -f "package.json" ] && [ ! -f "package-lock.json" ] && FATAL "Directory not initialized"
}

# pre-parse the lines of a jdlt file
#
# a jdlt file is a jdl file template
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# $1: the file to parse
#
pre_parse_jdlt() {
  FILE="$1" # the file to parse
  grep "{{[a-zA-Z][.-_a-zA-Z0-9]*}}," "$FILE" | sed 's/\s\+[^{]*{{\([^}]*\).*/\1/'
}
