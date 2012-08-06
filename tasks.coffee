AWS = require "awssum"
AMAZON = AWS.load('amazon/amazon')
AWS_S3 = AWS.load("amazon/s3").S3
fs = require "fs"
path = require "path"
Sync = require "sync"
events = require "events"
FileUtils = require "file"
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

        psd.parse()
        psd.toFileSync screenshot_png
        fs.writeFileSync processed_json, JSON.stringify(psd)
        
        for layer in psd.layers
          continue unless layer.image
          layer.image.toFileSync "#{exported_images_dir}/#{layer.name}.png"
          
        break

    emitter.emit 'processing-done'

class Store
  @S3 = null

  @get_connection = () ->
    aws_access_key_id = process.env.AWS_ACCESS_KEY_ID
    aws_access_key_secret = process.env.AWS_SECRET_ACCESS_KEY
    aws_region = AMAZON.US_EAST_1
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
          console.log "Successfully written #{destination_file}"
          # This object has been fetched and saved. Signal object-done
          emitter.emit 'object-done'
          
        fptr.end()
    else
      # We have come to the last object, so entire list of objects have been completed.
      emitter.emit 'fetch-done'
    
  @fetch_directory_from_store = (store, prefix, filter = null) ->
    console.log "Fetching design from  #{store}"
    list_options = {
      BucketName: store,
      Prefix: prefix
    }
    
    s3 = Store.get_connection()
    
    s3.ListObjects list_options, (err, data) ->
      try
        raw_objects = data.Body.ListBucketResult.Contents
        objects = (object.Key for object in raw_objects)
        Store.fetch_next_object_from_store store, objects, filter
      catch error
        console.log error
        
  @save_next_object_to_store = (store, local_files) ->
    local_source_file = local_files.shift()

    emitter.once 'put-done', () ->
      Store.save_next_object_to_store store, local_files

    s3 = Store.get_connection()

    if local_source_file
      object_key = path.relative(path.join("/tmp", "store"), local_source_file)
      buf = fs.readFileSync local_source_file
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
    
    FileUtils.walkSync processed_directory, (dirPath, dirs, files) ->
      for file in files
        full_path = path.join dirPath, file
        files_to_put.push full_path

    Store.save_next_object_to_store store, files_to_put    

module.exports = {
  
  PsdjsProcessorJob: (args, callback) ->
    prefix = "#{args.user}/#{args.design}"
    
    # An array of done events  
    emitter.addListener 'fetch-done', () ->
      Utils.process_photoshop_file prefix
      
    emitter.addListener 'processing-done', () ->
      Store.save_to_store args.store, prefix
      
    emitter.addListener 'saving-done', () ->
      callback()

    Store.fetch_directory_from_store args.store, prefix, ".psd"
}