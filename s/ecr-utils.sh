#!/bin/bash
# ECR UTILS

#-----------------------------------------------------------------------------------------------------------------------
# Runs general operation to prepare running actions against the ECR
# $1: the received of the url to use for the action
# $2: the received of the authentication token to use for the action
#
ecr-prepare-action() {
  local VERBOSE=true; [ "$1" == "-s" ] && { VERBOSE=false; shift; }
  local var_url="$1"
  shift
  local var_token="$1"
  shift
  $VERBOSE && print_current_profile_info
  kube.utils.is_api_server_reachable || _FATAL -s "Unable to connect to the Entando application"
  # shellcheck disable=SC2034
  local main_ingress ecr_ingress ignored url_scheme
  app-get-main-ingresses url_scheme main_ingress ecr_ingress ignored
  [ -z "$main_ingress" ] && FATAL "Unable to determine the main ingress url (s1)"
  [ -z "$ecr_ingress" ] && FATAL "Unable to determine the ecr ingress url (s1)"
  case "$FORCE_URL_SCHEME" in
      "http")
        url_scheme=http
        ;;
      "https")
        url_scheme="https"
        ;;
  esac
  if [ -n "$url_scheme" ]; then
    main_ingress="$url_scheme://$main_ingress"
  fi
  [ -z "$main_ingress" ] && FATAL "Unable to determine the main ingress url (s2)"
  http-get-url-scheme url_scheme "$main_ingress"
  save_cfg_value LATEST_URL_SCHEME "$url_scheme"
  local token
  keycloak-get-token token "$url_scheme" "$TENANT_CODE"
  _set_var "$var_url" "$url_scheme://$ecr_ingress"
  _set_var "$var_token" "$token"
}

# Runs an ECR action for a bundle given:
# $1: the received of the of the http status
# $2: the http verb
# $3: the action
# $4: the ingress url
# $5: the authentication token
# $6: the bundle id
#
# returns:
# - the http status in $1
# - the http operation output in stdout
#
ecr-bundle-action() {
  local DEBUG=false; [ "$1" == "--debug" ] && DEBUG=true && shift
  local res_var="$1";shift
  local verb="$1";shift
  local action="$1";shift
  local ingress="$1";shift
  local token="$1";shift
  local bundle_id="$1";shift
  local tenant_code="$1";shift
  local raw_data="$1";shift
  
  local url
  path-concat url "${ingress}" ""
  url+="components"
  
  local http_status OUT

  [ -n "$bundle_id" ] && url+="/$bundle_id"
  [ -n "$action" ] && url+="/$action"

  local OUT="$(mktemp /tmp/ent-auto-XXXXXXXX)"

  # shellcheck disable=SC2155
  if "$DEBUG"; then
      local ERR="$(mktemp /tmp/ent-auto-XXXXXXXX)"
      local STATUS="$(mktemp /tmp/ent-auto-XXXXXXXX)"
      curl --insecure -o "$OUT" -sL -w "%{http_code}\n" -X "$verb" -v "$url" \
        -H 'Accept: */*' \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer $token" \
        -H "Origin: ${ingress}" \
        -H "X-ENTANDO-TENANTCODE: $tenant_code" \
        ${raw_data:+--data "$raw_data"} \
        1> "$STATUS" 2> "$ERR"
      
      # shellcheck disable=SC2155 disable=SC2034
      {
        local T_STATUS="$(cat "$STATUS")"
        local T_OUT="$(cat "$OUT")"
        local T_ERR="$(cat "$ERR")"
        _pp T_STATUS T_OUT T_ERR
      } > /dev/tty
      
    rm "$STATUS" "$ERR" "$OUT"
    return
  else
    http_status=$(
      curl --insecure -o "$OUT" -sL -w "%{http_code}\n" -X "$verb" -v "$url" \
        -H 'Accept: */*' \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer $token" \
        -H "Origin: ${ingress}" \
        -H "X-ENTANDO-TENANTCODE: $tenant_code" \
        ${raw_data:+--data "$raw_data"} \
        2> /dev/null
    )
  fi
  
  if [ "$res_var" != "%" ]; then
    if [ "$res_var" != "" ]; then
      _set_var "$res_var" "$http_status"
    fi
  else
    if [ "$http_status" -ge 300 ]; then
      echo "%$http_status"
      return 1
    fi
  fi
  
  if [ -s "$OUT" ]; then
    cat "$OUT"
  else
    if [ "$res_var" = "%" ]; then
      echo "%$http_status"
    fi
  fi
  rm "$OUT"
}

