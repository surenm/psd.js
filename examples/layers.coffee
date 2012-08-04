fs = require 'fs'
{exec} = require 'child_process'

{PSD} = require __dirname + '/../lib/psd.js'

PSD.DEBUG = false

if process.argv.length is 2
  console.log "Please specify an input file"
  process.exit()

psd = PSD.fromFile process.argv[2]
psd.setOptions
  layerImages: true
  onlyVisibleLayers: true

psd.parse()
psd.toFileSync('./output.png')
fs.writeFileSync('./output.json', JSON.stringify(psd))