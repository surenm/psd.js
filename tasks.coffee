AWS = require "awssum"
AMAZON = AWS.load('amazon/amazon')
AWS_S3 = AWS.load("amazon/s3").S3
fs = require "fs"
path = require "path"
Sync = require "sync"
events = require "events"
emitter = new events.EventEmitter()

class FileUtils
  @mkdir_p = (p, mode="0777") ->
    ps = path.normalize(p).split('/')
    exists = path.existsSync p
    if not exists
      FileUtils.mkdir_p ps.slice(0,-1).join('/'), mode
      fs.mkdirSync p, mode

class Store
  PRODUCTION = "store_prod"
  STAGING = "store_staging"

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
      FileUtils.mkdir_p destination_dir

      basename = path.basename object_name
      destination_file = path.join destination_dir, basename
      
      s3.GetObject options, (err, data) ->
        fptr = fs.createWriteStream destination_file, {flags: 'w', encoding: 'binary', mode: '0666'}
        fptr.write(data.Body)
        console.log "Successfully written #{destination_file}"
        
        # This object has been fetched and saved. Signal object-done
        emitter.emit 'object-done'
    else
      # We have come to the last object, so entire list of objects have been completed.
      emitter.emit 'list-done'
    
  @fetch_directory_from_store = (store, prefix, filter = null) ->
    console.log "Fetching design from  #{store}"
    list_options = {
      BucketName: store,
      Prefix: prefix
    }
    
    s3 = Store.get_connection()
    
    emitter.addListener 'list-done', () ->
      emitter.emit 'fetch-done'

    s3.ListObjects list_options, (err, data) ->
      try
        raw_objects = data.Body.ListBucketResult.Contents
        objects = (object.Key for object in raw_objects)
        Store.fetch_next_object_from_store store, objects, filter
      catch error
        console.log error
  
  @save_to_store = (design_path, design_store) ->
    console.log "Saving output to #{design_store}"

module.exports = {
  
  psdjsProcessorJob: (args, callback) ->
    prefix = "#{args.user}/#{args.design}"

    emitter.addListener 'fetch-done', () ->
      callback()

    Store.fetch_directory_from_store args.store, prefix
}

