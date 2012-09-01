class PSDPattern
  constructor: (@layer, @length) ->
    @file = @layer.file

  parse: ->
    version = @file.readInt()
    assert version is 16

    descriptor = (new PSDDescriptor(@file)).parse()
    return Parser.parsePattern descriptor

module.exports = PSDPattern