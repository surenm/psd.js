PSDDescriptor = require '../psddescriptor'
Parser = require '../parser'
assert = require '../psdassert'
Log = require '../log'
# libpsd has effect layer parsing 
# see https://github.com/alco/psdump/blob/master/libpsd-0.9

class PSDEffectsInfo
  constructor: (@layer, @length) ->
    @file = @layer.file

  parse: ->
    effectsVersion = @file.readInt()
    assert effectsVersion is 0

    version = @file.readInt()
    assert version is 16

    descriptor = (new PSDEffectsDescriptor(@file)).parse()
    effects = Parser.parseEffects descriptor
    return effects

  parseLegacy: ->
    effects = []

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

      data = effect?.parse()

      left = (pos + size) - @file.tell()
      if left != 0
       Log.debug("Failed to parse effect layer with type #{type}")
       @file.seek left
      else
        effects.push(data) unless type == "cmnS" # ignore commons state info

    legacy: true
    effects: effects

# This is ridiculous. The effects layer does not follow the standard
# descriptor structure. Have to do a little hacking here.
class PSDEffectsDescriptor extends PSDDescriptor
  parseItem: (id) ->
    type = @file.readString(4)
    data = super(id, type)
    data

class PSDLayerEffect

  constructor: (@file) ->
  
  parse: ->
    # these are common to all effects
    [@version] = @file.readf ">i"

  getSpaceColor: ->
    @file.read(2) # 2 bytes for space
    @file.readf ">HHHH" # 4 * 2 byte color component - r, g, b, a
   
class PSDLayerEffectCommonStateInfo extends PSDLayerEffect

  parse: ->
    super()
    # always true
    @visible = @file.readBoolean()
    # unused
    @file.read(2)

    {visible: @visible}

# Based on https://github.com/alco/psdump/blob/master/libpsd-0.9/src/drop_shadow.c
class PSDDropDownLayerEffect extends PSDLayerEffect

  constructor: (file, @inner = false) -> 
    super(file)

    #defaults 
    @blendMode = "mul"
    @color = @nativeColor = [0,0,0,0]
    @opacity = 191
    @angle = 120
    @useGlobalLight = true
    @distance = 5

    # v2
    @spread = 0
    @size = 5
    @antiAliased = false
    @knocksOut = false

  parse: ->
    super()

    [
      @blur,      # This seems to be wrong in the specification! - see libpsd
      @intensity,
      @angle,
      @distance
    ] = @file.readf ">hiii"


    @file.read(2) # extra 2 bytes for space. The spec doesn't mention this!

    @color = @getSpaceColor()

    [ 
      @signature,
      @blendMode
    ] =  @file.readf ">4s4s"

    @enabled = @file.readBoolean()
    @useAngleInAllFX = @file.readBoolean()
    
    [@opacity] = @file.read(1) 
    
    @nativeColor = @getSpaceColor() if @version == 2

    data = {}
    for own key, val of @
      continue if key is "file"
      data[key] = val

    data

module.exports = PSDEffectsInfo