# Runs an ECR action for a bundle given:
# $1: the received of the of the http status
# $2: the http verb
#
ecr-watch-installation-result() {
  local action="$1";shift
  local ingress="$1";shift
  local token="$1";shift
  local bundle_id="$1";shift
  local tenant_code="$1";shift

  local http_res

  local start_time end_time elapsed
  start_time="$(date -u +%s)"

  echo ""

  while true; do
    http_res=$(
      ecr-bundle-action "%" "GET" "$action" "$ingress" "$token" "$bundle_id" "$tenant_code"
    )
    
    if [ "${http_res:0:1}" != '%' ]; then
      http_res=$(
        echo "$http_res" | _jq -r ".payload.status" 2> /dev/null
      )
  
      end_time="$(date -u +%s)"
      elapsed="$((end_time - start_time))"
      printf "\r                                  \r"
      printf "%4ds STATUS: %s.." "$elapsed" "$http_res"
    fi

    case "$http_res" in
      "INSTALL_IN_PROGRESS" | "INSTALL_CREATED" | "UNINSTALL_IN_PROGRESS" | "UNINSTALL_CREATED") ;;
      "INSTALL_COMPLETED")
        echo -e "\nTerminated."
        return 0
        ;;
      "UNINSTALL_COMPLETED")
        echo -e "\nTerminated."
        return 0
        ;;
      "INSTALL_ROLLBACK") ;;
      "INSTALL_ERROR")
        echo -e "\nTerminated."
        return 1
        ;;
      %*)
        echo -e "\nTerminated \"$http_res\""
        return 2
        ;;
      *)
        echo ""
        FATAL "Unknown status \"$http_res\""
        return 99
        ;;
    esac
    sleep 3
  done
}

#-----------------------------------------------------------------------------------------------------------------------
# Generates the and EntandoDeBundle CR given:
# $1: the name of the bundle
# $2: the bundle plugin repository address
# $3: the thumbnail file
# $4: the thumbnail url (alternative to $3)
#
ecr.generate-custom-resource() {
  local NAME="$1"
  local REPOSITORY="$2"
  local THUMBNAIL_FILE="$3"
  local THUMBNAIL_URL="$4"
  local TENANT_CODES="$5"
  if [ "$THUMBNAIL_FILE" == "<auto>" ]; then
    THUMBNAIL_FILE="$ENTANDO_ENT_HOME/$C_ENTANDO_LOGO_FILE"
  fi
  
  if [ -n "$THUMBNAIL_FILE" ]; then
    OPT="--thumbnail-file"
    OPT_VALUE="$THUMBNAIL_FILE"
  elif [ -n "$THUMBNAIL_URL" ]; then
    OPT="--thumbnail-url"
    OPT_VALUE="$THUMBNAIL_URL"
  fi
  
  if [[ "$REPOSITORY" = "docker://"* ]]; then
    ecr.docker.generate-cr "${REPOSITORY:9}" "$TENANT_CODES"
  else
    _ent-bundler from-git \
      --dry-run \
      ${NAME:+--name "$NAME"} \
      --repository "$REPOSITORY" \
      $OPT "$OPT_VALUE"
  fi
}

