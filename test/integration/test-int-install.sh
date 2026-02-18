#!/bin/bash

XDEV_TEST.BEFORE_FILE() {
  export TEST_PROFILE="ent-integration-tests"
}

#TEST:integration,profile
test_install() {

  if [[ -z "$ENTANDO_RELEASE_TO_TEST" || -z "$ENT_VERSION_TO_TEST" ]]; then
    return 0
  fi
    
  ( _IT "should install 7.3.2 with bundle 1.2.1"

    bash <(curl -L "https://get.entando.org/cli") --update --release="$ENTANDO_RELEASE_TO_TEST" --cli-version="$ENT_VERSION_TO_TEST"
    # shellcheck disable=SC1091
    source "$HOME/.entando/activate" --force
    
    if [ -n "$BUNDLE_CLI_VERSION_TO_TEST" ]; then
      ent check-env base-develop --yes --entando-bundle-cli-version="$BUNDLE_CLI_VERSION_TO_TEST" --verbose --lenient
    else
      ent check-env base-develop --yes --verbose --lenient
    fi
    
    #~

    ent status --full

    _ASSERT -v ENT_VER "$(ent version)" = "v7.3.2"
    _ASSERT -v ENT_BUNDLE_VER "$(ent bundle version)" = "v1.2.1-SNAPSHOT"

  ) || _SOE
}
