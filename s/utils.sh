#!/bin/bash
# UTILS

# CFG
WAS_DEVELOP_CHECKED=false

IS_GIT_CREDENTIAL_MANAGER_PRESENT=false
git credential-cache 2> /dev/null
if [ "$?" != 1 ]; then
  IS_GIT_CREDENTIAL_MANAGER_PRESENT=true
fi


xu_set_status() { :; }

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
  local config_file="$CFG_FILE"
  [ -n "$1" ] && {
    config_file="$1"
    shift
  }

  if [[ -f "$config_file" ]]; then
    if $IS_MAP; then
      _sed_in_place "/^${name}__/d" "$config_file"
    else
      _sed_in_place "/^${name}=/d" "$config_file"
    fi
  fi
  if [ "$(echo "$value" | wc -l)" -gt 1 ]; then
    FATAL "save_cfg_value: Unsupported multiline value \"$value\" for var: \"$name\""
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
    [[ -z "${var// }" ]] && continue
    if assert_ext_ic_id_with_arr "CFGVAR" "$var" "silent"; then
      printf -v sanitized "%q" "$value"
      sanitized="${sanitized/\\r/}"
      sanitized="${sanitized/\\n/}"
      eval "$var"="$sanitized"
    else
      _log_e "Skipped illegal var name $var"
    fi
  done <<<"$(cat "$config_file")"
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
# $4: pdef        (default to propose in the user prompt)
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
  if [[ "$asserter" =~ (.*)\? ]]; then
    asserter="${BASH_REMATCH[1]}"
    local NULLABLE=true
  else
    local NULLABLE=false
  fi

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
_FATAL() {
  local rv=77
  if [ "$1" != "-s" ]; then
    SKIP=1;[ "$1" = "-S" ] && { SKIP="$((SKIP+$2))"; shift 2; }
    [ "$1" = "-99" ] && shift && rv=99
    CALL_TRACE_LOGGER() { _log_e "$*" 1>&2; }
    print_calltrace "$SKIP" 5 "" CALL_TRACE_LOGGER "$@" 1>&2
  else
    shift
    [ "$1" = "-99" ] && shift && rv=99
    _log_e "$@" 1>&2
  fi
  exit "$rv"
}

FATAL() {
  _FATAL -s "$@"
}

# Validates for non-null a list of mandatory variables
# Fatals if a violation is found
#
NONNULL() {
  # shellcheck disable=SC2124
  local O="-S 1"; [ "$1" = "-s" ] && { O="-s"; shift; }
  for var_name in "$@"; do
    local var_value="${!var_name}"
    [ -z "$var_value" ] && _FATAL $O "${FUNCNAME[1]}> Variable \"$var_name\" should not be null"
  done
}

# QUITS due to a user error
#
EXIT_UE() {
  echo -e "---"
  [ "$1" != "" ] && _log_w "$@"
  xu_set_status "USER-ERROR"
  exit 1
}

# converts a snake case identifier to camel case
snake_to_camel() {
  local res="$(echo "$2" | _perl_sed 's/[ _-]([a-z])/\U\1/gi;s/^([A-Z])/\l\1/')"
  _set_or_print "$1" "$res"
}

