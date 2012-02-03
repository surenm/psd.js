# A PSDImage stores parsed image data for images contained within the PSD, and 
# for the PSD itself.
class PSDImage
  constructor: (@mode, @width, @height, @data = []) ->
    # The pixel data is stored in the same format that is used by the HTML 
    # canvas. It is a 1D array that consists of a single pixel's color values 
    # expressed from 0 to 255 in chunks of 4. Each chunk consists of red, 
    # green, blue, and alpha values, respectively.
    #
    # This means a pure-red single pixel is expressed as: `[255, 0, 0, 255]`
    @pixelData = []

    switch @mode
      when "L" then @parseLuminance()
      when "RGB" then @parseRGB()
      when "RGBA" then @parseRGB(true)

  parseLuminance: ->
    for val in @data
      @pixelData.push val
      @pixelData.push val
      @pixelData.push val
      @pixelData.push 255

  parseRGB: (alpha = false) ->
    for i in [0...(@width*@height)]
      @pixelData.push @data.r[i]
      @pixelData.push @data.g[i]
      @pixelData.push @data.b[i]
      @pixelData.push if alpha then @data.a[i] else 255
        