fs = require 'fs'
Canvas = require 'canvas'
Image = Canvas.Image

{PSD} = require __dirname + '/../lib/psd.js'
PSD.DEBUG = true

psd = PSD.fromFile __dirname + '/test.psd'

start = (new Date()).getTime()

psd.toFile __dirname + '/output.png', ->
  end = (new Date()).getTime()

  console.log "PSD flattened to output.png in #{end - start}ms"
