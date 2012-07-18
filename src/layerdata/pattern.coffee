class PSDPattern
  constructor: (@layer, @length) ->
    @file = @layer.file

  parse: ->
    version = @file.parseInt()
    assert version is 16

    (new PSDDescriptor(@file)).parse()