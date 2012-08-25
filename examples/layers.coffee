fs = require 'fs'
path = require 'path'

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
psd_dirname   = path.dirname process.argv[2]
#processed_dir = path.join psd_dirname, "psdjsprocessed" 

psd.toFileSync('./output.png')
fs.writeFileSync('./output.psdjs.json', JSON.stringify(psd))


#for layer in psd.layers
#  continue unless layer.image
#  layer.image.toFileSync "#{processed_dir}/#{layer.name}.png"