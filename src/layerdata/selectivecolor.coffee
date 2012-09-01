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
    version = @file.getShortInt()
    assert version is 1

    # 0 = relative mode, 1 = absolute mode
    @data.correctionMethod = @file.getShortInt()

    # Ten 8 byte plate correction records
    # First record is ignored and reserved for future use
    # Rest of the records apply to specific areas of color or lightness
    # values in the image, in the order: reds, yellows, greens, cyans,
    # blues, magentas, whites, neutrals, blacks.
    for i in [0...10]
      @data.cyanCorrection.push @file.getShortInt()
      @data.magentaCorrection.push @file.getShortInt()
      @data.yellowCorrection.push @file.getShortInt()
      @data.blackCorrection.push @file.getShortInt()

    @data

module.exports = PSDSelectiveColor