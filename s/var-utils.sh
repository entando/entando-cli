#!/bin/bash
# VAR-UTILS

## SET AND CHECKED SETS

# set variable
# - $1: variable to set
# - $2: value
_set_var() {
  if [ -z "$2" ]; then
    read -r -d '' "$1" <<< ""
  else
    read -r -d '' "$1" <<< "$2"
  fi
  return 0
}


_coalesce_vars() {
  read -r -d '' "$1" <<< "$2"; [ -n "${!1}" ] && return 0
  read -r -d '' "$1" <<< "$3"; [ -n "${!1}" ] && return 0
  read -r -d '' "$1" <<< "$4"; [ -n "${!1}" ] && return 0
  read -r -d '' "$1" <<< "$5"; [ -n "${!1}" ] && return 0
}

_print_var() {
  if [ -n "$ZSH_VERSION" ]; then
    echo "${(P)1}"
  else
    echo "${!1}"
  fi
}

# Set of prints a value according with $1 that can be:
# - --print           the value is printed
# - <anything-else>   the value is assigned to the var name in $1
#
_set_or_print() {
  if [ "$1" != "--print" ]; then
    _set_var "$@"
  else
    shift; echo "$@"
  fi
}


# set variable with nonnull value
# - $1: variable to set
# - $2: value
_set_nn() {
  assert_nn "$1" "$2"
  _set_var "$@"
  return 0
}

set_var() {
  _set_var "$@"
  return 0
}

# Tests for non-null a variable given in $1
# If test fails and $2 is also provided the variable is set with $2
#
_nn() {
  test -n "${!1}" && return 0
  test -n "${2}" && _set_var "${1}" "${2}"
  test -n "${!1}"
}

# set variable with nonnull identifier
# - $1: variable to set
# - $2: value
set_nn_id() { assert_id "$1" "$2" && _set_nn "$@"; }

# set variable with nonnull strict identifier
# - $1: variable to set
# - $2: value
set_nn_strict_id() { assert_strict_id "$1" "$2" && _set_nn "$@"; }

# set variable with nonnull domain name
# - $1: variable to set
# - $2: value
set_nn_dn() { assert_dn "$1" "$2" && _set_nn "$@"; }

# set variable with nonnull url
# - $1: variable to set
# - $2: value
set_nn_url() { assert_url "$1" "$2" && _set_nn "$@"; }

# set variable with nonnull full (multilevel) domain name
# - $1: variable to set
# - $2: value
set_nn_fdn() { assert_fdn "$1" "$2" && _set_nn "$@"; }

# set variable with nonnull ip address
# - $1: variable to set
# - $2: value
set_nn_ip() { assert_ip "$1" "$2" && _set_nn "$@"; }

## ASSERTIONS

assert_nn() {
  local pre && [ -n "$XCLP_RUN_CONTEXT" ] && pre="In context \"$XCLP_RUN_CONTEXT\""
  [ -z "$2" ] && [ "$3" != "silent" ] && _log_e "${pre}Value $1 cannot be null" && exit 3
  return 0
}

assert_lit() {
  local pre && [ -n "$XCLP_RUN_CONTEXT" ] && pre="In context \"$XCLP_RUN_CONTEXT\""
  local desc && [ -n "$3" ] && desc=" for $3"
  [ "$1" != "$2" ] && _log_e "${pre}Expected literal \"$1\" found \"$2\"$desc" && exit 3
  return 0
}

assert_any() {
  :;
}

assert_id() {
  _assert_regex_nn "$1" "$2" "^[a-z][a-zA-Z0-9_]*$" "" "identifier" "$3"
}

assert_ext_id() {
  _assert_regex_nn "$1" "$2" "^[a-z][a-zA-Z0-9_-]*$" "" "identifier" "$3"
}

# Like assert_id but case is ignored
assert_ic_id() {
  _assert_regex_nn "$1" "$2" "^[a-zA-Z0-9_]*$" "" "identifier" "$3"
}

assert_ext_ic_id() {
  _assert_regex_nn "$1" "$2" "^[a-zA-Z0-9_-]*$" "" "extended identifier" "$3"
}

assert_ext_ic_id_spc() {
  _assert_regex_nn "$1" "$2" "^[a-zA-Z0-9 _-]*$" "" "extended-identifier-with-spaces" "$3"
}

