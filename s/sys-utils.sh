#!/bin/bash
# SYS-UTILS

perl -e 'print -t 1 ? exit 0 : exit 1;'
if [ $? -eq 0 ]; then
  ENTANDO_IS_TTY=true
else
  ENTANDO_IS_TTY=false
fi

netplan_add_custom_ip() {
  F=$(sudo ls /etc/netplan/* 2>/dev/null | head -n 1)
  [ ! -f "$F" ] && FATAL "This function only supports netplan based network configurations"
  sudo grep -v addresses "$F" | sed '/dhcp4/a ___addresses: [ '"$1"' ]' | sed's/_/    /g' >"w/netplan.tmp"
  [ -f "$F.orig" ] && sudo cp -a "$F" "$F.orig"
  sudo cp "w/netplan.tmp" "$F"
}

netplan_add_custom_nameserver() {
  F=$(sudo ls /etc/netplan/* 2>/dev/null | head -n 1)
  [ ! -f "$F" ] && FATAL "This function only supports netplan based network configurations"
  sudo grep -v "#ENT-NS" "$F" | sed'/dhcp4/a ___nameservers: #ENT-NS\n____addresses: [ '"$1"' ] #ENT-NS' | sed 's/_/    /g' >"w/netplan.tmp"
  [ ! -f "$F.orig" ] && sudo cp -a "$F" "$F.orig"
  sudo cp "w/netplan.tmp" "$F"
}

net_is_address_present() {
  [ "$(ip a s 2>/dev/null | grep "$1" -c)" -gt 0 ] && return 0 || return 1
}

#net_is_hostname_known() {
#  [ $(dig +short "$1" | wc -l) -gt 0 ] && return 0 || return 1
#}

hostsfile_clear() {
  (
    T="$(mktemp /tmp/ent-auto-XXXXXXXX)"
    cleanup() { rm "$T"; }
    trap cleanup exit
    # shellcheck disable=SC2024
    sudo sed "/##ENT-CUSTOM-VALUE##$1/d" "$C_HOSTS_FILE" >"$T"
    echo "##ENT-CUSTOM-VALUE##$1" >>"$T"
    _sudo cp "$C_HOSTS_FILE" "${C_HOSTS_FILE}.ent.save~"
    _sudo cp "$T" "$C_HOSTS_FILE"
  )
}

hostsfile_add_dns() {
  echo "$1 $2    ##ENT-CUSTOM-VALUE##$3" | _sudo tee -a "$C_HOSTS_FILE" >/dev/null
}

# Checks the SemVer of a program
# > check_ver <program> <expected-semver-pattern> <program-params-for-showing-version\> <mode>
check_ver() {
  local mode="$4"
  local err_desc="$5"
  [[ ! "$mode" =~ "quiet" ]] && _log_i 3 "Checking $1.."

  [[ "$mode" =~ "literal" ]] &&
    VER=$(eval "$1 $3") ||
    VER=$(eval "$1 $3 2>/dev/null")

  if [ $? -ne 0 ] || [ -z "$VER" ]; then
    if [[ ! "$mode" =~ "quiet" ]]; then
      if [ -z "$err_desc" ]; then
        _log_i 2 "Program \"$1\" is not available"
      else
        _log_i 2 "$err_desc"
      fi
    fi
    return 1
  fi

  P="${VER:0:1}"
  [[ "${P}" == "v" || "${P}" == "V" ]] && VER=${VER:1}

  VER="${VER//_/.}"
  REQ="${2//_/.}"

  IFS='.' read -r -a V <<<"$VER"
  f_maj="${V[0]}" && f_min="${V[1]}" && f_ptc="${V[2]}" && f_upd="${V[3]}"
  IFS='.' read -r -a V <<<"$REQ"
  r_maj="${V[0]}" && r_min="${V[1]}" && r_ptc="${V[2]}" && r_upd="${V[3]:-"*"}"

  # shellcheck disable=SC2015
  (
    check_ver_num_start
    check_ver_num "$f_maj" "$r_maj" || return 1
    check_ver_num "$f_min" "$r_min" || return 1
    check_ver_num "$f_ptc" "$r_ptc" || return 1
    check_ver_num "$f_upd" "$r_upd" || return 1
    return 0
  ) && {
    check_ver_res="$VER"
    [[ "$mode" =~ "verbose" ]] && _log_i 3 "\tfound: $check_ver_res => OK"
    return 0
  } || {
    [[ ! "$mode" =~ "quiet" ]] && _log_i 2 "Version \"$2\" of program \"$1\" is not available (found: $VER)"
    return 1
  }
}

check_ver_num_start() {
  check_ver_num_op=""
}

check_ver_num() {
  L="$1"
  R="$2"
  [ "${L:0:1}" = "v" ] && {
    L="${L:1}"
  }
  [ "${R:0:1}" = "v" ] && {
    R="${R:1}"
  }
  [[ "$R" == "*" ]] && return 0
  [[ "$L" == "$R" ]] && return 0
  [[ "$check_ver_num_op" != "" ]] && return 1

  # GTE
  [[ "$2" =~ \>=(.*) ]] && {
    check_ver_num_op=">="
    [[ "$L" -ge "${BASH_REMATCH[1]}" ]] && return 0 || return 1
  }
  # GT
  [[ "$R" =~ \>(.*) ]] && {
    check_ver_num_op=">"
    [[ "$L" -gt "${BASH_REMATCH[1]}" ]] && return 0 || return 1
  }
  # LTE
  [[ "$R" =~ \<=(.*) ]] && {
    check_ver_num_op="<="
    [[ "$L" -le "${BASH_REMATCH[1]}" ]] && return 0 || return 1
  }
  # LT
  [[ "$R" =~ \<(.*) ]] && {
    check_ver_num_op="<"
    [[ "$L" -lt "${BASH_REMATCH[1]}" ]] && return 0 || return 1
  }
  return 1
}

make_safe_resolv_conf() {
  [ ! -f /etc/resolv.conf.orig ] && sudo cp -ap /etc/resolv.conf /etc/resolv.conf.orig

  # shellcheck disable=SC2002
  cat "/etc/resolv.conf" |
    _perl_sed 's/nameserver.*/nameserver 8.8.8.8/' \
      >/tmp/resolv.conf.tmp

  sudo mv /tmp/resolv.conf.tmp /etc/resolv.conf
}

# MISC

if ! $ENTANDO_IS_TTY || $OS_WIN; then
  _watch() {
    if [ "$1" == "-v" ]; then
      echo "ent fake watch UNKNOWN"
      return 0
    fi
    while true; do
      OUT="$("$@")"
      clear
      echo -e "$*\t$USER: $(date)\n"
      echo "$OUT"
      sleep 2
    done
  }
else
  _watch() {
    export ENTANDO_TTY_QUALIFIER
    export ENTANDO_DEV_TTY
    export -f _kubectl
    kubectl_mode --export
    watch "$@"
  }
fi

$OS_WIN && {
  winpty --version 1>/dev/null 2>&1 && {
    SYS_CLI_PRE() {
      if $ENTANDO_IS_TTY; then
        "winpty" "$@"
      else
        "$@"
      fi
    }
  }
}

# Runs npm from the private npm modules
function _ent-npm() {
  activate_shell_login_environment

  local P="$ENTANDO_ENT_HOME/lib/node"

  [ ! -d "$ENTANDO_ENT_HOME/lib/node" ] && mkdir -p "$ENTANDO_ENT_HOME/lib/node"
  if [ ! -f "$P/package.json" ]; then
    (
      echo "Ent node dir not initialized => INITIALIZING.." 1>&2
      cd "$P"
      _npm init -y 1>/dev/null
    ) || return $?
  fi
  (
    case "$1" in
    bin)
      npm bin --prefix "$P" -g 2>/dev/null
      ;;
    install-from-source)
      shift
      [ -d "$P" ] || FATAL -t "Required dir \"$P\" is missing"
      _npm install --prefix "$P" -g .
      ;;
    install-package)
      shift
      cd "$P" || FATAL -t "Unable to switch to dir \"$P\""
      _npm install --prefix "$P" -g "$@"
      ;;
    *)
      _log_i 0 "missing parameter (install-from-source|install-package|bin)"
      ;;
    esac
  ) || return $?
}

