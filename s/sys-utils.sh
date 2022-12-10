#!/bin/bash
# SYS-UTILS

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

  if [[ "$mode" =~ "string" ]]; then
    VER="$1"
    mode+=",quiet"
  else
    [[ ! "$mode" =~ "quiet" ]] && _log_i "Checking $1.."
    
    if command -V "$1" &> /dev/null; then
      if [[ "$2" == "-" ]]; then
        return 0
      else
        if [[ "$mode" =~ "literal" ]]; then
          VER=$(eval "$1 $3")
        else
          VER=$(eval "$1 $3 2>/dev/null")
        fi
      fi
    else
      VER=""
    fi
      
    if [ $? -ne 0 ] || [ -z "$VER" ]; then
      if [[ ! "$mode" =~ "quiet" ]]; then
        if [ -z "$err_desc" ]; then
          _log_i "Program \"$1\" is not available"
        else
          _log_i "$err_desc"
        fi
      fi
      return 1
    fi
  fi

  P="${VER:0:1}"
  [[ "${P}" == "v" || "${P}" == "V" ]] && VER=${VER:1}

  VER="${VER//_/.}"
  REQ="${2//_/.}"

  # shellcheck disable=SC2015
  (
    IFS='.' read -r -a V <<<"$VER"
    f_maj="${V[0]}" && f_min="${V[1]}" && f_ptc="${V[2]}" && f_upd="${V[3]}"
    IFS='.' read -r -a V <<<"$REQ"
    r_maj="${V[0]}" && r_min="${V[1]}" && r_ptc="${V[2]}" && r_upd="${V[3]:-"*"}"

    check_ver_num_start
    check_ver_num "$f_maj" "$r_maj" || return 1
    check_ver_num "$f_min" "$r_min" || return 1
    check_ver_num "$f_ptc" "$r_ptc" || return 1
    check_ver_num "$f_upd" "$r_upd" || return 1
    return 0
  ) && {
    check_ver_res="$VER"
    [[ "$mode" =~ "verbose" ]] && _log_i "\tfound: $check_ver_res => OK"
    return 0
  } || {
    [[ ! "$mode" =~ "quiet" ]] && _log_i "Version \"$2\" of program \"$1\" is not available (found: $VER)"
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

  [[ "$L" = "$R" ]] && return 0 || return 1
}

