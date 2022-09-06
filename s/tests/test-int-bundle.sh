#!/bin/bash

# shellcheck disable=SC2034
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"

# BUNDLE INTEGRATION TEST
test_int_bundle() {  
  print_current_function_name "> " ".."
  (
    OD="$PWD"
    TD="$(mktemp -d)"
    __cd "$TD"
    
    tar xfz "$OD/res/test-bundle.tar.gz" && __cd "test-bundle"
    
    # PRJ get-bundle-id
    ASSERT -v prj_get-bundle-id "$(
      ent prj get-bundle-id
    )" = "8483edb7"
    
    # ECR get-bundle-id
    ASSERT -v ecr_get-bundle-id "$(
      ent ecr get-bundle-id "../bundle-repo-clone.git"
    )" = "8483edb7"

    # ECR get-bundle-id other url
    ASSERT -v ecr_get-bundle-id "$(
      ent ecr get-bundle-id --repo "https://github.com/entando/entando-test-bundle"
    )" = "2265dc2e"

    # PRJ get-plugin-code
    ASSERT -v prj_get-plugin-code "$(
      ent prj get-plugin-code --auto
    )" = "pn-8483edb7-89ea6fea-wcaent-my-bundle"
    # ECR get-plugin-code other url
    R="$PWD/bundle-repo-clone.git"
    BID="$(ent ecr get-bundle-id "file://$R")"
    ASSERT -v ecr_get-plugin-code "$(
      ent ecr get-plugin-code --auto --repo="file://$R"
    )" = "pn-$BID-89ea6fea-wcaent-my-bundle"
  ) || _SOE
}
