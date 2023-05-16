#!/bin/bash

_require 's/var-utils.sh'
_require 's/utils.sh'
_require 's/node-utils.sh'

XDEV_TEST.BEFORE_FILE() {
  # shellcheck disable=SC2034
  ENT_NODE_BINS="$PWD/workdir/bin"
  # shellcheck disable=SC2034
  WAS_DEVELOP_CHECKED=true;
  # shellcheck disable=SC2034
  SYS_IS_STDOUT_A_TTY=true;
  mkdir -p workdir/bin
  cp "$PROJECT_DIR"/res/test-fail workdir/bin/test-fail
  cp "$PROJECT_DIR"/res/test-success workdir/bin/test-success
  node.activate_environment() { :; }
}

#TEST:unit,lib,ent_run_internal_npm_tool
test_ent_run_internal_npm_tool() {

  # shellcheck disable=SC2034
  SYS_IS_STDIN_A_TTY=false  

  ( _IT "should propagate the error code if npm tool fails when STDIN is not TTY"
    _ent-run-internal-npm-tool "test-fail"
    _ASSERT_RC 37
  ) 

  ( _IT "should return the exit code of success if npm tool works successfully when STDIN is not TTY"
    _ent-run-internal-npm-tool "test-success"
    _ASSERT_RC 0
  )

  # shellcheck disable=SC2034
  SYS_IS_STDIN_A_TTY=true

  ( _IT "should propagate the error code if npm tool fails when STDIN is TTY"
    _ent-run-internal-npm-tool "test-fail"
    _ASSERT_RC 37
  )

  ( _IT "should return the exit code of success if npm tool works successfully when STDIN is TTY"
    _ent-run-internal-npm-tool "test-success"
    _ASSERT_RC 0
  )

}