# checks if a version is equal or after another version
#
# $1: reference version
# $2: compare version
#
# please note that:
# - version suffixes (1.2.3-suffix) are ignored
# - "v" prefixes (v1.2.3) are ignored
#
# the function returns:
# - "0" (success) if reference version >= compare version
# - "1" (failure) if reference version < compare version
#
check_ver_ge() {
  VER=$1
  IFS='.' read -r -a ARR <<< "$2"
  MAJ="${ARR[0]}"
  [ "${MAJ:0:1}" = "v" ] && MAJ="${MAJ:1}"
  MIN="${ARR[1]}"
  PTC="${ARR[2]}"
  
  if check_ver "$VER" "$MAJ.$MIN.>=$PTC" "" "string" ||
     check_ver "$VER" "$MAJ.>$MIN.*" "" "string" ||
     check_ver "$VER" ">$MAJ.*.*" "" "string"; then
     return 0
  else
     return 1
  fi
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

if ! $SYS_IS_STDIN_A_TTY || $OS_WIN; then
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

#  Starts a cli command and applies compatibility workarouns if necessary
#  (this is the null implementation see below for the full one)
#
if "$OS_WIN" && command -v winpty &>/dev/null; then
  SYS_CLI_PRE() {
    if perl -e 'print -t STDOUT ? exit 0 : exit 1'; then
      "winpty" "$@"
    else
      "winpty" -Xallow-non-tty -Xplain "$@"
    fi
  }
else
  SYS_CLI_PRE() {
    "$@"
  }
fi


function ent-init-project-dir() {
  [ -f "$C_ENT_PRJ_FILE" ] && {
    _log_w "The project seems to be already initialized"
    ask "Should I init it again?" "n" || return 1
  }
  require_develop_checked
  _ent-npm init --yes
  _ent-npm link "$C_GENERATOR_JHIPSTER_ENTANDO_NAME"
  rm -rf package.json package-lock.json
  generate_ent_project_file
}

generate_ent_project_file() {
  ! grep -qs "^$C_ENT_STATE_FILE\$" .gitignore && {
    echo -e "\n########\n$C_ENT_STATE_FILE\n" >>".gitignore"
  }
  mkdir -p "$C_ENT_PRJ_ENT_DIR"

  if [ ! -f "$C_ENT_PRJ_FILE" ]; then
    echo "# ENT-PRJ / $(date -u '+%Y-%m-%dT%H:%M:%S%z')" > "$C_ENT_PRJ_FILE"
  fi

  camel_to_snake -d ENT_PRJ_NAME "$(basename "$PWD")"
  set_or_ask ENT_PRJ_NAME "" "Please provide the project name" "$ENT_PRJ_NAME"
  save_cfg_value ENT_PRJ_NAME "$ENT_PRJ_NAME" "$C_ENT_PRJ_FILE"
}

rescan-sys-env() {
  true
}

win_convert_existing_path_to_posix_path() {
  powershell "cd \"$1\" > \$null; bash -c 'pwd'"
}

win_convert_existing_posix_path_to_win_path() {
  (
    __cd "$1"
    RES="$("$ENTANDO_ENT_HOME/s/currdir.cmd" | sed 's/\\/\\\\/g')"
    [[ -z "$RES" ]] && _FATAL "Error converting \"$1\" to windows path"
    if [[ "$1" =~ ^.*/$ ]]; then
      echo "$RES\\\\"
    else
      echo "$RES"
    fi
  ) || exit 1
}

# Clones a git repository by handing also ent special cases and user communication
#
# $1:  URL TO CLONE
# $2:  TAG TO CHECKOUT
# $3:  local folder name
# $4:  human description of the cloned repository
# $5:  options

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
    ERRC="_log_w"
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
      # shellcheck disable=SC2143
      if [ -z "$(git tag | grep -F "$TAG" | grep "^$TAG\$" 2>/dev/null)" ]; then
        $ERRC "> Unable to find the tag or branch \"$TAG\" of package \"$DSC\""
        exit 91
      fi
      if ! git checkout -b "$TAG" "$TAG" 1>/dev/null; then
        $ERRC "> Unable to checkout tag or branch \"$TAG\" of package \"$DSC\""
        exit 92
      fi
    )
    local EC="$?"
    
    if [ "$EC" == 0 ]; then
      ! $ENTER && {
        cd - >/dev/null || $ERRC "Unable to return back to the original path"
      }
      return 0
    else
      cd - >/dev/null && {
        rm -rf "./${FLD:?}" 2>/dev/null
        return "$EC"
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
    _FATAL "Unable to enter dir \"$1\""
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
      _log_e "Unable to import the cfg from $src"
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
    _log_e "Unable to import the cfg from $src"
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
      _log_i "done"

      ask "Should I try to import the library?" && {
        _log_i "This may take a while"
        import_ent_library "$VER_TO_IMPORT" "copy" && {
          _log_i "done."
        }
      }
    }
  }
}

_strip_colors() {
  perl -pe 's/\e\[[0-9;]*m(?:\e\[K)?//g'
}

_trace() {
  local trace_id="$1"; shift
  # shellcheck disable=SC2076
  [[ " $CTRACE " =~ " $trace_id " ]] && debug-print "$*"
  "$@"
}

print_hr() {
  if "$SYS_IS_STDIN_A_TTY"; then
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | _perl_sed "s/ /${1:-~}/g"
  else
    printf '%*s\n' "${COLUMNS}" '' | _perl_sed "s/ /${1:-~}/g"
  fi
}

debug-print() {
  if $SYS_IS_STDOUT_A_TTY; then
    B() { echo -e '\033[101;37m'; }
    E() { echo -e '\033[0;39m'; }
  else
    B() { true; }
    E() { true; }
  fi  
  
  {    
    if [ "$1" == "--title" ]; then
      echo -e "$(B)### DEBUG ### $2"
      shift 2
    else
      echo -en "$(B) ### DEBUG ### "
    fi

    echo -e "$*$(E)"
  }>&2
}

