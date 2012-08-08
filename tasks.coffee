AWS = require "awssum"
AMAZON = AWS.load('amazon/amazon')
AWS_S3 = AWS.load("amazon/s3").S3
fs = require "fs"
path = require "path"
events = require "events"
FileUtils = require "file"
yaml = require "js-yaml"
wrench = require 'wrench'
{PSD} = require './lib/psd.js'

emitter = new events.EventEmitter()

class Utils
  @process_photoshop_file = (design_directory) ->
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

    emitter.emit 'processing-done'
    
  @get_local_constants = () ->
    configs = require "./local_constants.yml"
    return configs

class Store
  @S3 = null

  @get_connection = () ->
    aws_access_key_id = process.env.AWS_ACCESS_KEY_ID || ""
    aws_access_key_secret = process.env.AWS_SECRET_ACCESS_KEY || ""
    aws_region = AMAZON.US_EAST_1 || ""
    if not @S3?
      @S3 = new AWS_S3({
       'accessKeyId' : aws_access_key_id,
       'secretAccessKey' : aws_access_key_secret,
       'region' : aws_region
      })

    return @S3
  
  @fetch_next_object_from_store = (store, objects, filter) ->
    object_name = objects.shift()

    if object_name
      # Add an one time listener to queue the next item when this object gets processed.
      emitter.once 'object-done', () ->
        Store.fetch_next_object_from_store store, objects, filter
      
      object_extname = path.extname object_name

      if filter? and filter != object_extname
        # skipping processing this object
        emitter.emit 'object-done' 
        return
    
      s3 = Store.get_connection()
      
      options = {
        BucketName: store, 
        ObjectName: object_name
      }
      
      dirname = path.dirname object_name
      destination_dir = path.join "/tmp", "store", dirname
      FileUtils.mkdirsSync destination_dir

      basename = path.basename object_name
      destination_file = path.join destination_dir, basename
      
      s3.GetObject options, (err, data) ->
        fptr = fs.createWriteStream destination_file, {flags: 'w', encoding: 'binary', mode: '0666'}
        fptr.write(data.Body)

        fptr.on 'close', () ->
          console.log "Successfully fetched #{destination_file}"
          # This object has been fetched and saved. Signal object-done
          emitter.emit 'object-done'
          
        fptr.end()
    else
      # We have come to the last object, so entire list of objects have been completed.
      emitter.emit 'fetch-done'
    
  @fetch_directory_from_store = (store, prefix, filter = null) ->
    console.log "Fetching design from #{store}"
    list_options = {
      BucketName: store,
      Prefix: prefix
    }
    
    if store == "store_local"
      configs = Utils.get_local_constants()
      local_src_dir = "#{configs.LOCAL_STORE}/#{prefix}"
      local_destination_dir = path.join "/tmp", "store", prefix
      FileUtils.mkdirsSync local_destination_dir
      wrench.copyDirSyncRecursive local_src_dir, local_destination_dir
      emitter.emit 'fetch-done'
    else 
      s3 = Store.get_connection()
    
      s3.ListObjects list_options, (err, data) ->
        try
          raw_objects = data.Body.ListBucketResult.Contents
          if typeof(raw_objects.Key) == "undefined"
            objects = (object.Key for object in raw_objects)
          else
            objects = [raw_objects.Key]

          Store.fetch_next_object_from_store store, objects, filter
        catch error
          console.log error
        
  @save_next_object_to_store = (store, local_files) ->
    local_source_file = local_files.shift()

    emitter.once 'put-done', () ->
      Store.save_next_object_to_store store, local_files

    if local_source_file
      object_key = path.relative(path.join("/tmp", "store"), local_source_file)
      buf = fs.readFileSync local_source_file
      
      s3 = Store.get_connection()
      
      put_options = {
        BucketName: store,
        ObjectName: object_key,
        ContentLength: buf.length,
        Body: buf,
      }
  
      s3.PutObject put_options, (err, data) ->
        emitter.emit 'put-done'
    else
      emitter.emit 'saving-done'
  
  @save_to_store = (store, design_directory) ->
    files_to_put = []
    processed_directory = path.join '/tmp', 'store', design_directory, "psdjsprocessed"
    
    if store == "store_local"
      configs = Utils.get_local_constants()
      local_destination_dir = "#{configs.LOCAL_STORE}/#{design_directory}/psdjsprocessed"
      FileUtils.mkdirsSync local_destination_dir
      wrench.copyDirSyncRecursive processed_directory, local_destination_dir
      emitter.emit 'saving-done'
    else
      FileUtils.walkSync processed_directory, (dirPath, dirs, files) ->
        for file in files
          full_path = path.join dirPath, file
          files_to_put.push full_path

      Store.save_next_object_to_store store, files_to_put

module.exports = {
  
  PsdjsProcessorJob: (args, callback) ->
    prefix = "#{args.user}/#{args.design}"
    
    emitter.removeAllListeners 'fetch-done'
    emitter.removeAllListeners 'processing-done'
    emitter.removeAllListeners 'saving-done'
    
    # An array of done events  
    emitter.once 'fetch-done', () ->
      console.log "Beginning to process psd file"
      Utils.process_photoshop_file prefix
      
    emitter.once 'processing-done', () ->
      console.log "Storing output files to store again"
      Store.save_to_store args.bucket, prefix
      
    emitter.once 'saving-done', () ->
      callback()

    Store.fetch_directory_from_store args.bucket, prefix, ".psd"
}
