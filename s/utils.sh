# UTILS

# CFG

# runs a sed "in place" given the sed command and the file to change
# (multiplatform wrapper)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# $@ the sed in place args *without* the "-i
#
_sed_in_place() {
  [ "$2" = "" ] && FATAL "Illegal function call (missing file param)"
  if $OS_MAC; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# Saves a key/value pair to a configuration file
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# $1: key           strict identifier
# $2: value         the value of the key
# $3: [cfg-file]    optional cfg file name; defaults to the project config file
#
save_cfg_value() {
  local config_file=${3:-$CFG_FILE}
  if [[ -f "$config_file" ]]; then
    _sed_in_place "/^$1=.*$/d" "$config_file"
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
    if assert_ic_id "CFGVAR" "$var" "silent"; then
      printf -v sanitized "%q" "$value"
      eval "$var"="$sanitized"
    else
      _log_e 0 "Skipped illegal var name $var"
    fi
  done < "$config_file"
  return 0
}

# INTERACTION

prompt() {
  ask "$1" "" notif
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
  local NULLABLE=false
  [[ "$asserter" =~ ^.*\?$ ]] && NULLABLE=true

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
      if [ -n "$res" ] || ! $NULLABLE; then
        ("$asserter" "$dvar" "$res") || {
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
  local prompt="$1"
  local default="$2"
  local mode="$3"
  while true; do
    local suffix=""
    if [ "$mode" != "notif" ]; then
      suffix="$(echo " (y/n/q)" | _perl_sed "s/($default)/\U\1/i")"
    fi
    echo -ne "$prompt$suffix"
    if [ -n "$ENTANDO_OPT_YES_FOR_ALL" ] && "$ENTANDO_OPT_YES_FOR_ALL"; then
      echo " (auto-yes/ok)"
      return 0
    fi

    # shellcheck disable=SC2162
    read -rep " " res
    [ "$mode" == "notif" ] && return 0
    [ "$res" == "" ] && res="$default"

    case $res in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      [Qq]*)
        EXIT_UE "User stopped the execution"
        exit 99
        ;;
      *)
        echo "Please answer yes, no or quit."
        sleep 0.5
        ;;
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
  local res="$(echo "$2" | _perl_sed 's/[ _-]([a-z])/\U\1/gi;s/^([A-Z])/\l\1/')"
  _set_var "$1" "$res"
}

# converts a snake case identifier to camel case
camel_to_snake() {
  if [ "$1" == "-d" ]; then
    shift
    local res="$(echo "$2" | _perl_sed 's/([A-Z]{1,})/-\L\1/g;s/^-//')"
  else
    local res="$(echo "$2" | _perl_sed 's/([A-Z]{1,})/_\L\1/g;s/^_//')"
  fi
  _set_var "$1" "$res"
}

# Returns the index of the given argument value
# if "-p" is provided as first argument performs a partial match
# if "-P" is provided as first argument performs a bash pattern match
# if "-n X" is provided for first X-1 matches are ignored
# return 255 if the arguments was not found
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# $1:   the argument value to look for
# $...: the remaining arguments are the array to be searched
#
index_of_arg() {
  local N=1; local REGEX=0
  if [ "$1" = "--" ]; then
    REGEX=0;shift;
  else
    [ "$1" = "-p" ] && { REGEX=1;shift; }
    [ "$1" = "-P" ] && { REGEX=2;shift; }
    [ "$1" = "-n" ] && { N="$2";shift 2; }
  fi
  par="$1"
  shift
  local i=0
  while true; do
    case "$REGEX" in
    1)
      while [[ ! "$1" = ${par}* ]] && [ -n "$1" ] && [ $i -lt 100 ]; do
        i=$((i + 1))
        shift
      done;;
    2)
      while [[ ! "$1" =~ ${par}* ]] && [ -n "$1" ] && [ $i -lt 100 ]; do
        i=$((i + 1))
        shift
      done;;
    *)
      while [[ ! "$1" = "$par" ]] && [ -n "$1" ] && [ $i -lt 100 ]; do
        i=$((i + 1))
        shift
      done;;
    esac
    i=$((i + 1))
    N=$((N - 1))
    [ "$N" -le 0 ] && break
    shift
  done
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
  [ "$WAS_DEVELOP_CHECKED" != "true" ] && FATAL "Run \"ent-check-env develop\" before this command"
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
  grep "{{[a-zA-Z][.-_a-zA-Z0-9]*}}," "$FILE" | _perl_sed 's/\s+[^{]*{{([^}]*).*/\1/'
}

git_enable_credentials_cache() {
  if [ -n "$1" ]; then
    git config credential.helper "cache --timeout='$1'"
  else
    git config credential.helper
  fi
}

