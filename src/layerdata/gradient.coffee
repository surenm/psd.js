PSDDescriptor = require '../psddescriptor'
Parser = require '../parser'
assert = require '../psdassert'

class PSDGradient
  constructor: (@layer, @length) ->
    @file = @layer.file

  parse: ->
    version = @file.readInt()
    assert version is 16

    descriptor = (new PSDDescriptor(@file)).parse()
    gradient = Parser.parseGradient descriptor
    return gradient

module.exports = PSDGradient