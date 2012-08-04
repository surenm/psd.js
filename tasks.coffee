AWS = require "awssum"
AMAZON = AWS.load('amazon/amazon')
AWS_S3 = AWS.load("amazon/s3").S3

class Store
  PRODUCTION = "store_prod"
  STAGING = "store_staging"
  fetch_from_store = (design_path, design_store) ->
    console.log "Fetching design from  #{design_store}"
    
  save_to_store = (design_path, design_store) ->
    console.log "Saving output to #{design_store}"
    
    
module.exports = {
  screenshotJob: (design, callback) ->
    Store.fetch_from_store (design, )
    callback()

  psdjsProcessorJob: (design, callback) ->
    callback()
}