ecr.docker.generate-cr() {
  (
    REPO="$1"
    local TENANT_CODES="$2"
    local OVERWRITE_TENANTS="$3"
    local FORCE_OVERWRITE_TENANTS="$4"

    tmp="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm \"$tmp\"" exit

    if [ -n "$OVERWRITE_TENANTS" ] && [ -z "$FORCE_OVERWRITE_TENANTS" ]; then
      _ent-bundle generate-cr \
      -f -o "$tmp" 1>&2 \
      ${REPO:+--image "$REPO"} --tenants "$TENANT_CODES" "--overwriteTenants"
    fi
    if [ -n "$OVERWRITE_TENANTS" ] && [ -n "$FORCE_OVERWRITE_TENANTS" ]; then
      _ent-bundle generate-cr \
      -f -o "$tmp" 1>&2 \
      ${REPO:+--image "$REPO"} --tenants "$TENANT_CODES" "--overwriteTenants" "--forceOverwriteTenants"
    fi
    if [ -z "$OVERWRITE_TENANTS" ] && [ -n "$FORCE_OVERWRITE_TENANTS" ]; then
      _ent-bundle generate-cr \
      -f -o "$tmp" 1>&2 \
      ${REPO:+--image "$REPO"} --tenants "$TENANT_CODES" "--forceOverwriteTenants"
    fi
    if [ -z "$OVERWRITE_TENANTS" ] && [ -z "$FORCE_OVERWRITE_TENANTS" ]; then
      _ent-bundle generate-cr \
      -f -o "$tmp" 1>&2 \
      ${REPO:+--image "$REPO"} --tenants "$TENANT_CODES"
    fi

    cat "$tmp"
  )
}

#-----------------------------------------------------------------------------------------------------------------------
# Calculates the bundle id given:
# $1: the receiver var
# $2: the name of the bundle
# $3: the bundle artifact repository url
#
# if $2 is not provided it is taken from the repository
#
ecr.calculate-bundle-id() {
  local _tmp_RESVAR="$1"
  local REPOSITORY="$2"
  local _tmp
  NONNULL REPOSITORY
  [ "$VERBOSE" == "true" ] && _pp REPOSITORY 1>&2
  _tmp="$(echo -n "$REPOSITORY" | _perl_sed 's|^[^:]*://||' | _sha256sum)"
  _tmp="${_tmp:0:8}"
  [ "${#_tmp}" -gt 200 ] && {
    _tmp="${_tmp:0:200}"
  }
  _set_var "$_tmp_RESVAR" "$_tmp"
}

#-----------------------------------------------------------------------------------------------------------------------
# Calculates the plugin id given:
# $1: the receiver var
# $2: the bundle deployment base name
# $3: the plugin id
#
# if $2 is not provided it is taken from the repository
#
ecr.calculate-plugin-code() {
  local _tmp_RESVAR="$1"
  local PLUGIN_NAME="$2"
  local BUNDLE_ID="$3"
  local _tmp
  NONNULL PLUGIN_NAME BUNDLE_ID
  _tmp="pn-${BUNDLE_ID}-${PLUGIN_NAME}"
  _tmp="$(echo -n "$PLUGIN_NAME" | _sha256sum)"
  _tmp="${_tmp:0:8}"
  _tmp="pn-${BUNDLE_ID}-${_tmp}-$(kube.utils.url_path_to_identifier "$PLUGIN_NAME")"
  [ "${#_tmp}" -gt 200 ] && _FATAL -s "Resulting PLUGIN_ID exceeded the max length of 200 chars (+$((${#_tmp}-200)))"
  _set_var "$_tmp_RESVAR" "$_tmp"
}