select_one() {
  local i=1
  local SELECTED=""
  [ "$1" == "-a" ] && ALL=true && shift
  P="$1"
  shift
  select_one_res=""
  select_one_res_alt=""

  for item in "$@"; do
    echo "$i) $item"
    i=$((i + 1))
  done
  ${ALL:-false} && echo "a) all"
  echo "q) to quit"

  while true; do
    printf "%s" "$P"
    set_or_ask "SELECTED" "" ""
    [[ "$SELECTED" == "q" ]] && EXIT_UE "User interrupted"
    [[ ! "$SELECTED" =~ ^[0-9]+$ ]] && continue
    [[ "$SELECTED" -gt 0 && "$SELECTED" -lt "$i" ]] && break
    [[ "$SELECTED" -gt 0 && "$SELECTED" -lt "$i" ]] && break
  done

  # shellcheck disable=SC2034
  {
    select_one_res="$SELECTED"
    select_one_res_alt="${!SELECTED}"
  }
}

# Sets a variable according with the value found in a variable definition and arguments
# - variable name
# - variable definition     arg-name/type/default/prompt
# - arguments
# Flags:
# - -n    suppress the "ask" and just fails or returns the default
# - -f    flag mode, looks for expression with no value and sets the return value
# - -F    like "-f" but also sets the give var with true or false
# - -a    looks for the positional arg of given index (that doesn't start with dash)
# - -p    only set the var is a value was found
#
# Example:
# - args_or_ask  "NAME" "name/id//Enter the name" "$@"
# {argument to look for}/{type}/{default}/{prompt message}
args_or_ask() {
  local NOASK=false
  local FLAG=false
  local FLAGANDVAR=false
  local ARG=false
  local PRESERVE=false
  local JUST_PRINT_HELP=false

  while true; do
    case "$1" in
      -n) NOASK=true;shift;;
      -f) FLAG=true;shift;;
      -F) FLAGANDVAR=true;shift;;
      -a) ARG=true;shift;;
      -p) PRESERVE=true;shift;;
      -h) JUST_PRINT_HELP=true;shift;;
      *) break;;
    esac
  done

  if $FLAG; then
    local V="$1"; shift
    val_name="$(echo "$V" | cut -d'/' -f 1)"
    index_of_arg "${val_name}" "$@"
    [ "$?" -eq 255 ] && return 1 || return 0;
  else
    local var_name="$1"; shift
    local V="$1/"; shift
    local val_name="$(echo "$V" | cut -d'/' -f 1)"
    local val_type="$(echo "$V" | cut -d'/' -f 2)"
    local val_def="$(echo "$V" | cut -d'/' -f 3)"
    local val_msg="$(echo "$V" | cut -d'/' -f 4)"
    ! $PRESERVE && _set_var "$var_name" ""
  fi

  $JUST_PRINT_HELP && {
    echo "    $val_name @$val_msg" | _align_by_sep "@" 25
    return 0
  }

  # user provided value
  if $ARG; then
    assert_num "POSITIONAL_ARGUMENT_INDEX" "$val_name"
    index_of_arg -p -n "$val_name" "[^-]" "$@"
    found_at="$?"
    val_name="Argument #$val_name"

    if [ $found_at -ne 255 ]; then
      val_from_args="$(echo "${!found_at}" | cut -d'=' -f 2)"
    else
      val_from_args=""
    fi
  elif $FLAG || $FLAGANDVAR; then
    index_of_arg "${val_name}" "$@"
    found_at="$?"

    if [ $found_at -ne 255 ]; then
      $FLAGANDVAR && _set_var "$var_name" "true"
      return 0
    else
      $FLAGANDVAR &&_set_var "$var_name" "${val_def:-false}"
      return 1
    fi
  else
    index_of_arg -p "${val_name}=" "$@"
    found_at="$?"

    if [ $found_at -eq 255 ]; then
      index_of_arg "${val_name}" "$@"
      found_at="$?"
      val_from_args=""
    else
      if [ $found_at -ne 255 ]; then
        val_from_args="$(echo "${!found_at}" | cut -d'=' -f 2)"
      else
        val_from_args=""
      fi
    fi
  fi

  [[ "$found_at" -eq 255 && -z "$val_def" ]] && return 255

  # prompt message processing
  if [ -z "$val_msg" ]; then
    val_msg="Please provide the value for \"$val_name\""
  fi

  # type processing
  if [ -n "$val_type" ]; then
    if [[ "$val_type" =~ (.*)\? ]]; then
      val_type="${BASH_REMATCH[1]}"
      local NULLABLE=true
    else
      local NULLABLE=false
    fi

    local assertion="assert_$val_type"

    if [ "$(LC_ALL=C type -t "$assertion")" != "function" ]; then
      echo "undefined type \"$val_type\", falling back to \"strict_id\"" 1>&2
      val_type="strict_id"
      assertion="assert_$val_type"
    fi
  else
    local NULLABLE=true
    local assertion=""
  fi


  # set/ask
  if $NOASK; then
    if [ -z "$val_from_args" ]; then
      local val="$val_def"
    else
      local val="$val_from_args"
    fi
    $NULLABLE && [ -z "$val" ] && return 0

    [ -n "$assertion" ] && { "$assertion" "$var_name" "$val" "silent" || return $?; }
    _set_var "$var_name" "$val"
    return 0
  else
    set_or_ask "$var_name" "$val_from_args" "$val_msg" "$val_def" "$assertion"
    return 0
  fi
}
