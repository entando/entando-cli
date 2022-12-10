#!/bin/bash

_require 's/var-utils.sh'
_require 's/utils.sh'
_require 's/pkg.sh'

#TEST:system,lib,pkg
test_pkg() {
#   [ "$XDEV_TEST_ENABLE_SYSTEM_TESTS" = "true" ] || exit 0
  
  ( _IT "should be able to make available a set of well-known executables"

    ENTANDO_ENT_HOME="$PWD/.entando"
    # shellcheck disable=SC2034
    CFG_FILE="$ENTANDO_ENT_HOME/cfg"
    # shellcheck disable=SC2034
    ENTANDO_BINS="$ENTANDO_ENT_HOME/bin"
    mkdir "$ENTANDO_ENT_HOME"

    _pkg_get "jq"
    _pkg_get "fzf"
    _pkg_get "k9s"
    _pkg_get "crane"

    _pkg_jq --version
    _pkg_fzf --version
    _pkg_k9s version  --short
    _ent.pkg run crane version
  )
}

true
