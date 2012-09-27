PSDDescriptor = require '../psddescriptor'
Parser = require '../parser'
assert = require '../psdassert'

class PSDFillColor
  constructor: (@layer, @length) ->
    @file = @layer.file

  parse: ->
    opacity_hex = parseInt(@file.read(1))
    fill_opacity = Math.round (opacity_hex*100/255)
    return fill_opacity

module.exports = PSDFillColor
