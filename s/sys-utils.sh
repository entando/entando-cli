# SYS-UTILS

SYS_UTILS_BASE_DIR=$PWD

# OS DETECT
OS_LINUX=false
OS_MAC=false
OS_WIN=false
OS_BSD=false
SYS_OS_UNKNOWN=false
case "$OSTYPE" in
  linux*)
    SYS_OS_TYPE="linux"
    OS_LINUX=true
    ;;
  "darwin")
    SYS_OS_TYPE="mac"
    OS_MAC=true
    ;;
  "cygwin" | "msys" | win*)
    SYS_OS_TYPE="win"
    OS_WIN=true
    ;;
  "freebsd" | "openbsd")
    SYS_OS_TYPE="bsd"
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
  [ "$(ip a s | grep "$1" | wc -l)" -gt 0 ] && return 0 || return 1
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
# > check_ver <program> <expected-semver-pattern> <program-params-for-showing-version> <mode>
check_ver() {
  local mode="$4"
  local err_desc="$5"
  _log_i 3 "Checking $1.."

  [[ "$mode" =~ "literal" ]] \
                             && VER=$(eval "$1 $3") \
                        || VER=$(eval "$1 $3 2>/dev/null")

  if [ $? -ne 0 ] || [ -z "$VER" ]; then
    [ -z "$err_desc" ] \
                       && _log_i 2 "Program \"$1\" is not available" \
                                                 || _log_i 2 "$err_desc"
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
    _log_i 2 "Version \"$2\" of program \"$1\" is not available (found: $VER)"
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

XCLI=""
$OS_WIN && {
  watch() {
    if [  "$1" == "-v" ]; then
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
    XCLI="winpty"
  }
}


return 0
