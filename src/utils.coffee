fs = require "fs"
path = require "path"
yaml = require "js-yaml"

FileUtils = require "file"

# Require and instantiate EventEventsHandler.emitter to simulate serial flow of events
EventsHandler = require "./events_handler"

{PSD} = require '../lib/psd.js'

module.exports = {
  process_photoshop_file: (design_directory) ->
    absolute_design_directory = path.join "/tmp", "store", design_directory
    processed_directory = path.join absolute_design_directory, "psdjsprocessed"
    screenshot_png = path.join processed_directory, 'output.png'
    processed_json = path.join processed_directory, 'output.json'
    exported_images_dir = path.join processed_directory, 'images'
    
    FileUtils.mkdirsSync exported_images_dir
      
    files = fs.readdirSync absolute_design_directory
    for file in files
      if path.extname(file) == ".psd"
        console.log "Found a psd file - #{file}"
        psd_file_path = path.join absolute_design_directory, file
        psd = PSD.fromFile psd_file_path
        psd.setOptions
          layerImages: true
          onlyVisibleLayers: true
        console.log "Starting to parse the file..."
        psd.parse()
        
        console.log "Generating screenshot file..."
        psd.toFileSync screenshot_png

        console.log "Generating processed JSON..."
        fs.writeFileSync processed_json, JSON.stringify(psd)
        
        for layer in psd.layers
          continue if not layer.image?
          try
            layer_safe_name = layer.name.replace(/[^0-9a-zA-Z]/g,'_')
            layer.image.toFileSync "#{exported_images_dir}/#{layer_safe_name}.png"
          catch error
            console.log  "Error #{error} in generating image for #{layer.name}"
        break

    EventsHandler.emitter.emit 'processing-done'
    
}
