# A PSDImage stores parsed image data for images contained within the PSD, and
# for the PSD itself.
class PSDImage
  COMPRESSIONS =
    0: 'Raw'
    1: 'RLE'
    2: 'ZIP'
    3: 'ZIPPrediction'

  channelsInfo: [
    {id: 0},
    {id: 1},
    {id: 2},
    {id: -1}
  ]

  constructor: (@file, @header) ->
    @numPixels = @getImageWidth() * @getImageHeight()

    @length = switch @getImageDepth()
      when 1 then (@getImageWidth() + 7) / 8 * @getImageHeight()
      when 16 then @getImageWidth() * @getImageHeight() * 2
      else @getImageWidth() * @getImageHeight()

    @channelLength = @length # in bytes
    @length *= @getImageChannels()

    @channelData = []
    @channelData.push 0 for x in [0...@length]

    @startPos = @file.tell()
    @endPos = @startPos + @length

    @pixelData =
      r: []
      g: []
      b: []
      a: []

  parse: ->
    @compression = @parseCompression()

    # ZIP compression isn't implemented yet. Luckily this is pretty rare. Still,
    # it's a TODO.
    Log.debug "Image size: #{@length} (#{@getImageWidth()}x#{@getImageHeight()})"

    if @compression in [2, 3]
      unless PSD.ZIP_ENABLED
        Log.debug "ZIP library not included, skipping."
        return @file.seek @endPos, false

    @parseImageData()

  parseCompression: -> @file.readShortInt()

  parseImageData: ->
    Log.debug "Image compression: id=#{@compression}, name=#{COMPRESSIONS[@compression]}"

    switch @compression
      when 0 then @parseRaw()
      when 1 then @parseRLE()
      when 2, 3 then @parseZip()
      else
        Log.debug "Unknown image compression. Attempting to skip."
        return @file.seek @endPos, false

    @processImageData()

  # Parse the image data as raw pixel values. There is no compression used here.
  parseRaw: (length = @length) ->
    Log.debug "Attempting to parse RAW encoded image..."
    @channelData = []
    @channelData.push @file.read(1)[0] for i in [0...length]

  # Parse the image with RLE compression. This is the same as the TIFF standard format.
  # Contains the scanline byte lengths first, then the actual encoded image data.
  parseRLE: ->
    Log.debug "Attempting to parse RLE encoded image..."

    # RLE stores the scan line byte counts in the first chunk of data
    @byteCounts = @getByteCounts()

    Log.debug "Read byte counts. Current pos = #{@file.tell()}, Pixels = #{@length}"

    @parseChannelData()

  # Get the height of the image. This varies depending on whether we're parsing layer
  # channel data or not.
  getImageHeight: -> @header.rows
  getImageWidth: -> @header.cols
  getImageChannels: -> @header.channels
  getImageDepth: -> @header.depth

  getByteCounts: ->
    byteCounts = []
    for i in [0...@getImageChannels()]
      for j in [0...@getImageHeight()]
        byteCounts.push @file.readShortInt()

    byteCounts

  parseChannelData: ->
    # And then it stores the compressed image data
    chanPos = 0
    lineIndex = 0

    for i in [0...@getImageChannels()] # i = plane num
      Log.debug "Parsing channel ##{i}, Start = #{@file.tell()}"
      [chanPos, lineIndex] = @decodeRLEChannel(chanPos, lineIndex)

  decodeRLEChannel: (chanPos, lineIndex) ->
    for j in [0...@getImageHeight()]
      byteCount = @byteCounts[lineIndex++]
      start = @file.tell()

      while @file.tell() < start + byteCount
        [len] = @file.read(1)

        if len < 128
          len++
          data = @file.read len

          # memcpy!
          @channelData[chanPos...chanPos+len] = data
          chanPos += len
        else if len > 128
          len ^= 0xff
          len += 2

          [val] = @file.read(1)
          data = []
          data.push val for z in [0...len]

          @channelData[chanPos...chanPos+len] = data
          chanPos += len

    [chanPos, lineIndex]

  parseZip: (prediction = false) ->
    #stream = inflater.append @file.read(@length)
    #inflater.flush()

    # ZIP decompression not implemented until I can find a PSD that's actually using it
    @file.seek @endPos, false

  # Once we've read the image data, we need to organize it and/or convert the pixel
  # values to RGB so they're easier to work with and can be easily output to either
  # browser or file.
  processImageData: ->
    Log.debug "Processing parsed image data. #{@channelData.length} pixels read."

    switch @header.mode
      when 1 # Greyscale
        @combineGreyscale8Channel() if @getImageDepth() is 8
        @combineGreyscale16Channel() if @getImageDepth() is 16
      when 3 # RGBColor
        @combineRGB8Channel() if @getImageDepth() is 8
        @combineRGB16Channel() if @getImageDepth() is 16
      when 4 #CMKYColor
        @combineCMYK8Channel()

  combineGreyscale8Channel: ->
    if @getImageChannels() is 2
      # Has alpha channel
      for i in [0...@numPixels]
        alpha = @channelData[i]
        grey = @channelData[@channelLength + i]

        @pixelData.r[i] = grey
        @pixelData.g[i] = grey
        @pixelData.b[i] = grey
        @pixelData.a[i] = alpha
    else
      for i in [0...@numPixels]
        @pixelData.r[i] = @channelData[i]
        @pixelData.g[i] = @channelData[i]
        @pixelData.b[i] = @channelData[i]
        @pixelData.a[i] = 255

  combineGreyscale16Channel: ->
    if @getImageChannels() is 2
      # Has alpha channel
      for i in [0...@numPixels]
        alpha = @channelData[i] >> 8
        grey = @channelData[@channelLength + i] >> 8

        @pixelData.r[i] = grey
        @pixelData.g[i] = grey
        @pixelData.b[i] = grey
        @pixelData.a[i] = alpha
    else
      for i in [0...@numPixels]
        @pixelData.r[i] = @channelData[i]
        @pixelData.g[i] = @channelData[i]
        @pixelData.b[i] = @channelData[i]
        @pixelData.a[i] = 255

  combineRGB8Channel: ->
    for i in [0...@numPixels]
      index = 0
      for chan in @channelsInfo
        switch chan.id
          when -1
            if @getImageChannels() is 4
              @pixelData.a[i] = @channelData[i + (@channelLength * index)]
          when 0 then @pixelData.r[i] = @channelData[i + (@channelLength * index)]
          when 1 then @pixelData.g[i] = @channelData[i + (@channelLength * index)]
          when 2 then @pixelData.b[i] = @channelData[i + (@channelLength * index)]

        index++
      

  combineRGB16Channel: ->
    for i in [0...@numPixels]
      @pixelData.r[i] = @channelData[i] >> 8
      @pixelData.g[i] = @channelData[i + @channelLength] >> 8
      @pixelData.b[i] = @channelData[i + (@channelLength * 2)] >> 8
      @pixelData.a[i] = @channelData[i + (@channelLength * 3)] >> 8 if @getImageChannels() is 4

  combineCMYK8Channel: ->
    for i in [0...@numPixels]
      c = @channelData[i]
      m = @channelData[i + @channelLength]
      y = @channelData[i + @channelLength * 2]
      k = @channelData[i + @channelLength * 3]

      rgb = PSDColor.cmykToRGB(c, m, y, k)
      @pixelData.r[i] = rgb.r
      @pixelData.g[i] = rgb.g
      @pixelData.b[i] = rgb.b

      if @getImageChannels() is 5
        @pixelData.a[i] = @channelData[i + @channelData * 4]
      else
        @pixelData.a[i] = 255

      
  # Normally, the pixel data is stored in planar order, meaning all the red
  # values come first, then the green, then the blue. In the HTML canvas, the
  # pixel color values are grouped by pixel such that the values alternate
  # between R, G, B, A over and over.
  #
  # This will return the pixels in the same format that is used by the HTML 
  # canvas. It is a 1D array that consists of a single pixel's color values 
  # expressed from 0 to 255 in chunks of 4. Each chunk consists of red, 
  # green, blue, and alpha values, respectively.
  #
  # This means a pure-red single pixel is expressed as: `[255, 0, 0, 255]`
  toCanvasPixels: ->
    result = []
    
    for i in [0...@numPixels]
      alpha = @pixelData.a[i]; alpha ?= 255
      result.push(
        @pixelData.r[i], 
        @pixelData.g[i], 
        @pixelData.b[i], 
        alpha)

    result

  toFile: (filename, cb = ->) ->
    try
      Canvas = require 'canvas'
    catch e
      throw "Exporting PSDs to file requires the canvas library"

    Image = Canvas.Image

    canvas = new Canvas(@getImageWidth(), @getImageHeight())
    context = canvas.getContext('2d')
    imageData = context.getImageData 0, 0, canvas.width, canvas.height
    pixelData = imageData.data

    pixelData[i] = pxl for pxl, i in @toCanvasPixels()

    context.putImageData imageData, 0, 0

    fs.writeFile filename, canvas.toBuffer(), cb

  toCanvas: (canvas, width = null, height = null) ->
    if width is null and height is null
      canvas.width = @getImageWidth()
      canvas.height = @getImageHeight()

    context = canvas.getContext('2d')
    imageData = context.getImageData 0, 0, canvas.width, canvas.height
    pixelData = imageData.data

    pixelData[i] = pxl for pxl, i in @toCanvasPixels()

    context.putImageData imageData, 0, 0

  toImage: ->
    canvas = document.createElement 'canvas'
    @toCanvas canvas
    canvas.toDataURL "image/png"
