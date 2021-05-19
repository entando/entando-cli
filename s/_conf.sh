#!/bin/bash
# shellcheck disable=SC2034

REPO_GENERATOR_JHIPSTER_ENTANDO_ADDR="https://github.com/entando/entando-blueprint/"

# UTILITIES CONFIGURATION
XU_LOG_LEVEL=9

ENTANDO_HOME=$(
  cd "$ENTANDO_ENT_HOME/../../../.." && pwd && exit
)

ENTANDO_GLOBAL_CFG="$ENTANDO_HOME/.global-cfg"

ENT_WORK_DIR="$ENTANDO_ENT_HOME/w"
ENT_FIRST_RUN_CFG_FILE="$ENTANDO_ENT_HOME/w/.first-run-cfg"
ENT_DEFAULT_CFG_FILE="$ENT_WORK_DIR/.cfg"
CFG_FILE="$ENT_DEFAULT_CFG_FILE"
ENT_KUBECONF_FILE_PATH="$ENT_WORK_DIR/.kubeconf"

# CONSTS
C_HOSTS_FILE="/etc/hosts"
C_BUNDLE_DESCRIPTOR_FILE_NAME="descriptor.yaml"
C_ENT_PRJ_ENT_DIR=".ent"
C_ENT_PRJ_FILE="$C_ENT_PRJ_ENT_DIR/ent-prj"
C_ENT_STATE_FILE="$C_ENT_PRJ_ENT_DIR/ent-state"
C_ENT_OLD_PRJ_FILE=".ent-prj"
C_ENT_OLD_STATE_FILE=".ent-state"

C_GENERATOR_JHIPSTER_ENTANDO_NAME="generator-jhipster-entando"
C_ENTANDO_BUNDLER_DIR="entando-bundle-tool"
C_ENTANDO_BUNDLER_NAME="entando-bundler"
C_ENTANDO_BUNDLE_BIN_NAME="entando-bundler"
C_QUICKSTART_DEFAULT_RELEASE="quickstart"

C_ENTANDO_LOGO_FILE="res/entando.png"

C_WIN_VM_HOSTNAME_SUFFIX="mshome.net"
C_AUTO_VM_HOSTNAME_SUFFIX="local.entando.org"

ENTANDO_RELEASES_REPO_URL="https://github.com/entando/entando-releases.git"

# More dynamic configurations

ENTANDO_STANDARD_IMAGES=(
  "entando-component-manager" "entando-de-app-wildfly" "entando-k8s-app-controller"
  "entando-k8s-app-plugin-link-controller" "entando-k8s-cluster-infrastructure-controller"
  "entando-k8s-composite-app-controller" "entando-k8s-controller-coordinator"
  "entando-k8s-dbjob" "entando-k8s-keycloak-controller"
  "entando-k8s-plugin-controller" "entando-k8s-service"
  "entando-keycloak" "entando-plugin-sidecar"
)