# Imports a module from the entando private npm modules
# the the given mode_modules dir
function _ent-npm--import-module-to-current-dir() {
  local BP="$ENTANDO_ENT_HOME/lib/"
  #[ ! -f package.json ] && echo "{}" > package.json
  _npm install "$BP/$1/$2"
}

# Run the ent private installation of jhipster
function _ent-jhipster() {
  require_develop_checked
  activate_designated_node
  if [ "$1" == "--ent-get-version" ]; then
    if $OS_WIN; then
      "$ENT_NPM_BIN_DIR/jhipster.cmd" -V 2>/dev/null | grep -v INFO
    else
      "$ENT_NPM_BIN_DIR/jhipster" -V 2>/dev/null | grep -v INFO
    fi
  else
    #require_initialized_dir
    # protection against yeoman's reverse recursive lookup
    #[ ! -f ".yo-rc.json" ] && echo "{}" > ".yo-rc.json"

    [[ ! -f package.json ]] && {
      ask "The project dir doesn't seem to be initialized, should I do it now?" && {
        ent-init-project-dir
      }
    }

    # RUN
    if $OS_WIN; then
      SYS_CLI_PRE "$ENT_NPM_BIN_DIR/jhipster.cmd" "$@"
    else
      "$ENT_NPM_BIN_DIR/jhipster" "$@"
    fi

    _log_i 0 "Updating the entando generator"

    _ent-npm--import-module-to-current-dir \
      "$C_GENERATOR_JHIPSTER_ENTANDO_NAME" \
      "$VER_GENERATOR_JHIPSTER_ENTANDO_DEF" |
      grep -v 'No description\|No repository field.\|No license field.'
  fi
}

