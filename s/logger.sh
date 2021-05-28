#!/bin/bash

# License
# The author has placed this work in the Public Domain, thereby relinquishing
# all copyrights. Everyone is free to use, modify, republish, sell or give away
# this work without prior consent from anybody.

# This software is provided on an "as is" basis, without warranty of any
# kind. Use at your own risk! Under no circumstances shall the author(s) or
# contributor(s) be liable for damages resulting directly or indirectly from
# the use or non-use of this software.

XU_LOG_LEVEL=3
#XU_ENABLED_LOG_TYPES="EWIDT"
XU_ENABLED_LOG_TYPES="EWID"

__log() { #NOTRACE
  TP=$1 && shift
  SY=$1 && shift
  LL=$1 && shift
  [[ ! "$LL" =~ ^[0-9]+$ ]] && {
    echo -e "➤ Logging instruction failed do to invalid log level provided" 1>&2 
    print_calltrace 1 1>&2
    return 0
  }
  [[ ! $XU_ENABLED_LOG_TYPES =~ $TP ]] && return 0
  [[ $XU_LOG_LEVEL -lt $LL ]] && return 0
  
  local HCOL=''
  local NCOL='\033[0;39m';
  
  if "${ENTANDO_IS_TTY:-false}"; then
    case $TP in
      I) HCOL='\033[41m\033[1m';;
      W) HCOL='\033[40m\033[1;33m';;
    esac
  fi
  
  if [ -n "$HCOL" ]; then
    echo -e "➤ $(echo -e "$HCOL")$SY | $(date +'%Y-%m-%d %H-%M-%S') | $*$(echo -e "$NCOL")"
  else
    echo -e "➤ $SY | $(date +'%Y-%m-%d %H-%M-%S') | $*"
  fi
}

_log_e() {
  __log "E" "[E]" "$@" 1>&2
}

_log_w() {
  __log "W" "[W]" "$@"
}

_log() {
  __log "T" "[T]" "$@"
}

_log_i() {
  __log "I" "[I]" "$@"
}

_log_d() {
  __log "D" "[D]" "$@"
}

_log_enable_types() {
  [ "$1" == "all" ] && XU_ENABLED_LOG_TYPES="EWIDT" && return
  [ -n "$1" ] && XU_ENABLED_LOG_TYPES="${1^^}"
}

_log_set_level() {
  [ -n "$1" ] && XU_LOG_LEVEL="$1"
}
