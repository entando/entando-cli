#!/bin/bash
# SYS-UTILS

netplan_add_custom_ip() {
  F=$(sudo ls /etc/netplan/* 2> /dev/null | head -n 1)
  [ ! -f "$F" ] && FATAL "This function only supports netplan based network configurations"
  sudo grep -v addresses "$F" | sed '/dhcp4/a ___addresses: [ '"$1"' ]' | sed's/_/    /g' > "w/netplan.tmp"
  [ -f "$F.orig" ] && sudo cp -a "$F" "$F.orig"
  sudo cp "w/netplan.tmp" "$F"
}

netplan_add_custom_nameserver() {
  F=$(sudo ls /etc/netplan/* 2> /dev/null | head -n 1)
  [ ! -f "$F" ] && FATAL "This function only supports netplan based network configurations"
  sudo grep -v "#ENT-NS" "$F" | sed'/dhcp4/a ___nameservers: #ENT-NS\n____addresses: [ '"$1"' ] #ENT-NS' | sed 's/_/    /g' > "w/netplan.tmp"
  [ ! -f "$F.orig" ] && sudo cp -a "$F" "$F.orig"
  sudo cp "w/netplan.tmp" "$F"
}

net_is_address_present() {
  [ "$(ip a s 2> /dev/null | grep "$1" -c)" -gt 0 ] && return 0 || return 1
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
    sudo sed "/##ENT-CUSTOM-VALUE##$1/d" "$C_HOSTS_FILE" > "$T"
    echo "##ENT-CUSTOM-VALUE##$1" >> "$T"
    _sudo cp "$C_HOSTS_FILE" "${C_HOSTS_FILE}.ent.save~"
    _sudo cp "$T" "$C_HOSTS_FILE"
  )
}

hostsfile_add_dns() {
  echo "$1 $2    ##ENT-CUSTOM-VALUE##$3" | _sudo tee -a "$C_HOSTS_FILE" > /dev/null
}


# Checks the SemVer of a program
# > check_ver <program> <expected-semver-pattern> <program-params-for-showing-version\> <mode>
check_ver() {
  local mode="$4"
  local err_desc="$5"
  [[ ! "$mode" =~ "quiet" ]] && _log_i 3 "Checking $1.."

  [[ "$mode" =~ "literal" ]] \
    && VER=$(eval "$1 $3") \
    || VER=$(eval "$1 $3 2>/dev/null")

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

  IFS='.' read -r -a V <<< "$VER"
  f_maj="${V[0]}" && f_min="${V[1]}" && f_ptc="${V[2]}" && f_upd="${V[3]}"
  IFS='.' read -r -a V <<< "$REQ"
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
  [[ "$2" == "*" ]] && return 0
  [[ "$1" == "$2" ]] && return 0
  [[ "$check_ver_num_op" != "" ]] && return 1

  # GTE
  [[ "$2" =~ \>=(.*) ]] && {
    check_ver_num_op=">="
    [[ "$1" -ge "${BASH_REMATCH[1]}" ]] && return 0 || return 1
  }
  # GT
  [[ "$2" =~ \>(.*) ]] && {
    check_ver_num_op=">"
    [[ "$1" -gt "${BASH_REMATCH[1]}" ]] && return 0 || return 1
  }
  # LTE
  [[ "$2" =~ \<=(.*) ]] && {
    check_ver_num_op="<="
    [[ "$1" -le "${BASH_REMATCH[1]}" ]] && return 0 || return 1
  }
  # LT
  [[ "$2" =~ \<(.*) ]] && {
    check_ver_num_op="<"
    [[ "$1" -lt "${BASH_REMATCH[1]}" ]] && return 0 || return 1
  }
  return 1
}

make_safe_resolv_conf() {
  [ ! -f /etc/resolv.conf.orig ] && sudo cp -ap /etc/resolv.conf /etc/resolv.conf.orig
  sudo cp -a /etc/resolv.conf /etc/resolv.conf.tmp
  sudo _sed_in_place 's/nameserver.*/nameserver 8.8.8.8/' /etc/resolv.conf.tmp
  sudo mv /etc/resolv.conf.tmp /etc/resolv.conf
}

# MISC

if [[ ! -t 0 || $OS_WIN = "true" ]]; then
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
    watch "$@"
  }
fi

$OS_WIN && {
  winpty --version 1> /dev/null 2>&1 && {
    SYS_CLI_PRE() {
      RES="$(perl -e 'print -t 1 ? "Y" : "N";')"
      if [ "$RES" = 'Y' ]; then
        "winpty" "$@"
      else
        "$@"
      fi
    }
  }
}

# Runs npm from the private npm modules
function _ent-npm() {
  local P="$ENTANDO_ENT_ACTIVE/lib/node"

  [ ! -d "$ENTANDO_ENT_ACTIVE/lib/node" ] && mkdir -p "$ENTANDO_ENT_ACTIVE/lib/node"
  if [ ! -f "$P/package.json" ]; then
    (
      echo "Ent node dir not initialized => INITIALIZING.." 1>&2
      cd "$P"
      _npm init -y 1> /dev/null
    ) || return $?
  fi
  (
    case "$1" in
      bin)
        npm bin --prefix "$P" -g 2>/dev/null
        ;;
      install-from-source)
        shift
        [ -d "$P" ] || FATAL "Required dir \"$P\" is missing"
        _npm install --prefix "$P" -g .
        ;;
      install-package)
        shift
        cd "$P" || FATAL "Unable to switch to dir \"$P\""
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
  local BP="$ENTANDO_ENT_ACTIVE/lib/"
  #[ ! -f package.json ] && echo "{}" > package.json
  _npm install "$BP/$1/$2"
}

