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
    @isFolder = false
    @isHidden = false

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
      Log.debug "Error parsing mask data for layer ##{layerIndex}. Skipping."
      return @file.seek @layerEnd, false

    @parseBlendingRanges()

    namelen = Util.pad4 @file.read(1)[0]
    @name = @file.readString namelen

    Log.debug "Layer name: #{@name}"

    @parseExtraData()

    Log.debug "Layer #{layerIndex}:", @

    if @file.tell() != @layerEnd
      Log.debug "Error parsing layer - unexpected end. Attempting to recover..."
      @file.seek @layerEnd, false

  # Parse important information about this layer such as position, size,
  # and channel info. Layer Records section.
  parseInfo: (layerIndex) ->
    @idx = layerIndex

    ###
    Layer Info
    ###
    [@top, @left, @bottom, @right, @channels] = @file.readf ">iiiih"
    [@rows, @cols] = [@bottom - @top, @right - @left]

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

      @channelsInfo.push id: channelID, length: channelLength
    
  # Parse the blend mode used for this layer including type and opacity
  parseBlendModes: ->
    @blendMode = {}

    [
      @blendMode.sig, 
      @blendMode.key, 
      @blendMode.opacity,
      @blendMode.clipping, 
      flags, 
      filler # unused data
    ] = @file.readf ">4s4sBBBB"

    @blendMode.key = @blendMode.key.trim()
    @blendMode.opacityPercentage = (@blendMode.opacity * 100) / 255
    @blendMode.blender = BLEND_MODES[@blendMode.key]

    @blendMode.transparencyProtected = flags & 0x01
    @blendMode.visible = (flags & (0x01 << 1)) > 0
    @blendMode.visible = 1 - @blendMode.visible
    @blendMode.obsolete = (flags & (0x01 << 2)) > 0
    
    if (flags & (0x01 << 3)) > 0
      @blendMode.pixelDataIrrelevant = (flags & (0x01 << 4)) > 0

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
      flags
    ] = @file.readf ">LLLLBB"

    @mask.width = @mask.right - @mask.left
    @mask.height = @mask.bottom - @mask.top

    @mask.relative = flags & 0x01
    @mask.disabled = (flags & (0x01 << 1)) > 0
    @mask.invert = (flags & (0x01 << 2)) > 0

    # If the size is 20, then there are 2 bytes of padding
    if @mask.size is 20
      @file.seek(2)
    else
      # This is weird.
      [
        flags,
        @mask.defaultColor
      ] = @file.readf ">BB"

      # Real flags. Same as above. Seriously, who designed this crap?
      @mask.relative = (flags & 0x01)
      @mask.disabled = (flags & (0x01 << 1)) > 0
      @mask.invert = (flags & (0x01 << 2)) > 0

    # For some reason the mask position info is duplicated here? Skip. Ugh.
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
        #when "TySh" then @readTypeTool() # PS 6.0+
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

  readMetadata: ->
    Log.debug "Parsing layer metadata..."

    count = @file.readUInt16()

    for i in [0...count]
      [sig, key, padding] = @file.readf ">4s4s4s"

      #if key is "mlst"
        #readAnimation. needs research.

      @file.skipBlock("image metadata")
        
  readLayerSectionDivider: ->
    code = @file.readInt()
    @layerType = SECTION_DIVIDER_TYPES[code]

    Log.debug "Layer type:", @layerType

    switch code
      when 1, 2 then @isFolder = true
      when 3 then @isHidden = true
    
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