# Run the ent private installation of the entando bundle tool
_ent-bundler() {
  if [ "$1" == "--ent-get-version" ]; then
    if $OS_WIN; then
      "$ENT_NPM_BIN_DIR/$C_ENTANDO_BUNDLE_BIN_NAME.cmd" --version
    else
      "$ENT_NPM_BIN_DIR/$C_ENTANDO_BUNDLE_BIN_NAME" --version
    fi
  else
    require_develop_checked
    activate_designated_node
    # RUN
    if $OS_WIN; then
      if "$ENTANDO_IS_TTY"; then
        SYS_CLI_PRE "$ENT_NPM_BIN_DIR/$C_ENTANDO_BUNDLE_BIN_NAME.cmd" "$@"
      else
        SYS_CLI_PRE "$ENT_NPM_BIN_DIR/$C_ENTANDO_BUNDLE_BIN_NAME.cmd" "$@" |
          perl -pe 's/\e\[[0-9;]*m(?:\e\[K)?//g'
      fi
    else
      if "$ENTANDO_IS_TTY"; then
        "$ENT_NPM_BIN_DIR/$C_ENTANDO_BUNDLE_BIN_NAME" "$@"
      else
        "$ENT_NPM_BIN_DIR/$C_ENTANDO_BUNDLE_BIN_NAME" "$@" |
          perl -pe 's/\e\[[0-9;]*m(?:\e\[K)?//g'
      fi
    fi
  fi
}

function ent-init-project-dir() {
  [ -f "$C_ENT_PRJ_FILE" ] && {
    _log_w 0 "The project seems to be already initialized"
    ask "Should I init it again?" "n" || return 1
  }
  require_develop_checked
  #_ent-npm--import-module-to-current-dir "$C_GENERATOR_JHIPSTER_ENTANDO_NAME" "$VER_GENERATOR_JHIPSTER_ENTANDO_DEF" \
  #  | grep -v 'No description\|No repository field.\|No license field.'
  generate_ent_project_file
}

generate_ent_project_file() {
  ! grep -qs "^$C_ENT_STATE_FILE\$" .gitignore && {
    echo -e "\n########\n$C_ENT_STATE_FILE\n" >>".gitignore"
  }

  if [ ! -f "$C_ENT_PRJ_FILE" ]; then
    echo "# ENT-PRJ / $(date -u '+%Y-%m-%dT%H:%M:%S%z')" >"$C_ENT_PRJ_FILE"
  fi

  camel_to_snake -d ENT_PRJ_NAME "$(basename "$PWD")"
  set_or_ask ENT_PRJ_NAME "" "Please provide the project name" "$ENT_PRJ_NAME"
  mkdir -p "$C_ENT_PRJ_ENT_DIR"
  save_cfg_value ENT_PRJ_NAME "$ENT_PRJ_NAME" "$C_ENT_PRJ_FILE"
}

