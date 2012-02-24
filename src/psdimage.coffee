# A PSDImage stores parsed image data for images contained within the PSD, and 
# for the PSD itself.
class PSDImage
  COMPRESSIONS =
    0: 'Raw'
    1: 'RLE'
    2: 'ZIP'
    3: 'ZIPPrediction'

  constructor: (@file, @compression, @header, @length) ->
    @startPos = @file.tell()
    @endPos = @startPos + @length

    @width = @header.cols
    @height = @header.rows
    
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

    switch @compression
      when 0 then @parseRaw()
      when 1 then @parseRLE()

  parseRaw: ->
    Log.debug "Attempting to parse RAW encoded image..."

    # First, determine the size of the image data
    @size = @width * @height
    Log.debug "Image size: #{@size} (#{@width}x#{@height})"
    
    for color in ['r', 'g', 'b']
      for i in [0...@size]
        @pixelData[color].push @file.read(2)[0]

  parseRLE: ->
    Log.debug "Attempting to parse RLE encoded image..."
      
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
      alpha = @pixelData.a[i]
      alpha ?= 255
      result.push @pixelData.r[i], @pixelData.g[i], @pixelData.b[i], alpha

    result