# converts a snake case identifier to camel case
camel_to_snake() {
  if [ "$1" == "-d" ]; then
    shift
    local res="$(echo "$2" | _perl_sed 's/([A-Z]{1,})/-\L\1/g;s/^-//')"
  else
    local res="$(echo "$2" | _perl_sed 's/([A-Z]{1,})/_\L\1/g;s/^_//')"
  fi
  _set_or_print "$1" "$res"
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
  {
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
  } > /dev/stderr
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
  local ALL=false
  local AUTO_SET_IF_SINGLE=false
  [ "$1" = "-s" ] && AUTO_SET_IF_SINGLE=true && shift
  [ "$1" = "-a" ] && ALL=true && shift
  P="$1"
  shift
  select_one_res=""
  select_one_res_alt=""

  if $AUTO_SET_IF_SINGLE && [ "$#" -eq 1 ]; then
    select_one_res="1"
    select_one_res_alt="$1"
    return 0
  fi

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
# - -s    assumes space separator
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
  local NEVER_ASK=false
  local ALWAYS_ASK=false
  local FLAG=false
  local FLAGANDVAR=false
  local ARG=false
  local PRESERVE=false
  local PRINT_HELP=false
  local JUST_PRINT_HELP=false
  local SPACE_SEP=false
  local PRINT_COMPLETION_CODE=false
  local IS_DEFAULT=false

  print_sub_help() {
    local val_name="$1"
    local val_msg="$2"
    $PRINT_HELP && {
      before_printing_help
      
      if [ -n "$ENT_HELP_SECTION_TITLE" ]; then
        echo "$ENT_HELP_SECTION_TITLE"
        ENT_HELP_SECTION_TITLE=""
      fi

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
  
  JUST_PRINT_HELP=false
  # pare flags
  while true; do
    case "$1" in
      -n) NEVER_ASK=true;shift;;
      -A) ALWAYS_ASK=true;shift;;
      -f) FLAG=true;shift;;
      -F) FLAGANDVAR=true;shift;;
      -a) ARG=true;shift;;
      -p) PRESERVE=true;shift;;
      -s) SPACE_SEP=true;shift;;
      -d) IS_DEFAULT=true;shift;;
      --help) PRINT_HELP=true;NEVER_ASK=true;shift;;
      --help-only) PRINT_HELP=true;JUST_PRINT_HELP=true;shift;;
      --cmplt) PRINT_COMPLETION_CODE=true;NEVER_ASK=true;shift;;
      -h)
        case "$2" in
          "--help") PRINT_HELP=true;NEVER_ASK=true;;
          "--help-only") PRINT_HELP=true;JUST_PRINT_HELP=true;;
          "--cmplt") PRINT_COMPLETION_CODE=true;NEVER_ASK=true;;
        esac
        shift 2
        ;;
      --)
        shift
        break
        ;;
      *) break ;;
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
      :
    else
      if $SPACE_SEP || $FLAG || $FLAGANDVAR; then
        echo "${val_name}"
      else
        echo "${val_name}="
      fi
    fi
    
    $JUST_PRINT_HELP && return 1
    ! $ARG && return 1
  }

  ! $FLAG && ! $PRESERVE && {
    _set_var "$var_name" ""
  }

  $IS_DEFAULT && [ -z "$1" ] && return 0

  # user provided value
  if $ARG; then                                                                     # POSITIONAL VALUE
    assert_num "the index of positional argument" "$val_name" || _FATAL "Internal Error"
    index_of_arg -p -n "$val_name" "[^-]" "$@"
    found_at="$?"
    val_name="Argument #$((val_name))"

    if [ $found_at -ne 255 ]; then
      val_from_args="$(echo "${!found_at}" | cut -d'=' -f 2)"
    else
      val_from_args=""
    fi
  elif $FLAG || $FLAGANDVAR; then                                                   # FLAGS or FLAG-VARS
    print_sub_help "$val_name" "$val_msg" && $JUST_PRINT_HELP && return 2

    index_of_arg "${val_name}" "$@"
    found_at="$?"

    if [ $found_at -eq 255 ]; then
      index_of_arg -p "${val_name}=" "$@"
      found_at="$?"
      if [ $found_at -eq 255 ]; then
        val_from_args=""
      else
        val_from_args="$(echo "${!found_at}" | cut -d'=' -f 2)"
      fi
    else
      val_from_args=""
    fi

    if [ -z "$val_from_args" ]; then
      if [ $found_at -ne 255 ]; then
        $FLAGANDVAR && _set_var "$var_name" "true"
        return 0
      else
        if $FLAGANDVAR; then
          if [ -n "$val_def" ] || ! $PRESERVE; then
            _set_var "$var_name" "${val_def:-false}"
          fi
        fi
        return 1
      fi
    fi
  else                                                                            # NOMINAL SWITCHES
    if $SPACE_SEP; then                                                             # with space
      index_of_arg -- "${val_name}" "$@"
      found_at="$?"
      if [ $found_at -ne 255 ]; then
        found_at=$((found_at + 1))
      fi
    else
      index_of_arg -p "${val_name}=" "$@"                                           # with equal sign
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

  print_sub_help "$val_name" "$val_msg" && $JUST_PRINT_HELP && return 2

  if $FLAG; then
    index_of_arg "${val_name}" "$@"
    [ "$?" -eq 255 ] && return 1 || return 0
  fi

  [[ "$found_at" -eq 255 && -z "$val_def" ]] && $NEVER_ASK && return 255

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
      print_calltrace
      val_type="strict_id"
      assertion="assert_$val_type"
    fi
  else
    local NULLABLE=true
    local assertion=""
  fi

  # set/ask
  if $NEVER_ASK; then
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
    val="$val_from_args"
    if $NULLABLE; then
      assertion+="?"
      [[ "$found_at" -ne 255 && -z "$val" ]] && {
        _set_var "$var_name" "$val"
        return 0
      }
      ! $ALWAYS_ASK && $NULLABLE && [[ "$found_at" -ne 255 || -n "$val" ]] && {
        _set_var "$var_name" "$val"
        return 0
      }
    fi
    set_or_ask "$var_name" "$val" "$val_msg" "$val_def" "$assertion"
    return 0
  fi
}

