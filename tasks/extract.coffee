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
  layerImages: true
  onlyVisibleLayers: true

png_file = path.join output_dir, "#{basename}.png"
design_file = path.join output_dir, "#{basename}.json"
assets_directory = path.join output_dir, "assets"
images_directory = path.join assets_directory, "images"

# Parse the photoshop file
psd.parse()

if psd.hasClippingLayers()
  clipping_layer_file = path.join output_dir, "has_clipping_layer"
  console.log "Input photoshop file has clipping layer. Sending for preprocessing"
  fs.writeFileSync clipping_layer_file, ""
  process.exit()

# Save the processed output to processed json
fs.writeFileSync design_file, JSON.stringify(psd)

# Save a screenshot of the photoshop file in PNG format
psd.toFileSync png_file

# Save individual layer assets
for layer in psd.layers
  continue unless layer.image
  
  image_name = layer.name.replace /[^0-9a-zA-Z]/g, '_'
  image_file_name = path.join images_directory, "#{image_name}_#{layer.layerId}.png"
  layer.image.toFileSync image_file_name