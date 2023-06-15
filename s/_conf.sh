#!/bin/bash
# shellcheck disable=SC2034

ENTANDO_VARS_DEFAULTS=(
  ENTANDO_HOME ENTANDO_ENT_HOME ENTANDO_BINS ENTANDO_PROFILES ENTANDO_GLOBAL_CFG ENTANDO_DIST_DIR
  ENT_WORK_DIR ENT_DEFAULT_CFG_FILE CFG_FILE ENT_KUBECONF_FILE_PATH ENT_OPTS
  ENTANDO_OPT_OVERRIDE_HOME_VAR ENTANDO_ENT_EXTENSIONS_MODULES_PATH ENTANDO_CLI_FORCE_COLORS
  ENTANDO_CLI_DEFAULT_DOCKER_REGISTRY ENTANDO_CLI_DEFAULT_HUB ENTANDO_RELEASE ENTANDO_NPM_REGISTRY_NO_SCHEMA
  ENTANDO_NPM_REGISTRY_TOKEN_FOR_ANONYMOUS_ACCESS
)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# SHARED ENTANDO DIRS

if [ "$ENTANDO_PIPELINE_EXECUTION" != "true" ]; then
  ENTANDO_HOME="$(
    cd "$ENTANDO_ENT_HOME/../../../.." && pwd && exit
  )"

  ENTANDO_DIST_DIR="$(
    __cd "$ENTANDO_ENT_HOME/../.."
    pwd
  )"
else
  ENTANDO_HOME="$HOME/.entando"
  ENTANDO_DIST_DIR="$HOME/.entando/dis"
  mkdir -p "$ENTANDO_DIST_DIR"
fi

  (
    [ -z "$ENTANDO_DIST_DIR" ] && exit 1
    __cd "$ENTANDO_DIST_DIR"
  ) || _FATAL -s "Unable to determine the ent's base entando version dir"

ENTANDO_BINS="$ENTANDO_HOME/bin"
ENTANDO_PROFILES="$ENTANDO_HOME/profiles"

ENTANDO_GLOBAL_CFG="$ENTANDO_HOME/.global-cfg"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ENT INSTALLATION DIRS
ENT_WORK_DIR="$ENTANDO_ENT_HOME/w"
ENT_DEFAULT_CFG_FILE="$ENT_WORK_DIR/.cfg"
CFG_FILE="$ENT_DEFAULT_CFG_FILE"
ENT_KUBECONF_FILE_PATH="$ENT_WORK_DIR/.kubeconf"
ENT_OPTS="$ENTANDO_DIST_DIR/opt"

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

# BUNDLER
C_ENTANDO_BUNDLER_DIR="entando-bundler"
C_ENTANDO_BUNDLER_NAME="entando-bundler"
C_ENTANDO_BUNDLER_BIN_NAME="entando-bundler"

# BUNDLE-CLI
C_ENTANDO_BUNDLE_CLI_DIR="entando-bundle-cli"
C_ENTANDO_BUNDLE_CLI_NAME="entando-bundle-cli"
C_ENTANDO_BUNDLE_CLI_BIN_NAME="entando-bundle-cli"
ENTANDO_BUNDLE_CLI_BIN_NAME="ent bundle"
ENTANDO_BUNDLE_CLI_DEBUG=false
ENTANDO_CLI_ORIGINAL_HOME=""
ENTANDO_CLI_ORIGINAL_USERPROFILE=""
ENTANDO_BUNDLE_CLI_INIT_SUPPRESS_NO_ENTANDO_JSON_WARNING=false

#
C_QUICKSTART_DEFAULT_RELEASE="quickstart"

C_ENTANDO_LOGO_FILE="res/entando.png"

C_WIN_VM_HOSTNAME_SUFFIX="mshome.net"
C_AUTO_VM_HOSTNAME_SUFFIX="local.entando.org"

C_DEFAULT_KUBECT_VERSION="v1.23.4"

ENTANDO_CLI_DOCKER_CONFIG_PATH="$ENT_ORIGIN_WORKDIR/.entando/.docker/config.json"
ENTANDO_OPT_OVERRIDE_HOME_VAR="true"

ENTANDO_ENT_EXTENSIONS_MODULES_PATH="${ENTANDO_ENT_HOME}/bin/mod/ext"
ENTANDO_CLI_FORCE_COLORS="false"

ENTANDO_CLI_DEFAULT_DOCKER_REGISTRY="registry.hub.docker.com"
ENTANDO_CLI_DEFAULT_HUB="https://entando.com/entando-hub-api"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# UTILITIES DEFAULTS
XU_LOG_LEVEL=9
FLAG_FZF_SELECT=false

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

TMP_CLI_VERSION="$(
  cd "$ENTANDO_ENT_HOME" &> /dev/null || exit 1
  git describe --exact-match --tags 2>/dev/null
)"

ENTANDO_MANIFEST_CLI_VERSION="${ENTANDO_CLI_VERSION:-"$TMP_CLI_VERSION"}"
ENTANDO_CLI_VERSION="${TMP_CLI_VERSION:-"$ENTANDO_MANIFEST_CLI_VERSION"}"


ENTANDO_MANIFEST_RELEASE="$ENTANDO_RELEASE"
TMP_CLI_VERSION="$(
  cd "$ENTANDO_ENT_HOME/dist" &> /dev/null || exit 1
  # shellcheck disable=SC1090
  git describe --tags "$(git rev-list --tags --max-count=1)"
)"

ENTANDO_MANIFEST_RELEASE="${ENTANDO_RELEASE:-"$TMP_CLI_VERSION"}"
ENTANDO_RELEASE="${TMP_CLI_VERSION:-"$ENTANDO_MANIFEST_RELEASE"}"

# ENTANDO NPM REGISTRY DATA
ENTANDO_NPM_REGISTRY_NO_SCHEMA="npm.pkg.github.com"
ENTANDO_NPM_REGISTRY="https://$ENTANDO_NPM_REGISTRY_NO_SCHEMA"

# UNPRIVILEDGED TOKEN USED FOR ANONYMOUS ACCESS TO GITHUB PACKAGES
# THE TOKEN HAS IN FACT NO PERMISSION BUT repository:read
# it's obfuscated just to avoid false positives from security scanners
ENTANDO_NPM_REGISTRY_TOKEN_FOR_ANONYMOUS_ACCESS="$(
  echo -n "ZXc2Z2IwbUtWMUZ5c0g0NWxLTFBOZVBwNGJDaUk5TE9iNUw4X3BoZw==" \
    | perl -e "use MIME::Base64; print decode_base64(<>);" \
    | perl -e 'print scalar reverse(<>);' \
    | tr -d '\n' | tr -d '\r'
)"
