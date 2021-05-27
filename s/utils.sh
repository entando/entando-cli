#!/bin/bash
# UTILS

# CFG
WAS_DEVELOP_CHECKED=false

IS_GIT_CREDENTIAL_MANAGER_PRESENT=false
git credential-cache 2> /dev/null
if [ "$?" != 1 ]; then
  IS_GIT_CREDENTIAL_MANAGER_PRESENT=true
fi

if [ -z "$ENTANDO_IS_TTY" ]; then
  perl -e 'print -t 1 ? exit 0 : exit 1;'
  if [ $? -eq 0 ]; then
    ENTANDO_IS_TTY=true
  else
    ENTANDO_IS_TTY=false
  fi
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
    [[ -z "${var// }" ]] && continue
    if assert_ext_ic_id_with_arr "CFGVAR" "$var" "silent"; then
      printf -v sanitized "%q" "$value"
      sanitized="${sanitized/\\r/}"
      sanitized="${sanitized/\\n/}"
      eval "$var"="$sanitized"
    else
      _log_e 0 "Skipped illegal var name $var"
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

# QUITS due to a low level fatal error
#
FATAL() {
  LOGGER() {
    _log_e 0 "FATAL: $*"
  }
  if [ "$1" = "-t" ]; then
    shift
    print_calltrace 1 5 "" LOGGER "$@" 1>&2
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
  if $ENTANDO_IS_TTY; then
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
  fi
}

print_hr() {
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | _perl_sed "s/ /${1:-~}/g"
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
      --help-only) PRINT_HELP=true;JUST_PRINT_HELP=true;shift;;
      --help) PRINT_HELP=true;NEVER_ASK=true;shift;;
      --cmplt) PRINT_COMPLETION_CODE=true;shift;;
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
      echo "${val_name}="
    fi
    return 1
  }

  ! $FLAG && ! $PRESERVE && {
    _set_var "$var_name" ""
  }

  $IS_DEFAULT && [ -z "$1" ] && return 0

  # user provided value
  if $ARG; then                                                                     # POSITIONAL VALUE
    assert_num "the index of position argument" "$val_name" || FATAL -t "Internal Error"
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

simple_shell_completion_handler() {
  if [ "$1" = "--cmplt" ]; then
    shift
    for a in "$@"; do echo "$a"; done
    return 0
  fi
  return 1
}

parse_help_option() {
  # shellcheck disable=SC2124
  local ARG="${!#}"
  local HH

  case "$ARG" in
    "--help") HH="--help" ;;
    "--cmplt") HH="--cmplt" ;;
  esac

  echo "$HH"
}

show_help_option() {
  case "$1" in
    --help)
      echo ""
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
    --cmplt) echo "--help" ;;
  esac
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
      "--help") HH="$1";shift;;
      *) break ;;
    esac
  done
  local res_var_name="$1";shift
  local arg_code_or_num="$1";shift
  local type="${1:-"ext_id"}";shift
  local arg_desc="$1"; shift
  local msg="$1"; shift

  local TMP

  args_or_ask "$PRE" -n -p ${HH:+"$HH"} "TMP" "$arg_code_or_num/$type//$msg" "$@"

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
          TITLES=($(map-list "${src_list}" -k))
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
    _log_i 0 "Current profile info:"
    echo " - PROFILE:           ${THIS_PROFILE:-<NO-PROFILE>}"
  else
    if [ -n "$THIS_PROFILE" ]; then
      _log_i 0 "Currently using profile \"$THIS_PROFILE\"" 1>&2
    else
      _log_i 0 "Currently not using any profile" 1>&2
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
  local JP=""
  
  if [ "$version" = "6.3.0" ]; then
    JP+='{range .items[?(@.metadata.labels.EntandoApp)]}'
    JP+='{"-"}{"\n"}'
    JP+='{.spec.rules[0].host}{"\n"}'
    JP+='{.spec.rules[0].http.paths[0].path}{"\n"}'
    JP+='{.spec.rules[0].http.paths[1].path}{"\n"}'
    JP+='{.spec.rules[0].http.paths[2].path}{"\n"}'
  elif [ "$version" = "6.3.2" ]; then
    JP+='{range .items[?(@.metadata.labels.EntandoApp)]}'
    JP+='{"-"}{.spec.tls}{"\n"}'
    JP+='{.spec.rules[0].host}{"\n"}'
    JP+='{.spec.rules[0].http.paths[?(@.backend.serviceName=="quickstart-server-service")].path}{"\n"}'
    JP+='{.spec.rules[0].http.paths[?(@.backend.serviceName=="quickstart-cm-service")].path}{"\n"}'
    JP+='{.spec.rules[0].http.paths[?(@.backend.serviceName=="quickstart-ab-service")].path}{"\n"}'
    JP+='{.spec.rules[0].http.paths[?(@.backend.service.name=="quickstart-server-service")].path}{"\n"}'
    JP+='{.spec.rules[0].http.paths[?(@.backend.service.name=="quickstart-cm-service")].path}{"\n"}'
    JP+='{.spec.rules[0].http.paths[?(@.backend.service.name=="quickstart-ab-service")].path}{"\n"}'
  else
    FATAL -t "Unsupported version \"$version\""
  fi
  
  local OUT
  stdin_to_arr $'\n\r' OUT < <(_kubectl get ingress -o jsonpath="$JP" 2> /dev/null)
  
  if [ "${OUT[0]}" = "-" ]; then
    _set_var "$res_var_scheme" "http"
  else
    _set_var "$res_var_scheme" "https"
  fi
  local base_url TMP
  path-concat base_url "${base_url}" "${OUT[1]}"
  _set_var "$res_var_svc" ""
  _set_var "$res_var_ecr" ""
  _set_var "$res_var_apb" ""
  [ -n "${OUT[2]}" ] && path-concat -t "$res_var_svc" "${base_url}" "${OUT[2]}"
  [ -n "${OUT[3]}" ] && path-concat -t "$res_var_ecr" "${base_url}" "${OUT[3]}"
  [ -n "${OUT[4]}" ] && path-concat -t "$res_var_apb" "${base_url}" "${OUT[4]}"
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

