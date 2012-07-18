class PSDBlackWhite
  constructor: (@layer, @length) ->
    @file = @layer.file

  parse: ->
    version = @file.readInt()
    assert version is 16

    (new PSDDescriptor(@file)).parse()