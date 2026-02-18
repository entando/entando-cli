#!/bin/bash

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

which_ent() {
  case "$1" in
    version) echo "${ENTANDO_CLI_VERSION}"; return;;
    which) echo "${ENTANDO_CLI_VERSION}";;
    home) echo "$ENTANDO_ENT_HOME"; return;;
  esac
  
  (
    echo ""
    echo "---"
    echo ""
    
    # CLI INFO
    echo "## CLI:"
    echo ""
    __cd "$ENTANDO_ENT_HOME"
    echo "- DIR: $ENTANDO_ENT_HOME"
    IFS='|' read -r sha time < <(git log --pretty=format:'%H|%ci' -1)
    echo "- SHA: $sha"
    echo "- UPD: $time"
    echo ""
    
    # RELEASE INFO
    __cd "$(_dist_directory)"
    echo "## RELEASE:"
    echo ""
    echo "- DIR: $PWD"
    IFS='|' read -r sha time < <(git log --pretty=format:'%H|%ci' -1)
    echo "- SHA: $sha"
    echo "- UPD: $time"
    echo ""
    
  ) 1>&2
}

handle_config_command() {
  bgn_help_parsing "${BASH_SOURCE[0]}" "$@"

  args_or_ask -a -n -h "$HH" CFG_KEY "1///the config key" "$@"
  args_or_ask -a -n -h "$HH" CFG_VALUE "2///the value to set" "$@"
  OPT_EXPORT=""
  args_or_ask -h "$HH" -f -- "--export///also export config key as variable" "$@" && {
    OPT_EXPORT="-e"
  }
  
  args_or_ask -h "$HH" -f -- '--default///selects the default ent configuration' "$@" && {
    # shellcheck disable=SC2034
    CFG_FILE="$ENT_DEFAULT_CFG_FILE"
    ENT_WORK_DIR="${ENTANDO_ENT_HOME}/w"
    THIS_PROFILE=""
  }
  args_or_ask -h "$HH" -f -- '--global///selects the global ent configuration' "$@" && {
    CFG_FILE="$ENTANDO_GLOBAL_CFG"
    # shellcheck disable=SC2034
    ENT_WORK_DIR="${ENTANDO_ENT_HOME}/w"
    THIS_PROFILE=""
  }

  args_or_ask -h "$HH" -F ENTANDO_NO_OBFUSCATION '--no-obfuscation///disables the obfuscation in the effective configuration' "$@"
  args_or_ask -h "$HH" -f -- '--effective///prints the effective configuration' "$@" && {
    print-effective-config
    return 0
  }

  args_or_ask -h "$HH" -f -- '--edit///edits the configuration' "$@" && {
    _edit "$CFG_FILE"
    return 0
  }
  
  args_or_ask -h "$HH" -f -- '--set///sets a specific configuration parameter' "$@" && {
    args_or_ask -a -h "$HH" "CFG_KEY" "1///%sp the config key" "$@"
    args_or_ask -a -n -h "$HH" "CFG_VALUE" "2///%sp the value to set" "$@"
    save_cfg_value $OPT_EXPORT "$CFG_KEY" "$CFG_VALUE" "$CFG_FILE" "$DO_EXPORT"
    return 0
  }
  
  args_or_ask -h "$HH" -f -- '--del///deletes a specific configuration parameter' "$@" && {
    args_or_ask -a -h "$HH" "CFG_KEY" "1///%sp the config key" "$@"
    save_cfg_value "$CFG_KEY" "" "$CFG_FILE"
    return 0
  }
  
  args_or_ask -h "$HH" -f -- '--get///gets a specific configuration parameter' "$@" && {
    args_or_ask -a -h "$HH" "CFG_KEY" "1///%sp the config key" "$@"
    print_cfg_value "$CFG_KEY" "$CFG_FILE"
    return 0
  }
  end_help_parsing
  
  if [ -n "$CFG_KEY" ]; then
    if [ -n "$CFG_VALUE" ]; then
      save_cfg_value $OPT_EXPORT "$CFG_KEY" "$CFG_VALUE" "$CFG_FILE"
    else
      print_cfg_value "$CFG_KEY" "$CFG_FILE"
    fi
  else
    print_config_file
  fi
}

print_config_file() {
  if [ -n "$THIS_PROFILE" ]; then
    _log_i "Configuration of the profile \"$THIS_PROFILE\" ($CFG_FILE):" 1>&2
  else
    _log_i "Default configuration of the current entando distribution ($CFG_FILE):" 1>&2
  fi
  
  [ -f "$CFG_FILE" ] || _FATAL -s "Configuration file \"$CFG_FILE\" not found"
  cat "$CFG_FILE"
  print-secrets-leak-warning
}

handle_appname() {
  bgn_help_parsing "${BASH_SOURCE[0]}" "$@"
  args_or_ask -h "$HH" -a -n -- APPNAME '1///%sp the EntandoApp name' "$@"
  if [ -z "$APPNAME" ]; then
    args_or_ask -h "$HH" -n -f -- '--auto///%sp tries to auto-discover the EntandoApp name by checking the namespace' "$@" && {
      # shellcheck disable=SC2034
      ENTANDO_APPNAME=":auto"
      kube.discover-and-set-app-name-if-needed
      exit 0
    }
  fi
  end_help_parsing
  
  handle_status_config ENTANDO_APPNAME "$APPNAME"
}

