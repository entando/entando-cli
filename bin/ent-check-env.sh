#!/bin/bash

H() {
  if [ "$1" == "short" ]; then
    echo -e "Checks the environment for required dependencies and settings | Syntax: ${0##*/} [--lenient] <env-type>"
  else
    echo -e "Checks the environment for required dependencies and settings\nSyntax: ${0##*/} [--lenient] <env-type>"
    echo -e "--lenient:\n    don't fail if a required dependency or setting is missing"
    echo "env-type:"
    grep '#''H:' "$0" | sed 's/[[:space:]]*\(.*\))[[:space:]]*#''H:\(.*\)/  - \1: \2/'
  fi
}

[ "$1" = "-h" ] && {
  { [ "$2" != "--short" ] && H "full" && exit 0; } || { H "short" && exit 0; }
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
cd "$DIR/.." || {
  echo "Internal error: unable to find the script source dir" 1>&2
  exit
}

. s/_base.sh

if [ "$1" == "--lenient" ]; then
  shift
  MAYBE_FATAL() {
    prompt "Recommended dependency not found, some tool may not work as expected.\nPress enter to continue.."
  }
else
  MAYBE_FATAL() { FATAL "$@"; }
fi

M_DEVL=false
M_KUBE=false
M_QS=false
case $1 in
  develop) #H: environment for bundle developers
    M_DEVL=true ;;
  runtime) #H: kubernetes execution environment
    M_KUBE=true ;;
  qs-runtime) #H: kubernetes execution environment for the quickstart
    ask "I need to alter your resolv.conf. Can I proceed?" || FATAL "Quitting"
    M_KUBE=true
    M_QS=true
    ;;
  all) #H: all checks
    M_DEVL=true
    M_KUBE=true
    ;;
  *) H && exit 0 ;;
esac
shift

# PRE
$M_DEVL && {
  cd "$ENTANDO_ENT_ACTIVE" || FATAL "Unable to switch to dir \"$ENTANDO_ENT_ACTIVE\""
  mkdir -p "lib/node"
}


# MISC

check_ver "git" "*.*.*" "--version | head -n 1" || MAYBE_FATAL "Quitting"
check_ver "sed" "*.*.*" "--version | head -n 1" || MAYBE_FATAL "Quitting"
check_ver "awk" "*.*.*" "--version | head -n 1" || MAYBE_FATAL "Quitting"
check_ver "grep" "*.*.*" "--version | head -n 1" || MAYBE_FATAL "Quitting"
check_ver "cat" "*.*.*" "--version | head -n 1" || MAYBE_FATAL "Quitting"
$M_DEVL && {
  [ -z "$VER_JDK_REQ" ] && VER_JDK_REQ="11.*.*"
  check_ver "java" "$VER_JDK_REQ" "-version 2>&1 | head -n 1 | awk '{gsub(/\"/, \"\", \$3);print \$3}'" || MAYBE_FATAL "Quitting"
}
$M_KUBE && { check_ver "hostname" "*.*.*" "--version | head -n 1" || MAYBE_FATAL "Quitting"; }
$M_KUBE && { check_ver "dig" "*.*.*" "-v 2>&1" literal || MAYBE_FATAL "Quitting"; }
check_ver "curl" "*.*.*" "--version | head -n 1" || MAYBE_FATAL "Quitting"
$M_DEVL && {
  check_ver "watch" "*.*.*" "-v" || {
    prompt "Recommended dependency not found, some tool may not work as expected.\nPress enter to continue.."
  }
}

# DNS
$M_QS && {
  make_safe_resolv_conf
}

$M_KUBE && {
  _log_i 1 "Checking DNS"

  dns_state="$(s/check-dns-state.sh)"

  case ${dns_state:-""} in
    "full")
      true
      ;;
    "no-dns")
      _log_e 1 "SEVERE: This system appears to have no DNS."
      ask "Do you what to process anyway?" || FATAL "Quitting"
      ;;
    "filtered[RR]")
      _log_e 1 "SEVERE: DNS query for local adresses appears to be actively filtered."
      ask "Do you what to process anyway?" || FATAL "Quitting"
      ;;
    "filtered[R]")
      if $M_QS; then
        _log_e 1 "SEVERE: Your DNS server appears to implement DNS rebinding protection, preventing queries like 192.168.1.1.nip.io to work."
        ask "Workaround doesn't seem to work. Do you want to proceed anyway?" || FATAL "Quitting"
      else
        _log_e 1 "SEVERE: Your DNS server appears to implement DNS rebinding protection, preventing queries like 192.168.1.1.nip.io to work."
        ask "Should alter the resolv.conf?" && {
          make_safe_resolv_conf
        }
      fi
      ;;
    "*")
      _log_e 1 "SEVERE: Unable to precisely determine the status of the DNS."
      ask " Do you what to proceed anyway?" || FATAL "Quitting"
      ;;
  esac
}

