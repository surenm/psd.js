PSDDescriptor = require '../psddescriptor'
assert = require '../psdassert'

class PSDSolidColor
  constructor: (@layer, @length) ->
    @file = @layer.file

  parse: ->
    version = @file.readInt()
    assert version is 16

    descriptor = (new PSDDescriptor(@file)).parse()
    return descriptor.color

module.exports = PSDSolidColor
