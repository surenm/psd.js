PSDDescriptor = require '../psddescriptor'
Parser = require '../parser'
assert = require '../psdassert'

class PSDVibrance
  constructor: (@layer, @length) ->
    @file = @layer.file

  parse: ->
    version = @file.readInt()
    assert version is 16

    (new PSDDescriptor(@file)).parse()

module.exports = PSDVibrance