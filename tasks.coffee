AWS = require "awssum"
AMAZON = AWS.load('amazon/amazon')
AWS_S3 = AWS.load("amazon/s3").S3

class Store
  PRODUCTION = "store_prod"
  STAGING = "store_staging"
  fetch_from_store = (design_path, design_store) ->
    console.log "Fetching design from  #{design_store}"
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
    
  save_to_store = (design_path, design_store) ->
    console.log "Saving output to #{design_store}"
    
    
module.exports = {
  screenshotJob: (design, callback) ->
    Store.fetch_from_store (design, )
    callback()

  psdjsProcessorJob: (design, callback) ->
    callback()
}

