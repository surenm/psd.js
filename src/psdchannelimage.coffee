PSDImage = require './psdimage'
Log = require './log'
# PSD files also store merged image data for each individual layer.
# Unfortunately, parsing this image data is a bit different than parsing
# the overall merged image data at the end of the file. The main difference
# is that each image channel has independent compression, and the channel
# order is defined individually for each layer. Also, the layer size is often
# not the same size as the full image.
class PSDChannelImage extends PSDImage
  constructor: (file, header, @layer) ->
    @width = @layer.cols
    @height = @layer.rows
    @channelsInfo = @layer.channelsInfo

    super file, header

  skip: ->
    Log.debug "Skipping channel image data. Layer = #{@layer.name}"
    for channel in @channelsInfo
      @file.seek channel.length

  getImageWidth: -> @width
  getImageHeight: -> @height
  getImageChannels: -> @layer.channels

  # Since we're working on a per-channel basis now, we only read the byte counts
  # for the current channel only.
  getByteCounts: ->
    byteCounts = []
    for i in [0...@getImageHeight()]
      byteCounts.push @file.readShortInt()

    byteCounts

  parse: ->
    Log.debug "\nLayer: #{@layer.name}, image size: #{@length} (#{@getImageWidth()}x#{@getImageHeight()})"
    
    # We must keep track of the current channel data position global to this object
    # now, since we parse a single channel at a time.
    @chanPos = 0

    # Loop through each image channel and parse each one like a full image.
    for i in [0...@getImageChannels()]
      @chInfo = @layer.channelsInfo[i]

      if @chInfo.length <= 0
        @parseCompression()
        continue

      # If the ID of this current channel is -2, then we assume the dimensions
      # of the layer mask.
      if @chInfo.id is -2
        @width = @layer.mask.width
        @height = @layer.mask.height
      else
        @width = @layer.cols
        @height = @layer.rows

      start = @file.tell()

      Log.debug "Channel ##{@chInfo.id}: length=#{@chInfo.length}"
      @parseImageData()

      end = @file.tell()

      # Sanity check
      if end isnt start + @chInfo.length
        Log.debug "ERROR: read incorrect number of bytes for channel ##{@chInfo.id}. Layer=#{@layer.name}, Expected = #{start + @chInfo.length}, Actual: #{end}"
        @file.seek start + @chInfo.length, false

    # Futher sanity checks
    if @channelData.length isnt @length
      Log.debug "ERROR: #{@channelData.length} read; expected #{@length}"

    @processImageData()
    #@parseUserMask()

    if exports?
      memusage = process.memoryUsage()
      used = Math.round memusage.heapUsed / 1024 / 1024
      total = Math.round memusage.heapTotal / 1024 / 1024
      Log.debug "\nMemory usage: #{used}MB / #{total}MB"

  # Since we're parsing on a per-channel basis, we need to modify the behavior
  # of the RAW encoding parser a bit. This version is aware of the current
  # channel data position, since layers that have RAW encoding often use RLE
  # encoded alpha channels.
  parseRaw: ->
    Log.debug "Attempting to parse RAW encoded channel..."
    data = @file.read(@chInfo.length - 2)
    dataIndex = 0
    for i in [@chanPos...@chanPos+@chInfo.length - 2]
      @channelData[i] = data[dataIndex++]

    @chanPos += @chInfo.length - 2

  # Compression is stored on a per-channel basis, not a per-image basis for layers
  parseImageData: ->
    @compression = @parseCompression()

    switch @compression
      when 0 then @parseRaw()
      when 1 then @parseRLE()
      when 2, 3 then @parseZip()
      else
        Log.debug "Unknown image compression. Attempting to skip."
        return @file.seek @endPos, false

  # Parse a single channel instead of every image channel
  parseChannelData: ->
    lineIndex = 0
    
    Log.debug "Parsing layer channel ##{@chInfo.id}, Start = #{@file.tell()}"
    [@chanPos, lineIndex] = @decodeRLEChannel(@chanPos, lineIndex)

  #parseUserMask: ->
  #  if @getImageDepth() is 8
  #    @parseUserMask8()
    
module.exports = PSDChannelImage