rescan-sys-env() {
  [[ "$WAS_DEVELOP_CHECKED" == "true" || "$1" == "force" ]] && {
    if $OS_WIN; then
      [[ -z "$NVM_CMD" || "$1" == "force" ]] && {
        NVM_CMD="$(command -v nvm | head -n 1)"
        save_cfg_value "NVM_CMD" "$NVM_CMD" "$ENT_DEFAULT_CFG_FILE"
      }
      [[ -z "$NPM_CMD" || "$1" == "force" ]] && {
        NPM_CMD="$(command -v npm | head -n 1)"
        save_cfg_value "NPM_CMD" "$NPM_CMD" "$ENT_DEFAULT_CFG_FILE"
      }
      [[ -z "$ENT_NPM_BIN_DIR" || "$1" == "force" ]] && {
        ENT_NPM_BIN_DIR="$(_ent-npm bin)"
        mkdir -p "$ENT_NPM_BIN_DIR"
        ENT_NPM_BIN_DIR="$(win_convert_existing_path_to_posix_path "$ENT_NPM_BIN_DIR")"
        save_cfg_value "ENT_NPM_BIN_DIR" "$ENT_NPM_BIN_DIR" "$ENT_DEFAULT_CFG_FILE"
      }
    else
      [[ -z "$NVM_CMD" || "$1" == "force" ]] && NVM_CMD="nvm"
      save_cfg_value "NVM_CMD" "$NVM_CMD" "$ENT_DEFAULT_CFG_FILE"
      [[ -z "$NPM_CMD" || "$1" == "force" ]] && NPM_CMD="npm"
      save_cfg_value "NPM_CMD" "$NPM_CMD" "$ENT_DEFAULT_CFG_FILE"
      [[ -z "$ENT_NPM_BIN_DIR" || "$1" == "force" ]] && {
        ENT_NPM_BIN_DIR="$(_ent-npm bin)"
        save_cfg_value "ENT_NPM_BIN_DIR" "$ENT_NPM_BIN_DIR" "$ENT_DEFAULT_CFG_FILE"
      }
    fi
  }
}

_nvm() {
  activate_shell_login_environment
  "$NVM_CMD" "$@"
}

_npm() {
  activate_shell_login_environment
  "$NPM_CMD" "$@"
}

win_convert_existing_path_to_posix_path() {
  powershell "cd \"$1\" > \$null; bash -c 'pwd'"
}

git_clone_repo() {
  local URL="$1" # URL TO CLONE
  local TAG="$2" # TAG TO CHECKOUT
  local FLD="$3" # local folder name
  local DSC="$4" # human description of the cloned repository
  local OPT="$5" # options

  local ENTER=false
  local FORCE=false
  local ERRC="nop"

  if [[ "$OPT" =~ "FATAL" ]]; then
    ERRC="FATAL"
  fi
  if [[ "$OPT" =~ "LOGW" ]]; then
    ERRC="_log_w 0"
  fi
  if [[ "$OPT" =~ "FORCE" ]]; then
    FORCE=true
  fi
  if [[ "$OPT" =~ "ENTER" ]]; then
    ENTER=true
  fi

  [ -z "$FLD" ] && FLD="$(basename "$URL")"
  [ -z "$DSC" ] && DSC="$FLD/$TAG"

  if [[ -d "$FLD" ]]; then
    if $FORCE; then
      echo "> Destination dir \"$PWD/$FLD\" already exists and will not be overwritten.." 1>&2
      return 99
    else
      rm -rf "./${FLD:?}"
    fi
  fi

  git clone "$URL" "$FLD"
  if cd "$FLD"; then
    (
      git fetch --tags --force
      git tag | grep "^$TAG\$" >/dev/null || local OP="origin/"
      if ! git checkout -b "$TAG" "${OP}$TAG" 1>/dev/null; then
        $ERRC "> Unable to checkout the tag or branch of $DSC \"$TAG\""
        exit 92
      fi
    ) || return $?

    if [ $? ]; then
      ! $ENTER && {
        cd - >/dev/null || $ERRC "Unable to return back to the original path"
      }
    else
      cd - >/dev/null && {
        rm -rf "./${FLD:?}" 2>/dev/null
        return "$?"
      }
    fi
  fi
}

__mk-cd() {
  mkdir -p "$1"
  __cd "$1"
}

__cd() {
  cd "$1" || {
    echo "~~~" 1>&2
    FATAL -t "Unable to enter dir \"$1\""
  }
}

# shellcheck disable=SC1090
# shellcheck disable=SC1091
activate_shell_login_environment() {
  [ -f /etc/profile ] && . /etc/profile
  [ -f ~/.bash_profile ] && . ~/.bash_profile && return 0
  [ -f ~/.bash_login ] && . ~/.bash_login && return 0
  [ -f ~/.profile ] && . ~/.profile && return 0
}

