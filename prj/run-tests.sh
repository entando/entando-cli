#!/bin/bash

#
# LICENSE: Public Domain
#

XDEV_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
. "$XDEV_SCRIPT_DIR/xdev-lib.sh"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~s~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

RUN() {
  xdev.prepare_test_session
  (
    XDEV_TEST_EXECUTION_LABELS=("$@")
    XDEV_TEST_EXECUTION_LABELS="${XDEV_TEST_EXECUTION_LABELS:-".*"}"
    _xdev.log "Execution labels: ${XDEV_TEST_EXECUTION_LABELS[*]}\n"

    XDEV_TEST.BEFORE_FILE() { :; }
    XDEV_TEST.BEFORE_TEST() { :; }
    XDEV_TEST.AFTER_TEST() { :; }

    _xdev.failures 0
    _xdev.test_already_executed --init
    _xdev.run_custom_test_init "$@"

    # ~~~ LABELS LOOP
    for label in "${XDEV_TEST_EXECUTION_LABELS[@]}"; do

      # ~~~ FILES LOOP
      while read -r file; do
        (
          _xdev.load_test_script "$file"
          _xdev.prepare_test_env
          XDEV_TEST.BEFORE_FILE "$file"

          # ~~~ FUNCTIONS LOOP
          while read -r fn; do
            _xdev.test_is_disabled "$fn" && continue
            _xdev.test_already_executed "$file" "$fn" && continue
            _xdev.print_test_execution "$fn"
            _xdev.run_test "$fn"
            _xdev.handle_test_error "$?"
          done < <(_xdev.list_functions_with_matching_labels "$label" "$file")
        ) || exit "$?"
      done  < <(_xdev.list_files_with_matching_labels "$label")
    done
  )
  _xdev.handle_termination "$?"
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

_xdev.fail_with_code() {
  [ "$1" != "99" ] && _xdev.failures --inc
  _xdev.fatal "$1" "TEST FAILURE DETECTED (EXITCODE: $1)\n";
}

XDEV_TEST.RESET_TLOG() {
  echo "[REM] STARTED AT $(date +'%Y-%m-%d %H-%M-%S')" > "$TEST__TECHNICAL_LOG_FILE"
}

xdev.prepare_test_session() {
  XDEV_TEST_SESSION_DIR="$(mktemp -d)"
  touch "$XDEV_TEST_SESSION_DIR/.effimeral-test-dir"
  _xdev._test-session-cleanup() { [ -f "$XDEV_TEST_SESSION_DIR/.effimeral-test-dir" ] && rm -rf "$XDEV_TEST_SESSION_DIR"; }
  trap _xdev._test-session-cleanup exit
}

_xdev.prepare_test_env() {
  XDEV_TEST_WORK_DIR="$XDEV_TEST_SESSION_DIR/workdir"
  mkdir "$XDEV_TEST_WORK_DIR"
  _xdev._test-cleanup() { [ -f "$XDEV_TEST_WORK_DIR/.effimeral-test-dir" ] && rm -rf "$XDEV_TEST_WORK_DIR"; }
  trap _xdev._test-cleanup exit

  cd "$XDEV_TEST_WORK_DIR"
  touch "$XDEV_TEST_WORK_DIR/.effimeral-test-dir"
  [ -d "$XDEV_PROJECT_TEST_DIR/resources/" ] && cp -ra "$XDEV_PROJECT_TEST_DIR/resources/" "./resources"
  cd "$XDEV_TEST_WORK_DIR" || _xdev.fatal 1 "Unable to enter test dir"
}

export XDEV_TEST_EXECUTION=true


type XDEV_TEST.BEFORE_RUN &>/dev/null && XDEV_TEST.BEFORE_RUN

[ -t 0 ] && XDEV_STDIN_IS_TTY=false || XDEV_IN_STDIN_IS_TTY=true
[ -t 1 ] && XDEV_STDOUT_IS_TTY=false || XDEV_STDOUT_STDIN_IS_TTY=true


_xdev.list_files_with_matching_labels() {
  (
    if [ "$XDEV_PROJECT_TEST_DIR" = "." ]; then
      XDEV_PROJECT_TEST_DIR="$PWD"
    fi
    while read -r dir; do
      grep -lr "^#TEST:\(.*,\)\?$1\(,.*\)\?\$" "$dir"
    done < <(_xdev.list-src-files "$XDEV_SRC")
  )
}

_xdev.list_functions_with_matching_labels() {
  grep -A 1 "TEST:\(.*,\)\?$1\(,.*\)\?\$" "$XDEV_BASE_DIR/$2" | sed 's/().*//'
}

_xdev.print_test_execution() {
  _xdev.log --no-prefix ''
  _xdev.log --no-prefix '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
  _xdev.log --no-prefix '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
  _xdev.log "RUNNING TEST \"$1\""
  echo ""
}

_xdev.test_is_disabled() {
  [[ "${1:0:1}" = "#" || "${1:0:2}" = "--" ]]
}

_xdev.test_already_executed() {
  local FF="$XDEV_TEST_SESSION_DIR/executed.log"
  if [ "$1" = "--init" ]; then
    echo -n "" > "$FF"
  else
    grep -c "<$file/$fn>" "$FF" 1>/dev/null && return 0
    echo "<$file/$fn>" >> "$FF"
  fi
  return 1
}

_xdev.run_custom_test_init() {
  [ -f "$XDEV_PROJECT_TEST_DIR/init.sh" ] && . "$XDEV_PROJECT_TEST_DIR/init.sh" "$@"
}

_xdev.load_test_script() {
  local file="$1"
  [ "${file:0:2}" = "./" ] && file="$XDEV_BASE_DIR/${file:2}"
  XDEV_FILE_DIR="$(dirname "$file")"
  . $file;
}

_xdev.failures() {
  _xdev.var "failures" "$@"
}

_xdev.var() {
  local VN="$1";shift
  local FF="$XDEV_TEST_SESSION_DIR/$VN.var"
  
  if [ "$1" == "--inc" ]; then
    local tmp="$(_xdev.var "$VN")"
    _xdev.var "$VN" "$((tmp+1))"
  elif [ -n "$1" ]; then
    echo "$1" > "$FF"
  else
    cat "$FF"
  fi
}

_xdev.run_test() {
  (
    echo "BEFORE" > "$XDEV_TEST_WORK_DIR/.xdev-test-state"
    XDEV_TEST.BEFORE_TEST "$1" || exit "$?"
    rm -f "$XDEV_TEST_WORK_DIR/.xdev-test-state"
    ("$1" || true) || return "$?"  # expected to fail with an explicit interruption
    echo "AFTER" > "$XDEV_TEST_WORK_DIR/.xdev-test-state"
    XDEV_TEST.AFTER_TEST "$1"
  )
}

_xdev.handle_test_error() {
  local rc="$1"
  [ "$rc" = "0" ] && return 0

  if [ -f "$XDEV_TEST_WORK_DIR/.xdev-test-state" ]; then
    local rc="$(cat "$XDEV_TEST_WORK_DIR/.xdev-test-state")"
    rm -f "$XDEV_TEST_WORK_DIR/.xdev-test-state"
  fi

  case "$rc" in
    "BEFORE") _xdev.fatal 71 "BEFORE_TEST hook failed";;
    "AFTER") echo ""; _xdev.log "AFTER_TEST hook failed (IGNORED)"; echo "";;
    *) _xdev.fail_with_code "$rc"
  esac

  return 0
}

