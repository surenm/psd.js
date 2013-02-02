fs = require 'fs'
path = require 'path'
PSD = require '../src/psd'

input_psd_file = process.argv[2]
output_dir = process.argv[3]
basename = process.argv[4]

console.log "Input psd file is #{input_psd_file}"
console.log "Output directory is #{output_dir}"

psd = PSD.fromFile input_psd_file

psd.setOptions
  layerImages: false
  onlyVisibleLayers: true

png_file = path.join output_dir, "#{basename}.png"
design_file = path.join output_dir, "#{basename}.json"

# Parse the photoshop file
psd.parse()

# Save the processed output to processed json
fs.writeFileSync design_file, JSON.stringify(psd)

# Save a screenshot of the photoshop file in PNG format
psd.toFileSync png_file