_remove_broken_symlink() {
  find -L . -iname "$1" -type l -exec rm -- {} +
}

_dist_directory() {
  (
    __cd "$ENTANDO_ENT_HOME/../../dist"
    echo "$PWD"
  ) || _SOE
}

# STOP ON ERROR
#
# Options:
# --pipe N  checks the result of the part #N of a pipe expression, can be specified up to 3 times
#
# shellcheck disable=SC2120
_SOE() {
  local R="$?" PPS=("${PIPESTATUS[@]}")
  [ "$1" == "--pipe" ] && { shift; R="${PPS[$1]}"; shift; }
  [ "$R" = 0 ] && return 0
  [ "$1" == "--res-file" ] && {
    shift
    [ -f "$1" ] && {
      local tmp="$(mktemp)"
      cp "$1" "$tmp"
      echo ""
      echo "> An ERROR was detected ($R)"
      echo "> Full log available in this file: \"$tmp\""
      echo "> Tail of the log:"
      echo "~~~"
      tail -n 10 "$1"
      rm "$1"
    } 1>&2
    shift
  }
  exit "$R"
}

_print_npm_rc() {
  echo "//$ENTANDO_NPM_REGISTRY_NO_SCHEMA/:_authToken=$ENTANDO_NPM_REGISTRY_TOKEN_FOR_ANONYMOUS_ACCESS"
  echo "@entando:registry=$ENTANDO_NPM_REGISTRY"
}

_ent-setup_home_env_variables() {
  export ENTANDO_CLI_HOME_OVERRIDE="$(_dist_directory)/opt/home"
  mkdir -p "$ENTANDO_CLI_HOME_OVERRIDE"

  if [ "$SYS_OS_TYPE" = "windows" ]; then
    export ENTANDO_CLI_USERPROFILE_OVERRIDE="$(win_convert_existing_posix_path_to_win_path "$HOME")"
    [[ -z "$ENTANDO_CLI_ORIGINAL_USERPROFILE" ]] && export ENTANDO_CLI_ORIGINAL_USERPROFILE="$USERPROFILE"
    [[ "$ENTANDO_OPT_OVERRIDE_HOME_VAR" = "true" ]] && export USERPROFILE="$ENTANDO_CLI_USERPROFILE_OVERRIDE"
  else
    [[ -z "$ENTANDO_CLI_ORIGINAL_HOME" ]] && export ENTANDO_CLI_ORIGINAL_HOME="$HOME"
    [[ "$ENTANDO_OPT_OVERRIDE_HOME_VAR" = "true" ]] && export HOME="$ENTANDO_CLI_HOME_OVERRIDE"
  fi
}

_ent.extension-modules.list() {
  if [ -d "$ENTANDO_ENT_EXTENSIONS_MODULES_PATH" ]; then
  (
    cd "$ENTANDO_ENT_EXTENSIONS_MODULES_PATH" || exit 0
    # shellcheck disable=SC2010
    ls ent-* -p 2>/dev/null | grep -v / | sed 's/^ent-//'
  )
  fi
}

_ent.extension-module.is-present() {
  local module="$1";shift;
  local mod_script="${ENTANDO_ENT_EXTENSIONS_MODULES_PATH}/ent-${module}"
  [ -f "$mod_script" ]
}

_ent.extension-module.execute() {
  (
    local module="$1";shift;
    local mod_script="${ENTANDO_ENT_EXTENSIONS_MODULES_PATH}/ent-${module}"
    [ ! -f "$mod_script" ] && _FATAL "unable to find script \"$mod_script\" of extension module \"$module\""
    # shellcheck disable=SC2034
    ENTANDO_CLI_MODULE_NAME="$module"
    RUN() { _FATAL "unable to load extension module \"$module\" from script \"$mod_script\""; }
    # shellcheck disable=SC1090
    source "$mod_script"
    RUN "$@"
  )
}

_ent.sys.is-stdout-tty() {
  perl -e 'print -t STDOUT ? exit 0 : exit 1;'
}
