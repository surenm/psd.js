# A PSDImage stores parsed image data for images contained within the PSD, and
# for the PSD itself.
class PSDImage
  COMPRESSIONS =
    0: 'Raw'
    1: 'RLE'
    2: 'ZIP'
    3: 'ZIPPrediction'

  constructor: (@file, @header) ->
    @width = @header.cols
    @height = @header.rows

    @length = switch @header.depth
      when 1 then (@width + 7) / 8 * @height
      when 16 then @width * @height * 2
      else @width * @height

    @channelLength = @length
    @length *= @header.channels

    @startPos = @file.tell()
    @endPos = @startPos + @length

    @compression = @file.readShortInt()
    
    @pixelData =
      r: []
      g: []
      b: []
      a: []

  parse: ->
    # ZIP compression isn't implemented yet. Luckily this is pretty rare. Still,
    # it's a TODO.
    if @compression in [2, 3]
      throw "Image with ZIP compression. Don't know how to parse this. Giving up."
    else
      Log.debug "Image compression: id=#{@compression}, name=#{COMPRESSIONS[@compression]}"
      Log.debug "Image size: #{@length} (#{@width}x#{@height})"

    switch @compression
      when 0 then @parseRaw.apply @, Array.prototype.slice.call(arguments)
      when 1 then @parseRLE.apply @, Array.prototype.slice.call(arguments)

  parseRaw: ->
    Log.debug "Attempting to parse RAW encoded image..."
    
    for color in ['r', 'g', 'b']
      for i in [0...@size]
        @pixelData[color].push @file.read(2)[0]

  parseRLE: ->
    Log.debug "Attempting to parse RLE encoded image..."

    # RLE stores the scan line byte counts in the first chunk of data
    byteCounts = []
    for i in [0...@header.channels]
      for j in [0...@height]
        byteCounts.push @file.readShortInt()

    Log.debug "Read byte counts. Current pos = #{@file.tell()}, Pixels = #{@length}"

    # And then it stores the compressed image data
    @channelData = []
    @channelData.push 0 for x in [0...@length]

    chanPos = 0
    lineIndex = 0

    for i in [0...@header.channels] # i = plane num
      console.log "Parsing channel ##{i}, Start = #{@file.tell()}"

      for j in [0...@height]
        byteCount = byteCounts[lineIndex++]
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

    switch @header.mode
      when 3 # RGBColor
        @combineRGB8Channel() if @header.depth is 8
        @combineRGB16Channel() if @header.depth is 16

  combineRGB8Channel: ->
    for i in [0...@channelLength]
      @pixelData.r[i] = @channelData[i]
      @pixelData.g[i] = @channelData[i + @channelLength]
      @pixelData.b[i] = @channelData[i + (@channelLength * 2)]
      @pixelData.a[i] = @channelData[i + (@channelLength * 3)] if @header.channels is 4
      
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