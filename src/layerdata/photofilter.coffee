assert = require '../psdassert'

class PSDPhotoFilter
  constructor: (@layer, @length) ->
    @file = @layer.file

  parse: ->
    version = @file.parseInt()
    assert version is 3

    data = {}
    data.color =
      x: @file.readInt()
      y: @file.readInt()
      z: @file.readInt()

    data.density = @file.readInt()
    data.preserveLuminosity = @file.readBoolean()
    data

module.exports = PSDPhotoFilter