simple_cmplt_handler() {
  [ "$HH" == "--cmplt" ] && { echo "$@" | tr ' ' $'\n'; exit 0; }
}

simple_help_handler() {
  [ -z "$HH" ] && { HH="$(parse_help_option "$@")"; }
  [ "$HH" == "--help" ] && show_help_option "$HH";
  "$@"
  [ -n "$HH" ] && return 0
  return 1
}

parse_help_option() {
  # shellcheck disable=SC2124
  case "${!#}" in
    "--help") echo "--help";;
    "--cmplt") echo "--cmplt";;
    *) echo ""
  esac
}

show_help_option() {
  case "$1" in
    "--help")
      _nn ENT_MODULE_FILE && print_ent_module_help "$ENT_MODULE_FILE" "$2"
      if [ -n "$2" ]; then
        if [ "$2" = ":main" ]; then
          ENT_HELP_SECTION_TITLE="> Main arguments:"
        else
          ENT_HELP_SECTION_TITLE="> Arguments of \"$2\":"
        fi
      else
        ENT_HELP_SECTION_TITLE="> Arguments:"
      fi
      ;;
    "--cmplt") echo "--help" ;;
  esac
}

# declates the begin of the help and completion parsing phase, given:
# $1: the location on disk (ARG0) of the script for which the help is generated, or :<TITLE> if it's a sub-command
# $2: the command line parameters
#
# Implictly calls print_ent_module_help if help is requested
#
# Affects 3 global vars:
# HH                     set with the help/completion command ("--help", "--cmplt", "")
# HH_COMPLETION_REQUEST  set to true if it's the completion was requested
# HH_HELP_REQUEST        set to true if it's the help was requested
#
# Returns 0 if help or completion was requested
#
bgn_help_parsing() {
  if [ "${1:0:1}" != ":" ]; then
    ENT_MODULE_FILE="$1"
  else
    ENT_MODULE_FILE=""
  fi
  shift
  HH="$(parse_help_option "$@")"
  HH_COMPLETION_REQUEST=false;HH_HELP_REQUEST=false;HH_COMMAND=false;

  HH_LATCHED_HELP_HEADING() { :; }
  case "$HH" in
    "--help")
      # shellcheck disable=SC2034
      HH_HELP_REQUEST=true
      HH_LATCHED_HELP_HEADING() { show_help_option "$HH"; }
      ;;
    "--cmplt")
      # shellcheck disable=SC2034
      HH_COMPLETION_REQUEST=true
      ;;
    *)
      # shellcheck disable=SC2034
      HH_COMMAND=true
      ;;
  esac
  test -n "$HH"
}

before_printing_help() {
  [[ "$(type -t HH_LATCHED_HELP_HEADING)" == "function" ]] && HH_LATCHED_HELP_HEADING
  HH_LATCHED_HELP_HEADING() { :; }
}

end_help_parsing() {
  test -n "$HH" && exit 0
  HH=""
}


