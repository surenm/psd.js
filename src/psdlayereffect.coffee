# libpsd has effect layer parsing 
# see https://github.com/alco/psdump/blob/master/libpsd-0.9

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
