#!/bin/bash
# UTILS

# CFG
WAS_DEVELOP_CHECKED=false

IS_GIT_CREDENTIAL_MANAGER_PRESENT=false
git credential-cache 2> /dev/null
if [ "$?" != 1 ]; then
  IS_GIT_CREDENTIAL_MANAGER_PRESENT=true
fi

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
# Maps:
# save_cfg_value -m {MAP_NAME} {KEY} {VALUE}
#
save_cfg_value() {
  IS_MAP=false
  [ "$1" = "-m" ] && IS_MAP=true && shift
  local name="${1}"
  shift
  local value="${1}"
  shift
  local config_file=${1:-$CFG_FILE}
  shift

  if [[ -f "$config_file" ]]; then
    if $IS_MAP; then
      _sed_in_place "/^${name}__/d" "$config_file"
    else
      _sed_in_place "/^${name}=/d" "$config_file"
    fi
  fi
  if [ "$(echo "$value" | wc -l)" -gt 1 ]; then
    FATAL "save_cfg_value: Unsupported multiline value $value"
  fi
  if $IS_MAP; then
    local key
    local val
    for key in $(echo "${!__AA_*}" | grep "__AA_${name}_"); do
      val="${!key}"
      [ -z "$val" ] && continue
      printf "${key}=%s\n" "$val" >> "$config_file"
    done
  else
    if [ -n "$value" ]; then
      printf "$name=%s\n" "$value" >> "$config_file"
    fi
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
    if assert_ext_ic_id_with_arr "CFGVAR" "$var" "silent"; then
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
  LOGGER() {
    _log_e 0 "FATAL: $*"
  }
  if [ "$1" = "-t" ]; then
    shift
    print_calltrace 1 3 "" LOGGER "$@" 1>&2
  else
    LOGGER "$@"
  fi
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
  local N=1
  local REGEX=0
  if [ "$1" = "--" ]; then
    REGEX=0
    shift
  else
    [ "$1" = "-p" ] && {
      REGEX=1
      shift
    }
    [ "$1" = "-P" ] && {
      REGEX=2
      shift
    }
    [ "$1" = "-n" ] && {
      N="$2"
      shift 2
    }
  fi
  par="$1"
  shift
  local i=0
  while true; do
    case "$REGEX" in
      1)
        while [[ ! "$1" == ${par}* ]] && [ -n "$1" ] && [ $i -lt 100 ]; do
          i=$((i + 1))
          shift
        done
        ;;
      2)
        while [[ ! "$1" =~ ${par}* ]] && [ -n "$1" ] && [ $i -lt 100 ]; do
          i=$((i + 1))
          shift
        done
        ;;
      *)
        while [[ ! "$1" == "$par" ]] && [ -n "$1" ] && [ $i -lt 100 ]; do
          i=$((i + 1))
          shift
        done
        ;;
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
# shellcheck disable=SC2059
print_entando_banner() {
  B() { echo '\033[0;34m'; }
  W() { echo '\033[0;39m'; }
  N=''
  printf "\n"
  printf " $(B)████████╗$(W)\n"
  printf " $(B)██╔═════╝$(W)\n"
  printf " $(B)██║$(W) $(B)███████╗$(W)  ██    █  ███████    ███    ██    █  ██████    █████ \n"
  printf " $(B)╚═╝${N} $(B)█╔═════╝$(W)  █ █   █     █      █   █   █ █   █  █     █  █     █\n"
  printf " ${N}${N}    $(B)█████╗  $(W)  █  █  █     █     █     █  █  █  █  █     █  █     █\n"
  printf " ${N}${N}    $(B)█╔═══╝  $(W)  █   █ █     █     ███████  █   █ █  █     █  █     █\n"
  printf " ${N}${N}    $(B)███████╗$(W)  █    ██     █     █     █  █    ██  ██████    █████    $(B)██╗$(W)\n"
  printf " ${N}${N}    $(B)╚══════╝$(W)                                                         $(B)██║$(W)\n"
  printf " ${N}${N}${N}${N}                                                               $(B)████████║$(W)\n"
  printf " ${N}${N}${N}${N}                                                               $(B)╚═══════╝$(W)\n"
}

