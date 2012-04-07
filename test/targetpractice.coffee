glob = require "glob"
{PSDTest} = require('./psdtest')

class exports.TargetPractice
  libs: []
  pattern: ""

  constructor: (@pattern) ->

  runTests: ->
    glob @pattern, cwd: __dirname, (err, files) =>
      console.log err if err
      test = new PSDTest files
      test.run()
