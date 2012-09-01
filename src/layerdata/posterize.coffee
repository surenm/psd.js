assert = require '../psdassert'

class PSDPosterize
  constructor: (@layer, @length) ->
    @file = @layer.file
    @data = {}

  parse: ->
    @data.levels = @file.readShortInt()
    assert @data.levels >= 2 and @data.levels <= 255

    # Padding
    @file.seek 2

    @data

module.exports = PSDPosterize