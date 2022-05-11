#!/bin/bash

QS.SET_DEFAULTS() {
  DESTROY_NAMESPACE=FALSE
  ENT_KUBECTL_CMD=""
  ENTANDO_INTERACTIVE="true"
  EDIT_MANIFEST=false
  ENTANDO_VM_REUSE=""
  WITH_HOSTNAME=false
  WITH_SINGLE_HOSTNAME=false
  FOUND=false
  ENTANDO_STANDARD_QUICKSTART=true
  OPT_OVERRIDE=""
  YES_OPT=""
}

# simple manifest helper
#
# $1 the command
# $2 the manifest file
# $* command specific params
#
# Examples:
# - set-configmap {yaml file} {configmap-file}"
# - set-cocoo-version {yaml file} {version}
#
manifest_helper() {
  CMD="$1"
  YAML_FILE="$2"
  
  stat "$YAML_FILE" &> /dev/null || { echo "Please provide an existing yaml file" 1>&2 && exit 1; }
  
  case "$CMD" in
    "set-configmap")
      CONFIGMAP_FILE="$3"
      stat "$CONFIGMAP_FILE" &> /dev/null || { echo "Please provide an exiting configmap file" 1>&2 && exit 1; }

      if grep "entando-k8s-controller-coordinator:" "$CONFIGMAP_FILE" &>/dev/null; then
        echo "Warning, the key \"entando-k8s-controller-coordinator\" in configmaps is ignored" 1>&2
      fi

      perl -p0e 's/(.*)apiVersion: v1.*\nkind: ConfigMap.*/\1/msg' "$YAML_FILE"
      cat "$CONFIGMAP_FILE"
      echo -n "---"
      perl -p0e 's/.*apiVersion: v1.*\nkind: ConfigMap.*?^---$//msg' "$YAML_FILE"
      ;;
    "set-cocoo-version")
      VER="$3"
      C="s|"
      C+="(image:\s.*)/entando-k8s-controller-coordinator:.*|"
      C+="\1/entando-k8s-controller-coordinator:$VER|"
      perl -pe "$C" "$YAML_FILE"
      ;;
    *)
      echo "Unknown command \"$CMD\""
      ;;
  esac
}

# shellcheck disable=SC2120
debug_trace_vars() {
  if [[ "$ENTANDO_DEBUG" -gt 0 || "$1" == "-f" ]]; then
    _pp \
      ENTANDO_RELEASE ENTANDO_RELEASES_FILES_STRUCTURE ENTANDO_CLI_VERSION \
      DESIGNATED_PROFILE DESIGNATED_KUBECONFIG DESIGNATED_DESIGNATED_KUBECTX \
      ENTANDO_NAMESPACE ENTANDO_APPNAME \
      ENTANDO_STANDARD_QUICKSTART ENTANDO_PRE_EXISTING K8S_TEMPLATE \
      ADDR VM_OPT WITH_HOSTNAME WITH_SINGLE_HOSTNAME \
      ENTANDO_DEBUG WITH_VM ENTANDO_OPT_YES_FOR_ALL ENTANDO_INTERACTIVE \
      JUST_SET_CFG \
      ENTANDO_VM_NAME ENTANDO_VM_CPU ENTANDO_VM_MEM ENTANDO_VM_DISK ENTANDO_VM_REUSE \
      ENTANDO_AUTO_HOSTNAME ENTANDO_CONFIGMAP_OVERRIDE_FILE ENTANDO_COCOO_VERSION_OVERRIDE EDIT_MANIFEST \
      ENT_KUBECTL_CMD
  fi
}


