fs = require 'fs'

{PSD} = require __dirname + '/../lib/psd.js'

if process.argv.length is 2
  console.log "Please specify an input file"
  process.exit()

psd = PSD.fromFile process.argv[2]

start = (new Date()).getTime()

psd.toFile __dirname + '/output.png', ->
  end = (new Date()).getTime()
  console.log "PSD flattened to output.png in #{end - start}ms"