# NVM
$M_DEVL && {
  nvm_activate
  check_ver "nvm" "$VER_NVM_REQ" "--version | grep -v '^$' | head -1" verbose || {
    $OS_WIN && FATAL "Please install nvm for windows (nvm-windows)"
    ask "Should I try to install it?" && {
      curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$VER_NVM_DEF/install.sh" | bash
    } || {
      MAYBE_FATAL "Mandatory dependency not available"
    }
  }
  nvm_activate
}

rescan-sys-env force

# NODE
$M_DEVL && {
  _log_i 1 "Checking node.."
  FOUND=""
  CURRENT="$(node -v)"
  PREFERRED="$VER_NODE_DEF"
  #VERSIONS="$(nvm ls --no-colors --no-alias | sed 's/[^v]*\(v\S*\).*/\1/' | grep -v system | grep -v $CURRENT)"
  if $OS_WIN; then
    VERSIONS="$(
      nvm ls | grep '^\s\+v.*$' \
        | grep -v system | grep -v "$CURRENT" | grep -v "$PREFERRED" \
        | sed 's/[^v]*\(v\S*\).*/\1/'
     )"
  else
    VERSIONS="$(
      nvm ls --no-colors --no-alias | grep '^\s\+v.*$' \
        | grep -v system | grep -v "$CURRENT" | grep -v "$PREFERRED" \
        | sed 's/[^v]*\(v\S*\).*/\1/'
     )"
  fi

  VERSIONS="$VERSIONS $CURRENT $PREFERRED"

  for ver in $VERSIONS; do
    if check_ver "echo" "$VER_NODE_REQ" "\"$ver\"" "quiet"; then
      FOUND=$ver
    else
      _log_d 2 "\t- version \"$ver\" doesn't satisfy the requirements"
    fi
  done

  if [ "$FOUND" != "" ]; then
    _log_i 0 "\tfound suitable node version $FOUND"
    DESIGNATED_NODE_VERSION="$FOUND"
    save_cfg_value "DESIGNATED_NODE_VERSION" "$DESIGNATED_NODE_VERSION"
    activate_designated_node
  else
    _log_w 0 "No suitable version of node was found"
    if ask "Should I try to install it?"; then
      _nvm install "$VER_NODE_DEF"
      _nvm use "$VER_NODE_DEF"
    else
      MAYBE_FATAL "Mandatory dependency not available"
    fi
  fi
}

# ENT-LOCAL-JHIPSTER installation
$M_DEVL && {
  check_ver "ent-jhipster" "$VER_JHIPSTER_REQ" "--ent-no-envcheck -V 2>/dev/null | grep -v INFO" verbose "ENT private jhipster installation is not available" || {
    if ask "Should I try to install it?"; then
      ent-npm install generator-jhipster@$VER_JHIPSTER_DEF
    else
      MAYBE_FATAL "Mandatory dependency not available"
    fi
  }
}

# ENTANDO-GENERATOR-JHIPSTER (entando blueprint)
$M_DEVL && {
  _log_i 3 "Checking ENT installation of generator-jhipster-entando.."

  cd "$ENTANDO_ENT_ACTIVE" || FATAL "Unable to switch to dir \"$ENTANDO_ENT_ACTIVE\""

  if [ -d "lib/generator-jhipster-entando/$VER_GENERATOR_JHIPSTER_ENTANDO_REQ/" ]; then
    _log_i 3 "\tfound: $VER_GENERATOR_JHIPSTER_ENTANDO_REQ => OK"
  else
    _log_i 2 "Version \"$VER_GENERATOR_JHIPSTER_ENTANDO_REQ\" of \"generator-jhipster-entando\" was not found"

    if ask "Should I try to install it?"; then
      mkdir -p "lib/generator-jhipster-entando/"
      cd "lib/generator-jhipster-entando/"
      git clone "$C_ENTANDO_BLUEPRINT_REPO" "$VER_GENERATOR_JHIPSTER_ENTANDO_DEF"
      cd "$VER_GENERATOR_JHIPSTER_ENTANDO_DEF"
      git checkout -b "$VER_GENERATOR_JHIPSTER_ENTANDO_DEF" "$VER_GENERATOR_JHIPSTER_ENTANDO_DEF" || {
        FATAL "Unable to checkout version $VER_GENERATOR_JHIPSTER_ENTANDO_DEF of generator-jhipster-entando"
      }
      _npm install
      ent-npm install .
    else
      MAYBE_FATAL "Mandatory dependency not available"
    fi
  fi
  cd - > /dev/null
}

$M_KUBE && {
  if check_ver "k3s" "$VER_K3S_REQ" "--version 2>/dev/null | sed 's/k3s version \(.*\)+k.*/\1/'"; then
    _log_i 3 "\tfound: $check_ver_res => OK"
  else
    if ask "Should I try to install it?"; then
      curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$VER_K3S_DEF" sh -
    else
      prompt "Recommended dependency not found, some tool may not work as expected.\nPress enter to continue.."
    fi
  fi
}

$M_DEVL && {
  save_cfg_value "WAS_DEVELOP_CHECKED" "true"
}
