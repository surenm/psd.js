class PSDChannelImage extends PSDImage
  constructor: (file, header, @layer) ->
    @width = @layer.cols
    @height = @layer.rows
    @channelsInfo = @layer.channelsInfo

    super file, header

  getImageWidth: -> @width
  getImageHeight: -> @height
  getImageChannels: -> @layer.channels

  getByteCounts: ->
    byteCounts = []
    for i in [0...@getImageHeight()]
      byteCounts.push @file.readShortInt()

    byteCounts

  parse: ->
    Log.debug "\nLayer: #{@layer.name}, image size: #{@length} (#{@getImageWidth()}x#{@getImageHeight()})"
    
    @chanPos = 0

    for i in [0...@getImageChannels()]
      @chInfo = @layer.channelsInfo[i]

      if @chInfo.length <= 0
        @parseCompression()
        continue

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

      if end isnt start + @chInfo.length
        Log.debug "ERROR: read incorrect number of bytes for channel ##{@chInfo.id}. 
        Expected = #{start + @chInfo.length}, Actual: #{end}"
        @file.seek start + @chInfo.length, false

    if @channelData.length isnt @length
      Log.debug "ERROR: #{@channelData.length} read; expected #{@length}"

    @processImageData()

  parseRaw: ->
    Log.debug "Attempting to parse RAW encoded channel..."
    data = @file.read(@chInfo.length - 2)
    @channelData[@chanPos...@chanPos+@chInfo.length - 2] = data
    @chanPos += @chInfo.length - 2

  parseImageData: ->
    @compression = @parseCompression()

    switch @compression
      when 0 then @parseRaw()
      when 1 then @parseRLE()
      when 2, 3 then @parseZip()
      else
        Log.debug "Unknown image compression. Attempting to skip."
        return @file.seek @endPos, false

  parseChannelData: ->
    lineIndex = 0
    chanPos = @chanPos
    
    Log.debug "Parsing layer channel ##{@chInfo.id}, Start = #{@file.tell()}"
    [chanPos, lineIndex] = @decodeRLEChannel(@chanPos, lineIndex)
    @chanPos = chanPos