# Takes a value from the arguments or interactively from a provided array or map-reference
# A map reference the name of a map manipulated using the map-* functions
#
# $1: src_list:           the map name
# [ -m | -e | -a | --helps ]
# $4: res_var_name:       the var to set with the result
# $3: arg_code_or_num:    the map key to extract
# $6: type:               the expect type of the input data (defaults to "exp_id")
# $2: arg_desc:           the description of the expected input argument
# $5: msg:                the prompt message
#
args_or_ask_from_list() {
  local src_list="$1";shift
  local EXACT=false
  local IS_MAPREF=false
  local HH=""
  while true; do
    case $1 in
      "-m") IS_MAPREF=true;shift;;
      "-e") EXACT=true;shift;;
      "-a") PRE="$1";shift;;
      "-h") HH="$2";shift 2;;
      *) break ;;
    esac
  done
  local res_var_name="$1";shift
  local arg_code_or_num="$1";shift
  local type="${1:-"ext_id"}";shift
  local arg_desc="$1"; shift
  local msg="$1"; shift

  local TMP

  args_or_ask "$PRE" -n -p -h "$HH" "TMP" "$arg_code_or_num/$type//$msg" "$@"

  [ -z "$HH" ] && {
    if [ -z "$TMP" ]; then
      local count
      if $IS_MAPREF; then
        map-count "${src_list}" count
      else
        count="${#src_list[@]}"
      fi
      if [ "$count" -eq 0 ]; then
        TMP=""
      else
        # shellcheck disable=SC2207
        if $IS_MAPREF; then
          TITLES=($(map-list "${src_list}" -v))
        else
          TITLES=("${src_list[@]}")
        fi
        ! $EXACT && TITLES+=("other..")
        select_one "Select the ${arg_desc}" "${TITLES[@]}"
        local TMP="$select_one_res_alt"
        [ "$TMP" = "other.." ] && TMP=""
      fi
    fi

    if [ -z "$TMP" ]; then
      args_or_ask -p "TMP" "$arg_code_or_num/$type/$TMP/$msg" "$@"
    else
      "assert_${type}" "$res_var_name" "$TMP"
    fi

    _set_var "$res_var_name" "$TMP"
  }
}

stdin_to_arr() {
  local i=0
  local arr
  IFS="$1" read -d '' -r -a arr
  for line in "${arr[@]}"; do
    _set_var "$2[$i]" "$line"
    ((i++))
  done
}

# shellcheck disable=SC2120
print_current_profile_info() {
  VERBOSE=false; [ "$1" = "-v" ] && VERBOSE=true
  if $VERBOSE; then
    _log_i "Current profile info:"
    echo " - PROFILE:           ${THIS_PROFILE:-<NO-PROFILE>}"
    echo " - PROFILE HOME:      ${DESIGNATED_PROFILE_HOME}"
    _nn PROFILE_ORIGIN && echo " - PROFILE ORIGIN:    ${PROFILE_ORIGIN}"
  else
    if [ -n "$THIS_PROFILE" ]; then
      _log_i "Currently using profile \"$THIS_PROFILE\"" 1>&2
    else
      _log_i "Currently not using any profile" 1>&2
    fi
  fi
  
  $VERBOSE && {
    echo " - APPNAME:           ${ENTANDO_APPNAME:-<EMPTY>}"
    echo " - APPVER:            ${ENTANDO_APPVER:-<EMPTY>}"
    echo " - NAMESPACE:         ${ENTANDO_NAMESPACE:-<EMPTY>}"
    echo " - K8S CONTEXT:       ${DESIGNATED_KUBECTX:-<NO-CONTEXT>}"
  }
}


#-----------------------------------------------------------------------------------------------------------------------

http-check() {
  local RES
  RES=$(curl -sL -o /dev/null "$1" -w "%{http_code}" --insecure)
  
  case "$RES" in
    200 | 201)
      return 0;;
    401)
      [[ "$2" == "--accept-401" ]] && return 0
      return 1;;
    *)
      return 1;;
  esac
}

http-get-url-scheme() {
  _set_var "$1" "${2//:\/\/*/}"
}

http-get-working-url() {
  local res_var="$1"
  shift
  local res
  if http-check "$1" --accept-401; then
    res="$1"
  else
    if http-check "$2" --accept-401; then
      res="$2"
    else
      res=""
    fi
  fi

  _set_var "$res_var" "$res"
}

