#!/bin/bash

XDEV_TEST.BEFORE_FILE() {
  export TEST_PROFILE="ent-integration-tests"
}

#TEST:integration,profile
test_profile_use() {
  
  _test_profile.cleanup
    
  ( _IT "should create and use the valid profile"
  
    ent profile new "$TEST_PROFILE" "$TEST_PROFILE" "$TEST_PROFILE"
    
    _ASSERT -v current-profile "|$(_test_profile.get_current_profile)|" = "|$TEST_PROFILE|"

    ent config TEST_VAR "<BASE>"
    _ASSERT -v TEST_VAR "$(ent config TEST_VAR)" = "<BASE>"
  ) || _SOE
  
  ( _IT "should graciously fail when trying to use an unexisting subprofile"
      
    _ASSERT -v use-sub-profile-result "$(
      ent profile use "$TEST_PROFILE" "x" 2>&1 
    )" contains "The sub-profile was not found"

    _ASSERT -v current-profile "$(_test_profile.get_current_profile)" = "$TEST_PROFILE"
    _ASSERT -v TEST_VAR "$(ent config TEST_VAR)" = "<BASE>"
  ) || _SOE
  
  ( _IT "should support autocreation"
      
    ent profile use "$TEST_PROFILE" "x" -a
    ent config TEST_VAR "<X>"
    
    _ASSERT -v current-profile "$(_test_profile.get_current_profile)" = "$TEST_PROFILE/x"
    _ASSERT -v TEST_VAR "$(ent config TEST_VAR)" = "<X>"

  ) || _SOE

  ( _IT "should be able to properly restore the base profile"
      
    ent profile use "$TEST_PROFILE"
    _ASSERT -v current-profile "$(_test_profile.get_current_profile)" = "$TEST_PROFILE"
    _ASSERT -v TEST_VAR "$(ent config TEST_VAR)" = "<BASE>"

  ) || _SOE

  _test_profile.cleanup
}

_test_profile.get_current_profile() {
  ent status | grep "PROFILE:" | sed 's/.*PROFILE:[[:space:]]*//'
}

_test_profile.cleanup() {
  ent profile delete "$TEST_PROFILE" --yes #&>/dev/null
}
