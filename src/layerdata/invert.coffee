class PSDInvert
  constructor: (@layer, @length) ->
    @file = @layer.file

  # There is no parameter. If this adjustment layer is present,
  # then the layer is inverted.
  parse: -> true

module.exports = PSDInvert