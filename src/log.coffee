# A simple logger class that lets you enable/disable logging to
# the console, since it can be very verbose.
class Log
  @DEBUG = false
  
  # Alias debug() to log()
  @debug: @log = -> @output "log", arguments

  # Call the console function
  @output: (method, data) ->
    console[method].apply null, data if this.DEBUG

module.exports = Log