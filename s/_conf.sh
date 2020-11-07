REPO_GENERATOR_JHIPSTER_ENTANDO_ADDR="https://github.com/entando/entando-blueprint/"
REPO_BUNDLECLI_ADDR="https://github.com/entando-k8s/entando-bundle-cli/"

# UTILITIES CONFIGURATION
XU_LOG_LEVEL=9

# CONSTS
CFG_FILE="$ENTANDO_ENT_ACTIVE/w/.cfg"
C_HOSTS_FILE="/etc/hosts"
C_BUNDLE_DESCRIPTOR_FILE_NAME="descriptor.yaml"
C_ENT_PRJ_FILE=".ent-prj"

C_GENERATOR_JHIPSTER_ENTANDO_NAME="generator-jhipster-entando"
C_ENTANDO_BUNDLE_TOOL_NAME="entando-bundle-tool"
C_WIN_VM_HOSTNAME_SUFFIX="mshome.net"
C_QUICKSTART_DEFAULT_RELEASE="quickstart"

# More dynamic configurations

[ -f dist/manifest ] && . dist/manifest
[ -f d/_env ] && . d/_env
[ -f w/_env ] && . w/_env
[ -f _env ] && . _env