QS.PARSE_ARGS() {
  HH="$(parse_help_option "$@")"
  show_help_option "$HH"

  args_or_ask -h "$HH" -n -F "ENTANDO_PRE_EXISTING" \
    "--pre-existing///Assumes a pre-existing kubernetes and namespace, so doesn't create cluster resources and namespace" "$@"

  args_or_ask -h "$HH" -n "PROFILE" "--profile///Forces the quickstart to use the profile" "$@"

  if [ -z "$HH" ]; then
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    if ! $ENTANDO_PRE_EXISTING && [ -z "$ENT_KUBECTL_CMD" ]; then
      echo "~ STARTING QUICKSTART"
      ENTANDO_STANDARD_QUICKSTART=true
    else
      echo "~ STARTING NON-STANDARD QUICKSTART"
      ENTANDO_STANDARD_QUICKSTART=false
    fi
    echo "~ NAME OF THIS HOST: $(hostname)"
    echo "~ ARGUMENTS: $*"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  fi

  #-----------------------------------------------------------------------------------------------------------------------

  args_or_ask -h "$HH" -n -a "ENTANDO_NAMESPACE" "1/ext_id//The namespace" "$@"
  args_or_ask -h "$HH" -n -a "ENTANDO_APPNAME" "2/ext_id//The application name" "$@"
  args_or_ask -h "$HH" -n -p "ENTANDO_RELEASE" \
    "--release//$C_QUICKSTART_DEFAULT_RELEASE/the version tag of the release" "$@"
  args_or_ask -h "$HH" -n -p "ENTANDO_CLI_VERSION" "--cli-version///the version tag of CLI" "$@"
  args_or_ask -h "$HH" -n "ENTANDO_DEBUG" "--debug/num/0/if set to 1 shows debug information" "$@"
  args_or_ask -h "$HH" -n -F "WITH_VM" "--with-vm///starts in a VM instead of natively" "$@"
  args_or_ask -h "$HH" -n -F "ENTANDO_OPT_YES_FOR_ALL" "--yes///Assumes yes for all yes-no questions" "$@"
  args_or_ask -h "$HH" -n -p -F "ENTANDO_INTERACTIVE" \
    "--interactive///Explicitly tell to execute or not in interactive mode" "$@"
  args_or_ask -h "$HH" -n "ENTANDO_VM_NAME" \
    "--vm-name//$ENTANDO_NAMESPACE/The name of the VM (defaults to the namespace name)" "$@"
  args_or_ask -h "$HH" -n "ENTANDO_VM_CPU" "--vm-cpu///Number of CPUs" "$@"
  args_or_ask -h "$HH" -n "ENTANDO_VM_MEM" "--vm-mem/giga//VM memory, ex: 5G" "$@"
  args_or_ask -h "$HH" -n "ENTANDO_VM_DISK" "--vm-disk/giga//Disk space: ex: 15G" "$@"
  args_or_ask -h "$HH" -n -p -F "ENTANDO_VM_REUSE" "--vm-reuse///Allows the quickstart to reuse an existing VM" "$@"
  args_or_ask -h "$HH" -n -F "ENTANDO_AUTO_HOSTNAME" \
    "--auto-hostname///Automatically registers the VM hostname into the \"hosts\" file of the VM's host system" "$@"
  args_or_ask -h "$HH" -n "ENTANDO_COCOO_VERSION_OVERRIDE" \
    "--override-cocoo-version///Overrides the version of the controller coordinator with the supplied version" "$@"
  args_or_ask -h "$HH" -n "ENTANDO_CONFIGMAP_OVERRIDE_FILE" \
    "--override-configmap///Overrides the configmap with the supplied file content" "$@"
  args_or_ask -h "$HH" -n -p -F "ENTANDO_STANDARD_QUICKSTART" \
    "--standard///Forces the standard behaviour in case of special kubectl setup or pre-existing k8s targets" "$@"
  args_or_ask -h "$HH" -n "K8S_TEMPLATE" "--use-template///Forces the use of a specific manifest template type" "$@"
  args_or_ask -h "$HH" -n -p -F "EDIT_MANIFEST" \
    "--edit-manifest///Allows the user to manually customize the manifest yaml file" "$@"
  args_or_ask -h "$HH" -n -p "EDIT_MANIFEST" \
    "--edit-manifest-with///Allows the user to manually customize the manifest yaml file" "$@"
  args_or_ask -h "$HH" -n "OVERRIDE_DB_TYPE" \
    "--override-db-type///Forces the use of the given DB type" "$@"

  [ -n "$HH" ] && echo "" && exit 0
  
  _nn ENTANDO_NAMESPACE || FATAL "Please provide the namespace"
  _nn ENTANDO_APPNAME || FATAL "Please provide the appname"

  _nn ENTANDO_VM_CPU "4"
  _nn ENTANDO_VM_MEM "5G"
  _nn ENTANDO_VM_DISK "15G"
}

QS.PARSE_UNDOCUMENTED_ARGS() {
  args_or_ask -n -F "ENTANDO_NO_CHECK" "--no-check" "$@"
  args_or_ask -n -F "ENTANDO_NO_AUTO_ATTACH" "--no-auto-attach" "$@"
  args_or_ask -n -F "IN_QUICKSTART_VM" "--in-quickstart-vm///Tells quickstart the it's being run in a VM designed to run it" "$@"
  args_or_ask -n -F "ENTANDO_MOCK_TEST_RUN" "--use-mocks///enables the mocks" "$@"
  
  args_or_ask -n -F -- DESTROY_NAMESPACE "--destroy" "$@"
}