_xdev.handle_termination() {
  local exit_code="$1"
  local failures="$(_xdev.failures)"

  if [[ "$exit_code" = "0" && "$failures" = "0" ]]; then
    echo ""
    _xdev.log "Tests execution completed SUCCESSFULLY."
    echo ""
  else
    echo ""
    _xdev.log -e "Tests execution terminated with ERRORS (XC:${exit_code}|FC:${failures})."
    [ "$exit_code" = "0" ] && exit_code="99"
    echo ""
  fi
  return "$exit_code"
}

_xdev.test-failed() {
  local skip="$1"; shift
  local rc="$2"; shift
  _xdev.test-failed-low-level "$rc" "$(caller "$skip")" "$@"
  echo ""
}

_xdev.test-failed-low-level() {
  local rc="$1"; shift
  local caller="$1"; shift
  read -r line fn file <<<"$caller"
  [ "$rc" != "99" ] && _xdev.failures --inc
  _xdev.fatal "$rc" "Test failed${rc:+" with exit code \"$rc\""} in $file on line $line with error message:\n$*"
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

if [ "$1" == "--base-dir" ]; then
  cd "$2"
  shift 2
fi

XDEV_BASE_DIR="$PWD"

_xdev.ensure-project-type "sh"

XDEV_SRC=$(_xdev.get-config "XDEV_SRC")
XDEV_TEST_FOLDER="$(_xdev.get-config "XDEV_TEST_FOLDER" ".")"

XDEV_PROJECT_SRC_DIR="$(_xdev.get-config "XDEV_PROJECT_SRC_DIR" "$PWD")"
XDEV_PROJECT_TEST_DIR="$(_xdev.get-config "XDEV_PROJECT_SRC_DIR" "$PWD/$XDEV_TEST_FOLDER")"

(cd "$XDEV_PROJECT_SRC_DIR") || _xdev.fatal 1 "Unable to enter project dir"
(cd "$XDEV_PROJECT_TEST_DIR") || _xdev.fatal 1 "Unable to enter test dir"

RUN "$@"
