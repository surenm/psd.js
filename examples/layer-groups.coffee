fs = require 'fs'

{PSD} = require __dirname + '/../lib/psd.js'

if process.argv.length is 2
  console.log "Please specify an input file"
  process.exit()

psd = PSD.fromFile process.argv[2]

console.log "Parsing PSD..."
psd.parse()

console.log "Parsing finished!\n"
console.log "PSD Groups\n======================="

prefix = []
for layer in psd.layers
  console.log prefix.join("") + layer.name unless layer.isHidden

  if layer.isFolder
    prefix.push "->  "
  else if layer.isHidden
    prefix.pop()
