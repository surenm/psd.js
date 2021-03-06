assert = require('./psdassert')
Log = require('./log')
Util = require('./util')

Parser = require './parser'
PSDBlackWhite = require('./layerdata/blackwhite')
PSDBrightnessContrast= require('./layerdata/brightnesscontrast')
PSDColorBalance = require('./layerdata/colorbalance')
PSDCurves = require('./layerdata/curves')
PSDExposure = require('./layerdata/exposure')
PSDFillOpacity = require('./layerdata/fillopacity')
PSDGradient = require('./layerdata/gradient')
PSDHueSaturation = require('./layerdata/huesaturation')
PSDInvert = require('./layerdata/invert')
PSDEffectsInfo = require('./layerdata/layereffect')
PSDLevels = require('./layerdata/levels')
PSDPattern = require('./layerdata/pattern')
PSDPosterize = require('./layerdata/posterize')
PSDPath = require('./layerdata/path')
PSDPhotoFilter = require('./layerdata/photofilter')
PSDSelectiveColor = require('./layerdata/selectivecolor')
PSDSolidColor = require('./layerdata/solidcolor')
PSDThreshold = require('./layerdata/threshold')
PSDTypeTool = require('./layerdata/typetool')
PSDVibrance = require('./layerdata/vibrance')

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

  LAYER_TYPES = 
    TEXT: "text"
    SHAPE: "shape"
    NORMAL: "normal"
  

  constructor: (@file, @header = null) ->
    @image = null
    @mask = {}
    @blendingRanges = {}

    @adjustments = {}
    @effects = {}
    @path_items = {}
    @text_item = {}

    # Defaults
    @layerType = "normal"
    @blendingMode = "normal"
    @opacity = 255

    @isFolder = false
    @isHidden = false

  parse: (layerIndex = null) ->
    @parseInfo(layerIndex)
    @parseBlendModes()

    # Length of the rest of the layer data
    extralen = @file.readInt()
    @layerEnd = @file.tell() + extralen

    assert extralen > 0

    # Marking our start point in case we need to bail and recover
    extrastart = @file.tell()

    result = @parseMaskData()
    if not result
      # Make this more graceful in the future?
      Log.debug "Error parsing mask data for layer ##{layerIndex}. Skipping."
      return @file.seek @layerEnd, false

    @parseBlendingRanges()
    @parseLegacyLayerName()
    
    extra_data_start_pos = @file.tell()
    @parseExtraData()
    
    if @top == 0 and @bottom == 0 and @left == 0 and @right == 0
      # this happens sometimes with layers that has shapes
      # TODO: return a superbound of bounds of all the pathItems
      if @pathItems?
        bounds = @pathItems[0].bounds
        @top = bounds.top
        @bottom = bounds.bottom
        @left = bounds.left
        @right = bounds.right
        @rows = @bottom - @top
        @cols = @right - @left

    Log.debug "Layer #{layerIndex}:", @

    # In case there are filler zeros
    @file.seek extrastart + extralen, false

  # Parse important information about this layer such as position, size,
  # and channel info. Layer Records section.
  parseInfo: (layerIndex) ->
    @idx = layerIndex

    ###
    Layer Info
    ###
    [@top, @left, @bottom, @right, @channels] = @file.readf ">iiiih"
    [@rows, @cols] = [@bottom - @top, @right - @left]

    assert @channels > 0

    # Alias
    @height = @rows
    @width = @cols
    # Sanity check
    if @bottom < @top or @right < @left or @channels > 64
      Log.debug "Somethings not right, attempting to skip layer."
      @file.seek 6 * @channels + 12
      @file.skipBlock "layer info: extra data"
      return # next layer

    # Read channel info
    @channelsInfo = []
    for i in [0...@channels]
      [channelID, channelLength] = @file.readf ">hi"
      Log.debug "Channel #{i}: id=#{channelID}, #{channelLength} bytes, type=#{CHANNEL_SUFFIXES[channelID]}"

      @channelsInfo.push id: channelID, length: channelLength
    
  # Parse the blend mode used for this layer including type and opacity
  parseBlendModes: ->
    @blendMode = {}

    [
      @blendMode.sig, # 8BIM
      @blendMode.key, # blending mode key
      @blendMode.opacity, # 0 - 255
      @blendMode.clipping, # 0 = base, 1 = non-base
      flags, 
      filler # unused data
    ] = @file.readf ">4s4sBBBB"

    assert @blendMode.sig is "8BIM"

    @blendMode.key = @blendMode.key.trim()
    @blendMode.opacityPercentage = (@blendMode.opacity * 100) / 255
    @blendMode.blender = BLEND_MODES[@blendMode.key]

    @blendMode.transparencyProtected = flags & 0x01
    @blendMode.visible = (flags & (0x01 << 1)) > 0
    @blendMode.visible = 1 - @blendMode.visible
    @blendMode.obsolete = (flags & (0x01 << 2)) > 0
    
    # PS >= 5.0; tells if bit 4 has useful info
    if (flags & (0x01 << 3)) > 0
      @blendMode.pixelDataIrrelevant = (flags & (0x01 << 4)) > 0

    @blendingMode = @blendMode.blender
    @opacity = parseInt(@blendMode.opacityPercentage)/100
    @visible = @blendMode.visible

    Log.debug "Blending mode:", @blendMode

  parseMaskData: ->
    @mask.size = @file.readInt()

    # Something wrong, bail.
    assert @mask.size in [36, 20, 0]

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
    ] = @file.readf ">llllBB"

    assert @mask.defaultColor in [0, 255]

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
    length = @file.readInt()
    
    # Not sure why this happens but this could be empty, in which case just return
    if length == 0 
      return

    # First, the grey blend. This is irrelevant for Lab & Greyscale.
    @blendingRanges.grey =
      source:
        black: @file.readShortInt()
        white: @file.readShortInt()
      dest:
        black: @file.readShortInt()
        white: @file.readShortInt()

    pos = @file.tell()
    

    @blendingRanges.numChannels = (length - 8) / 8
    assert @blendingRanges.numChannels > 0

    @blendingRanges.channels = []
    for i in [0...@blendingRanges.numChannels]
      @blendingRanges.channels.push
        source: 
          black: @file.readShortInt()
          white: @file.readShortInt()
        dest: 
          black: @file.readShortInt()
          white: @file.readShortInt()

  # Parse the name of this layer. This is considered the "legacy"
  # name because it is encoded with MacRoman encoding. PS >= 5.0
  # includes a unicode version of the name, which is in the additional
  # layer information section.
  parseLegacyLayerName: ->
    # Name length is padded in multiples of 4
    namelen = Util.pad4 @file.read(1)[0]
    @legacyName = Util.decodeMacroman(@file.read(namelen)).replace /\u0000/g, ''
    @name = @legacyName unless @name?

  parseExtraData: ->
    while @file.tell() < @layerEnd
      [
        signature,
        key
      ] = @file.readf ">4s4s"

      assert.equal signature, "8BIM"

      length = Util.pad2 @file.readInt()
      pos = @file.tell()

      # TODO: many more adjustment layers to implement
      Log.debug("Extra layer info: key = #{key}, length = #{length}")
      switch key
        when "SoCo"
          @adjustments.solid_fill = (new PSDSolidColor(@, length)).parse()
        when "GdFl"
          @adjustments.gradient_fill = (new PSDGradient(@, length)).parse()
        when "PtFl"
          @adjustments.pattern_fill = (new PSDPattern(@, length)).parse()
        when "tySh" # PS <= 5
          @textItem = (new PSDTypeTool(@, length)).parse(true)
        when "TySh" # PS >= 6
          @textItem = (new PSDTypeTool(@, length)).parse()
        when "lrFX" # PS 5.0
          legacyEffects = (new PSDEffectsInfo(@, length)).parseLegacy()
          @file.read(2) # why these 2 bytes?
        when "lfx2" # PS 6.0
          @effects = (new PSDEffectsInfo(@, length)).parse()
        when "vmsk"
          @pathItems = (new PSDPath(@, length)).parse()
        when "lyid"
          @layerId = @file.readInt()
        when "lsct"
          @readLayerSectionDivider()
        when "iOpa"
          fillOpacityPercentage = (new PSDFillOpacity(@, length)).parse()
          @opacity = parseInt (@opacity * fillOpacityPercentage)/100

        #when "brit"
        #  @adjustments.brightnessContrast = (new PSDBrightnessContrast(@, length)).parse()
        #when "levl"
        #  @adjustments.levels = (new PSDLevels(@, length)).parse()
        #when "curv"
        #  @adjustments.curves = (new PSDCurves(@, length)).parse()
        #when "expA"
        #  @adjustments.exposure = (new PSDExposure(@, length)).parse()
        #when "vibA"
        #  @adjustments.vibrance = (new PSDVibrance(@, length)).parse()
        #when "hue2" # PS >= 5.0
        #  @adjustments.hueSaturation = (new PSDHueSaturation(@, length)).parse()
        #when "blnc"
        #  @adjustments.colorBalance = (new PSDColorBalance(@, length)).parse()
        #when "blwh"
        #  @adjustments.blackWhite = (new PSDBlackWhite(@, length)).parse()
        #when "phfl"
        #  @adjustments.photoFilter = (new PSDPhotoFilter(@, length)).parse()
        #when "thrs"
        #  @adjustments.threshold = (new PSDThreshold(@, length)).parse()
        #when "nvrt"
        #  @adjustments.invert = (new PSDInvert(@, length)).parse()
        #when "post"
        #  @adjustments.posterize = (new PSDPosterize(@, length)).parse()
        #
        #when "luni" # PS >= 5.0
        #  @name = @file.readUnicodeString()
        #
        #  # This seems to be padded with null bytes (by 4?), but the easiest
        #  # thing to do is to simply jump to the end of this section.
        #  @file.seek pos + length, false
        #when "selc"
        #  @adjustments.selectiveColor = (new PSDSelectiveColor(@, length)).parse()
        else
          @file.seek length
          Log.debug("Skipping additional layer info with key #{key}")

      if @file.tell() != (pos + length)
        Log.debug "Warning: additional layer info with key #{key} - unexpected end. Position = #{@file.tell()}, Expected = #{(pos + length)}"
        @file.seek pos + length, false # Attempt to recover

        
  readLayerSectionDivider: ->
    code = @file.readInt()
    @layerType = SECTION_DIVIDER_TYPES[code]

    Log.debug "Layer type:", @layerType

    switch code
      when 1, 2 then @isFolder = true
      when 3 then @isHidden = true
      
  toJSON: ->
    data = {}
    data.uid        = @layerId
    data.name       = @name
    data.height     = @rows
    data.width      = @cols
    data.zindex     = @idx
    data.idx  = @idx + 1

    # Adjust opacity if there is a fill opacity
    if @fillOpacityPercentage?
      data.opacity = parseInt (@opacity * @fillOpacityPercentage)/100
    else 
      data.opacity = @opacity
    
    
    data.bounds = {'top': @top, 'bottom': @bottom, 'left': @left, 'right': @right}

    # Calculate layer type
    data.type = LAYER_TYPES.NORMAL
    
    # calculate if the layer is clipping or not
    if @blendMode.clipping == 0
      data.clipping = false
    else
      data.clipping = true
      
    
    if @textItem?
      # Does the layer have text data
      data.text = @textItem
      data.type = LAYER_TYPES.TEXT
    
    else if @pathItems?
      # Does the layer has pathItems
      # TODO: Handle this is a better way
      if @pathItems.length == 1
        if @pathItems[0].type != "GENERIC"
          data.type = LAYER_TYPES.SHAPE
          data.shape = @pathItems[0]
        else
          data.type = LAYER_TYPES.NORMAL
          data.shapes = @pathItems
      else
        data.type = LAYER_TYPES.NORMAL
        data.shapes = @pathItems
    else
      data.type = LAYER_TYPES.NORMAL
  
    # Add style effects
    styles = {}

    # Adjustments could be solid fill, gradient fill or pattern fill for now
    if @adjustments?
      for style in Object.keys(@adjustments)
        if style == "solid_fill"
          styles[style] = Parser.parseColor @adjustments[style], @opacity
        else
          # TODO: find out how to handle these items
          styles[style] = @adjustments[style]

    # effects directly belong to styles
    if @effects?
      for effect in Object.keys(@effects)
        styles[effect] = @effects[effect]

    if data.type == LAYER_TYPES.NORMAL
      data.styles = {}
    else
      data.styles = styles

    return data

module.exports = PSDLayer