keycloak-get-token() {
  local res_var="$1"
  shift
  local scheme="$1"
  local auth_url
  auth_url="$(
    _kubectl get ingress -o "custom-columns=NAME:.metadata.name,HOST:.spec.rules[0].host" 2>/dev/null \
      | grep kc-ingress | awk '{print $2}'
  )/auth"
  
  [ -z "$auth_url" ] && FATAL "Unable to determine the IDP auth_url"

  local TOKEN_ENDPOINT
  TOKEN_ENDPOINT="$(curl --insecure -sL "${scheme}://${auth_url}/realms/entando/.well-known/openid-configuration" \
    | jq -r ".token_endpoint")"
  
  [ -z "$ENTANDO_APPNAME" ] && FATAL "Please set the application name"

  #local client_secret_name="${ENTANDO_APPNAME}-server-secret"
  local client_secret_name="${ENTANDO_APPNAME}-de-secret"
  local client_id client_secret tmp
  tmp="$(
    _kubectl get secret "$client_secret_name" -o jsonpath="{.data.clientId}:{.data.clientSecret}" 2> /dev/null
  )"
  client_id="$(echo "$tmp" | cut -d':' -f1)"
  client_secret="$(echo "$tmp" | cut -d':' -f2)"

  [ -z "$client_id" ] && FATAL "Unable to extract the application client secret"

  client_id=$(base64 -d <<< "$client_id")
  client_secret=$(base64 -d <<< "$client_secret")
  
  local TOKEN
  TOKEN="$(curl --insecure -sL "$TOKEN_ENDPOINT" \
    -H "Accept: application/json" \
    -H "Accept-Language: en_US" \
    -u "$client_id:$client_secret" \
    -d "grant_type=client_credentials" \
    | jq -r '.access_token')"

  [[ -z "$TOKEN" || "$TOKEN" == "null" ]] && FATAL "Unable to extract the access token"

  _set_var "$res_var" "$TOKEN"
}

#-----------------------------------------------------------------------------------------------------------------------
# Runs general operation to prepare running actions against the ECR
# $1: the received of the url to use for the action
# $2: the received of the authentication token to use for the action
ecr-prepare-action() {
  local var_url="$1"
  shift
  local var_token="$1"
  shift
  print_current_profile_info
  # shellcheck disable=SC2034
  local main_ingress ecr_ingress ignored url_scheme
  app-get-main-ingresses url_scheme main_ingress ecr_ingress ignored
  [ -z "$main_ingress" ] && FATAL "Unable to determine the main ingress url (s1)"
  [ -z "$ecr_ingress" ] && FATAL "Unable to determine the ecr ingress url (s1)"
  if [ -n "$url_scheme" ]; then
    main_ingress="$url_scheme://$main_ingress"
  else
    case "$FORCE_URL_SCHEME" in
      "http")
        http-get-working-url main_ingress "http://$main_ingress" "https://$main_ingress"
        ;;
      *)
        http-get-working-url main_ingress "https://$main_ingress" "http://$main_ingress"
        ;;
    esac
  fi
  [ -z "$main_ingress" ] && FATAL "Unable to determine the main ingress url (s2)"
  http-get-url-scheme url_scheme "$main_ingress"
  save_cfg_value LATEST_URL_SCHEME "$url_scheme"
  local token
  keycloak-get-token token "$url_scheme"
  _set_var "$var_url" "$url_scheme://$ecr_ingress"
  _set_var "$var_token" "$token"
}