# Declare basic helper functions
#
# They are mostly wrappers intended to be mocked during the mocked test
#
QS.DECLARE_BASIC_HELPERS_FUNCTIONS() {
  ent-attach-vm() { ent attach-vm "$@"; }
  ent-check-env() { bash "$ENTANDO_ENT_HOME/bin/mod/ent-check-env" "$@"; }
  ent-app-info() { ent app-info "$@"; }
  ent-host() { ent host "$@"; }
  qs-edit-manifest() {
    if [ "$1" = "true" ]; then
      _edit "$2"
    elif [[ "$1" != "false" && "$1" != "" ]]; then
      "$1" "$2"
    fi
  }
  sourced-ent-profile-use() {
    # shellcheck disable=SC1091
    . ent profile use "$@"
  }
  ent-profile-new() {
    ent profile new "$@"
  }

  ent-profile-delete() {
    ent profile delete "$@"
  }

  ent-set-kubectl-cmd() {
    ent kubectl ent-set-cmd "sudo k3s kubectl"
  }

  ent-kubectl() {
    ent kubectl "$@"
  }
  
  $ENTANDO_MOCK_TEST_RUN && {
    . s/quickstart-mocks.sh
  }
}

QS.HANDLE-EDIT-MANIFEST-REQUEST() {
 qs-edit-manifest "$EDIT_MANIFEST" "w/$DEPL_SPEC_YAML_FILE"
}

QS.BASIC_ARGS_VALIDATION() {
  [[ -n "$ENTANDO_CONFIGMAP_OVERRIDE_FILE" && ! -f "$ENTANDO_CONFIGMAP_OVERRIDE_FILE" ]] &&
    FATAL "Unable to find override file \"$ENTANDO_CONFIGMAP_OVERRIDE_FILE\""

  ! $ENTANDO_INTERACTIVE && {
    ENTANDO_OPT_YES_FOR_ALL=true
    [[ -n "$EDIT_MANIFEST" && "$EDIT_MANIFEST" != "false" ]] &&
      FATAL "It's impossible to satisfy \"--edit-manifest\" or \"--edit-manifest-with\" due to non-interactive session"
  }
  
  if [ "$ENTANDO_RELEASE" != "$C_QUICKSTART_DEFAULT_RELEASE" ]; then
    assert_ver "ENTANDO_RELEASE" "$ENTANDO_RELEASE" || FATAL "Please provide a valid release tag"
  fi
  
  if "$ENTANDO_PRE_EXISTING"; then
    $WITH_VM && FATAL "Flag \"--pre-existing\" is incompatible with \"--with-vm\""
    $IN_QUICKSTART_VM && FATAL "Flag \"--pre-existing\" is incompatible with \"--in-quickstart-vm\""
  fi
}

QS.CREATE-NAMESPACE() {
  if [ "$DESTROY_NAMESPACE" = "true" ]; then
    reload_cfg
    prepare_for_privileged_commands
    ask "Should I destroy namespace \"$ENTANDO_NAMESPACE\" and contained app \"$ENTANDO_APPNAME\" ?" && {
      ent-kubectl delete namespace "$ENTANDO_NAMESPACE"
    }
  fi
  ent-kubectl create namespace "$ENTANDO_NAMESPACE"  
}

QS.LOAD_QS_PROFILE() {
  [ -z "$PROFILE" ] && return 0
  
  # shellcheck disable=SC1091
  sourced-ent-profile-use "$PROFILE" 2> /dev/null && {
    _log_i "Ent profile \"$PROFILE\" already exists, I will reuse it"
  }
}

QS.CREATE-QS-PROFILE() {
  $ENTANDO_NO_CHECK && return 0
  
  ent-profile-delete "qs-localhost" --yes
  ent-profile-new "qs-localhost" \
    "$ENTANDO_APPNAME" \
    "$ENTANDO_NAMESPACE" \
    --auto-use=false \
  ;
  sourced-ent-profile-use "qs-localhost"
  kubectl_mode --reset-mem --reset-cfg
  if $ENTANDO_STANDARD_QUICKSTART; then
    ent-set-kubectl-cmd "sudo k3s kubectl"
  fi
}

QS.RUN-ENT-CHECK-ENV() {
  $ENTANDO_NO_CHECK && return 0
  ! $ENTANDO_STANDARD_QUICKSTART  && return 0
  
  local YES_OPT=""
  $ENTANDO_OPT_YES_FOR_ALL && YES_OPT="--yes"
  
  if $WITH_HOSTNAME; then
    ent-check-env runtime --no-dns-fix ${YES_OPT:+"$YES_OPT"}
  else
    ent-check-env runtime ${YES_OPT:+"$YES_OPT"}
  fi
}


