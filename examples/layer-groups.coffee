fs = require 'fs'

{PSD} = require __dirname + '/../lib/psd.js'
PSD.DEBUG = true
if process.argv.length is 2
  console.log "Please specify an input file"
  process.exit()

psd = PSD.fromFile process.argv[2]

console.log "Parsing PSD..."
psd.parse()

console.log "Parsing finished!\n"
console.log "PSD Groups\n======================="

base = psd.getLayerStructure()

outputFolder = (folder, prefix = []) ->
  console.log prefix.join("") + folder.name if folder.name
  for layer in folder.layers
    console.log prefix.join("") + layer.name
    if layer.layers?
      # This is a nested folder
      prefix.push "->  "; outputFolder(layer, prefix); prefix.pop()

outputFolder(base)