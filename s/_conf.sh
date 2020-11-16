REPO_GENERATOR_JHIPSTER_ENTANDO_ADDR="https://github.com/entando/entando-blueprint/"

# UTILITIES CONFIGURATION
XU_LOG_LEVEL=9

CFG_FILE="$ENTANDO_ENT_ACTIVE/w/.cfg"
ENT_KUBECONF_FILE_PATH="$ENTANDO_ENT_ACTIVE/w/.kubeconf"

# CONSTS
C_HOSTS_FILE="/etc/hosts"
C_BUNDLE_DESCRIPTOR_FILE_NAME="descriptor.yaml"
C_ENT_PRJ_FILE=".ent-prj"
C_ENT_STATE_FILE=".ent-state"

C_GENERATOR_JHIPSTER_ENTANDO_NAME="generator-jhipster-entando"
C_ENTANDO_BUNDLER_DIR="entando-bundle-tool"
C_ENTANDO_BUNDLER_NAME="entando-bundler"
C_WIN_VM_HOSTNAME_SUFFIX="mshome.net"
C_QUICKSTART_DEFAULT_RELEASE="quickstart"

C_ENTANDO_LOGO_FILE="res/entando.png"

# More dynamic configurations

[ -f dist/manifest ] && . dist/manifest
[ -f d/_env ] && . d/_env
[ -f w/_env ] && . w/_env
[ -f _env ] && . _env