# determines the structure and conventions of the entando-releases repository
QS.DETERMINE_FILE_STRUCTURE() {
  local BASEREL="${ENTANDO_RELEASE/-*/}"
  if check_ver_ge "$BASEREL" "7.0.0"; then
    ENTANDO_RELEASES_FILES_STRUCTURE="v7"
  elif check_ver_ge "$BASEREL" "6.3.2"; then
    ENTANDO_RELEASES_FILES_STRUCTURE="v6new"
  else
    ENTANDO_RELEASES_FILES_STRUCTURE="v6old"
  fi
}


# HOSTNAME MODE ----
QS.TRY_SETUP_HOSTNAME_MODE() {
  if args_or_ask -n -p "ADDR" "--hostname/fdn?" "$@" ||
      args_or_ask -n -p "ADDR" "--hostname/dn?" "$@"; then
    if [ -n "$ADDR" ]; then
      FOUND=true
    else
      if $OS_WIN && $WITH_VM && [ -n "$ENTANDO_VM_NAME" ]; then
        # OS_WIN: derive the hostname from the
        ADDR="$ENTANDO_VM_NAME.$C_WIN_VM_HOSTNAME_SUFFIX"
        _log_i "Assuming hostname name: \"$ADDR\""
        assert_fdn "HOSTNAME" "$ADDR"
        FOUND=true
      else
        FATAL "Please provide an hostname"
      fi
    fi

    WITH_HOSTNAME=true
    WITH_SINGLE_HOSTNAME=true
    if $WITH_VM; then
      VM_OPT="--hostname=\"$ADDR\""
    fi
  fi
}

# AUTO HOSTNAME MODE ----
QS.TRY_SETUP_AUTO_HOSTNAME_MODE() {
  if $ENTANDO_AUTO_HOSTNAME; then
    if ! $WITH_HOSTNAME; then
      _log_i "Checking if user is admin (skippable with CTRL+C)"
      if ! $ENTANDO_INTERACTIVE; then
        ENTANDO_AUTO_HOSTNAME=false
        _log_i "Non-interactive mode, requested auto-hostname not granted"
      elif prepare_for_privileged_commands; then
        ENTANDO_AUTO_HOSTNAME=true
        _log_i "User is an admin, requested auto-hostname granted"
      else
        _log_i "User admin check failed, requested auto-hostname not granted"
      fi
    fi
  fi

  $ENTANDO_AUTO_HOSTNAME && {
    $WITH_HOSTNAME && FATAL "--hostname is not compatible with --auto-hostname"

    if $WITH_VM; then
      VM_OPT="--auto-hostname"
      WITH_HOSTNAME=true
      WITH_SINGLE_HOSTNAME=true
      FOUND=true
    else
      ADDR="$ENTANDO_VM_NAME.$C_AUTO_VM_HOSTNAME_SUFFIX"
      _log_i "Assuming hostname name: \"$ADDR\""
      assert_fdn "HOSTNAME" "$ADDR"
      FOUND=true
      WITH_HOSTNAME=true
      WITH_SINGLE_HOSTNAME=true
    fi
  }
}

# SIMPLE MODE ----
QS.TRY_SETUP_SIMPLE_MODE() {
  ! $WITH_HOSTNAME && args_or_ask -n -p ADDR "--simple/ip?" "$@" && {
    FOUND=true
    if $WITH_VM; then
      if [ -n "$ADDR" ]; then
        VM_OPT="--simple=\"$ADDR\""
      else
        VM_OPT="--simple"
      fi
    else
      [[ -z "$ADDR" ]] && ADDR="$(hostname -I | awk '{print $1}')"
    fi
  }
}

QS.TRY_SETUP_CUSTOM_MODE() {
  # CUSTOM MODE: FQDN ----
  ! $FOUND && args_or_ask -n -p "ADDR" "--custom/fdn" "$@" && {
    FOUND=true
    WITH_HOSTNAME=true
    WITH_SINGLE_HOSTNAME=false
    VM_OPT="--custom=\"$ADDR\""
  }
}

