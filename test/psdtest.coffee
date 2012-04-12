nodeunit = require 'nodeunit'
assert = nodeunit.assert

fs = require 'fs'
crypto = require 'crypto'

{PSD} = require "#{__dirname}/../lib/psd"
PNG = require "png-js"

class exports.PSDTest
  TMP_FILE = "#{__dirname}/out.png"
  TP_ROOT = "#{__dirname}/psd.tp"
  color =
    errorPrefix: "\u001B[31m"
    errorSuffix: "\u001B[39m"
    okPrefix: "\u001B[32m"
    okSuffix: "\u001B[39m"

  metaCommands: [
    "Title"
    "ExportsTo"
    "Size"
  ]

  constructor: (@files) ->
    process.chdir __dirname

    try
      assert.ok fs.readdirSync(TP_ROOT).length > 0
    catch e
      console.log """
      #{color.errorPrefix}It looks like the psd.tp submodule is missing. Run:

        git submodule init
        git submodule update

      and then try running the tests again.#{color.errorSuffix}
      """

      process.exit()

    assert.ok @files, 'File data set'

  run: -> @testsAgainstFiles()
  teardown: -> fs.unlink TMP_FILE

  testsAgainstFiles: ->
    runTest = (file) =>
      return @teardown() unless @files.length
      @doFileTest file, => runTest @files.shift()

    runTest @files.shift()

  doFileTest: (file, cb) ->
    @needsNewline = false

    console.log "Starting test for #{file}"
    testData = JSON.parse fs.readFileSync(file, 'utf8')

    assert.ok testData._file, "Input file provided"

    psd = PSD.fromFile "#{TP_ROOT}/#{testData._file}"
    psd.parse()

    @successfullyParsed psd
    @assertExports psd, testData, =>
      @assertAttributes psd, testData.psd, =>
        console.log "" if @needsNewline
        cb()

  successfullyParsed: (psd) ->
    try
      assert.ok psd.header, "Header successfully parsed"
    catch e
      @outputError e

    try
      assert.ok psd.layers, "Layers successfully parsed"
    catch e
      @outputError e

    try
      assert.ok psd.image, "Image successfully parsed"
    catch e
      @outputError e

  assertExports: (psd, testData, cb) ->
    return cb() unless testData._exports_to?

    psd.toFileSync TMP_FILE
    @compareImages "#{TP_ROOT}/#{testData._exports_to}", TMP_FILE, cb
    

  assertAttributes: (obj, hash = {}, cb) ->
    hashLength = 0
    hashLength++ for own k, v of hash

    return cb() if hashLength is 0

    done = 0
    testDone = =>
      done++
      cb() if done is hashLength

    for own k, v of hash
      k = @toCamelCase k

      try
        assert.ok obj[k], "Attribute exists: #{@toCamelCase(k)}" unless @isMetaCommand(k)
      catch e
        @outputError e
        testDone()
        continue

      if @isMetaCommand(k)
        @performMetaAssertion obj, k, v, testDone
      else if Array.isArray v
        index = 0
        for i in v
          @assertAttributes obj[k][index], i, testDone
          index++
      else if typeof v is "object"
        @assertAttributes obj[k], v, testDone
      else if typeof v is "string"
        try
          assert.equal v, obj[k], "Attribute #{v} === #{obj[k]}"
        catch e
          @outputError e

        testDone()
      else testDone()

  isMetaCommand: (v) -> v in @metaCommands

  performMetaAssertion: (obj, command, v, cb) ->
    switch command
      when "_size"
        assert.equal val, obj[key].length for own key, val of v
        cb()
      when "_exports_to"
        assert.ok obj.image?
        obj.image.toFileSync TMP_FILE
        @compareImages "#{TP_ROOT}/#{v}", TMP_FILE, cb
      else cb() # unknown assertion


  compareImages: (expectedPath, actualPath, cb) ->
    expectedPixels = null
    actualPixels = null
    done = 0

    decodeDone = =>
      done++
      compare() if done is 2

    compare = =>
      try
        assert.deepEqual actualPixels, expectedPixels, "Output file matches control"
        @outputSuccess "Rendered image matches control"
        cb()
      catch e
        @outputError e
        cb()

    PNG.decode expectedPath, (pixels) -> 
      expectedPixels = pixels
      decodeDone()

    PNG.decode actualPath, (pixels) -> 
      actualPixels = pixels
      decodeDone()

  outputError: (e) ->
    @needsNewline = true
    console.log "#{color.errorPrefix}✖ #{e.name}: #{e.message}#{color.errorSuffix}"

  outputSuccess: (msg) -> 
    @needsNewline = true
    console.log "#{color.okPrefix}✔ #{msg}#{color.okSuffix}"

  toCamelCase: (attr) ->
    attr.replace /_([a-z])/gi, (s, group) -> group.toUpperCase()