find_nvm_node() {
  local found current versions ver
  local outvar="$1"
  local preferred="$2"
  local requested="$3"

  found=""
  _set_var "$outvar" ""

  current="$(node -v)"

  if $OS_WIN; then
    versions="$(nvm ls | _perl_sed 's/\*/ /' | grep -v system | _perl_sed 's/[^v]*(v\S*).*/\1/')"
  else
    versions="$(nvm ls --no-colors --no-alias 2>/dev/null |
      _perl_sed 's/->/  /' |
      grep -v system |
      grep '^\s\+v.*$' |
      _perl_sed 's/[^v]*(v\S*).*/\1/')"
    if [[ $? -ne 0 || -z "$versions" ]]; then
      versions="$(nvm ls --no-colors |
        _perl_sed 's/->/  /' |
        grep -v system |
        grep '^\s\+v.*$' |
        _perl_sed 's/[^v]*(v\S*).*/\1/')"
    fi
  fi

  if echo "$versions" | grep -q "$current"; then
    versions="$(echo "$versions" | grep -v "$current")"
    versions+=$'\n'" $current"
  fi

  if echo "$versions" | grep -q "$preferred"; then
    versions="$(echo "$versions" | grep -v "$preferred")"
    versions+=$'\n'" $preferred"
  fi

  for ver in $versions; do
    if check_ver "echo" "$requested" "\"$ver\"" "quiet"; then
      found="$ver"
    else
      _log_d 2 "\t- version \"$ver\" doesn't satisfy the requirements ($requested)"
    fi
  done

  if [ "$found" != "" ]; then
    _log_i 0 "\tfound suitable node version $found"
    _set_var "$outvar" "$found"
    return 0
  else
    _log_w 0 "No suitable version of node was found"
    return 1
  fi
}

list_compatible_installations() {
  local curr="$1"
  local patt="${curr%.*}"

  [ -n "$curr" ] && {
    (
      __cd "$ENTANDO_ENT_HOME/.."
      # shellcheck disable=SC2010
      # shellcheck disable=SC2154
      ls -d "$patt"* | grep -v "^$curr\$"
    )
  }
}

import_ent_config() {
  local src="$1"
  [ "$src" = "<skip this import>" ] && return 0
  (
    __cd "$ENTANDO_ENT_HOME"
    if [ -d "../$src" ]; then
      cp "../$src/w/.cfg" "w/.cfg" && exit 0
      exit 1
    else
      _log_e 0 "Unable to import the cfg from $src"
      exit 99
    fi
  )
}

import_ent_library() {
  local src="$1"
  [ "$src" = "<skip this import>" ] && return 0
  local mode="$2"
  (
    __cd "$ENTANDO_ENT_HOME"
    if [ -d "../$src" ]; then
      if [ "$mode" = "copy" ]; then
        rm lib -r
        cp -ra "../$src/lib" "." && exit 0
        exit 1
      elif [ "$mode" = "link" ]; then
        rm lib -r
        ln -s "../$src/lib" "." && exit 0
        exit 1
      fi
    fi
    _log_e 0 "Unable to import the cfg from $src"
    exit 99
  )
}

import_ent_installation() {
  local VERS=("$(list_compatible_installations "$ENTANDO_CLI_VERSION")")
  VERS+=("<skip this import>")

  select_one "Select the configuration to import" "${VERS[@]}" && {
    # shellcheck disable=SC2154
    VER_TO_IMPORT="$select_one_res_alt"
    import_ent_config "$VER_TO_IMPORT" && {
      _log_i 0 "done"

      ask "Should I try to import the library?" && {
        _log_i 0 "This may take a while"
        import_ent_library "$VER_TO_IMPORT" "copy" && {
          _log_i 0 "done."
        }
      }
    }
  }
}

list_kube_contexts() {
  local OPT filter
  HH="$(parse_help_option "$@")"
  show_help_option "$HH"
  args_or_ask ${HH:+"$HH"} -n -a -- filter '1///filter' "$@"
  [ -n "$HH" ] && exit 0

  if [ -n "$filter" ]; then
    ENT_KUBECTL_NO_AUTO_SUDO=true _kubectl config view -o jsonpath='{.contexts[*].name}' \
    | tr -s ' ' $'\n' | grep "$filter"
  else
    ENT_KUBECTL_NO_AUTO_SUDO=true _kubectl config view -o jsonpath='{.contexts[*].name}' \
    | tr -s ' ' $'\n'
  fi
}

return 0
