fs = require 'fs'
Canvas = require 'canvas'
Image = Canvas.Image

{PSD} = require __dirname + '/../lib/psd.js'

psd = PSD.fromFile __dirname + '/Concept 1.psd'
psd.parse()

canvas = new Canvas(psd.header.cols, psd.header.rows)
context = canvas.getContext('2d')
imageData = context.getImageData 0, 0, canvas.width, canvas.height
pixelData = imageData.data

pixelData[i] = pxl for pxl, i in psd.image.toCanvasPixels()

context.putImageData imageData, 0, 0

fs.writeFile __dirname + '/output.png', canvas.toBuffer(), ->
	console.log "Output image to output.png"

fs.writeFile __dirname + '/output.json', JSON.stringify(psd.image.toCanvasPixels(), null, 2), ->
  console.log "Output written to output.json"