QS.FINALIZE_MODE() {
  ! $FOUND && {
    echo -e "Please provide a valid address mode option:" 1>&2
    echo "  --simple=[ADDR]    => standard installation with an existing ip" 1>&2
    echo "  --hostname=[FQDN]  => standard installation with an existing fully qualified domain name" 1>&2
    echo "  --auto-hostname    => standard installation with an full qualified domain name generated and stored in the hosts file" 1>&2
    echo "  --custom=[ADDR]    => automatically adds an IP on the OS (only netplan)" 1>&2
    echo "" 1>&2
    echo "NOTE: if \"ADDR\" is not provided one is automatically determined" 1>&2
    echo "" 1>&2
    exit 1
  }
  
  ENTANDO_SUFFIX="$ADDR"
  ! $WITH_HOSTNAME && ENTANDO_SUFFIX+=".nip.io"
}


determine_versioned_filename_old_ver() {
  local dst_var="$1"
  local base_template_name="$2"
  local template_variant="$3"
  _set_var "$dst_var" "${base_template_name}${template_variant:+".$template_variant"}"
}

determine_versioned_filename_new_ver() {
  local TEMPLATE=false;[ "$1" == "--template" ] && { TEMPLATE=true;shift; }
  local dst_var="$1"
  local base_template_name="$2"
  local template_variant="$3"

  if [ -n "$template_variant" ]; then
    local k8s_version_tag="${template_variant:+".$template_variant"}"
  else
    local k8s_version_tag="ge-1-1-6"
  fi
  if "$TEMPLATE"; then
    local res_type="plain-templates/base"
  else
    local res_type="namespace-scoped-deployment"
  fi
  _set_var "$dst_var" "${k8s_version_tag}/$res_type/${base_template_name}"
}


# -- NETWORKING CHECKS
QS.NET-SETUP-ANALYSIS() {
  if "$WITH_HOSTNAME"; then
    FQADDR="$ADDR"
    if $WITH_SINGLE_HOSTNAME; then
      SINGLE_HOSTNAME="$FQADDR"
    else
      SINGLE_HOSTNAME="~"
    fi

    _log_d "> Using domain: $ADDR"
  else
    FQADDR="$ADDR.nip.io"
    SINGLE_HOSTNAME="~"

    _log_d "> Using ip address: $ADDR"
  fi
}

QS.MANIFEST.GENERATE-FILE() {
  local MANIFEST_TEMPLATE_FILE
  local SETPLACEHOLDERS_FN
  case "$ENTANDO_RELEASES_FILES_STRUCTURE" in
    "v7")
      determine_versioned_filename_new_ver MANIFEST_TEMPLATE_FILE "namespace-resources.yaml" "$K8S_TEMPLATE"
      determine_versioned_filename_new_ver --template APP_MANIFEST_TEMPLATE_FILE "entando-app.yaml" "$K8S_TEMPLATE"
      SETPLACEHOLDERS_FN="QS.MANIFEST.v7.SET-PLACEHOLDERS"
      ;;
    "v6new")
      determine_versioned_filename_new_ver MANIFEST_TEMPLATE_FILE "${DEPL_SPEC_YAML_FILE}.tpl" "$K8S_TEMPLATE"
      SETPLACEHOLDERS_FN="QS.MANIFEST.v6.SET-PLACEHOLDERS"
      ;;
    *)
      determine_versioned_filename_old_ver MANIFEST_TEMPLATE_FILE "${DEPL_SPEC_YAML_FILE}.tpl" "$K8S_TEMPLATE"
      SETPLACEHOLDERS_FN="QS.MANIFEST.v6.SET-PLACEHOLDERS"
      ;;
  esac

  if [ -f "$ENTANDO_RELEASE_DIST_DIR/$MANIFEST_TEMPLATE_FILE" ]; then
    _log_i "> Selecting manifest template file \"$ENTANDO_RELEASE_DIST_DIR/$MANIFEST_TEMPLATE_FILE\""
  else
    FATAL "Unable to find manifest template file \"$ENTANDO_RELEASE_DIST_DIR/$MANIFEST_TEMPLATE_FILE\""
  fi

  _log_i "> Generating the kubernetes specification file \"w/$DEPL_SPEC_YAML_FILE\" for the deployment"
  
  echo -n "" > "w/$DEPL_SPEC_YAML_FILE"
  _nn APP_MANIFEST_TEMPLATE_FILE && {
    "$SETPLACEHOLDERS_FN" "$APP_MANIFEST_TEMPLATE_FILE" > "w/$DEPL_SPEC_YAML_FILE"
  }
  "$SETPLACEHOLDERS_FN" "$MANIFEST_TEMPLATE_FILE" >> "w/$DEPL_SPEC_YAML_FILE"

  _log_i "File \"w/$DEPL_SPEC_YAML_FILE\" generated"
}

