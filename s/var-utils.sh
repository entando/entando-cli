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
  local pre && [ ! -z "$XCLP_RUN_CONTEXT" ] && pre="In context \"$XCLP_RUN_CONTEXT\""
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
  _assert_regex_nn "$1" "$2" "^[a-z][a-zA-Z0-9_]*$" "identifier" "$3"
}

assert_spc_id() {
  _assert_regex_nn "$1" "$2" "^[a-zA-Z0-9_ ]*$" "identifier with spaces" "$3"
}

assert_num() {
  _assert_regex_nn "$1" "$2" "^[0-9]*$" "number" "$3"
}

assert_strict_id() {
  _assert_regex_nn "$1" "$2" "^[a-z][a-zA-Z0-9]*$" "strict identifier" "$3"
}

assert_dn() {
  _assert_regex_nn "$1" "$2" "^[a-z][a-z0-9_-]*$" "domain name" "$3"
}

assert_url() {
  _assert_regex_nn "$1" "$2" '^(https?|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]' "url" "$3"
}

assert_email() {
  _assert_regex_nn "$1" "$2" '^[^@\s]+@[^@\s\.]+\.[^@\.\s]+$' "email" "$3"
}

assert_fdn() {
  _assert_regex_nn "$1" "$2" "^[.a-z0-9_-]*$" "full domain" "$3"
}

assert_ip() {
  _assert_regex_nn "$1" "$2" "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" "ip address" "$3"
}

# GENERIC REGEX ASSERTION
# - $1  var name
# - $2  value
# - $3  regex
# - $4  var type description
# - $5  if "silent" prints no error
_assert_regex_nn() {
  [ "$6" != "" ] && FATAL "Internal Error: Invalid function call"
  assert_nn "$1" "$2" "$5"
  if [[ "$2" =~ $3 ]]; then
    return 0
  else
    if [ "$5" != "silent" ]; then
      local pre && [ ! -z "$XCLP_RUN_CONTEXT" ] && pre="In context \"$XCLP_RUN_CONTEXT\""
      _log_e 0 "${pre}Value of $1 ($2) is not a valid $4"
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
