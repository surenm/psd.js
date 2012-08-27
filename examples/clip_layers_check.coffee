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

clipping = 0
for layer in psd['layers']
   if layer.blendMode.clipping == 1
     clipping++

console.log "#{clipping} clipping items"

fs.open('./clippingtext.txt', 'a', 777, ( e, id ) -> 
  fs.write( id, "#{process.argv[2]} #{clipping}\n", null, 'utf8', ->{});
);
