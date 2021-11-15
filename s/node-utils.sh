#!/bin/bash
# NODE TOOLS

node.reset_environment() {
  ENT_NODE_VER=""         # the version of node (for the current ent instance)
  ENT_NODE_DIR=""         # the path of the node base dir (for the current ent instance)
  ENT_NODE_BINS=""        # the path of the bide binaries dir (for the current ent instance)
  ENT_NODE_MODS=""        # the path of the node modules dir (for the current ent instance)
  ENT_NODE_BIN_NATIVE=""  # the os-native path of the node binary (for the current ent instance)
  ENT_NPM_BIN_NATIVE=""   # the os-native path of the npm binary (for the current ent instance)
  NODE_PATH=""            # the node base path standard variable
}

node.install() {
  (
    # shellcheck disable=SC2030
    ENT_NODE_VER="$1"
    NONNULL ENT_NODE_VER
    
    ENT_NODE_DIR="node-$ENT_NODE_VER"
    
    __cd "$ENT_OPTS"
    
    local pathseg_os="${SYS_OS_TYPE/windows/win}"
    
    _tpl_set_var DOWNLOAD_URL "$URL_NODE_JS_DIST_ADDR" \
      NODE_VER "$ENT_NODE_VER" \
      OS "$pathseg_os" \
      ARCH "${SYS_CPU_ARCH/x86-64/x64}" \
      EXT "${C_DEF_ARCHIVE_FORMAT}" \
    ;
    
    if [ ! -d "$ENT_NODE_DIR" ]; then
      rm -rf "./node-$ENT_NODE_VER-linux-x64"
      if [ "$SYS_OS_TYPE" = "windows" ]; then
        (
          tmp="$(mktemp).zip"
          # shellcheck disable=SC2064
          trap "rm \"$tmp\"" exit
          curl "$DOWNLOAD_URL" > "$tmp"
          unzip "$tmp"
        ) 
      else
        curl "$DOWNLOAD_URL" | tar xz
      fi
      mv "node-$ENT_NODE_VER-${pathseg_os}-${SYS_CPU_ARCH/x86-64/x64}" "$ENT_NODE_DIR"
    else
      _log_i 0 "ENT node dir \"$ENT_NODE_DIR\" is already present and so it will be reused"
    fi
    __exist -d "$ENT_NODE_DIR"
    __mk_disdir --mark "$ENT_NODE_DIR"
    
    save_cfg_value "ENT_NODE_VER" "$ENT_NODE_VER"
    
    true
  ) || exit "$?"

  reload_cfg
  node.activate_environment
  
  __exist -f "$ENT_NODE_BIN_NATIVE"
  __exist -f "$ENT_NPM_BIN_NATIVE"
}

# Activates the private node environment
#
node.activate_environment() {
  # shellcheck disable=SC2031
  ENT_NODE_DIR="$ENT_OPTS/node-$ENT_NODE_VER"
  # shellcheck disable=SC2154
  export PATH="$PATH:${sENT_NODE_DIR}bin"
  
  case "$SYS_OS_TYPE" in
    windows)
      ENT_NODE_CMDEXT=".cmd"
      ENT_NODE_BINS="$ENT_NODE_DIR"
      ENT_NODE_MODS="${ENT_NODE_DIR}/node_modules"
      ENT_NODE_BINS_NATIVE="$(win_convert_existing_posix_path_to_win_path "$ENT_NODE_BINS")"
      ENT_NODE_BIN_NATIVE="${ENT_NODE_BINS_NATIVE}/node.exe"
      ENT_NPM_BIN_NATIVE="${ENT_NODE_BINS_NATIVE}/npm.cmd"
      ;;
    *)
      ENT_NODE_CMDEXT=""
      ENT_NODE_BINS="${ENT_NODE_DIR}/bin"
      ENT_NODE_MODS="${ENT_NODE_DIR}/lib/node_modules"
      ENT_NODE_BINS_NATIVE="$ENT_NODE_BINS"
      ENT_NODE_BIN_NATIVE="${ENT_NODE_BINS}/node"
      ENT_NPM_BIN_NATIVE="${ENT_NODE_BINS}/npm"
      ;;
  esac
  
  ENT_NODE_ENTANDO="${ENT_OPTS}/entando"
  PATH="$ENT_NODE_BINS:$PATH"
}

