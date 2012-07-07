fs = require 'fs'
{exec} = require 'child_process'

{PSD} = require __dirname + '/../lib/psd.js'

PSD.DEBUG = true

if process.argv.length is 2
  console.log "Please specify an input file"
  process.exit()

psd = PSD.fromFile process.argv[2]
psd.setOptions
  layerImages: true
  onlyVisibleLayers: true

psd.parse()

exec "mkdir -p #{__dirname}/output", ->
  for layer in psd.layers
    continue unless layer.image

    do (layer) ->
      layer.image.toFile __dirname + "/output/#{layer.name}.png", ->
        console.log "Layer #{layer.name} output to file."
