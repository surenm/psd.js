class PSDLayerEffect

  constructor: (@file) -> 
  
  parse: ->
    # these are common to all effects
    [
        @size,
        @version
    ] = @file.readf ">ii"
        
class PSDDropDownLayerEffect extends PSDLayerEffect

  constructor: (file, @inner = false) -> super(file)

  parse: ->
    super()

    [
      @blur,
      @intensity,
      angle,
      @distance
    ] = @file.readf ">hiii"

    # TODO - Check this!
    @angle = 180 - angle

    @file.read(4) # 2 bytes for space

    @color = @file.readf ">BBBB" # r, g, b, a

    [ 
      @signature,
      @blendMode
    ] =  @file.readf ">4s4s"

    enabled = @file.readBoolean()
    useInAllEFX = @file.readBoolean()
    
    alpha = @file.read(1)[0] /255.0     
    
    @file.read(4) # 2 bytes for space
    
    @nativeColor = @file.readf ">BBBB" # r, g, b, a