QS.MANIFEST.v7.SET-PLACEHOLDERS() {
  local MANIFEST_TEMPLATE_FILE="$1"
  local APPVER="7.0"
  local REPLICA="1"
  local IMGTYPE="eap"
  local DB="${OVERRIDE_DB_TYPE:-"embedded"}"
  local ENTANDO_HOSTNAME="${SINGLE_HOSTNAME}"
  [ -z "$ENTANDO_HOSTNAME" ] || [ "$ENTANDO_HOSTNAME" = "~" ] && ENTANDO_HOSTNAME="$ENTANDO_APPNAME.$FQADDR"
  
  # shellcheck disable=SC2002
  cat "$ENTANDO_RELEASE_DIST_DIR/$MANIFEST_TEMPLATE_FILE" \
    | _perl_sed "s/{{ENTANDO_NAMESPACE}}/$ENTANDO_NAMESPACE/" \
    | _perl_sed "s/{{ENTANDO_APP_NAME}}/$ENTANDO_APPNAME/" \
    | _perl_sed "s/{{ENTANDO_HOSTNAME}}/$ENTANDO_HOSTNAME/" \
    | _perl_sed "s/{{ENTANDO_APP_IMAGE_TYPE}}/$IMGTYPE/" \
    | _perl_sed "s/{{ENTANDO_APP_REPLICAS}}/$REPLICA/" \
    | _perl_sed "s/{{ENTANDO_DBMS}}/$DB/" \
    | _perl_sed "s/{{ENTANDO_APP_VERSION}}/\"$APPVER\"/" \
    | _perl_sed "s/{{ENTANDO_VARS}}/null/" \
    ;
}

QS.MANIFEST.v6.SET-PLACEHOLDERS() {
  # shellcheck disable=SC2002
  local RES="$(
    cat "$ENTANDO_RELEASE_DIST_DIR/$MANIFEST_TEMPLATE_FILE" \
      | _perl_sed "s/PLACEHOLDER_ENTANDO_NAMESPACE/$ENTANDO_NAMESPACE/" \
      | _perl_sed "s/PLACEHOLDER_ENTANDO_APPNAME/$ENTANDO_APPNAME/" \
      | _perl_sed "s/PLACEHOLDER_ENTANDO_SINGLE_HOSTNAME/$SINGLE_HOSTNAME/" \
      | _perl_sed "s/PLACEHOLDER_ENTANDO_DOMAIN_SUFFIX/$FQADDR/" \
      ;
  )"

  if [ -n "$OVERRIDE_DB_TYPE" ]; then
    echo "$RES" | _perl_sed "s/dbms: .*/dbms: $OVERRIDE_DB_TYPE/g" "w/$DEPL_SPEC_YAML_FILE"
  else
    echo "$RES" 
  fi
}

QS.MANIFEST.APPLY-OVERRIDES() {
  if [ -n "$ENTANDO_CONFIGMAP_OVERRIDE_FILE$ENTANDO_COCOO_VERSION_OVERRIDE" ]; then
    local TGT_FILE="w/$DEPL_SPEC_YAML_FILE"
    local TMP_FILE="w/$DEPL_SPEC_YAML_FILE.tmp"

    # ConfigMap override
    [ -n "$ENTANDO_CONFIGMAP_OVERRIDE_FILE" ] && {
      _log_i "Applying the ConfigMap override"
      manifest_helper set-configmap \
        "$TGT_FILE" \
        "$ENTANDO_CONFIGMAP_OVERRIDE_FILE" \
        >"$TMP_FILE"
    }
    mv "$TMP_FILE" "$TGT_FILE"
    # CoCoo override
    [ -n "$ENTANDO_COCOO_VERSION_OVERRIDE" ] && {
      _log_i "Applying the Controller Coordinator override"
      manifest_helper set-cocoo-version \
        "$TGT_FILE" \
        "$ENTANDO_COCOO_VERSION_OVERRIDE" \
        >"$TMP_FILE"
    }
    mv "$TMP_FILE" "$TGT_FILE"
  fi
}

QS.INSTALL-CLUSTER-LEVEL-RESOURCES() {
  $ENTANDO_STANDARD_QUICKSTART && {
    ask "Should I register the Cluster Level Resources?" && {
      local CLUSTER_RESOURCES
      case "$ENTANDO_RELEASES_FILES_STRUCTURE" in
        "v6new"|"v7")
          determine_versioned_filename_new_ver CLUSTER_RESOURCES "cluster-resources.yaml" "$K8S_TEMPLATE";;
        *)
          determine_versioned_filename_old_ver CLUSTER_RESOURCES "crd" "$K8S_TEMPLATE";;
      esac
      
      ent-kubectl apply -f "$ENTANDO_RELEASE_DIST_DIR/$CLUSTER_RESOURCES"
    }
  }
}

