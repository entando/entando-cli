#!/bin/bash
# shellcheck disable=SC2034

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# SHARED ENTANDO DIRS

ENTANDO_HOME="$(
  cd "$ENTANDO_ENT_HOME/../../../.." && pwd && exit
)"
ENTANDO_BINS="$ENTANDO_HOME/bin"
ENTANDO_PROFILES="$ENTANDO_HOME/profiles"

ENTANDO_GLOBAL_CFG="$ENTANDO_HOME/.global-cfg"

ENTANDO_VERSION_DIR="$(
  __cd "$ENTANDO_ENT_HOME/../.."
  pwd
)"

(
  [ -z "$ENTANDO_VERSION_DIR" ] && exit 1
  __cd "$ENTANDO_VERSION_DIR"
) || _FATAL -s "Unable to determine the ent's base entando version dir"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ENT INSTALLATION DIRS
ENT_WORK_DIR="$ENTANDO_ENT_HOME/w"
ENT_DEFAULT_CFG_FILE="$ENT_WORK_DIR/.cfg"
CFG_FILE="$ENT_DEFAULT_CFG_FILE"
ENT_KUBECONF_FILE_PATH="$ENT_WORK_DIR/.kubeconf"
ENT_OPTS="$ENTANDO_VERSION_DIR/opt"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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

C_DEFAULT_KUBECT_VERSION="v1.23.4"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# UTILITIES DEFAULTS
XU_LOG_LEVEL=9

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# EXTERNAL RESOURCES DEFAULTS

REPO_GENERATOR_JHIPSTER_ENTANDO_ADDR="https://github.com/entando/entando-blueprint/"
URL_NODE_JS_DIST_ADDR="https://nodejs.org/dist/{NODE_VER}/node-{NODE_VER}-{OS}-{ARCH}.{EXT}"

ENTANDO_STANDARD_IMAGES=(
  "entando-component-manager" "entando-de-app-wildfly" "entando-k8s-app-controller"
  "entando-k8s-app-plugin-link-controller" "entando-k8s-cluster-infrastructure-controller"
  "entando-k8s-composite-app-controller" "entando-k8s-controller-coordinator"
  "entando-k8s-dbjob" "entando-k8s-keycloak-controller"
  "entando-k8s-plugin-controller" "entando-k8s-service"
  "entando-keycloak" "entando-plugin-sidecar"
)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DYNAMIC CONFIGURATIONS

# shellcheck disable=SC1091
{
  [ -f dist/manifest ] && . dist/manifest
  [ -f d/_env ] && . d/_env
  [ -f w/_env ] && . w/_env
  [ -f _env ] && . _env
}

# READS THE ACTUAL VALUES AND OVERRIDES THE ONES COMING FROM THE MANIFEST

TMP="$(
  cd "$ENTANDO_ENT_HOME" &> /dev/null || exit 1
  git describe --exact-match --tags 2>/dev/null
)"

ENTANDO_MANIFEST_CLI_VERSION="${ENTANDO_CLI_VERSION:-"$TMP"}"
ENTANDO_CLI_VERSION="${TMP:-"$ENTANDO_MANIFEST_CLI_VERSION"}"


ENTANDO_MANIFEST_RELEASE="$ENTANDO_RELEASE"
TMP="$(
  cd "$ENTANDO_ENT_HOME/dist" &> /dev/null || exit 1
  # shellcheck disable=SC1090
  git describe --tags "$(git rev-list --tags --max-count=1)"
)"

ENTANDO_MANIFEST_RELEASE="${ENTANDO_RELEASE:-"$TMP"}"
ENTANDO_RELEASE="${TMP:-"$ENTANDO_MANIFEST_RELEASE"}"