# Imports a module from the entando private npm modules
# the the given mode_modules dir
#
_ent-npm--import-module-to-current-dir() {
  _ent-npm install "${ENT_NODE_MODS}/$1/$2"
}

_ent-node() {
  activate_shell_login_environment
  node.activate_environment
  "$ENT_NODE_BIN_NATIVE" "$@"
}

_ent-npm() {
  activate_shell_login_environment
  node.activate_environment
  
  local GLOBAL=false
  args_or_ask -p -F GLOBAL "--global" "$@"
  args_or_ask -p -F GLOBAL "-g" "$@"
  if $GLOBAL; then
    "$ENT_NPM_BIN_NATIVE" --prefix "$ENT_NODE_DIR" "$@"
  else
    "$ENT_NPM_BIN_NATIVE" "$@"
  fi
}

# Run the ent private installation of jhipster
_ent-jhipster() {
  require_develop_checked
  node.activate_environment
  if [ "$1" == "--ent-get-version" ]; then
    _mp_node_exec jhipster -V 2>/dev/null | grep -v INFO
  else
    [[ ! -f "$C_ENT_PRJ_FILE" ]] && {
      ask "The project dir doesn't seem to be initialized, should I do it now?" "y" && {
        ent-init-project-dir
      }
    }

    # RUN
    _mp_node_exec jhipster "$@"
  fi
}

# Executes a node command in any of the sypported platforms
#
_mp_node_exec() {
  local CMD="${ENT_NODE_BINS_NATIVE}/${1}${ENT_NODE_CMDEXT}"; shift
  SYS_CLI_PRE "$CMD" "$@"
}

# Run the ent private installation of the entando bundle tool
_ent-bundler() {
  node.activate_environment
  if [ "$1" == "--ent-get-version" ]; then
    if $OS_WIN; then
      "$ENT_NODE_BINS/$C_ENTANDO_BUNDLE_BIN_NAME.cmd" --version
    else
      "$ENT_NODE_BINS/$C_ENTANDO_BUNDLE_BIN_NAME" --version
    fi
  else
    require_develop_checked
    node.activate_environment
    # RUN
    if $OS_WIN; then
      if "$SYS_IS_STDIN_A_TTY" && "$SYS_IS_STDOUT_A_TTY"; then
        SYS_CLI_PRE "$ENT_NODE_BINS/$C_ENTANDO_BUNDLE_BIN_NAME.cmd" "$@"
      else
        "$ENT_NODE_BINS/$C_ENTANDO_BUNDLE_BIN_NAME" "$@" | _strip_colors
      fi
    else
      if "$SYS_IS_STDIN_A_TTY" && "$SYS_IS_STDOUT_A_TTY"; then
        "$ENT_NODE_BINS/$C_ENTANDO_BUNDLE_BIN_NAME" "$@"
      else
        "$ENT_NODE_BINS/$C_ENTANDO_BUNDLE_BIN_NAME" "$@" | _strip_colors
      fi
    fi
  fi
}

node.command_wrapper() {
  CMD="$1"
  H() { echo -e "$2"; }
  shift 2
  [[ "$1" = "--help" && "$2" == "--short" ]] && H && exit 0
  [ "$1" = "--cmplt" ] && exit 0

  WD="$PWD"
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
  cd "$DIR/../.." || {
    echo "Internal error: unable to find the script source dir" 1>&2
    exit
  }
  . s/_base.sh

  cd "$WD" || _FATAL "Unable to access the current dir: $WD"
  _ent-npm "$@"
}

node.reset_environment

return 0
