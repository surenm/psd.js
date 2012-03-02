fs = require 'fs'
Canvas = require 'canvas'
Image = Canvas.Image

{PSD} = require __dirname + '/../lib/psd.js'

psd = PSD.fromFile __dirname + '/test.psd'
psd.parse()
