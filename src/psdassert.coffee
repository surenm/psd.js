assert = null

# Quick and dirty assertion polyfill for browsers
do (assert) ->
  if exports?
    assert = require 'assert'
    return

  assert = (test) -> test == true
  assert.equal = (actual, expected) -> actual is expected