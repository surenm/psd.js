fs = require 'fs'

{PSD} = require __dirname + '/../lib/psd.js'

PSD.DEBUG = true

if process.argv.length is 2
  console.log "Please specify an input file"
  process.exit()

psd = PSD.fromFile process.argv[2]
psd.parse()

data = psd.toJSON()

fs.writeFile __dirname + "/output.json", JSON.stringify(data, null, "\t"), (err) ->
  console.log "JSON data saved to output.json"