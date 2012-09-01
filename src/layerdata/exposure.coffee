assert = require '../psdassert'

class PSDExposure
  constructor: (@layer, @length) ->
    @file = @layer.file

  parse: ->
    version = @file.parseInt()
    assert version is 1

    exposure: @file.parseInt()
    offset: @file.parseInt()
    gamma: @file.parseInt()

module.exports = PSDExposure