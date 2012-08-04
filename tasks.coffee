AWS = require "awssum"
AMAZON = AWS.load('amazon/amazon')
AWS_S3 = AWS.load("amazon/s3").S3

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
    
  @fetch_from_store = (store, prefix) ->
    console.log "Fetching design from  #{store}"
    options = {
      BucketName: store,
      Prefix: prefix
    }
    console.log options
    
    s3 = Store.get_connection()
    objects = []

    s3.ListObjects options, (err, data) ->
      try
        objects = data.Body.ListBucketResult.Contents
        for object in objects 
          console.log object.Key

      catch error
        console.log error
    
    return objects
  
  @save_to_store = (design_path, design_store) ->
    console.log "Saving output to #{design_store}"

module.exports = {
  
  psdjsProcessorJob: (args, callback) ->
    prefix = "#{args.user}/#{args.design}"
    Store.fetch_from_store args.store, prefix
    callback()
}

