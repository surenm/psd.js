###
# PSD.js - A Photoshop file parser for browsers and NodeJS
# https://github.com/meltingice/psd.js
#
# MIT LICENSE
# Copyright (c) 2011 Ryan LeFevre
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of this 
# software and associated documentation files (the "Software"), to deal in the Software 
# without restriction, including without limitation the rights to use, copy, modify, merge, 
# publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons 
# to whom the Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all copies or 
# substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING 
# BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
###

"use strict"

# NodeJS or browser?
if exports?
  Root = exports
  fs = require 'fs'
else
  Root = window

# Create our class and add to global scope
Root.PSD = class PSD
  # Enable/disable debugging console logs
  @DEBUG = false

  # Loads a PSD from a file. If we're in node, then this loads the
  # file from the filesystem. If we're in the browser, then this assumes
  # it has been passed a File object (either from a file input element,
  # or from HTML5 drag & drop).
  @fromFile: (file, cb = ->) ->
    if exports?
      # We're in node. Load via fs module.
      # Callback function isn't needed.
      data = fs.readFileSync file
      new PSD data
    else
      # We're in the browser. Assume we have a File object.
      reader = new FileReader()
      reader.onload = (f) ->
        # In order to convert the file data to a useful format, we need
        # to conver the buffer into a byte array.
        bytes = new Uint8Array(f.target.result)

        psd = new PSD(bytes)
        cb(psd)

      reader.readAsArrayBuffer(file)

  # Load a PSD from a URL via ajax
  @fromURL: (url, cb = ->) ->
    xhr = new XMLHttpRequest
    xhr.open "GET", url, true
    xhr.responseType = "arraybuffer"
    xhr.onload = ->
      data = new Uint8Array(xhr.response or xhr.mozResponseArrayBuffer)
      psd = new PSD(data)
      cb(psd)

    xhr.send null

  options:
    layerImages: false
  
  constructor: (data) ->
    # Store the main reference to our PSD file
    @file = new PSDFile data

    @header = null
    @resources = null
    @layerMask = null
    @layers = null
    @images = null
    @image = null

  setOptions: (options) ->
    @options[key] = val for own key, val of options

  # Attempt to parse all sections of the PSD file
  parse: ->
    Log.debug "Beginning parsing"
    @startTime = (new Date()).getTime()

    # It's important to parse all of the file sections in the correct order,
    # which is used here.
    @parseHeader()
    @parseImageResources()
    @parseLayersMasks()
    @parseImageData()

    @endTime = (new Date()).getTime()
    Log.debug "Parsing finished in #{@endTime - @startTime}ms"

  # Parse the first section: the header.
  # This section cannot be skipped, since it contains important parsing information
  # for the rest of the PSD file (and is relatively small anyways).
  parseHeader: ->
    Log.debug "\n### Header ###"

    # Store a reference to the file header
    @header = new PSDHeader @file
    @header.parse()

    Log.debug @header

  parseImageResources: (skip = false) ->
    Log.debug "\n### Resources ###"

    # Every PSD file has a number of resources, so we simply store them in an
    # array for now. In the future, it might make more sense to store resources
    # in an object indexed by the resource ID.
    @resources = []

    # Find the size of the resources section
    [n] = @file.readf ">L"
    length = n

    if skip
      Log.debug "Skipped!"
      return @file.seek n

    start = @file.tell()

    # Continue parsing resources until we've reached the end of the section.
    while n > 0
      resource = new PSDResource @file
      n -= resource.parse()
      @resources.push resource

      Log.debug "Resource: ", resource

    # This shouldn't happen. If it does, then likely something is being parsed
    # incorrectly in one of the resources, or the file is corrupt.
    if n isnt 0
      Log.debug "Image resources overran expected size by #{-n} bytes"
      @file.seek start + length

  parseLayersMasks: (skip = false) ->
    @parseHeader() unless @header
    @parseImageResources(true) unless @resources

    Log.debug "\n### Layers & Masks ###"

    @layerMask = new PSDLayerMask @file, @header, @options
    @layers = @layerMask.layers

    if skip
      Log.debug "Skipped!"
      @layerMask.skip()
    else
      @layerMask.parse()

  parseImageData: ->
    @parseHeader() unless @header
    @parseImageResources(true) unless @resources
    @parseLayersMasks(true) unless @layerMask

    @image = new PSDImage @file, @header
    @image.parse()

  # Exports a flattened version to a file. For use in NodeJS.
  toFile: (filename, cb = ->) -> 
    @parseImageData() unless @image
    @image.toFile filename, cb

  toFileSync: (filename) ->
    @parseImageData() unless @image
    @image.toFileSync filename

  # Given a canvas element
  toCanvas: (canvas, width = null, height = null) ->
    @parseImageData() unless @image
    @image.toCanvas canvas, width, height

  toImage: ->
    @parseImageData() unless @image
    @image.toImage()
