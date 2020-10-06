[ -z $ZSH_VERSION ] && [ -z $BASH_VERSION ] && echo "Unsupported shell, user either bash or zsh" 1>&2 && exit 99

[ "$ENTANDO_ENT_ACTIVE" = "" ] && echo "No ent instance is currently active" && exit 99

ENT_HOME="$PWD"
mkdir -p "$ENTANDO_ENT_ACTIVE/w"

nvm_activate() {
  NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || return
  export NVM_DIR
}

# TRAPS
function backtrace() {
  xu_get_status
  if [ "$XU_RES" != "FATAL" ] && [ "$XU_RES" != "USER-ERROR" ] && [ "$XU_RES" != "EXIT" ]; then
    n=${#FUNCNAME[@]}

    echo "" 2>&1
    echo "~~~" 2>&1
    echo -e "> Error detected in: function \"${FUNCNAME[1]}\" and position $(caller), backtrace:" 2>&1

    for ((i = 0; i < $((n - 1)); i++)); do
      printf '%*s' "$((i * 2 + 2))" ' ' 2>&1
      echo "${BASH_SOURCE[$((i))]}:${BASH_LINENO[$((i))]}" 2>&1
    done

    xu_set_status "EXIT"
  fi
}

set -o errtrace
trap backtrace ERR

# UTILS
. s/utils.sh
. s/sys-utils.sh
. s/var-utils.sh
. s/logger.sh

# ENVIRONMENT
$SYS_OS_UNKNOWN && FATAL "Unsupported operating system"

mkdir -p "$ENTANDO_ENT_ACTIVE/w"
mkdir -p "$ENTANDO_ENT_ACTIVE/d"
mkdir -p "$ENTANDO_ENT_ACTIVE/lib"

. s/_conf.sh

ENT_RUN_TMP_DIR=$(mktemp /tmp/ent.run.XXXXXXXXXXXX)
[[ ! "$ENT_RUN_TMP_DIR" =~ /tmp/ ]] && {
  # keep this as simple as possible, only native commands
  echo "Internal Error: Unable to create the tmp dir" 2>&1
  exit 99
}

exit-trap() {
  xu_get_status
  sz=$(stat -c "%s" "$ENT_RUN_TMP_DIR")

  if [ "$sz" -eq 0 ] || { [ "$XU_RES" != "FATAL" ] && [ "$XU_RES" != "USER-ERROR" ]; }; then
    [[ ! "$ENT_RUN_TMP_DIR" =~ /tmp/ ]] && {
      # keep this as simple as possible, only native commands
      echo "Internal Error: Detected invalid tmp dir" 2>&1
      exit 99
    }

    rm -rf "$ENT_RUN_TMP_DIR"
  else
    echo "---"
    echo "[EXIT-TRAP] Execution info are available under: \"$ENT_RUN_TMP_DIR\""
    echo ""
  fi
}
trap exit-trap EXIT
