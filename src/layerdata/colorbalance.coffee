class PSDColorBalance
  constructor: (@layer, @length) ->
    @file = @layer.file
    @data =
      cyanRed: []
      magentaGreen: []
      yellowBlue: []

  parse: ->
    for i in [0...3]
      @data.cyanRed.push @file.getShortInt()
      @data.magentaGreen.push @file.getShortInt()
      @data.yellowBlue.push @file.getShortInt()

    @data

module.exports = PSDColorBalance
