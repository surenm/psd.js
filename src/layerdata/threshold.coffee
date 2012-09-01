assert = require '../psdassert'

class PSDThreshold
  constructor: (@layer, @length) ->
    @file = @layer.file
    @data = {}

  parse: ->
    @data.level = @file.readShortInt()
    assert @data.level >= 1 and @data.level <= 255

    @file.seek 2 # padding?

    @data

module.exports = PSDThreshold