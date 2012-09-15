PSDDescriptor = require '../psddescriptor'
Parser = require '../parser'
assert = require '../psdassert'

class PSDSolidColor
  constructor: (@layer, @length) ->
    @file = @layer.file

  parse: ->
    version = @file.readInt()
    assert version is 16

    descriptor = (new PSDDescriptor(@file)).parse()
    opacity = @layer.opacity
    fill_color = Parser.parseColor descriptor.color, opacity
    return fill_color

module.exports = PSDSolidColor