#-----------------------------------------------------------------------------------------------------------------------
# Retrieve the main application ingresses:
# $1: var for the scheme
# $2: var for the portal ingress
# $3: var for the ecr ingress
# $4: var for the application builder ingress
#
app-get-main-ingresses() {
  if check_ver "$ENTANDO_APPVER" "6.3.0" "" "string"; then
    app-get-main-ingresses-by-version "6.3.0" "$@"
  elif check_ver "$ENTANDO_APPVER" "6.3.>=2"  "" "string"; then
    app-get-main-ingresses-by-version "6.3.2" "$@"
  else
    local TMP1 TMP2 TMP3 TMP4
    app-get-main-ingresses-by-version "6.3.2" TMP1 TMP2 TMP3 TMP4
    _set_var "$1" "$TMP1"
    if [ -z "$TMP2" ] ||[ -z "$TMP3" ]; then
      # Before 6.3.2 the ingresses are marked with the same serviceName
      # So all the values end up in TMP1 and TMP3 and TMP4 are empty
      # shellcheck disable=SC2034
      ENTANDO_LATEST_DETECTED_APPVER="6.3.0"
      app-get-main-ingresses-by-version "6.3.0" "$@"
    else
      # From 6.3.2 instead they are properly marked
      # shellcheck disable=SC2034
      ENTANDO_LATEST_DETECTED_APPVER="6.3.2"
      _set_var "$2" "$TMP2"
      _set_var "$3" "$TMP3"
      _set_var "$4" "$TMP4"
    fi
  fi
}

app-get-main-ingresses-by-version() {
  local version="$1"
  local res_var_scheme="$2"
  local res_var_svc="$3"
  local res_var_ecr="$4"
  local res_var_apb="$5"
  shift

  local JP='{range .items[?(@.metadata.name=="'"$ENTANDO_APPNAME-ingress"'")]}'

  if [ "$version" = "6.3.0" ]; then
    JP+='{"?"}{"\n"}'
    JP+='{.spec.rules[0].host}{"\n"}'
    JP+='{.spec.rules[0].http.paths[0].path}{"\n"}'
    JP+='{.spec.rules[0].http.paths[0].path}{"\n"}'
    JP+='{.spec.rules[0].http.paths[1].path}{"\n"}'
    JP+='{.spec.rules[0].http.paths[2].path}{"\n"}'
  elif [ "$version" = "6.3.2" ]; then
    JP+='{"-"}{.spec.tls}{"\n"}'
    JP+='{.spec.rules[0].host}{"\n"}'
    # property detection: serviceName
    JP+='-{.spec.rules[0].http.paths[?(@.backend.serviceName=="'"$ENTANDO_APPNAME"'-server-service")].path}{"\n"}'
    JP+='-{.spec.rules[0].http.paths[?(@.backend.serviceName=="'"$ENTANDO_APPNAME"'-service")].path}{"\n"}'
    JP+='-{.spec.rules[0].http.paths[?(@.backend.serviceName=="'"$ENTANDO_APPNAME"'-cm-service")].path}{"\n"}'
    JP+='-{.spec.rules[0].http.paths[?(@.backend.serviceName=="'"$ENTANDO_APPNAME"'-ab-service")].path}{"\n"}'
    # property detection: service.name
    JP+='-{.spec.rules[0].http.paths[?(@.backend.service.name=="'"$ENTANDO_APPNAME"'-server-service")].path}{"\n"}'
    JP+='-{.spec.rules[0].http.paths[?(@.backend.service.name=="'"$ENTANDO_APPNAME"'-service")].path}{"\n"}'
    JP+='-{.spec.rules[0].http.paths[?(@.backend.service.name=="'"$ENTANDO_APPNAME"'-cm-service")].path}{"\n"}'
    JP+='-{.spec.rules[0].http.paths[?(@.backend.service.name=="'"$ENTANDO_APPNAME"'-ab-service")].path}{"\n"}'
  else
    _FATAL "Unsupported version \"$version\""
  fi
  
  JP+='{end}'

  local OUT
  stdin_to_arr $'\n\r' OUT < <(_kubectl get ingress -o jsonpath="$JP" 2> /dev/null)
  
  if [ "${OUT[0]}" = "-" ]; then
    _set_var "$res_var_scheme" "http"
  elif [ "${OUT[0]}" = "?" ]; then
    _set_var "$res_var_scheme" ""
  else
    _set_var "$res_var_scheme" "https"
  fi
  local base_url TMP
  path-concat base_url "${base_url}" "${OUT[1]}"
  _set_var "$res_var_svc" ""
  _set_var "$res_var_ecr" ""
  _set_var "$res_var_apb" ""
  
  [ "${OUT[2]}" != "-" ] && path-concat -t "$res_var_svc" "${base_url}" "${OUT[2]:1}"
  [ "${OUT[3]}" != "-" ] && path-concat -t "$res_var_svc" "${base_url}" "${OUT[3]:1}"
  [ "${OUT[6]}" != "-" ] && path-concat -t "$res_var_svc" "${base_url}" "${OUT[6]:1}"
  [ "${OUT[7]}" != "-" ] && path-concat -t "$res_var_svc" "${base_url}" "${OUT[7]:1}"
  
  [ "${OUT[4]}" != "-" ] && path-concat -t "$res_var_ecr" "${base_url}" "${OUT[4]:1}"
  [ "${OUT[8]}" != "-" ] && path-concat -t "$res_var_ecr" "${base_url}" "${OUT[8]:1}"
  
  [ "${OUT[5]}" != "-" ] && path-concat -t "$res_var_apb" "${base_url}" "${OUT[5]:1}"
  [ "${OUT[9]}" != "-" ] && path-concat -t "$res_var_apb" "${base_url}" "${OUT[9]:1}"
}