QS.START-DEPLOYMENT() {
  ask "Should I start the deployment?" || return "$?"
  _sed_in_place "s/ingressHostName: ~//g" "w/$DEPL_SPEC_YAML_FILE"
  ent-kubectl apply -f "w/$DEPL_SPEC_YAML_FILE" -n "$ENTANDO_NAMESPACE"
}

QS.WATCH-DEPLOYMENT() {
  if ask "Should I start the monitor?"; then
    export ENTANDO_ENT_KUBECTL_CMD="$ENT_KUBECTL_CMD"
    ent-app-info watch || true
  else
    echo -e "\n~~~\nUse the command:\n  - ent app-info.sh watch\nto check the status of the app"
  fi
}

QS.REFRESH-ENVIRONMENT() {
  # shellcheck disable=SC1090 disable=SC1091
  [ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
  # shellcheck disable=SC2034
  [ -z "$ENT_KUBECTL_CMD" ] && DESIGNATED_KUBECONFIG=""
  setup_kubectl
}

#-----------------------------------------------------------------------------------------------------------------------
QS.VM.PROBE-VM() {
  _log_i "> Preflight checks"

  if multipass info "$ENTANDO_VM_NAME" &>/dev/null; then
    local err_msg="A VM named \"$ENTANDO_VM_NAME\" already exists"

    if [ -z "${ENTANDO_VM_REUSE}" ]; then
      _log_w "$err_msg"
      ! $ENTANDO_INTERACTIVE && FATAL "$err_msg"
      
      multipass info "$ENTANDO_VM_NAME"
      ask "Should I try reusing it?" || {
        EXIT_UE "$err_msg"
      }
    elif $ENTANDO_VM_REUSE; then
      _log_i "$err_msg and you choose to reuse it"
    else
      _log_w "${err_msg}"
      multipass info "$ENTANDO_VM_NAME"
      FATAL "$err_msg"
    fi
    multipass start "$ENTANDO_VM_NAME" || FATAL "VM can't be reused"
    LAUNCH_NEW_VM=false
  else
    LAUNCH_NEW_VM=true
  fi
}

QS.VM.CREATE-QS-PROFILE() {
  if ! $ENTANDO_NO_AUTO_ATTACH && [ -z "$PROFILE" ]; then
    ent-profile-delete "qs-$ENTANDO_VM_NAME" --yes
    ent-profile-delete "qs-$ENTANDO_VM_NAME" --yes
    ent-profile-new "qs-$ENTANDO_VM_NAME" \
      "$ENTANDO_APPNAME" \
      "$ENTANDO_NAMESPACE" \
      --auto-use=false \
    ;
    # shellcheck disable=SC1091
    sourced-ent-profile-use "qs-$ENTANDO_VM_NAME"
  fi
}

QS.VM.LAUNCH-VM() {
  [ "$ENTANDO_DEBUG" -gt 0 ] && VM_OPT+=" --debug=$ENTANDO_DEBUG"
  $ENTANDO_MOCK_TEST_RUN && VM_OPT+=" --use-mocks"

  $ENTANDO_OPT_YES_FOR_ALL && VM_OPT+=" --yes"
  ! $ENTANDO_INTERACTIVE && {
    VM_OPT+=" --interactive=false"
    VM_VAR="ENTANDO_OPT_YES_FOR_ALL=true"
  }

  #~ LAUNCH OR REUSE VM
  if $LAUNCH_NEW_VM; then
    _log_i "> Generating the base VM"
    multipass launch --name "$ENTANDO_VM_NAME" --cpus "$ENTANDO_VM_CPU" --mem "$ENTANDO_VM_MEM" --disk "$ENTANDO_VM_DISK"
  else
    _log_i "Trying to reuse the exiting base VM"
  fi
}

QS.VM.SEND-NECESSARY-FILES-TO-VM() {
  [ -n "$ENTANDO_CONFIGMAP_OVERRIDE_FILE" ] && {
    multipass copy-files "$ENTANDO_CONFIGMAP_OVERRIDE_FILE" "$ENTANDO_VM_NAME:/tmp/configmap-override-file"
  }
}

#~ INSTALL ENT IN THE VM
QS.VM.ON-VM.INSTALL-ENT() {
  _log_i "> Installing Ent on the VM"
  multipass exec "$ENTANDO_VM_NAME" -- bash -c "
    bash <(curl \"https://raw.githubusercontent.com/entando/entando-cli/$ENTANDO_CLI_VERSION/auto-install\") \
      --release=\"$ENTANDO_RELEASE\" --cli-version=\"$ENTANDO_CLI_VERSION\"
    "
}

QS.VM.DETERMINE-EXECUTION-ARGUMENTS() {
  OPT_OVERRIDE=""
  
  _nn ENTANDO_CONFIGMAP_OVERRIDE_FILE && {
    OPT_OVERRIDE+=" --override-configmap='/tmp/configmap-override-file'"
  }

  _nn ENTANDO_COCOO_VERSION_OVERRIDE && {
    OPT_OVERRIDE+=" --override-cocoo-version=$ENTANDO_COCOO_VERSION_OVERRIDE"
  }

  case "$EDIT_MANIFEST" in
    true) OPT_OVERRIDE+=" --edit-manifest" ;;
    "") ;;
    *) OPT_OVERRIDE+=" --edit-manifest-with='$EDIT_MANIFEST'" ;;
  esac
}

