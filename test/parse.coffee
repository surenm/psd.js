fs = require 'fs'
Canvas = require 'canvas'
Image = Canvas.Image

{PSD} = require __dirname + '/../lib/psd.js'

PSD.DEBUG = true

psd = PSD.fromFile __dirname + '/twitpic.psd'
psd.parse()
