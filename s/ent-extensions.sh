#!/bin/bash

_require 's/essentials.sh'
_require 's/var-utils.sh'
_require 's/utils.sh'

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ent-load-extension-module() {
  (
    local REPO NAME BRANCH
    args_or_ask -h "$HH" -a -n -- REPO '1/git_repo//%sp repository of the module' "$@"
    args_or_ask -h "$HH" -n -- NAME '--name/strict_file_name//%sp name of the module' "$@"
    args_or_ask -h "$HH" -n -- BRANCH '--branch/dn//%sp branch to use instead of the default one' "$@"
    end_help_parsing

    DIRNAME="$(basename "$REPO")"
    [ -z "$NAME" ] && NAME="$DIRNAME"

    local EXT_DIR="${ENTANDO_ENT_HOME}/bin/mod/ext"
    mkdir -p "$EXT_DIR"
    __cd "$EXT_DIR"
    if [[ "$PWD" = *".entando"* ]]; then
      [ -d "$DIRNAME" ] && rm -rf "$DIRNAME"
      git clone --depth=1 ${BRANCH:+-b "$BRANCH"} --single-branch "$REPO"
      cp -p -- "$PWD/$DIRNAME/mod/"* .
    else
      _FATAL "Extension module cleanup: Refusing to delete a non entando-cli dir"
    fi
  )
}
