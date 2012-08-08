fs = require "fs"
path = require "path"
yaml = require "js-yaml"

# File handling utils
FileUtils = require "file"
wrench = require 'wrench'

# Require and instantiate EventEventsHandler.emitter to simulate serial flow of events
EventsHandler = require "./events_handler"

# Require all AWS stuff for storing to S3 in remote stores
AWS = require "awssum"
AMAZON = AWS.load('amazon/amazon')
AWS_S3 = AWS.load("amazon/s3").S3

module.exports = {
  S3: null

  get_config: () ->
    configs = require "../local_constants.yml"
    return configs

  get_connection: () ->
    aws_access_key_id = process.env.AWS_ACCESS_KEY_ID || ""
    aws_access_key_secret = process.env.AWS_SECRET_ACCESS_KEY || ""
    aws_region = AMAZON.US_EAST_1 || ""
    if not S3?
      S3 = new AWS_S3({
       'accessKeyId' : aws_access_key_id,
       'secretAccessKey' : aws_access_key_secret,
       'region' : aws_region
      })

    return S3
  
  fetch_next_object_from_store: (store, objects, filter) ->
    object_name = objects.shift()

    if object_name
      # Add an one time listener to queue the next item when this object gets processed.
      EventsHandler.emitter.once 'object-done', () ->
        fetch_next_object_from_store store, objects, filter
      
      object_extname = path.extname object_name

      if filter? and filter != object_extname
        # skipping processing this object
        EventsHandler.emitter.emit 'object-done'
        return
    
      s3 = this.get_connection()
      
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
          EventsHandler.emitter.emit 'object-done'
          
        fptr.end()
    else
      # We have come to the last object, so entire list of objects have been completed.
      EventsHandler.emitter.emit 'fetch-done'
    
  fetch_directory_from_store: (store, prefix, filter = null) ->
    console.log "Fetching design from #{store}"
    list_options = {
      BucketName: store,
      Prefix: prefix
    }
    
    if store == "store_local"
      configs = this.get_config()
      local_src_dir = "#{configs.LOCAL_STORE}/#{prefix}"
      local_destination_dir = path.join "/tmp", "store", prefix
      FileUtils.mkdirsSync local_destination_dir
      wrench.copyDirSyncRecursive local_src_dir, local_destination_dir
      EventsHandler.emitter.emit 'fetch-done'
    else
      s3 = this.get_connection()
    
      s3.ListObjects list_options, (err, data) ->
        try
          raw_objects = data.Body.ListBucketResult.Contents
          if typeof(raw_objects.Key) == "undefined"
            objects = (object.Key for object in raw_objects)
          else
            objects = [raw_objects.Key]

          this.fetch_next_object_from_store store, objects, filter
        catch error
          console.log error
        
  save_next_object_to_store: (store, local_files) ->
    local_source_file = local_files.shift()

    EventsHandler.emitter.once 'put-done', () ->
      save_next_object_to_store store, local_files

    if local_source_file
      object_key = path.relative(path.join("/tmp", "store"), local_source_file)
      buf = fs.readFileSync local_source_file
      
      s3 = this.get_connection()
      
      put_options = {
        BucketName: store,
        ObjectName: object_key,
        ContentLength: buf.length,
        Body: buf,
      }
  
      s3.PutObject put_options, (err, data) ->
        EventsHandler.emitter.emit 'put-done'
    else
      EventsHandler.emitter.emit 'saving-done'
  
  save_to_store: (store, design_directory) ->
    files_to_put = []
    processed_directory = path.join '/tmp', 'store', design_directory, "psdjsprocessed"
    
    if store == "store_local"
      configs = this.get_config()
      local_destination_dir = "#{configs.LOCAL_STORE}/#{design_directory}/psdjsprocessed"
      FileUtils.mkdirsSync local_destination_dir
      wrench.copyDirSyncRecursive processed_directory, local_destination_dir
      EventsHandler.emitter.emit 'saving-done'
    else
      FileUtils.walkSync processed_directory, (dirPath, dirs, files) ->
        for file in files
          full_path = path.join dirPath, file
          files_to_put.push full_path

      save_next_object_to_store store, files_to_put
}
