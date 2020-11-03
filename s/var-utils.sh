# VAR-UTILS

## SET AND CHECKED SETS

# set variable
# - $1: variable to set
# - $2: value
_set_var() {
  local V
  if [ -z "$2" ]; then
    eval "$1=''"
  else
    V=$(printf "%q" "$2")
    eval "$1=$V"
  fi
  return 0
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
  [ -z "$2" ] && [ "$3" != "silent" ] && _log_e 0 "${pre}Value $1 cannot be null" && exit 3
  return 0
}

assert_lit() {
  local pre && [ ! -z "$XCLP_RUN_CONTEXT" ] && pre="In context \"$XCLP_RUN_CONTEXT\""
  local desc && [ ! -z "$3" ] && desc=" for $3"
  [ "$1" != "$2" ] && _log_e 0 "${pre}Expected literal \"$1\" found \"$2\"$desc" && exit 3
  return 0
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
  _assert_regex_nn "$1" "$2" "^[a-zA-Z0-9_-]*$" "" "identifier" "$3"
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

assert_ver() {
  _assert_regex_nn "$1" "$2" "^v?[0-9.]+-?[a-zA-Z0-9-]+$" "" "version" "$3"
}

assert_ip() {
  _assert_regex_nn "$1" "$2" "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" "" "ip address" "$3"
}

# GENERIC REGEX ASSERTION
# - $1  var name
# - $2  value
# - $3  regex
# - $4  alternative regex
# - $5  var type description
# - $6  if "silent" prints no error
_assert_regex_nn() {
  [ "$7" != "" ] && FATAL "[_assert_regex_nn] Internal Error: Invalid function call "
  assert_nn "$1" "$2" "$6"
  if [[ "$2" =~ $3 ]]; then
    return 0
  else
    if [[ -n "$4" && "$2" =~ $4 ]]; then
      return 0
    fi
    if [ "$6" != "silent" ]; then
      local pre && [ -n "$XCLP_RUN_CONTEXT" ] && pre="In context \"$XCLP_RUN_CONTEXT\""
      _log_e 0 "${pre}Value of $1 ($2) is not a valid $5"
    fi
    return 1
  fi
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
  sed --in-place='' -E "s/(^.*$K\:[[:space:]]*).*$/\1$V/" "$FILE"
  return 0
}