# requires that the system environment was checked for development mode
#
require_develop_checked() {
  [ "$WAS_DEVELOP_CHECKED" != "true" ] && FATAL "Run \"ent check-env develop\" before this command"
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
  ! $IS_GIT_CREDENTIAL_MANAGER_PRESENT && return 99

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
#
# Notes the {prompt message} supports the placeholders:
# - %sp:  "Please provide " (resolved to "" when printing the help)
# - %var: the var name
#
args_or_ask() {
  local NOASK=false
  local FLAG=false
  local FLAGANDVAR=false
  local ARG=false
  local PRESERVE=false
  local JUST_PRINT_HELP=false
  local SPACE_SEP=false
  local PRINT_COMPLETION_CODE=false
  local IS_DEFAULT=false

  print_sub_help() {
    local val_name="$1"
    local val_msg="$2"
    $JUST_PRINT_HELP && {
      if [ -z "$val_msg" ]; then
        val_msg="$val_name"
      else
        val_msg="${val_msg//%sp/}"
      fi
      echo "    $val_name @$val_msg" | _align_by_sep "@" 25
      return 0
    }
    return 1
  }

  # pare flags
  while true; do
    case "$1" in
      -n) NOASK=true; shift;;
      -f) FLAG=true; shift;;
      -F) FLAGANDVAR=true;shift;;
      -a) ARG=true;shift;;
      -p) PRESERVE=true;shift;;
      -s) SPACE_SEP=true;shift;;
      -d) IS_DEFAULT=true;shift;;
      --help) JUST_PRINT_HELP=true;shift;;
      --cmplt) PRINT_COMPLETION_CODE=true;shift;;
      --) shift;break;;
      *) break;;
    esac
  done

  ! $FLAG && {
    local var_name="$1"
    shift
  }

  local val_name val_type val_def val_msg
  IFS='/' read -r val_name val_type val_def val_msg <<< "${1}/"
  shift

  $PRINT_COMPLETION_CODE && {
    if $FLAG; then
      echo "${val_name}"
    elif $ARG; then
      :;
    else
      echo "${val_name}="
    fi
    return 1
  }

  ! $FLAG && ! $PRESERVE && {
    _set_var "$var_name" ""
  }

  $IS_DEFAULT && [ -z "$1" ] && return 0

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

    print_sub_help "$val_name" "$val_msg" && return 2

    if [ $found_at -ne 255 ]; then
      $FLAGANDVAR && _set_var "$var_name" "true"
      return 0
    else
      $FLAGANDVAR && _set_var "$var_name" "${val_def:-false}"
      return 1
    fi
  else
    if $SPACE_SEP; then
      index_of_arg -- "${val_name}" "$@"
      found_at="$?"
      found_at=$((found_at + 1))
    else
      index_of_arg -p "${val_name}=" "$@"
      found_at="$?"
    fi

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

  print_sub_help "$val_name" "$val_msg" && return 2

  if $FLAG; then
    index_of_arg "${val_name}" "$@"
    [ "$?" -eq 255 ] && return 1 || return 0
  fi


  [[ "$found_at" -eq 255 && -z "$val_def" ]] && $NOASK && return 255

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

simple_shell_completion_handler() {
  if [ "$1" = "--cmplt" ]; then
    shift
    for a in "$@"; do echo "$a"; done
  fi
}

parse_help_option() {
  local ARG="${BASH_ARGV[0]}"

  case "$ARG" in
    "--help") HH="--help";;
    "--cmplt") HH="--cmplt"
  esac

  echo "$HH"
}

show_help_option() {
  case "$1" in
    --help) echo "> Parameters:";;
    --cmplt) echo "--help";;
  esac
}

args_or_ask__a_remote() {
  [ "$1" = "-a" ] && local PRE="$1" && shift
  [ "$1" = "--help" ] && local HH="$1" && shift
  local var_name="$1"
  shift
  local switch="$1"
  shift
  local msg="$1"
  shift
  local TMP

  args_or_ask "$PRE" -n -p ${HH:+"$HH"} "TMP" "$switch/ext_id?//$msg" "$@"

  [ -z "$HH" ] && {
    if [ -z "$TMP" ]; then
      local count
      remotes-count count
      if [ "$count" -eq 0 ]; then
        TMP=""
      else
        TITLES="$(remotes-list)"
        TITLES+=("other..")
        select_one "Select the remote" "${TITLES[@]}"
        local TMP="$select_one_res_alt"
        [ $TMP = "other.." ] && TMP=""
      fi
    fi

    if [ -z "$TMP" ]; then
      args_or_ask -p "TMP" "$switch/ext_id/$TMP/$msg" "$@"
    else
      assert_ext_id "$var_name" "$TMP"
    fi

    _set_var "$var_name" "$TMP"
  }
}
#-----------------------------------------------------------------------------------------------------------------------

remotes-clear() {
  for name in ${!__AA_ENTANDO_REMOTES__*}; do
    unset "${name}"
  done
}

remotes-count() {
  local i=0
  for name in ${!__AA_ENTANDO_REMOTES__*}; do
    i=$((i + 1))
  done
  _set_var "$1" "$i"
  [ "$i" -gt 0 ] && return 0
  return 255
}

remotes-set() {
  local name="$1"
  local address="$2"
  _set_var "__AA_ENTANDO_REMOTES__${name}" "$address"
}

remotes-get() {
  if [ "$1" = "--first" ]; then
    shift
    local dst_var_name="$1"
    local name="$(remotes-list | head -n 1)"
  else
    local dst_var_name="$1"
    local name="$2"
  fi
  local tmp
  tmp="__AA_ENTANDO_REMOTES__${name}"
  value="${!tmp}"
  _set_var "$dst_var_name" "$value"
  [ -n "$value" ] && return 0
  return 255
}

remotes-del() {
  local name="$1"
  unset "__AA_ENTANDO_REMOTES__${name}"
}

# shellcheck disable=SC2120
remotes-list() {
  local SEP="$1"
  local tmp
  for name in ${!__AA_ENTANDO_REMOTES__*}; do
    {
      if [ -z "$SEP" ]; then
        echo "$name"
      else
        tmp="${name}"
        echo "${name}${SEP}${!tmp}"
      fi
    } | sed "s/__AA_ENTANDO_REMOTES__//"
  done
}

remotes-save() {
  save_cfg_value -m "ENTANDO_REMOTES"
}