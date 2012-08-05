AWS = require "awssum"
AMAZON = AWS.load('amazon/amazon')
AWS_S3 = AWS.load("amazon/s3").S3
fs = require "fs"
path = require "path"
Sync = require "sync"


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
  
  @fetch_object_from_store = (store, key) ->
    options = {
      BucketName: store, 
      ObjectName: key 
    }
    
    s3 = Store.get_connection()

    s3.GetObject options, (err, data) ->
      basename = path.basename key
      destination_file = path.join "/tmp", basename
      fptr = fs.createWriteStream destination_file, {flags: 'w', encoding: 'binary', mode: '0666'}
      fptr.write(data.Body)
      console.log "Successfully written #{destination_file}"
    
    
  @fetch_directory_from_store = (store, prefix) ->
    console.log "Fetching design from  #{store}"
    list_options = {
      BucketName: store,
      Prefix: prefix
    }
    
    s3 = Store.get_connection()

    s3.ListObjects list_options, (err, data) ->
      try
        objects = data.Body.ListBucketResult.Contents
        for object in objects 
          Sync( () -> Store.fetch_object_from_store.sync(null, store, object.Key))
      catch error
        console.log error
    
    return
  
  @save_to_store = (design_path, design_store) ->
    console.log "Saving output to #{design_store}"

module.exports = {
  
  psdjsProcessorJob: (args, callback) ->
    prefix = "#{args.user}/#{args.design}"
    Store.fetch_directory_from_store args.store, prefix
    callback()
}