assert_ext_ic_id_op() {
  _assert_regex_nn "$1" "$2" "^:?[a-zA-Z0-9 _-]*$" "" "extended-identifier-with-spaces" "$3"
}

assert_ext_ic_id_with_arr() {
  _assert_regex_nn "$1" "$2" "^[a-zA-Z0-9_-]*\[?[a-zA-Z0-9_-]*\]?$" "" "identifier" "$3"
}

assert_spc_id() {
  _assert_regex_nn "$1" "$2" "^[a-zA-Z0-9_ ]*$" "" "identifier with spaces" "$3"
}

assert_num() {
  _assert_regex_nn "$1" "$2" "^[0-9]*$" "" "number" "$3"
}

assert_strict_id() {
  _assert_regex_nn "$1" "$2" "^[a-z][a-zA-Z0-9]*$" "" "strict identifier" "$3"
}

assert_dn() {
  _assert_regex_nn "$1" "$2" "^[a-z][a-z0-9_-]*$" "" "single domain name" "$3"
}

assert_url() {
  _assert_regex_nn "$1" "$2" '^(https?|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]' "" "url" "$3"
}

assert_git_repo() {
  _assert_regex_nn "$1" "$2" \
    '^(git|https?|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]' "" "git-url" "$3"
}

assert_email() {
  _assert_regex_nn "$1" "$2" '^[^.]+.*$' "" "email" "$3" || return $?
  _assert_regex_nn "$1" "$2" \
    '^[a-z0-9._-]+@[a-z0-9._-]+\.[a-z0-9._-]+$' \
    '^[a-z0-9._-]+@[a-z0-9._-]+\.[a-z0-9._-]+\.[a-z0-9._-]+$' \
    "email" "$3"
  _assert_regex_nn "$1" "$2" '^[a-z0-9._-]+@[a-z0-9._-]+\.[a-z0-9._-]+$' "" "email" "$3"
}

assert_fdn() {
  _assert_regex_nn "$1" "$2" "\\." "" "full domain" "$3" || return $?
  _assert_regex_nn "$1" "$2" "^([a-z0-9._-])+$" "" "full domain" "$3"
}

assert_strict_file_name() {
  _assert_regex_nn --neg "$1" "$2" '^[.]$' "" "strict file name" "$3"
  _assert_regex_nn --neg "$1" "$2" '^[.][.]' "" "strict file name" "$3"
  _assert_regex_nn "$1" "$2" "^([a-z0-9._-])+$" "" "strict file name" "$3"
}

assert_semver() {
  _assert_regex_nn "$1" "$2" "^v?[0-9]+\.[0-9]+\.[0-9]+$" \
  "^v?[0-9]+\.[0-9]+\.[0-9]+-[a-zA-Z0-9-]+$" "version" "$3"
}

assert_acceptable_version_tag() {
  _assert_regex_nn "$1" "$2" "\\." "" "full domain" "$3" || return $?
  _assert_regex_nn "$1" "$2" "^([a-z0-9._-])+$" "" "full domain" "$3"
}

assert_ver() {
  _assert_regex_nn "$1" "$2" "^v?[0-9.]+-?[a-zA-Z0-9-]+$" "" "version" "$3"
}

assert_ip() {
  _assert_regex_nn "$1" "$2" "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" "" "ip address" "$3"
}

assert_giga() {
  _assert_regex_nn "$1" "$2" "^[0-9]*G$" "" "ip address" "$3"
}

# GENERIC REGEX ASSERTION
# - $1  var name
# - $2  value
# - $3  regex
# - $4  alternative regex
# - $5  var type description
# - $6  if "silent" prints no error
#
# Options:
# --neg negates the regex comparison result
#
_assert_regex_nn() {
  local CMPRES=0;[ "$1" = "--neg" ] && { CMPRES=1;shift; }
  [ "$7" != "" ] && FATAL "[_assert_regex_nn] Internal Error: Invalid function call "
  assert_nn "$1" "$2" "$6"
  local FATAL=false; [ "$6" = "fatal" ] && FATAL=true
  (
    LC_COLLATE=C
    [[ "$2" =~ $3 ]]
    if [ "$?" = "$CMPRES" ]; then
      return 0
    else
      if [[ -n "$4" && "$2" =~ $4 ]]; then
        return 0
      fi
      if $FATAL; then
        local pre && [ -n "$XCLP_RUN_CONTEXT" ] && pre="In context \"$XCLP_RUN_CONTEXT\""
        FATAL "${pre}Value of $1 ($2) is not a valid $5"
      elif [ "$6" != "silent" ]; then
        local pre && [ -n "$XCLP_RUN_CONTEXT" ] && pre="In context \"$XCLP_RUN_CONTEXT\""
        _log_e "${pre}Value of $1 ($2) is not a valid $5"
      fi
      return 1
    fi
  ) || {
    $FATAL && exit $?
  }
}