# Runs an ECR action for a bundle given:
# $1: the received of the of the http status
# $2: the http verb
# $3: the action
# $4: the ingress url
# $5: the authentication token
# $6: the bundle id
#
# returns:
# - the http status in $1
# - the http operation output in stdout
#
ecr-bundle-action() {
  local DEBUG=false; [ "$1" == "--debug" ] && DEBUG=true && shift
  local res_var="$1";shift
  local verb="$1";shift
  local action="$1";shift
  local ingress="$1";shift
  local token="$1";shift
  local bundle_id="$1";shift
  local raw_data="$1";shift
  
  local url
  path-concat url "${ingress}" ""
  url+="components"
  
  local http_status OUT

  [ -n "$bundle_id" ] && url+="/$bundle_id"
  [ -n "$action" ] && url+="/$action"

  local OUT="$(mktemp /tmp/ent-auto-XXXXXXXX)"
  
  # shellcheck disable=SC2155
  if "$DEBUG"; then
      local ERR="$(mktemp /tmp/ent-auto-XXXXXXXX)"
      local STATUS="$(mktemp /tmp/ent-auto-XXXXXXXX)"
      curl --insecure -o "$OUT" -sL -w "%{http_code}\n" -X "$verb" -v "$url" \
        -H 'Accept: */*' \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer $token" \
        -H "Origin: ${ingress}" \
        ${raw_data:+--data-raw "$raw_data"} \
        1> "$STATUS" 2> "$ERR"
      
      # shellcheck disable=SC2155 disable=SC2034
      {
        local T_STATUS="$(cat "$STATUS")"
        local T_OUT="$(cat "$OUT")"
        local T_ERR="$(cat "$ERR")"
        trace_vars T_STATUS T_OUT T_ERR
      } > /dev/tty
      
    rm "$STATUS" "$ERR" "$OUT"
    return
  else
    http_status=$(
      curl --insecure -o "$OUT" -sL -w "%{http_code}\n" -X "$verb" -v "$url" \
        -H 'Accept: */*' \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer $token" \
        -H "Origin: ${ingress}" \
        ${raw_data:+--data-raw "$raw_data"} \
        2> /dev/null
    )
  fi
  
  if [ "$res_var" != "%" ]; then
    if [ "$res_var" != "" ]; then
      _set_var "$res_var" "$http_status"
    fi
  else
    if [ "$http_status" -ge 300 ]; then
      echo "%$http_status"
      return 1
    fi
  fi
  
  if [ -s "$OUT" ]; then
    cat "$OUT"
  else
    if [ "$res_var" = "%" ]; then
      echo "%$http_status"
    fi
  fi
  rm "$OUT"
}

# Runs an ECR action for a bundle given:
# $1: the received of the of the http status
# $2: the http verb
ecr-watch-installation-result() {
  local action="$1";shift
  local ingress="$1";shift
  local token="$1";shift
  local bundle_id="$1";shift
  local http_res

  local start_time end_time elapsed
  start_time="$(date -u +%s)"

  echo ""

  while true; do
    http_res=$(
      ecr-bundle-action "%" "GET" "$action" "$ingress" "$token" "$bundle_id"
    )
    
    if [ "${http_res:0:1}" != '%' ]; then
      http_res=$(
        echo "$http_res" | jq -r ".payload.status" 2> /dev/null
      )
  
      end_time="$(date -u +%s)"
      elapsed="$((end_time - start_time))"
      printf "\r                                  \r"
      printf "%4d STATUS: %s.." "$elapsed" "$http_res"
    fi

    case "$http_res" in
      "INSTALL_IN_PROGRESS" | "INSTALL_CREATED" | "UNINSTALL_IN_PROGRESS" | "UNINSTALL_CREATED") ;;
      "INSTALL_COMPLETED")
        echo -e "\nTerminated."
        return 0
        ;;
      "UNINSTALL_COMPLETED")
        echo -e "\nTerminated."
        return 0
        ;;
      "INSTALL_ROLLBACK") ;;
      "INSTALL_ERROR")
        echo -e "\nTerminated."
        return 1
        ;;
      %*)
        echo -e "\nTerminated \"$http_res\""
        return 2
        ;;
      *)
        echo ""
        FATAL "Unknown status \"$http_res\""
        return 99
        ;;
    esac
    sleep 3
  done
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
handle_forced_profile() {
  local pv="ENTANDO_FORCE_PROFILE_0e7e8d89_$ENTANDO_TTY_QUALIFIER";
  local phv="ENTANDO_FORCE_PROFILE_HOME_0e7e8d89_$ENTANDO_TTY_QUALIFIER";
  if [[ "$1" =~ --profile=.* ]]; then
    args_or_ask -n ${HH:+"$HH"} "ENTANDO_USE_PROFILE" "--profile/ext_ic_id//" "$@"
    _set_var "$pv" "$ENTANDO_USE_PROFILE"
    _set_var "$phv" "$ENTANDO_HOME/profiles/$ENTANDO_USE_PROFILE"
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
