class PSDChannelImage extends PSDImage
  constructor: (file, header, @layer) ->
    @width = @layer.cols
    @height = @layer.rows

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
    Log.debug "Image size: #{@length} (#{@getImageWidth()}x#{@getImageHeight()})"
    
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

      Log.debug "Channel ##{@chInfo.id}: length=#{@chInfo.length}"
      @parseImageData()

    if @channelData.length isnt @length
      Log.debug "ERROR: #{@channelData.length} pixels read; expected #{@length}"

    @processImageData()

  parseRaw: (length = @channelLength) -> super length

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

    Log.debug "Parsing layer channel ##{@chInfo.id}, Start = #{@file.tell()}"
    [@chanPos, lineIndex] = @decodeRLEChannel(@chanPos, lineIndex)
