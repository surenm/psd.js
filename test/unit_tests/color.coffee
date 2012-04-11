{PSD} = require __dirname + '/../../lib/psd'
PSDColor = PSD.PSDColor

module.exports =
  hexToRGB: (test) ->
    test.deepEqual PSDColor.hexToRGB("#FF0000"), r: 255, g: 0, b: 0
    test.deepEqual PSDColor.hexToRGB("#ff0000"), r: 255, g: 0, b: 0
    test.deepEqual PSDColor.hexToRGB("FF0000"), r: 255, g: 0, b: 0
    test.done()

  rgbToHex: (test) ->
    test.equal PSDColor.rgbToHex(255, 0, 0), "#ff0000"
    test.equal PSDColor.rgbToHex("rgba(255, 0, 0)"), "#ff0000"
    test.done()

  rgbToHSL: (test) ->
    test.deepEqual PSDColor.rgbToHSL(50, 100, 150), h: .583, s: .500 , l: .392
    test.done()

  hslToRGB: (test) ->
    test.deepEqual PSDColor.hslToRGB(.583, .500, .392), r: 50, g: 100, b: 150
    test.done()

  cmykToRGB: (test) ->
    test.deepEqual PSDColor.cmykToRGB(11, 8, 8, 0), r: 245, g:248, b: 248
    test.done()

  labToRGB: (test) ->
    test.deepEqual PSDColor.labToRGB(94, 0, 0),
      r: 237.72034699108337
      g: 237.72806888514194
      b: 237.70272871697853

    test.done()