assert = require '../psdassert'

class PSDHueSaturation
  constructor: (@layer, @length) ->
    @file = @layer.file

  parse: ->
    version = @file.readShortInt()
    assert version is 2

    @data.colorization = @file.readBoolean()

    @file.seek 1 # padding byte

    # Photoshop 5.0 has a new hue system
    # Hue is [-180, 180]
    # Saturation is [0, 100]
    # Lightness is [-100, 100]
    #
    # Photoshop 4.0 uses HSB color space
    # Hue: [-100, 100]
    # Saturation: [0, 100]
    # Lightness: [-100, 1000]
    @data.hue = @file.readShortInt()
    @data.saturation = @file.readShortInt()
    @data.lightness = @file.readShortInt()

    @data.masterHue = @file.readShortInt()
    @data.masterSaturation = @file.readShortInt()
    @data.masterLightness = @file.readShortInt()

    # 6 sets of 14 bytes (4 range values followed by 3 settings values)
    @data.rangeValues = []
    @data.settingValues = []
    for i in [0...6]
      @data.rangeValues[i] = []
      @data.settingValues[i] = []

      # For RGB and CMYK
      @data.rangeValues[i][j] = @file.readShortInt() for j in [0...4]

      # For Lab color
      @data.settingValues[i][j] = @file.readShortInt() for j in [0...3]

    @data

module.exports = PSDHueSaturation