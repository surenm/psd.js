fs = require 'fs'
Canvas = require 'canvas'
Image = Canvas.Image

{PSD} = require __dirname + '/../lib/psd.js'

PSD.DEBUG = true

psd = PSD.fromFile __dirname + '/test.psd'
psd.parse()

for layer in psd.layers
  continue if layer.isFolder
  
  canvas = new Canvas(layer.cols, layer.rows)
  context = canvas.getContext('2d')
  imageData = context.getImageData 0, 0, canvas.width, canvas.height
  pixelData = imageData.data

  pixelData[i] = pxl for pxl, i in layer.image.toCanvasPixels()

  context.putImageData imageData, 0, 0

  do (layer, canvas) ->
    fs.writeFile "output/#{layer.name}.png", canvas.toBuffer(), ->
      console.log "Export #{layer.name} to disk"