#-----------------------------------------------------------------------------------------------------------------------
_ecr_determine_git_bundle_plugin_name() {
    local _tmp_RES="$(
    local BUNDLE_PUB_REPO="$2" BUNDLE_VERSION="$3"

    if [ "$BUNDLE_PUB_REPO" != "." ]; then
      local TMPDIR="$(mktemp -d)"
      # shellcheck disable=SC2064
      trap "rm -rf \"$TMPDIR\"" exit
      cd "$TMPDIR" || _FATAL "Unable to enter workdir" 1>&2
      git clone "$BUNDLE_PUB_REPO" tmpclone &>/dev/null || _FATAL "Unable to clone the given repository" 1>&2
      cd tmpclone || _FATAL "Unable to enter clonedir" 1>&2
      if _nn BUNDLE_VERSION; then
        git checkout "$BUNDLE_VERSION" &>/dev/null || _FATAL "Unable clone the given version" 1>&2
      fi
    else
      cd bundle || _FATAL "Unable to enter bundle dir" 1>&2
    fi

    local desc="$(find plugins -maxdepth 1 -type f | head -1)"
    # shellcheck disable=SC2002
    local RES=$(grep "deploymentBaseName:[[:space:]]*" < "$desc" | tr -d '"' | tr -d \"\'\" | sed 's/deploymentBaseName:[[:space:]]\([^:]*\).*/\1/')
    [ -z "$RES" ] && {
      RES=$(grep "image:[[:space:]]*" < "$desc" | tr -d '"' | tr -d \"\'\" | sed 's/image:[[:space:]]\([^:]*\).*/\1/')
    }

    echo "$RES"
  )"
  _nn _tmp_RES || exit 1
  _set_var "$1" "$_tmp_RES"
}

#-----------------------------------------------------------------------------------------------------------------------
# Generates and prints the skeleton of a plugin secret given:
# $1: the bundle id
# $2: the secret name
# $3: if "true" asks to interactively edit the secret before printing
#
ecr.generate-and-print-secret() {
  local SEC_NAME="$1"
  local BUNDLE_ID="$2"
  local EDIT="$3"
  local SAVE_TO="$4"
  local APPLY="$5"
  if [ "$EDIT" = "true" ]; then
    if ! "$SYS_IS_STDIN_A_TTY" || ! "$SYS_IS_STDOUT_A_TTY"; then
      _FATAL -s "Edit not allowed with non-tty stdin or stdout"
    fi
  fi
  
  (
    tmp="$(mktemp).zip"
    # shellcheck disable=SC2064
    trap "rm \"$tmp\"" exit
    {
      echo "kind: Secret"
      echo "apiVersion: v1"
      echo "metadata:"
      echo "  name: ${BUNDLE_ID}-${SEC_NAME}"
      echo "stringData:"
      echo "  key: value"
      echo "type: Opaque"
    } > "$tmp"
    [ "$EDIT" = "true" ] && _edit "$tmp"
    if _nn SAVE_TO; then
      cat "$tmp" > "$SAVE_TO"
    else
      cat "$tmp"
    fi
    [ "$APPLY" = "true" ] && _kubectl apply -f "$tmp"
  )
}

# Installs a bundle given its id
#
# $1: the bundle id
# $2: the version to install
# $3: the conflict strategy
#
ecr.install-bundle() {
  local BUNDLE_NAME="$1"; shift
  local VERSION_TO_INSTALL="${1:-latest}"
  local CONFLICT_STRATEGY="${2}"
  local TENANT_CODE="${3}"
  local MSGPRE="Installation of bundle \"$BUNDLE_NAME\""
  local INGRESS_URL TOKEN
  ecr-prepare-action INGRESS_URL TOKEN
  local DATA="{\"version\":\"$VERSION_TO_INSTALL\""
  
  if [ -n "$CONFLICT_STRATEGY" ]; then
    assert_ext_ic_id "CONFLICT_STRATEGY" "$CONFLICT_STRATEGY" fatal
    DATA+=",\"conflictStrategy\":\"$CONFLICT_STRATEGY\""
  fi  
  DATA+="}"

  [[ -n $TENANT_CODE ]] && _log_i "Installing $BUNDLE_NAME on $TENANT_CODE"

  local RV
  ecr-bundle-action RV "POST" "install" "$INGRESS_URL" "$TOKEN" "$BUNDLE_NAME" "$TENANT_CODE" "$DATA" &>/dev/null

  case "$RV" in
    2*)
      _log_i "$MSGPRE started"
      ecr-watch-installation-result "install" "$INGRESS_URL" "$TOKEN" "$BUNDLE_NAME" "$TENANT_CODE"
      ;;
    401)
      _FATAL -s "$MSGPRE failed because authentication is required but none was found in the request"
      ;;
    403)
      _FATAL -s "$MSGPRE failed because the request was not authorized"
      ;;
    409)
      _FATAL -s "$MSGPRE failed because it already exists in the remote entando application"
      ;;
    *)
      _FATAL -s "$MSGPRE failed with status \"$RV\""
      ;;
  esac
}