# Concatenates two path parts
#
# Note that the function tries to preserve local paths, so:
# - path-concat "" "b"
# generates:
# - "b"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# $1: destination var name 
# $2: the source value #1 
# $3: the source value #2
#
path-concat() {
  local terminated=false
  [[ "$1" = "-t" ]] && terminated=true && shift
  local out="$1"
  local val1="$2"
  local val2="$3"
  
  if [[ -n "$val1" ]]; then
    [[ "$val1" =~ ^.*/$ ]] && {
      val1_len="${#val1}"
      val1="${val1::$val1_len-1}"
    }
    [[ -n "$val2" ]] && [[ "$val2" =~ ^/.*$ ]] && val2="${val2:1}"
    TMP="${val1}/${val2}"
  else
    TMP="${val2}"
  fi
  
  if $terminated; then
    [[ ! "$TMP" =~ ^.*/$ ]] && TMP+="/"
  fi
  
  _set_var "$out" "$TMP"
}

# Removes the terminating path separator if present
#
path-blunt() {
  local val="$1"
  local val_len="${#val}"
  [[ "$val" =~ ^.*/$ ]] && val="${val::$val_len-1}"
  echo "$val"
}


keycloak-query-connection-data() {
  local tmp
  local scheme="$5"
  local _tmp_client_id
  local _tmp_client_secret
  local _tmp_auth_url
  local _tmp_realm="entando"
  
  tmp="$(
    _kubectl get secret "external-sso-secret" -o jsonpath="{.data.clientId}:{.data.clientSecret}:{.data.authUrl}:{.data.realm}" 2> /dev/null
  )"
  
  if [[ "$?" = "0" && -n "$tmp" ]]; then
    # EXTERNAL KEYCLOAK CONFIGURATION
    _log_d "external-sso-secret found"
    _tmp_auth_url="$(echo "$tmp" | cut -d':' -f3)"
    _tmp_auth_url=$(_base64_d <<< "$_tmp_auth_url")
    _tmp_realm="$(echo "$tmp" | cut -d':' -f4)"
    _tmp_realm=$(_base64_d <<< "$_tmp_realm")
    [ -z "$_tmp_auth_url" ] && FATAL "Unable to determine the IDP auth_url [e1]"
  else
    # INTERNAL KEYCLOAK CONFIGURATION
    local client_secret_name="${ENTANDO_APPNAME}-de-secret"
    tmp="$(
      _kubectl get secret "$client_secret_name" -o jsonpath="{.data.clientId}:{.data.clientSecret}" 2> /dev/null
    )"
    
    _tmp_auth_url="$(
      _kubectl get ingress -o "custom-columns=NAME:.metadata.name,HOST:.spec.rules[0].host" 2>/dev/null \
        | grep -E -- 'kc-ingress|-sso-' | head -n 1 | awk '{print $2}'
    )"
    
    [ -z "$_tmp_auth_url" ] && FATAL "Unable to determine the IDP auth_url [e2]"
    _tmp_auth_url+="/auth"
    _tmp_auth_url="$scheme://$_tmp_auth_url"
  fi
  
  client_id="$(echo "$tmp" | cut -d':' -f1)"
  client_secret="$(echo "$tmp" | cut -d':' -f2)"
  
  [ -z "$client_id" ] && FATAL "Unable to extract the application client secret"

  _tmp_client_id=$(_base64_d <<< "$client_id")
  _tmp_client_secret=$(_base64_d <<< "$client_secret")
 
  _set_var "$1" "$_tmp_auth_url"
  _set_var "$2" "$_tmp_client_id"
  _set_var "$3" "$_tmp_client_secret"
  _set_var "$4" "$_tmp_realm"
}

