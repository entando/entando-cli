#!/bin/bash

XDEV_TEST.BEFORE_FILE() {
  tar xfz "$PROJECT_DIR/res/test-bundle.tar.gz"
  __cd "test-bundle"
}

#TEST:integration,lib,bundle
test_int_bundle() {  

  ( _IT "should calculate corrent bundle-id"
  
    # PRJ get-bundle-id
    _ASSERT -v prj_get-bundle-id "$(
      ent prj get-bundle-id
    )" = "8483edb7"
    
    # ECR get-bundle-id other url
    _ASSERT -v ecr_get-bundle-id "$(
      ent ecr get-bundle-id --repo "https://github.com/entando/entando-test-bundle"
    )" = "2265dc2e"

    # PRJ get-plugin-code
    _ASSERT -v prj_get-plugin-code "$(
      ent prj get-plugin-code --auto
    )" = "pn-8483edb7-89ea6fea-wcaent-my-bundle"
    # ECR get-plugin-code other url
    R="$PWD/bundle-repo-clone.git"
    BID="$(ent ecr get-bundle-id "file://$R")"
    _ASSERT -v ecr_get-plugin-code "$(
      ent ecr get-plugin-code --auto --repo="file://$R"
    )" = "pn-$BID-89ea6fea-wcaent-my-bundle"
  ) || _SOE
}
