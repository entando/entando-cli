#!/bin/bash

_require "s/quickstart-mocks.sh"
_require "s/var-utils.sh"
_require "s/utils.sh"

#TEST:unit,lib,mock
test_multipass_mocks() {
  ( _IT "should properly simulate multipass execution"
  
    multipass info "test-vm" && _FAIL "image should not be present"
    multipass launch --name "test-vm" --cpus "4" --mem "8G" --disk "20G"
    multipass info "test-vm" || _FAIL "image should be present"
  )
}

true
