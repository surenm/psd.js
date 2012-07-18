# Photoshop 6.0
class PSDSolidColor
  constructor: (@layer, @length) ->
    @file = @layer.file

  parse: ->
    version = @file.readInt()
    assert version is 16

    # Just return the descriptor data
    (new PSDDescriptor(@file)).parse()