QS.VM.SETUP-HOST-DNS-WITH-HOSTMAME-IF-REQUESTED() {
  $ENTANDO_AUTO_HOSTNAME && {
    if prepare_for_privileged_commands; then
      _log_i "> Creating the hostname DNS \"$ENTANDO_VM_NAME\" on the hosts file"
      ent-host setup-vm-hostname "$ENTANDO_VM_NAME"
    else
      _log_w "> Unable to setup the hostname DNS \"$ENTANDO_AUTO_HOSTNAME\" on the hosts file"
      _log_w "> Please run \"ent host setup-vm-hostname \"$ENTANDO_VM_NAME\" manually"
    fi
  }
}

QS.VM.ON-VM.RUN-ENT-CHECK-ENV() {
  _log_i "> Checking the environment on the VM"
  if ! $ENTANDO_NO_CHECK; then
    local YES_OPT=""
    if $ENTANDO_OPT_YES_FOR_ALL; then
      YES_OPT="--yes"
    fi

    local OPT_DNS=""
    if $WITH_HOSTNAME; then
      OPT_DNS+="--no-dns-fix "
    fi

    multipass exec "$ENTANDO_VM_NAME" -- bash -c "
      cd \
      && source \".entando/ent/$ENTANDO_RELEASE/cli/$ENTANDO_CLI_VERSION/activate\" \
      && ent which \
      && $VM_VAR ent check-env runtime \
        ${YES_OPT:+"$YES_OPT"} \
        ${OPT_DNS:+"$OPT_DNS"}"
  fi
}

QS.VM.REGISTER-VM() {
  _log_i "> Registering the VM"
  map-set REMOTES "$ENTANDO_VM_NAME" "$ENTANDO_NAMESPACE/$ENTANDO_APPNAME/$ENTANDO_RELEASE"
  
  ! $ENTANDO_NO_AUTO_ATTACH && {
    ent-attach-vm "$ENTANDO_VM_NAME"
    save_cfg_value "DESIGNATED_VM_NAMESPACE" "$ENTANDO_NAMESPACE"
    save_cfg_value "ENTANDO_NAMESPACE" "$ENTANDO_NAMESPACE"
  }
}

QS.VM.ON-VM.START-QUICKSTART() {
  multipass exec "$ENTANDO_VM_NAME" -- bash -c "
    cd \
    && source \".entando/ent/$ENTANDO_RELEASE/cli/$ENTANDO_CLI_VERSION/activate\" \
    && ent quickstart $VM_OPT \"$ENTANDO_NAMESPACE\" \"$ENTANDO_APPNAME\" \
         --in-quickstart-vm \
         --release=\"$ENTANDO_RELEASE\" \
         --cli-version=\"$ENTANDO_CLI_VERSION\" \
        ${OPT_OVERRIDE:+"$OPT_OVERRIDE"} \
    "
}


QS.CHECKOUT-RELEASE() {
  ENTANDO_RELEASE_DIST_DIR="$ENTANDO_RELEASE_BASE_DIR/entando-releases/dist"
  (
    cd "$ENTANDO_RELEASE_BASE_DIR"
    git clone "https://github.com/entando/entando-releases" || _FATAL "Unable to download the release information"
    cd "entando-releases" || _FATAL "Unable to download the release information"
    git checkout "$ENTANDO_RELEASE" || _FATAL "Unable to find the release \"$ENTANDO_RELEASE\""
  ) || exit "$?"
}
