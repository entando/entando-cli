# SYS-UTILS

SYS_UTILS_BASE_DIR=$PWD
SYS_CLI_PRE=""

# OS DETECT
OS_LINUX=false
OS_MAC=false
OS_WIN=false
OS_BSD=false
SYS_GNU_LIKE=false
SYS_OS_UNKNOWN=false
case "$OSTYPE" in
  linux*)
    SYS_OS_TYPE="linux"
    SYS_GNU_LIKE=true
    OS_LINUX=true
    DEV_TTY="/dev/tty"
    ;;
  darwin*)
    SYS_OS_TYPE="mac"
    SYS_GNU_LIKE=true
    OS_MAC=true
    DEV_TTY="/dev/ttys000"
    ;;
  "cygwin" | "msys" | win*)
    SYS_OS_TYPE="win"
    SYS_GNU_LIKE=true
    OS_WIN=true
    DEV_TTY="/dev/tty"
    ;;
  win*)
    SYS_OS_TYPE="win"
    SYS_GNU_LIKE=false
    OS_WIN=true
    DEV_TTY="/dev/tty"
    ;;
  "freebsd" | "openbsd")
    SYS_OS_TYPE="bsd"
    SYS_GNU_LIKE=true
    OS_BSD=true
    ;;
  *)
    SYS_OS_TYPE="UNKNOWN"
    SYS_OS_UNKNOWN=true
    ;;
esac

netplan_add_custom_ip() {
  F=$(sudo ls /etc/netplan/* 2> /dev/null | head -n 1)
  [ ! -f "$F" ] && FATAL "This function only supports netplan based network configurations"
  sudo grep -v addresses "$F" | sed '/dhcp4/a ___addresses: [ '$1' ]' | sed 's/_/    /g' > "w/netplan.tmp"
  [ -f $F.orig ] && sudo cp -a "$F" "$F.orig"
  sudo cp "w/netplan.tmp" "$F"
}

netplan_add_custom_nameserver() {
  F=$(sudo ls /etc/netplan/* 2> /dev/null | head -n 1)
  [ ! -f "$F" ] && FATAL "This function only supports netplan based network configurations"
  sudo grep -v "#ENT-NS" "$F" | sed '/dhcp4/a ___nameservers: #ENT-NS\n____addresses: [ '$1' ] #ENT-NS' | sed 's/_/    /g' > "w/netplan.tmp"
  [ ! -f $F.orig ] && sudo cp -a "$F" "$F.orig"
  sudo cp "w/netplan.tmp" "$F"
}

net_is_address_present() {
  [ "$(ip a s 2> /dev/null | grep "$1" | wc -l)" -gt 0 ] && return 0 || return 1
}

#net_is_hostname_known() {
#  [ $(dig +short "$1" | wc -l) -gt 0 ] && return 0 || return 1
#}

hostsfile_clear() {
  sudo sed --in-place='' "/##ENT-CUSTOM-VALUE##$1/d" "$C_HOSTS_FILE"
  sudo echo "##ENT-CUSTOM-VALUE##$1" | sudo tee -a "$C_HOSTS_FILE" > /dev/null
}

hostsfile_add_dns() {
  sudo echo "$1 $2    ##ENT-CUSTOM-VALUE##$3" | sudo tee -a "$C_HOSTS_FILE" > /dev/null
}

ensure_sudo() {
  sudo true # NB: not using "sudo -v" because misbehaves with password-less sudoers
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
  [ "${P^^}" == "V" ] && VER=${VER:1}

  VER="${VER//_/.}"
  REQ="${2//_/.}"

  IFS='.' read -r -a V <<< "$VER"
  f_maj="${V[0]}" && f_min="${V[1]}" && f_ptc="${V[2]}" && f_upd="${V[3]}"
  IFS='.' read -r -a V <<< "$REQ"
  r_maj="${V[0]}" && r_min="${V[1]}" && r_ptc="${V[2]}" && r_upd="${V[3]:-"*"}"

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
  sudo sed --in-place='' 's/nameserver.*/nameserver 8.8.8.8/' /etc/resolv.conf.tmp
  sudo mv /etc/resolv.conf.tmp /etc/resolv.conf
}

# MISC - WIN

$OS_WIN && {
  watch() {
    if [ "$1" == "-v" ]; then
      echo "ent fake watch UNKNOWN"
      return 0
    fi
    while true; do
      OUT=$("$@")
      clear
      echo -e "$*\t$USER: $(date)\n"
      echo "$OUT"
      sleep 2
    done
  }

  win_run_as() {
    "$SYS_UTILS_BASE_DIR/s/win_run_as.cmd" "$@"
  }

  winpty --version 1> /dev/null 2>&1 && {
    SYS_CLI_PRE="winpty"
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
    cd "$P" || FATAL "Unable to switch to dir \"$P\""
    _npm "$@"
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
  if [ "$1" == "--ent-no-envcheck" ]; then
    shift
  else
    require_develop_checked
    activate_designated_node
    #require_initialized_dir
    # protection against yeoman's reverse recursive lookup
    #[ ! -f ".yo-rc.json" ] && echo "{}" > ".yo-rc.json"

    [ ! -f package.json ] && {
      ask "The project dir doesn't seem to be initialized, should I do it now?" && {
        ent-init-project-dir
      }
    }
  fi
  # RUN
  if $OS_WIN; then
    $SYS_CLI_PRE "$ENT_NPM_BIN_DIR/jhipster.cmd" "$@"
  else
    "$ENT_NPM_BIN_DIR/jhipster" "$@"
  fi
}

function ent-init-project-dir() {
  [ -f ".ent-prj" ] && {
    _log_w 0 "The project seems to be already initialized"
    ask "Do you want to init it again?" "n" || return 1
  }

  _ent-npm--import-module-to-current-dir generator-jhipster-entando "$VER_GENERATOR_JHIPSTER_ENTANDO_DEF" \
    | grep -v 'No description\|No repository field.\|No license field.'
  generate_ent_project_file
}

generate_ent_project_file() {
  #  grep -qs "\.ent$" .gitignore && {
  #    echo -e "\n########\n.ent\n" >> ".gitignore"
  #  }

  [ -f ".ent-prj" ] && return 0
  echo "# ENT-PRJ / $(date -u '+%Y-%m-%dT%H:%M:%S%z')" > ".ent-prj"
}

rescan-sys-env() {
  [[ "$WAS_DEVELOP_CHECKED" = "true" || "$1" == "force" ]] && {
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

return 0
