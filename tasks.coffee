# Require and instantiate EventEventsHandler.emitter to simulate serial flow of events

Store = require "./src/store"
Utils = require "./src/utils"
EventsHandler = require "./src/events_handler"

module.exports = {
  PsdjsProcessorJob: (args, callback) ->
    prefix = "#{args.user}/#{args.design}"
   
    EventsHandler.emitter.removeAllListeners 'fetch-done'
    EventsHandler.emitter.removeAllListeners 'processing-done'
    EventsHandler.emitter.removeAllListeners 'saving-done'
    
    # An array of done events  
    EventsHandler.emitter.once 'fetch-done', () ->
      console.log "Beginning to process psd file"
      Utils.process_photoshop_file prefix
      
    EventsHandler.emitter.once 'processing-done', () ->
      console.log "Storing output files to store again"
      Store.save_to_store args.bucket, prefix
      
    EventsHandler.emitter.once 'saving-done', () ->
      callback()

    # fetch the psd file alone to be processed  
    Store.fetch_directory_from_store args.bucket, prefix, ".psd"
}
