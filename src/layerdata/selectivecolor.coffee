assert = require '../psdassert'

class PSDSelectiveColor
  constructor: (@layer, @length) ->
    @file = @layer.file
    @data =
      cyanCorrection: []
      magentaCorrection: []
      yellowCorrection: []
      blackCorrection: []

  parse: ->
    version = @file.readShortInt()
    assert version is 1

    # 0 = relative mode, 1 = absolute mode
    @data.correctionMethod = @file.readShortInt()

    # Ten 8 byte plate correction records
    # First record is ignored and reserved for future use
    # Rest of the records apply to specific areas of color or lightness
    # values in the image, in the order: reds, yellows, greens, cyans,
    # blues, magentas, whites, neutrals, blacks.
    for i in [0...10]
      @data.cyanCorrection.push @file.readShortInt()
      @data.magentaCorrection.push @file.readShortInt()
      @data.yellowCorrection.push @file.readShortInt()
      @data.blackCorrection.push @file.readShortInt()

    @data

module.exports = PSDSelectiveColor