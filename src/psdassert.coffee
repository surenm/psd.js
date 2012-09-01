# Quick and dirty assertion polyfill for browsers
assert = do (assert) ->
  return require 'assert' if exports?

  assert = (test) ->
    throw "Assertion error" unless test == true

  assert.equal = (actual, expected) ->
    throw "Assertion error" unless actual is expected

  return assert

module.exports = assert