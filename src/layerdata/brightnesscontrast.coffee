class PSDBrightnessContrast
  constructor: (@layer, @length) ->
    @file = @layer.file
    @data = {}

  parse: ->
    @data.brightness = @file.getShortInt()
    @data.contrast = @file.getShortInt()
    @data.meanValue = @file.getShortInt()
    @data.labColor = @file.getShortInt()

    @data
  

module.exports = PSDBrightnessContrast