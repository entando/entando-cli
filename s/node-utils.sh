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

node.install-node() {
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
    
    if [ -d "$ENT_NODE_DIR" ]; then
      if [ ! -f "$ENT_NODE_DIR/.entando-finalized" ]; then
        __rm_disdir "$ENT_NODE_DIR"
      fi
    fi
  
    if [ ! -d "$ENT_NODE_DIR" ]; then
      rm -rf "./node-$ENT_NODE_VER-linux-x64"
      if [ "$SYS_OS_TYPE" = "windows" ]; then
        (
          tmp="$(mktemp).zip"
          # shellcheck disable=SC2064
          trap "rm \"$tmp\"" exit
          curl "$DOWNLOAD_URL" > "$tmp"
          unzip -q "$tmp"
        ) 
      else
        curl "$DOWNLOAD_URL" | tar xz
      fi
      mv "node-$ENT_NODE_VER-${pathseg_os}-${SYS_CPU_ARCH/x86-64/x64}" "$ENT_NODE_DIR"
    else
      _log_i "The ENT node installation \"$ENT_NODE_DIR\" is already present and so it will be reused"
    fi
    __exist -d "$ENT_NODE_DIR"
    __mk_disdir --mark "$ENT_NODE_DIR"
    date > "$ENT_NODE_DIR/.entando-finalized"
    
    save_cfg_value "ENT_NODE_VER" ""
    save_cfg_value "ENT_NODE_VER" "$ENT_NODE_VER" "$ENT_DEFAULT_CFG_FILE"
    
    true
  ) || exit "$?"

  reload_cfg "$ENT_DEFAULT_CFG_FILE"
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
  
  _ent-npm-init-rc
  
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
  
  ENT_OPTS_ENTANDO="${ENT_OPTS}/entando"
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
  require_develop_checked
  _ent-npm_direct "$@"
}

_ent-npm-init-rc() {
  if [ -d "$ENT_NODE_DIR" ]; then
  (
    _ent-setup_home_env_variables
    D="$ENT_NODE_DIR/etc/"
    F="${D}npmrc"
    mkdir -p "$D"
    echo -n "" > "$F"
    chmod 600 "$F"
    _print_npm_rc >> "$F"
  )
  fi
}

_ent-npm_direct() {
  (
    _ent-setup_home_env_variables
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
  )
}

# Runs the ent private installation of jhipster
_ent-jhipster() {
  if [ "$1" == "--ent-help" ]; then
    echo "Wrapper of the ent-internal installation of jhipster"
    return 0
  fi
  
  node.activate_environment
  if [[ "$1" == "--ent-get-version" || "$1" == "--version" || "$1" == "-V" ]]; then
    _mp_node_exec jhipster -V 2>/dev/null | grep -v INFO
    return 0
  fi
  
  print_entando_banner
  
  require_develop_checked
  [[ ! -f "$C_ENT_PRJ_FILE" ]] && {
    ask "The project dir doesn't seem to be initialized, should I do it now?" "y" && {
      ent-init-project-dir
    }
  }

  # RUN
  _mp_node_exec jhipster "$@"
}

# Executes a node command in any of the sypported platforms
#
_mp_node_exec() {
  local CMD="${ENT_NODE_BINS_NATIVE}/${1}${ENT_NODE_CMDEXT}"; shift
  SYS_CLI_PRE "$CMD" "$@"
}

# Runs the ent private installation of the entando bundle tool
_ent-bundler() {
  if [ "$1" == "--ent-help" ]; then
    echo "Export of resources from a running instance and generation old-generation bundle deployment CRs"
    return 0
  fi
  if [ "$1" == "--help" ]; then
    _ent-run-internal-npm-tool "$C_ENTANDO_BUNDLER_BIN_NAME" --help
    return 0
  fi
  
  print_entando_banner
  
  _ent-run-internal-npm-tool "$C_ENTANDO_BUNDLER_BIN_NAME" "$@"
}

# Runs the ent private installation of the entando-bundle-cli tool
_ent-bundle() {
  case "$1" in
    "--ent-help") echo "Management of new generation entando bundles";return 0;;
    "init") print_entando_banner;;
    "deploy") _ent-bundle-deploy "$@"; return 0;;
    "install") _ent-bundle-install "$@";return 0;;
    "cr") shift;_ent-entando-bundle-cli generate-cr "$@";return 0;;
  esac

  _ent-entando-bundle-cli "$@"
  local rv="$?"
  
  if [[ "$1" = "--help" || -z "$1" ]]; then
    echo "ADDITIONAL COMMANDS"
    echo "  deploy       Generates the CR and deploys it to the currently attached EntandoApp"
    echo "  install      Installs into currently attached EntandoApp the bundle in the current directory"
    echo ""
  fi
  
  return "$rv"
}

