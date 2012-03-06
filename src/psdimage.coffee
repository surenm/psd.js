# A PSDImage stores parsed image data for images contained within the PSD, and
# for the PSD itself.
class PSDImage
  COMPRESSIONS =
    0: 'Raw'
    1: 'RLE'
    2: 'ZIP'
    3: 'ZIPPrediction'

  MIN_TEMP_CHANNEL_LENGTH = 12288

  constructor: (@file, @header, @layer = null) ->
    @width = @header.cols
    @height = @header.rows
    @numPixels = @width * @height

    @length = switch @header.depth
      when 1 then (@width + 7) / 8 * @height
      when 16 then @width * @height * 2
      else @width * @height

    @channelLength = @length # in bytes
    @length *= @header.channels

    if @layer and not @layer.isFolder
      maskChannelLength = switch @header.depth
        when 8 then @layer.mask.width * @layer.mask.height
        when 16 then @layer.mask.width * @layer.mask.height * 2
        else 0

      maskPixels = @layer.mask.width * @layer.mask.height
      maskPixels *= 2 if @header.depth is 16
      @maxChannelLength = Math.max maskChannelLength, @channelLength

      if @maxChannelLength <= 0
        for i in [0...@header.channels]
          @file.seek @layer.channelsInfo[i].length

        return # No data?

    @startPos = @file.tell()
    @endPos = @startPos + @length

    @channelData = []

    if @layer
      for i in [0...@header.channels]
        compression = @file.readShortInt()
        @layer.channelsInfo[i].compression = compression

        length = @layer.channelsInfo[i].length - 2
        length = Math.max length, MIN_TEMP_CHANNEL_LENGTH

        @layer.channelsInfo[i].data = @file.read(length)
    else
      @compression = @file.readShortInt()

    @channelData.push 0 for x in [0...@length]

    @pixelData =
      r: []
      g: []
      b: []
      a: []

  parse: ->
    return @parseLayerChannels() if @layer

    # ZIP compression isn't implemented yet. Luckily this is pretty rare. Still,
    # it's a TODO.
    Log.debug "Image compression: id=#{@compression}, name=#{COMPRESSIONS[@compression]}"
    Log.debug "Image size: #{@length} (#{@width}x#{@height})"

    args = Array::slice.call(arguments)

    if @compression in [2, 3]
      unless PSD.ZIP_ENABLED
        Log.debug "ZIP library not included, skipping."
        return @file.seek @endPos, false

      args.unshift(@compression is 3)

    switch @compression
      when 0 then @parseRaw.apply @, args
      when 1 then @parseRLE.apply @, args
      when 2, 3 then @parseZip.apply @, args
      else
        Log.debug "Unknown image compression. Attempting to skip."
        @file.seek @endPos, false

  parseLayerChannels: ->
    for i in [0...@header.channels]
      channel = @layer.channelsInfo[i]

      switch channel.compression
        when 0
          if channel.id is -2
            @parseRaw.call @, channel.length
          else
            @parseRaw.call @, @channelLength
        when 1 then @parseRLE.call @, new PSDFile(channel.data), channel

  # Parse the image data as raw pixel values. There is no compression used here.
  parseRaw: (length = @length) ->
    Log.debug "Attempting to parse RAW encoded image..."
    @channelData.push @file.read(1)[0] for i in [0...length]

    @processImageData()

  # Parse the image with RLE compression. This is the same as the TIFF standard format.
  # Contains the scanline byte lengths first, then the actual encoded image data.
  parseRLE: (file = @file, channelInfo = null) ->
    Log.debug "Attempting to parse RLE encoded image..."

    if channelInfo
      if channelInfo.id is -2
        height = @layer.mask.height
      else
        height = @layer.rows
    else
      height = @height

    # RLE stores the scan line byte counts in the first chunk of data
    byteCounts = []

    if channelInfo
      for j in [0...height]
        byteCounts.push file.readShortInt()
    else
      for i in [0...@header.channels]
        for j in [0...height]
          byteCounts.push file.readShortInt()

    Log.debug "Read byte counts. Current pos = #{file.tell()}, Pixels = #{@length}"

    # And then it stores the compressed image data
    chanPos = 0
    lineIndex = 0

    parseChannel = =>
      for j in [0...height]
        byteCount = byteCounts[lineIndex++]
        start = file.tell()

        while file.tell() < start + byteCount
          [len] = file.read(1)

          if len < 128
            len++
            data = file.read len

            # memcpy!
            @channelData[chanPos...chanPos+len] = data
            chanPos += len
          else if len > 128
            len ^= 0xff
            len += 2

            [val] = file.read(1)
            data = []
            data.push val for z in [0...len]

            @channelData[chanPos...chanPos+len] = data
            chanPos += len

    if channelInfo
      Log.debug "Parsing layer channel..."
      parseChannel()
    else
      for i in [0...@header.channels] # i = plane num
        Log.debug "Parsing channel ##{i}, Start = #{file.tell()}"
        parseChannel()

    @processImageData()

  parseZip: (prediction = false) ->
    #stream = inflater.append @file.read(@length)
    #inflater.flush()

    # ZIP decompression not implemented until I can find a PSD that's actually using it
    @file.seek @endPos, false

  # Once we've read the image data, we need to organize it and/or convert the pixel
  # values to RGB so they're easier to work with and can be easily output to either
  # browser or file.
  processImageData: ->
    switch @header.mode
      when 1 # Greyscale
        @combineGreyscale8Channel() if @header.depth is 8
        @combineGreyscale16Channel() if @header.depth is 16
      when 3 # RGBColor
        @combineRGB8Channel() if @header.depth is 8
        @combineRGB16Channel() if @header.depth is 16
      when 4 #CMKYColor
        @combineCMYK8Channel()

  combineGreyscale8Channel: ->
    if @header.channels is 2
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
    if @header.channels is 2
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
      @pixelData.r[i] = @channelData[i]
      @pixelData.g[i] = @channelData[i + @channelLength]
      @pixelData.b[i] = @channelData[i + (@channelLength * 2)]
      @pixelData.a[i] = @channelData[i + (@channelLength * 3)] if @header.channels is 4

  combineRGB16Channel: ->
    for i in [0...@numPixels]
      @pixelData.r[i] = @channelData[i] >> 8
      @pixelData.g[i] = @channelData[i + @channelLength] >> 8
      @pixelData.b[i] = @channelData[i + (@channelLength * 2)] >> 8
      @pixelData.a[i] = @channelData[i + (@channelLength * 3)] >> 8 if @header.channels is 4

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

      if @header.channels is 5
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
    
    for i in [0...@pixelData.r.length]
      alpha = @pixelData.a[i]; alpha ?= 255
      result.push(
        @pixelData.r[i], 
        @pixelData.g[i], 
        @pixelData.b[i], 
        alpha)

    result