keycloak-get-token() {
  local res_var="$1"; shift
  local scheme="$1"
  local auth_url client_id client_secret realm
  
  [ -z "$ENTANDO_APPNAME" ] && FATAL "Please set the application name"

  keycloak-query-connection-data auth_url client_id client_secret realm "$scheme"
  
  # Finds the KEYCLOAK ENDPOINT
  local TOKEN_ENDPOINT
  TOKEN_ENDPOINT="$(curl --insecure -sL "${auth_url}/realms/${realm}/.well-known/openid-configuration" \
    | _jq -r ".token_endpoint")"
  
  local TOKEN
  TOKEN="$(curl --insecure -sL "$TOKEN_ENDPOINT" \
    -H "Accept: application/json" \
    -H "Accept-Language: en_US" \
    -u "$client_id:$client_secret" \
    -d "grant_type=client_credentials" \
    | _jq -r '.access_token')"

  [[ -z "$TOKEN" || "$TOKEN" == "null" ]] && FATAL "Unable to extract the access token"

  _set_var "$res_var" "$TOKEN"
}

# Implements a mechanism restrict and preserve in the current tty the profile to use 
#
# How:
# 1) The profile name to use is saved on environment variables
# 2) The environment variables are qualified with a string derived from the current tty name
# 3) The environment variables are set by sourcing the app-use: "source ent use my-app"
# 
# Why:
# 1) In order to avoid interferences between ttys 
# 2) The qualifiers allows to prevent from reusing the same environment variables on forked ttys
#
# shellcheck disable=SC2296
handle_forced_profile() {
  local pv="ENTANDO_FORCE_PROFILE_0e7e8d89_$ENTANDO_TTY_QUALIFIER";
  local phv="ENTANDO_FORCE_PROFILE_HOME_0e7e8d89_$ENTANDO_TTY_QUALIFIER";
  if [[ "$1" =~ --profile=.* ]]; then
    args_or_ask -n -h "$HH" "ENTANDO_USE_PROFILE" "--profile/ext_ic_id//" "$@"
    _set_var "$pv" "$ENTANDO_USE_PROFILE"
    _set_var "$phv" "$ENTANDO_PROFILES/$ENTANDO_USE_PROFILE"
  fi
  
  local pvv phvv
  if [ -n "$ZSH_VERSION" ]; then
    pvv=${(P)pv}
    phvv=${(P)phv}
  else
    pvv=${!pv}
    phvv=${!phv}
  fi
  
  if [[ -n "$pvv" && "$DESIGNATED_PROFILE" != "$pvv" ]]; then
    kubectl_mode --reset-mem 
    DESIGNATED_PROFILE="$pvv"
    # shellcheck disable=SC2034
    DESIGNATED_PROFILE_HOME="$phvv"
    activate_designated_workdir --temporary
  fi
}

# Sets a variable on a template string
# The variable placeholder should respect one of these form:
# - Form #1: {var}
# - Form #2: {/var}
#
# Params:
# $1  the destination var
# $2  the source value
# $3  the var name
# $4  the var value
# $.. params $3,$4 repeated at will
#
_tpl_set_var() {
  local _var_="$1"; shift
  local _tmp_="$1"; shift

  while true; do
    K=$1
    [ -z "$K" ] && break
    shift; V=$1; shift
    _tmp_="${_tmp_//\{${K}\}/${V}}"
    _tmp_="${_tmp_//\{\/${K}\}/\/${V}}"
  done
  _set_var "$_var_" "$_tmp_"
}

# File/dir existsor fatals
#
# Params:
# $1  mode (-f: file, -d: dir)
# $2  file/dir
#
__exist() {
  local where="";[[ "${2:0:1}" != "/" && "${2:0:1}" != "~" ]] && where=" under directory \"$PWD\""
  case "$1" in
    "-f") [ ! -f "$2" ] && _FATAL -S 1 "Unable to find the file \"$2\"$where";;
    "-d") [ ! -d "$2" ] && _FATAL -S 1 "Unable to find the dir \"$2\"$where";;
    *) _FATAL -S 1 "Invalid mode \"$1\"";;
  esac
}

# Removes a directory only if it's marked a disposable
#
__rm_disdir() {
  [ ! -d "$1" ] && _FATAL -S 1 "Not found or not a dir (\"$1\") "
  if [ -f "$1/.entando-disdir" ] || [[ "$1" = *".entando/$C_ENT_PRJ_ENT_DIR/"* ]] ; then
    rm -rf "$1" || _FATAL -S 1 "Unable to delete the dir (\"$1\") "
  else
    _FATAL -S 1 "I won't delete a directory (\"$1\") that is not marked as disposable" 1>&2
  fi
}

