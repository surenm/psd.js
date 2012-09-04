class PSDColorBalance
  constructor: (@layer, @length) ->
    @file = @layer.file
    @data =
      cyanRed: []
      magentaGreen: []
      yellowBlue: []

  parse: ->
    for i in [0...3]
      @data.cyanRed.push @file.readShortInt()
      @data.magentaGreen.push @file.readShortInt()
      @data.yellowBlue.push @file.readShortInt()

    @data

module.exports = PSDColorBalance
