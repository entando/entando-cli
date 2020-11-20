#!/bin/bash

# shellcheck disable=SC2034
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
. s/essentials.sh

ENTANDO_NAMESPACE="$1"
[ "$ENTANDO_NAMESPACE" == "" ] && echo "please provide the namespace name" 1>&2 && exit 1
shift

ENTANDO_APPNAME="$1"
[ "$ENTANDO_APPNAME" == "" ] && echo "please provide the app name" 1>&2 && exit 1
shift

if [ -n "$start_time" ]; then
  start_time="$1"
  now="$(date -u +%s)"
  elapsed="$((now-start_time))"
  elapsed_mm="$((elapsed/60))"
  elapsed_ss="$((elapsed-elapsed_mm*60))"
fi

RUN() {
  INGR=$(_kubectl get ingress -n "$ENTANDO_NAMESPACE" 2>/dev/null)

  # shellcheck disable=SC2015
  $SYS_GNU_LIKE && {
    DISKFREE="$(df . -h | tail -n 1 | awk '{print $4}')"
    MM="$(free -k -t | grep "Mem")"
    MMT="$(echo "$MM" | awk '{print $2}')"
    MMU="$(echo "$MM" | awk '{print $3}')"
    MEMFREE="$(((MMT-MMU)/1048576))G"
    true
  } || {
    DISKFREE="N/A"
    MEMFREE="N/A"
  }

  ingr_check "KC " "kc-ingress" "auth/"
  ingr_check "ECI" "eci-ingress" "k8s/"
  # shellcheck disable=SC2015
  ingr_check "APP" "$ENTANDO_APPNAME-ingress" "app-builder/" && {
    [ -z "$ENTANDO_APP_ADDR" ] && ENTANDO_APP_ADDR="$LAST_INGR_ADDR_CHECKED"
    echo ''
    echo '| '
    echo '|   █████████████████'
    echo '| '
    echo '|         READY      '
    echo '| '
    echo '|   █████████████████'
    echo '| '
    echo '|  The Entando app is ready at the address:'
    echo '| '
    echo -e "|\t$ENTANDO_APP_ADDR"
    echo '|'
    true
  } || {
    echo ''
    echo '| '
    echo '|   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒'
    echo '| '
    echo '|       NOT READY    '
    echo '| '
    echo '|   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒'
    echo '| '
if [ -n "$start_time" ]; then
    echo -e "|   - Elapsed time:  ${elapsed_mm}m${elapsed_ss}s"
fi
    echo -e "|   - Free Disk:     $DISKFREE"
    echo -e "|   - Free Mem:      $MEMFREE"
    echo '|'
    true
  }

  echo -e "\n~~~\n"

  _kubectl get pods -n "$ENTANDO_NAMESPACE"
}

ingr_check() {
  ADDR="$(echo "$INGR" | grep "$2" | awk '{print $3}')"
  [ -z "$ADDR" ] && {
    echo "> $1 entrypoint not registered.."
    return 1
  }
  echo -n "> $1 entrypoint is registered.."
  LAST_INGR_ADDR_CHECKED="http://$ADDR/$3"
  http_check "$LAST_INGR_ADDR_CHECKED" || true

  if [ -n "$ADDR" ] && [ "$http_check_res" != "000" ]; then
    echo -n " open.."

    T="\t(http://$ADDR/$3)"

    case "$http_check_res" in
    2* | 401) echo -e " AND READY $T" && return 0 ;;
    000 | 4* | 503) echo -e " but not ready ($http_check_res) $T" && return 1 ;;
    5*) echo -e " AND IN ERROR ($http_check_res) $T" && return 1 ;;
    *) echo -e " AND IN UNEXPECTED STATUS ($http_check_res) $T" && return 1 ;;
    esac
  else
    echo " but it's still closed.."
    false
  fi
}

http_check() {
  http_check_res=$(curl --write-out '%{http_code}' --silent --output /dev/null "$1")

  case "$http_check_res" in
  2*) return 0 ;;
  *) return 1 ;;
  esac
}

RUN
