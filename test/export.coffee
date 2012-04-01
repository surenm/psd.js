fs = require 'fs'
Canvas = require 'canvas'
Image = Canvas.Image

{PSD} = require __dirname + '/../lib/psd.js'

psd = PSD.fromFile __dirname + '/test.psd'
psd.setOptions layerImages: false

psd.toFile __dirname + '/output.png', ->
  console.log "PSD flattened to output.png"