# FORMAT CHECKERS

is_url() {
  regex='^(https?|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
  [[ $1 =~ $regex ]] && return 0 || return 1
}

# FILES

SET_KV() {
  local FILE K V
  FILE="$1"
  K=$(printf "%q" "$2")
  V=$(printf "%q" "$3")
  _sed_in_place -E "s/(^.*$K\:[[:space:]]*).*$/\1$V/" "$FILE"
  return 0
}

#-----------------------------------------------------------------------------------------------------------------------
# MAP MANAGEMENT FUNCTIONS

map-clear() {
  local arr_var_prefix="__AA_ENTANDO_${1}__"
  shift
  for name in ${!__AA_ENTANDO_*}; do
    if [[ "$name" =~ ^${arr_var_prefix}.* ]]; then
      unset "${name}"
    fi
  done
}

map-count() {
  local arr_var_prefix="__AA_ENTANDO_${1}__"
  shift
  local i=0
  for name in ${!__AA_ENTANDO_*}; do
    if [[ "$name" =~ ^${arr_var_prefix}.* ]]; then
      i=$((i + 1))
    fi
  done
  _set_var "$1" "$i"
  [ "$i" -gt 0 ] && return 0
  return 255
}

map-set() {
  local arr_var_prefix="__AA_ENTANDO_${1}__"
  shift
  local name="${1//-/_DASH_}"
  local address="$2"
  _set_var "${arr_var_prefix}${name}" "$address"
}

map-get() {
  local MAP_NAME="$1"
  local arr_var_prefix="__AA_ENTANDO_${MAP_NAME}__"
  shift
  local name

  if [ "$1" = "--first" ]; then
    shift
    local dst_var_name="$1"
    name="$(map-list "${MAP_NAME}" | head -n 1)"
  else
    local dst_var_name="$1"
    name="$2"
  fi
  local tmp
  tmp="${arr_var_prefix}${name//-/_DASH_}"
  value="${!tmp}"
  _set_var "$dst_var_name" "$value"
  [ -n "$value" ] && return 0
  return 255
}

map-del() {
  local arr_var_prefix="__AA_ENTANDO_${1}__"
  shift
  local name="${1//-/_DASH_}"
  unset "${arr_var_prefix}${name}"
}

# Lists the elements of a map
#
# prints by default only the keys or just the values with "-v" or both if $2 is provided
#
# $1 the map name
# $2 the key/value separator
#
# Options:
# -v  prints only the values
#
# shellcheck disable=SC2120
map-list() {
  local arr_var_prefix="__AA_ENTANDO_${1}__"
  shift
  local SEP="$1"
  local tmp
  for name in ${!__AA_ENTANDO_*}; do
    if [[ "$name" =~ ^${arr_var_prefix}.* ]]; then
      if [ "$SEP" == "-v" ]; then
        echo "${!name}"
      elif [ -z "$SEP" ]; then
        tmp="${name/${arr_var_prefix}/}"
        echo "${tmp//_DASH_/-}"
      else
        tmp="${name/${arr_var_prefix}/}${SEP}${!name}"
        echo "${tmp//_DASH_/-}"
      fi
    fi
  done
}

map-get-keys() {
  local arr_var_prefix="__AA_ENTANDO_${1}__"
  local dst_var_name="$2"
  shift
  local i=0
  for name in ${!__AA_ENTANDO_*}; do
    if [[ "$name" =~ ^${arr_var_prefix}.* ]]; then
      _set_var "dst_var_name[$i]" "$line"
    fi
  done
}

map-save() {
  local arrname="$1"
  shift
  save_cfg_value -m "ENTANDO_${arrname}"
}

map-from-stdin() {
  local arrname="$1"
  local SEP="$2"
  local i=0
  local arr
  IFS="$SEP" read -d '' -r -a arr

  for line in "${arr[@]}"; do
    map-set "$arrname" "$i" "$line"
    ((i++))
  done
}
