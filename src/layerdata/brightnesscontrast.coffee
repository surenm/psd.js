class PSDBrightnessContrast
  constructor: (@layer, @length) ->
    @file = @layer.file
    @data = {}

  parse: ->
    @data.brightness = @file.readShortInt()
    @data.contrast = @file.readShortInt()
    @data.meanValue = @file.readShortInt()
    @data.labColor = @file.readShortInt()

    @data
  

module.exports = PSDBrightnessContrast