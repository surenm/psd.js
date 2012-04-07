glob = require "glob"
{PSDTest} = require('./psdtest')

class exports.TargetPractice
  libs: []
  pattern: ""

  constructor: (@pattern) ->

  runTests: ->
    glob @pattern, cwd: __dirname, (er, files) =>
      test = new PSDTest files
      test.run()