# Creates or marks a directory as disposable
#
__mk_disdir() {
  if  [ "$1" != "--mark" ]; then
    mkdir "$1" || _FATAL "Unable to create the dir (\"$1\") "
  else
    shift
    [ ! -d "$1" ] && _FATAL "Not found or not a dir (\"$1\") "
  fi
  touch "$1/.entando-disdir" || _FATAL "Unable to mark the dir (\"$1\") "
}

_sha256sum() {
  if $OS_WIN; then
    sha256sum | cut -d ' ' -f 1
  else
    shasum -a 256 | cut -d ' ' -f 1
  fi
}

_base64_e() {
  perl -e "use MIME::Base64; print encode_base64(<>);" 
}

_base64_d() {
  perl -e "use MIME::Base64; print decode_base64(<>);" 
}

_pkg_get() {
  local VERBOSE=false;[ "$1" = "--verbose" ] && { VERBOSE=true;shift; }
  local pkg="$1" ver="$2" var="" url=""
  case "$pkg" in
    jq)
      var="JQ_PATH";ver="${ver:-1.6}";url="https://github.com/stedolan/jq/releases/download/jq-$ver"
      _pkg_download_and_install "$var" "jq" "$ver" \
        "$url/jq-linux64" "jq-linux64" "" \
        "$url/jq-osx-amd64" "jq-osx-amd64" "" \
        "$url/jq-win64.exe" "jq-win64.exe" "";
      ;;
    k9s)
      var="K9S_PATH";ver="${ver:-v0.25.18}";url="https://github.com/derailed/k9s/releases/download/$ver/"
      _pkg_download_and_install "$var" "k9s" "$ver" \
        "$url/k9s_Linux_x86_64.tar.gz" "k9s" "" \
        "$url/k9s_Darwin_x86_64.tar.gz" "k9s" "" \
        "$url/k9s_Windows_x86_64.tar.gz" "k9s.exe" "";
      ;;
    *)
      _FATAL -s "Unknown package \"$pkg\""
      ;;
  esac
  
  [ -n "$var" ] && {
    $VERBOSE && {
      _log_i "Config var: ${var}"
      _log_i "Location: ${!var}"
    }
    save_cfg_value "$var" "${!var}" "$ENT_DEFAULT_CFG_FILE"
  }
}

_jq() {
  _pkg_jq "$@"
}

_pkg_jq() {
  local CMD; _pkg_get_path CMD "jq"
  "$CMD" "$@"
}

_pkg_ok() {
  local CMD; _pkg_get_path CMD "k9s"
  test -n "$CMD"
}

_pkg_k9s() {
  local CMD; _pkg_get_path CMD "k9s"
  if [ -z "$1" ]; then
    if _nn DESIGNATED_KUBECTX; then
      "$CMD" "$@" --context="$DESIGNATED_KUBECTX" --namespace="$ENTANDO_NAMESPACE"
    elif _nn DESIGNATED_KUBECONFIG; then
      "$CMD" "$@" --kubeconfig="$DESIGNATED_KUBECONFIG" --namespace="$ENTANDO_NAMESPACE"
    else
      "$CMD" "$@" --namespace="$ENTANDO_NAMESPACE"
    fi
  else
    "$CMD" "$@"
  fi
}

_pkg_get_path() {
  local STRICT=false;[ "$1" = "--strict" ] && { STRICT=true;shift; }
  local _tmp_PKGPATH="$(_upper "${2}_PATH")"
  _tmp_PKGPATH="${!_tmp_PKGPATH}"
  if command -v "$_tmp_PKGPATH" &> /dev/null; then
    _set_or_print "$1" "$_tmp_PKGPATH"
    return 0
  elif command -v "$2" &> /dev/null; then
    ! $STRICT && {
      _set_or_print "$1" "$(command -v "$2")"
      return 0
    }
  fi
  _FATAL -s "Package \"$2\" not found" 1>&2
}

_column() {
  if command -v column &>/dev/null; then
    column "$@"
  else
    cat -
  fi
}

_upper() {
  echo "$1" | tr '[:lower:]' '[:upper:]'
}