handle_status_config() {
  if [ "$V"  = "--del" ]; then
    ent config --set ""
  else
    V="$2"
    [ "$V" == "--" ] && V="$3"
    if [ "$V"  = "" ]; then
      ent config --get "$1"
    else
      ent config --set "$1" "$V"
    fi
  fi
}

handle_kubectl_cmd() {
  if [ "$1"  = "" ]; then
    ent config --get "ENT_KUBECTL_CMD"
  else
    ent kubectl ent-set-cmd "$@"
  fi
}

upgrade_project_file() {
  local N=$1
  local O=$2
  if [ -f "$O" ]; then
    mkdir -p "$C_ENT_PRJ_ENT_DIR"
    if [ -f "$N" ]; then
      mv "$O" "$C_ENT_PRJ_ENT_DIR/$O.backup"
    else
      mv "$O" "$N"
    fi 
  fi
}

ent-trace() {
  [ "$1" == "--reset" ] && { shift;CTRACE="\\"; }
  KEY="$1"
  if [ -z "${KEY}" ]; then
    true
  elif [ "${KEY:0:1}" == "-" ]; then
    KEY="${KEY:1:200}"
    CTRACE="${CTRACE//\\$KEY\\/\\}"
    ent config --set CTRACE "${CTRACE}"
  else
    [ "${KEY:0:1}" == "+" ] && KEY="${KEY:1:200}"
    
    if [[ ! "$CTRACE" = *"\\$KEY\\"* ]]; then
      CTRACE="${CTRACE}\\${KEY}\\"
    fi
  fi

  ent config --set CTRACE "${CTRACE}"
  save_cfg_value "CTRACE" "$CTRACE"
  reload_cfg

  _log_i "Current CTRACE: \"$CTRACE\""
}

cmplt() {
  cd "$ENTANDO_ENT_HOME/bin/mod" || {
    echo "Unable to enter directory $PWD/bin"
    exit 99
  }
  for file in ent-*; do
    mod="${file//ent-/}"
    echo "$mod"
  done

  [ -z "$ENTANDO_ENT_EXTENSIONS_MODULES_PATH" ] && ENTANDO_ENT_EXTENSIONS_MODULES_PATH="$ENTANDO_ENT_HOME/bin/mod/ext"
  if [ -d "$ENTANDO_ENT_EXTENSIONS_MODULES_PATH" ]; then
  (
    cd "$ENTANDO_ENT_EXTENSIONS_MODULES_PATH" || exit 0
    for file in ent-*; do
      [ -f "$file" ] && {
        mod="${file//ent-/}"
        echo "$mod"
      }
    done
  )
  fi

  local topcmd+=(
    "attach-vm" "detach-vm" "fix-vm-ddns" "completion" "config" "which" "version" "home" "import" "activate"
      "kubectl-cmd" "reset-kubectl-mode" "status"
      "attach-kubeconfig" "detach-kubeconfig" "namespace" "appname" "pkg"
      "attach-kubectx" "detach-kubectx" "list-kubectx"
      "bundle" "bundler" "jhipster" "shell"
  )

  for tc in "${topcmd[@]}"; do
    echo "$tc"
  done
}

_ent() {
  # shellcheck disable=SC1090
  "$ENTANDO_ENT_HOME/bin/ent" "$@"
}

_source_ent() {
  # shellcheck disable=SC1090 disable=SC1091
  source "$ENTANDO_ENT_HOME/bin/ent" "$@"
}

_execute_script() {
  local RV="33"
  local cmd="$1";shift
  local IS_HELP IS_CMPLT
  args_or_ask -h "" -F IS_HELP "--help" "$@"
  args_or_ask -h "" -F IS_CMPLT "--cmplt" "$@"
  
  if $IS_HELP || $IS_CMPLT; then
    r() { cat -; }; $IS_HELP && r() { cat - 1>&2; }
    {
      (_execute_script_native "$@")
      _execute_script_extension "$@"
      RV="$?"
      $IS_HELP && echo ""
    } | r
    RV=0
  else
    _execute_script_extension "$@"
    RV="$?"
    [[ "$RV" != "33" && "$RV" != "34" ]] && return "$RV"
    _execute_script_native "$@"
    RV="$?"
  fi

  return "$RV"
}

_execute_script_extension() {
  if [[ -d "$ENTANDO_ENT_EXTENSIONS_MODULES_PATH" && "$ENTANDO_ENT_EXTENSIONS_ENABLED" != "false" ]]; then
    if _ent.extension-module.is-present "$cmd"; then
      RV="34"
      _ent.extension-module.chain-run "${cmd}" "$@"
      RV="$?"   # if 33 => command not found
    else
      RV="33"
    fi
  fi
  
  return "$RV"
}  
  
_execute_script_native() {
  
  local mod_script="${ENTANDO_ENT_HOME}/bin/mod/ent-${cmd}"
  if [ -f "$mod_script" ]; then
    # shellcheck disable=SC1090
    source "$mod_script" "$@"
    RV="$?"
  fi

  return "$RV"
}

_shortcut_subpro() {
  local pattern=${1:-..};shift
  # shellcheck disable=SC1091
  source "$ENTANDO_ENT_HOME/bin/mod/ent-profile" use . "$pattern" "$@"
}
