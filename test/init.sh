#!/bin/bash

PROJECT_DIR="$PWD"

# shellcheck disable=SC1091
. "$PROJECT_DIR/s/essentials.sh"

_require() {
  local SKIP=1;[ "$1" = "-S" ] && { ((SKIP+=$2)); shift 2; }
  \_sys.require -S "$SKIP" "$1"
}

_require "$PROJECT_DIR/s/logger.sh"
_require "$PROJECT_DIR/s/sys-utils.sh"
_require "$PROJECT_DIR/s/verify.sh"

export ENTANDO_OPT_GIT_USER_NAME="test-user"
export ENTANDO_OPT_GIT_USER_EMAIL="test-user@example.com"

_IT() {
  _ESS_TEST_CALLER="$(caller 0)"
  _ESS_TEST_IT="$1"; shift

  local ignored
  # shellcheck disable=SC2034
  read -r ignored fn ignored <<<"$_ESS_TEST_CALLER"
  _xdev.log "It $_ESS_TEST_IT"
  
  _ESS_SILENCE_ERRORS=false
  _ESS_IGNORE_EXITCODE=true
  _ESS_TEST_FAIL_MESSAGE=""
  _ESS_TEST_FAIL_RC=0
  _ESS_IN_TEST_EXIT_TRAP=false
  
  while [ $# -gt 0 ]; do
    case "$1" in
      "SILENCE-ERRORS") _ESS_SILENCE_ERRORS=true;;
      "CHECK-EXITCODE") _ESS_IGNORE_EXITCODE=false;;
    esac
    shift
  done

  TEST_EXIT_TRAP() {
    local rc="$?"

    [ "$_ESS_IN_TEST_EXIT_TRAP" == true ] && return 0
    _ESS_IN_TEST_EXIT_TRAP=true

    [[ "$_ESS_IGNORE_EXITCODE" == "true" && -z "$_ESS_FATAL_EXIT_CODE" ]] && {
      rc=0
      [ "$_ESS_TEST_FAIL_RC" != "0" ] && rc="${_ESS_TEST_FAIL_RC:-0}"
    }

    [ "$rc" != 0 ] && {
      local postmsg=""
      [ "$(_xdev.failures)" = 0 ] && {
        if [ -z "$_ESS_FATAL_EXIT_CODE" ]; then
          postmsg="\n\nNOTE that no explicit test failure was detected, but the test subshell returned error.\n---"
        else
          postmsg="\n\nNOTE that no explicit test failure was detected, but test execution was interrupted by an error.\n---"
        fi
      }
      
      _xdev.test-failed-low-level "$rc" \
        "${_ESS_TEST_CALLER}" "It $_ESS_TEST_IT${_ESS_TEST_FAIL_MESSAGE:+", details: $_ESS_TEST_FAIL_MESSAGE"}$postmsg"
    }
  }
  trap TEST_EXIT_TRAP EXIT
  
  return 0
}

_FAIL() {
  local SKIP=1;[ "$1" = "-S" ] && { ((SKIP+=$2)); shift 2; }
  local STOP=true;[ "$1" = "--and-continue" ] && { STOP=false; shift 1; }
  _ESS_TEST_FAIL_MESSAGE="$*"
  _ESS_TEST_FAIL_RC=99
  _xdev.failures --inc
  (_FATAL -S "${SKIP}" -99 "${_ESS_TEST_FAIL_MESSAGE:-"TEST FAILED"}") 
  $STOP && _exit 99
  return 99
}

_ASSERT_RC() {
  local rc="$?"
  _ASSERT -S 1 -v "EXIT CODE" "$rc" = "$1"
}

DBGSHELL() { :; }

_ASSERT() {
  local SKIP=1;[ "$1" = "-S" ] && { ((SKIP+=$2)); shift 2; }
  (
    _verify.verify-expression -S "$SKIP" "TEST" "$@"
  ) || {
    local rc="$?"
    "${TEST_RUN_DBGSHELL_ON_ASSERT:-false}" && DBGSHELL -S 1
    _xdev.failures --inc
    exit "$rc"
  }
}

_DETERMINE_TEST_RESOURCE_PATH() {
  if [ "$1" = "--relative" ]; then
    local F="$XDEV_FILE_DIR/$2"
  elif [ "$1" = "--global" ]; then
    local F="$PROJECT_DIR/test/resource/$2"
  else
    local F="$XDEV_FILE_DIR/resource/test/$1"
  fi
  [ -f "$F" ] || _FATAL -S 1 "Unable to find test file \"$F\""
  echo "$F"
}

_PRINT_TEST_FILE() {
  cat "$(_DETERMINE_TEST_RESOURCE_PATH "$@")"
}

_LOAD_TEST_FILE() {
  local OPT="";[[ "$1" = "--global" || "$1" = "--relative" ]] && { OPT="$1"; shift; }
  local VAR="$1";shift
  _set_var "$VAR" "$(_PRINT_TEST_FILE ${OPT:+"$OPT"} "$@")"
}

_IMPORT_TEST_RESOURCE() {
  local OPT="";[ "$1" = "--global" ] && { OPT="$1"; shift; }
  mkdir -p "resource"
  if [ "$1" = "--untar" ]; then
    shift
    (
      __cd "resource"
      _log_d "Importing resource $* ($OPT)"
      tar xfz "$(_DETERMINE_TEST_RESOURCE_PATH ${OPT:+"$OPT"} "$@")" 1>/dev/null
    )
  else
    _log_d "Importing resource $* ($OPT)"
    cp "$(_DETERMINE_TEST_RESOURCE_PATH "${OPT:+"$OPT"}" "$@")" "resource"
  fi
}

_TEST_VAR() {
  _xdev.var "$@"
}

_ASSERT_TEST_VAR() {
  local varname="$1";shift
  _ASSERT -v "$varname" "$(_TEST_VAR "$varname")" "$@"
}

export XDEV_TEST_SESSION_DIR
export -f _xdev.var
export -f _TEST_VAR