_ent-bundle-deploy() {
  ecr.docker.generate-cr \
  | _kubectl apply -f -
}

_ent-bundle-install() {
  local VERSION_TO_INSTALL CONFLICT_STRATEGY
  
  HH="$(parse_help_option "$@")"
  bgn_help_parsing ":bundle-cli-install" "$@"
  args_or_ask -h "$HH" -n VERSION_TO_INSTALL '--version/ver//defines the specific version to install' "$@"
  args_or_ask -h "$HH" -n CONFLICT_STRATEGY \
    '--conflict-strategy///strategy to adopt if the object is already present (CREATE|SKIP|OVERRIDE)' "$@"
  end_help_parsing

  require_develop_checked
  
  local bundle_info="$(ent bundle info)"
  
  ENT_PRJ_NAME="$(
    ent bundle cr | grep "^metadata:" -A 100  | grep "\sname:" | head -n 1 | sed 's/.*:\s*//' | xargs
  )"
  
  _nn ENT_PRJ_NAME || _FATAL "Unable to determine the bundle name"

  if [ -z "$VERSION_TO_INSTALL" ]; then
    VERSION_TO_INSTALL="$(
      grep -i "Version:" <<< "$bundle_info" | head -n 1 | sed 's/.*:\s*//' | xargs
    )"
  fi
  
  ecr.install-bundle "$ENT_PRJ_NAME" "$VERSION_TO_INSTALL" "$CONFLICT_STRATEGY"
}

_ent-entando-bundle-cli() {
  args_or_ask -a -n P1 '1///module' "$@"
  args_or_ask -a -n P2 '2///command' "$@"
  args_or_ask -F -n HELP_INVOKED '--help///help' "$@"

  if [[ "$P1" == "api" && "$P2" == "add-ext" && "$HELP_INVOKED" == "false" ]]; then
    ecr-prepare-action INGRESS_URL TOKEN
    export ENTANDO_CLI_ECR_TOKEN="$TOKEN"
    export ENTANDO_CLI_ECR_URL="$INGRESS_URL"
    export ENTANDO_CLI_BASE_URL="$(_url_remove_last_subpath "$INGRESS_URL")"
  fi
  export ENTANDO_CLI_CRANE_BIN="$CRANE_PATH"
  export ENTANDO_CLI_DOCKER_CONFIG_PATH
  export ENTANDO_BUNDLE_CLI_BIN_NAME

  ENTANDO_CLI_DEBUG="$ENTANDO_ENT_DEBUG" ENTANDO_OPT_OVERRIDE_HOME_VAR="false" \
    _ent-run-internal-npm-tool "$C_ENTANDO_BUNDLE_CLI_BIN_NAME" "$@"
}

# Runs the ent private installation of an internal npm-based entando tool
_ent-run-internal-npm-tool() {
  local TOOL_NAME="$1"; shift
  
  require_develop_checked
  node.activate_environment

  local BIN_PATH
  _ent-npm.get-internal-tool-path BIN_PATH "$TOOL_NAME"

  if [ "$1" == "--ent-get-version" ]; then
    "$BIN_PATH" --version
  else
    # RUN
    if $OS_WIN; then
      if "$SYS_IS_STDIN_A_TTY" && "$SYS_IS_STDOUT_A_TTY"; then
        SYS_CLI_PRE "$BIN_PATH" "$@"
      else
        SYS_CLI_PRE -Xallow-non-tty -Xplain "$BIN_PATH" "$@"
      fi
    else
      if "$SYS_IS_STDIN_A_TTY" && "$SYS_IS_STDOUT_A_TTY"; then
        "$BIN_PATH" "$@"
      else
        "$BIN_PATH" "$@" | _strip_colors
      fi
    fi
  fi
}

_ent-npm.get-internal-tool-path() {
  if $OS_WIN; then
    _set_var "$1" "$ENT_NODE_BINS/${2}.cmd"
  else
    _set_var "$1" "$ENT_NODE_BINS/${2}" "$@"
  fi
}

_ent-npm.delete-internal-tool-bin() {
  local BIN_PATH
  _ent-npm.get-internal-tool-path BIN_PATH "$TOOL_NAME"
  if [[ "$BIN_PATH" = *"/.entando/"* ]]; then
    rm "$BIN_PATH"
  else
    _log_e "Error determining the internal tool path while trying delete it"
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