# Run the ent private installation of jhipster
function _ent-jhipster() {
  if [ "$1" == "--ent-get-version" ]; then
    if $OS_WIN; then
      "$ENT_NPM_BIN_DIR/jhipster.cmd" -V 2>/dev/null | grep -v INFO
    else
      "$ENT_NPM_BIN_DIR/jhipster" -V 2>/dev/null | grep -v INFO
    fi
  else
    require_develop_checked
    activate_designated_node
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
      SYS_CLI_PRE "$ENT_NPM_BIN_DIR/$C_ENTANDO_BUNDLE_BIN_NAME.cmd" "$@"
    else
      "$ENT_NPM_BIN_DIR/$C_ENTANDO_BUNDLE_BIN_NAME" "$@"
    fi
  fi
}

function ent-init-project-dir() {
  [ -f "$C_ENT_PRJ_FILE" ] && {
    _log_w 0 "The project seems to be already initialized"
    ask "Do you want to init it again?" "n" || return 1
  }
  require_develop_checked
  _ent-npm--import-module-to-current-dir "$C_GENERATOR_JHIPSTER_ENTANDO_NAME" "$VER_GENERATOR_JHIPSTER_ENTANDO_DEF" \
    | grep -v 'No description\|No repository field.\|No license field.'
  generate_ent_project_file
}

generate_ent_project_file() {
  ! grep -qs "^$C_ENT_STATE_FILE\$" .gitignore && {
    echo -e "\n########\n$C_ENT_STATE_FILE\n" >> ".gitignore"
  }

  if [ ! -f "$C_ENT_PRJ_FILE" ]; then
    echo "# ENT-PRJ / $(date -u '+%Y-%m-%dT%H:%M:%S%z')" > "$C_ENT_PRJ_FILE"
  fi

  camel_to_snake -d ENT_PRJ_NAME "$(basename "$PWD")"
  set_or_ask ENT_PRJ_NAME "" "Please provide the project name" "$ENT_PRJ_NAME"
  save_cfg_value ENT_PRJ_NAME "$ENT_PRJ_NAME" "$C_ENT_PRJ_FILE"
}

rescan-sys-env() {
  [[ "$WAS_DEVELOP_CHECKED" == "true" || "$1" == "force" ]] && {
    if $OS_WIN; then
      [[ -z "$NVM_CMD" || "$1" == "force" ]] && {
        NVM_CMD="$(command -v nvm | head -n 1)"
        save_cfg_value "NVM_CMD" "$NVM_CMD"
      }
      [[ -z "$NPM_CMD" || "$1" == "force" ]] && {
        NPM_CMD="$(command -v npm | head -n 1)"
        save_cfg_value "NPM_CMD" "$NPM_CMD"
      }
      [[ -z "$ENT_NPM_BIN_DIR" || "$1" == "force" ]] && {
        ENT_NPM_BIN_DIR="$(_ent-npm bin)"
        mkdir -p "$ENT_NPM_BIN_DIR"
        ENT_NPM_BIN_DIR="$(win_convert_existing_path_to_posix_path "$ENT_NPM_BIN_DIR")"
        save_cfg_value "ENT_NPM_BIN_DIR" "$ENT_NPM_BIN_DIR"
      }
    else
      [[ -z "$NVM_CMD" || "$1" == "force" ]] && NVM_CMD="nvm"
      save_cfg_value "NVM_CMD" "$NVM_CMD"
      [[ -z "$NPM_CMD" || "$1" == "force" ]] && NPM_CMD="npm"
      save_cfg_value "NPM_CMD" "$NPM_CMD"
      [[ -z "$ENT_NPM_BIN_DIR" || "$1" == "force" ]] && {
        ENT_NPM_BIN_DIR="$(_ent-npm bin)"
        save_cfg_value "ENT_NPM_BIN_DIR" "$ENT_NPM_BIN_DIR"
      }
    fi
  }
}

_nvm() {
  "$NVM_CMD" "$@"
}

_npm() {
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
      git tag | grep "^$TAG\$" > /dev/null || local OP="origin/"
      if ! git checkout -b "$TAG" "${OP}$TAG" 1> /dev/null; then
        $ERRC "> Unable to checkout the tag or branch of $DSC \"$TAG\""
        exit 92
      fi
    ) || return $?

    if [ $? ]; then
      ! $ENTER && {
        cd - > /dev/null || $ERRC "Unable to return back to the original path"
      }
    else
      cd - > /dev/null && {
        rm -rf "./${FLD:?}" 2> /dev/null
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
    trace_position "CALLER:" "" 2
    FATAL "Unable to enter dir \"$1\""
  }
}

return 0
