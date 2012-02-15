# NodeJS or browser?
if exports?
  Root = exports
  fs = require 'fs'
else
  Root = window

# Create our class and add to global scope
Root.PSD = class PSD
  # Enable/disable debugging console logs
  @DEBUG = true

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

  # Load a PSD from a URL via ajax.
  # TODO
  @fromURL: (url) ->
  
  constructor: (data) ->
    # Store the main reference to our PSD file
    @file = new PSDFile data

    @header = null
    @resources = null
    @numLayers = 0
    @layers = null
    @images = null
    @image = null

  # Attempt to parse all sections of the PSD file
  parse: ->
    Log.debug "Beginning parsing"
    @startTime = (new Date()).getTime()

    # It's important to parse all of the file sections in the correct order,
    # which is used here.
    @parseHeader()
    @parseImageResources()
    @parseLayersMasks()
    #@parseImageData()

    @endTime = (new Date()).getTime()
    Log.debug "Parsing finished in #{@endTime - @startTime}ms"

  parseHeader: ->
    Log.debug "\n### Header ###"

    # Store a reference to the file header
    @header = new PSDHeader @file

    # Begin header parsing
    @header.parse()

    Log.debug @header

  parseImageResources: ->
    Log.debug "\n### Resources ###"

    # Every PSD file has a number of resources, so we simply store them in an
    # array for now. In the future, it might make more sense to store resources
    # in an object indexed by the resource ID.
    @resources = []

    # Find the size of the resources section
    [n] = @file.readf ">L"

    # Continue parsing resources until we've reached the end of the section.
    while n > 0
      resource = new PSDResource @file
      n -= resource.parse()

      Log.debug "Resource: ", resource

    # This shouldn't happen. If it does, then likely something is being parsed
    # incorrectly in one of the resources, or the file is corrupt.
    Log.debug "Image resources overran expected size by #{-n} bytes" if n isnt 0

  parseLayersMasks: ->
    @parseHeader() if not @header

    if not @resources
      @file.skipBlock('image resources')
      @resources = 'not parsed'

    Log.debug "\n### Layers & Masks ###"

    @layerMask = new PSDLayerMask @file, @header
    @layerMask.parse()

  parseImageData: ->
    @parseHeader() if not @header

    # 0 = raw; 1 = RLE (TIFF); 2 = ZIP w/o prediction; 3 = ZIP w/ prediction
    compression = @file.readShortInt()

    # Length until EOF
    length = @file.data.length - @file.tell()
    Log.debug "#{length} bytes until EOF. Parsing image data..."

    @image = new PSDImage @file, compression, @header, length
    @image.parse()
