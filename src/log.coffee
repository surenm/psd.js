# A simple logger class that lets you enable/disable logging to
# the console, since it can be very verbose.
class Log
  # Alias debug() to log()
  @debug: @log = -> @output "log", arguments

  # Call the console function
  @output: (method, data) ->
    if exports?
      # If we're in Node, we can call apply() on console functions
      console[method].apply null, data if PSD.DEBUG
    else
      # If we're in the browser, we have to log the array because
      # IE doesn't support calling apply() on console functions.
      console[method]("[PSD]", data) if PSD.DEBUG