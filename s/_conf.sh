# REPO_CUSTOM_MODEL
REPO_CUSTOM_MODEL_ADDR="https://github.com/entando-k8s/entando-k8s-custom-model.git"
REPO_CUSTOM_MODEL_DIR="entando-k8s-custom-model"

# REPO_QUICKSTART
REPO_QUICKSTART_ADDR="https://github.com/entando-k8s/entando-helm-quickstart.git"
REPO_QUICKSTART_DIR="entando-helm-quickstart"

# MISC
DEPL_SPEC_YAML_FILE="entando-deployment-specs.yaml"
REQUIRED_HELM_VERSION_REGEX="3.2.*"

# UTILITIES CONFIGURATION
XU_LOG_LEVEL=9

# CONSTS
C_ENTANDO_BLUEPRINT_REPO="https://github.com/entando/entando-blueprint"
CFG_FILE="$ENTANDO_ENT_ACTIVE/w/.cfg"
C_HOSTS_FILE="/etc/hosts"
C_BUNDLE_DESCRIPTOR_FILE_NAME="descriptor.yaml"


# More dynamic configurations

[ -f dist/manifest ] && . dist/manifest
[ -f d/_env ] && . d/_env
[ -f w/_env ] && . w/_env
[ -f _env ] && . _env
