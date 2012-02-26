class PSDLayer
  CHANNEL_SUFFIXES =
    '-2': 'layer mask'
    '-1': 'A'
    0: 'R'
    1: 'G'
    2: 'B'
    3: 'RGB'
    4: 'CMYK'
    5: 'HSL'
    6: 'HSB'
    9: 'Lab'
    11: 'RGB'
    12: 'Lab'
    13: 'CMYK'

  SECTION_DIVIDER_TYPES =
    0: "other"
    1: "open folder"
    2: "closed folder"
    3: "bounding section divider" # hidden in the UI

  BLEND_MODES =
    "norm": "normal"
    "dark": "darken"
    "lite": "lighten"
    "hue":  "hue"
    "sat":  "saturation"
    "colr": "color"
    "lum":  "luminosity"
    "mul":  "multiply"
    "scrn": "screen"
    "diss": "dissolve"
    "over": "overlay"
    "hLit": "hard light"
    "sLit": "soft light"
    "diff": "difference"
    "smud": "exclusion"
    "div":  "color dodge"
    "idiv": "color burn"
    "lbrn": "linear burn"
    "lddg": "linear dodge"
    "vLit": "vivid light"
    "lLit": "linear light"
    "pLit": "pin light"
    "hMix": "hard mix"

  BLEND_FLAGS =
    0: "transparency protected"
    1: "visible"
    2: "obsolete"
    3: "bit 4 useful"
    4: "pixel data irrelevant"

  MASK_FLAGS =
    0: "position relative"
    1: "layer mask disabled"
    2: "invert layer mask"

  SAFE_FONTS = [
    "Arial"
    "Courier New"
    "Georgia"
    "Times New Roman"
    "Verdana"
    "Trebuchet MS"
    "Lucida Sans"
    "Tahoma"
  ]

  constructor: (@file, @header = null) ->
    @images = []
    @mask = {}
    @blendingRanges = {}
    @effects = []

  parse: (layerIndex = null) ->
    @parseInfo(layerIndex)
    @parseBlendModes()

    # Length of the rest of the layer data
    extralen = @file.readUInt()
    @layerEnd = @file.tell() + extralen

    # Marking our start point in case we need to bail and recover
    extrastart = @file.tell()

    result = @parseMaskData()
    if not result
      # Make this more graceful in the future?
      throw "Error parsing mask data for layer ##{@idx}. Quitting"

    @parseBlendingRanges()

    namelen = Util.pad4 @file.read(1)[0]
    @name = @file.readString namelen

    Log.debug "Layer name: #{@name}"

    # Channel image data
    #@parseImageData()

    @parseExtraData()

    if @file.tell() != @layerEnd
      throw "Error parsing layer - unexpected end"

  # Parse important information about this layer such as position, size,
  # and channel info. Layer Records section.
  parseInfo: (layerIndex) ->
    @idx = layerIndex

    ###
    Layer Info
    ###
    [@top, @left, @bottom, @right, @channels] = @file.readf ">LLLLH"
    [@rows, @cols] = [@bottom - @top, @right - @left]

    Log.debug "Layer #{@idx}:", @

    # Sanity check
    if @bottom < @top or @right < @left or @channels > 64
      Log.debug "Somethings not right, attempting to skip layer."
      @file.seek 6 * @channels + 12
      @file.skipBlock "layer info: extra data"
      return # next layer

    # Read channel info
    @channelsInfo = []
    for i in [0...@channels]
      [channelID, channelLength] = @file.readf ">hL"
      Log.debug "Channel #{i}: id=#{channelID}, #{channelLength} bytes, type=#{CHANNEL_SUFFIXES[channelID]}"

      @channelsInfo.push [channelID, channelLength]
    
  # Parse the blend mode used for this layer including type and opacity
  parseBlendModes: ->
    @blendMode = {}

    [
      @blendMode.sig, 
      @blendMode.key, 
      @blendMode.opacity, 
      @blendMode.clipping, 
      @blendMode.flags, 
      @blendMode.filler # unused data
    ] = @file.readf ">4s4sBBBB"

    @blendMode.key = @blendMode.key.trim()
    @blendMode.opacityPercentage = (@blendMode.opacity * 100) / 255
    @blendMode.blender = BLEND_MODES[@blendMode.key]

    Log.debug "Blending mode:", @blendMode

  parseMaskData: ->
    @mask.size = @file.readUInt()

    # Something wrong, bail.
    return false if @mask.size not in [36, 20, 0]

    # Valid, but this section doesn't exist.
    return true if @mask.size is 0

    # Parse mask position
    [
      @mask.top, 
      @mask.left, 
      @mask.bottom, 
      @mask.right,

      # Either 0 or 255
      @mask.defaultColor, 
      @mask.flags
    ] = @file.readf ">LLLLBB"

    # If the size is 20, then there are 2 bytes of padding
    if @mask.size is 20
      @file.seek(2)
    else
      # This is weird. Not sure what "real" means in the spec.
      [
        @mask.realFlags,
        @mask.realMaskBackground
      ] = @file.readf ">BB"

    # For some reason the mask position info is duplicated here? Skip.
    @file.seek 16
    true

  parseBlendingRanges: ->
    length = @file.readUInt()

    # First, the grey blend. This is irrelevant for Lab & Greyscale.
    @blendingRanges.grey =
      source:
        black: @file.readf ">BB"
        white: @file.readf ">BB"
      dest:
        black: @file.readf ">BB"
        white: @file.readf ">BB"

    pos = @file.tell()

    @blendingRanges.channels = []
    while @file.tell() < pos + length - 8
      @blendingRanges.channels.push
        source: @file.readf ">BB"
        dest: @file.readf ">BB"

    Log.debug "Blending ranges:", @blendingRanges

  parseExtraData: ->
    while @file.tell() < @layerEnd
      [
        signature,
        key
      ] = @file.readf ">4s4s"

      length = @file.readUInt()
      pos = @file.tell()

      Log.debug("Found additional layer info with key #{key} and length #{length}")
      switch key
        when "lyid" then @layerId = @file.readUInt()
        when "shmd" then @file.seek length # TODO - @readMetadata()
        when "lsct" then @readLayerSectionDivider()
        when "luni" then @file.seek length # TODO - @uniName = @file.readUnicodeString()
        when "vmsk" then @file.seek length # TODO - @readVectorMask()
        when "tySh" then @readTypeTool(true) # PS 5.0/5.5 only
        when "TySh" then @readTypeTool() # PS 6.0+
        when "lrFX" then @parseEffectsLayer(); @file.read(2) # why these 2 bytes?
        else  
          @file.seek length
          Log.debug("Skipping additional layer info with key #{key}")

      if @file.tell() != (pos + length)
        Log.debug "Error parsing additional layer info with key #{key} - unexpected end"
        @file.seek pos + length, false # Attempt to recover

  parseEffectsLayer: ->

    [
        v, # always 0
        count
    ] = @file.readf ">HH"

    while count-- > 0
      [
        signature,
        type
      ] = @file.readf ">4s4s"

      [size] = @file.readf ">i"

      pos = @file.tell()

      Log.debug("Parsing effect layer with type #{type} and size #{size}")

      effect =    
        switch type
          when "cmnS" then new PSDLayerEffectCommonStateInfo @file
          when "dsdw" then new PSDDropDownLayerEffect @file     
          when "isdw" then new PSDDropDownLayerEffect @file, true # inner drop shadow

      effect?.parse()

      left = (pos + size) - @file.tell()
      if left != 0
       Log.debug("Failed to parse effect layer with type #{type}")
       @file.seek left 
      else
        @effects.push(effect) unless type == "cmnS" # ignore commons state info

  parseImageData: ->
    # From here to the end of the layer, it's all image data
    while @file.tell() < @layerEnd
      @compression = @file.readShortInt()

      Log.debug "Image compression: id=#{@compression.id}, name=#{@compression.name}"
      @image = new PSDImage @file, @compression
      @image.parse()

  readMetadata: ->
    Log.debug "Parsing layer metadata..."

    count = @file.readUInt16()

    for i in [0...count]
      [sig, key, padding] = @file.readf ">4s4s4s"

      #if key is "mlst"
        #readAnimation. needs research.

      @file.skipBlock("image metadata")
        
  readLayerSectionDivider: ->
    code = @file.readUInt16()
    @layerType = SECTION_DIVIDER_TYPES[code]
    
  readVectorMask: ->
    version = @file.readUInt()
    flags = @file.read 4

    # TODO read path information

  readTypeTool: (legacy = false) ->
    @typeTool = new PSDTypeTool @file, legacy
    @typeTool.parse()

  getSafeFont: (font) ->
    for safeFont in SAFE_FONTS
      it = true
      for word in safeFont.split " "
        it = false if not !!~ font.indexOf(word)

      return safeFont if it

    font

  getImageData: (readPlaneInfo = true, lineLengths = []) ->
    @channels =
      a: []
      r: []
      g: []
      b: []

    opacity = @blendMode.opacityPercentage 
    opacityDivider = opacity / 255
    for own i, channelTuple of @channelsInfo
      [channelId, length] = channelTuple
      if channelId < -1
        width = @mask.cols
        height = @mask.rows
      else
        width = @cols
        height = @rows
      Log.debug "Reading channel #{channelId} from layer #{@name}"
      channel = @readColorPlane readPlaneInfo, lineLengths, i, height, width
      switch channelId
        when -1
          @channels.a = []
          @channels.a.push ((ch * opacityDivider) & 255) for ch in channel
        when 0 then @channels.r = channel
        when 1 then @channels.g = channel
        when 2 then @channels.b = channel
        else
          result = []
          for i in [0...channel.length]
            result.push @channels.a[i] * (channel[i]/255)

          @channels.a = result

    @makeImage()

  readColorPlane: (readPlaneInfo, lineLengths, planeNum, height, width) ->
    size = width * height
    imageData = []
    rleEncoded = false

    if readPlaneInfo
      compression = @file.readShortUInt()

      rleEncoded = compression is 1

      # RLE compressed the image data starts with the byte counts for all the
      # scan lines (rows * color_channels), with each count stored as a two¨byte value.
      # In this case we're reading a single color channel so scan lines == height
      # The RLE compressed data follows, with each scan line compressed separately.
      if rleEncoded
        # Must always read the short so removed this :
        # if lineLengths.length == 0
        lineLengths = []
        for a in [0...height]
          lineLengths.push @file.readShortInt() 
      else
        Log.debug "ERROR: compression not implemented yet. Skipping."

      planeNum = 0
    else
      rleEncoded = lineLengths.length isnt 0

    if rleEncoded
      imageData = @readPlaneCompressed lineLengths, planeNum, height, width
    else
      imageData = @file.readBytesList(size)

    imageData

  readPlaneCompressed: (lineLengths, planeNum, height, width) ->
    b = []
    b.push 0 for x in [0...(width*height)]
    s = []
    pos = 0
    lineIndex = planeNum * height

    for i in [0...height]
      len = lineLengths[lineIndex++]
      s = @file.readBytesList(len)
      s.push 0 for x in [0...(width * 2 - len)]
      @decodeRLE s, 0, len, b, pos
      pos += width

    b

  decodeRLE: (src, sindex, slen, dst, dindex) ->
    max = sindex + slen

    while sindex < max
      b = src[sindex]
      sindex++
      n = b
      if b > 127
        n = 255 - n + 2
        b = src[sindex]
        sindex++
        for i in [0...n]
          dst[dindex] = b
          dindex++
      else
        n++
        dst[dindex...dindex+n] = src[sindex...sindex+n]
        dindex += n
        sindex += n

  makeImage: ->
    return if not @cols? or not @rows?

    type = if isNaN(@channels.a[0]) then "RGB" else "RGBA"
    image = new PSDImage(@file, 0, { cols: @cols, rows: @rows}, @cols * @rows)
    image.pixelData = @channels
    Log.debug "Image: type=#{type}, width=#{@cols}, height=#{@rows}"

    @images.push image

  isFolder: -> @layerType == SECTION_DIVIDER_TYPES[1] || @layerType == SECTION_DIVIDER_TYPES[2]

  isHidden: -> @layerType == SECTION_DIVIDER_TYPES[3]