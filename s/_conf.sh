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
XU_STATUS_FILE="$ENTANDO_ENT_ACTIVE/w/.status"

# CONSTS
C_ENTANDO_BLUEPRINT_REPO="https://github.com/entando/entando-blueprint"
CFG_FILE="$ENTANDO_ENT_ACTIVE/w/.cfg"
C_DEF_CUSTOM_IP="10.5.14.20"
C_HOSTS_FILE="/etc/hosts"
C_BUNDLE_DESCRIPTOR_FILE_NAME="descriptor.yaml"

# K3S
#KUBECTL="sudo k3s kubectl"
KUBECTL="sudo kubectl"

# More dynamic configurations
[ -f d/_env ] && . d/_env
[ -f w/_env ] && . w/_env
[ -f _env ] && . _env
