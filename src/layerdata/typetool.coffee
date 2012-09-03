PSDDescriptor = require '../psddescriptor'
Parser = require '../parser'
assert = require '../psdassert'
Log = require '../log'

class PSDTypeTool
  engineDataRegex: [
    # Null characters
    {search: /\u0000/g, replace: ""}
    {search: /\\\)/g, replace: ""}
    
    # fix hashes 
    {search: /<</g, replace: ' {'}
    {search: />>/g, replace: '},'}
    
    # Fix strings
    {search: /\(/g, replace: '"'}  
    {search: /\)/g, replace: '"'}
    
    # These lines has some unicode strings that the JSON doesn't agree with
    {search: /.*NoStart.*/g, replace: "" }
    {search: /.*NoEnd.*/g, replace: "" }
    {search: /.*Keep.*/g, replace: "" }
    {search: /.*Hanging.*/g, replace: "" }
    
    # values within hashes
    {search: /\/(\w+)\s+(\{)\s+/g, replace: '"$1": $2\n'} 
    {search: /\/(\w+)\s+(\[)\s+/g, replace: '"$1": $2'} 
    {search: /"(\w+)":\s(\[.*\])\s+/g, replace: '"$1": "$2",\n'}
    {search: /\/(\w+)\s+([0-9]+\.[0-9]+|[0-9]+)\s+/g, replace: '"$1": $2,\n'} #"/token 0.0"
    {search: /\/(\w+)\s+\.([0-9]+|[0-9]+)\s+/g, replace: '"$1": 0.$2,\n'} #"/token .0"
    {search: /\/(\w+)\s+([0-9]+)\s+/g, replace: '"$1": $2,\n'}    # "/token 0"
    {search: /\/(\w+)\s+(.*)\s/g, replace: '"$1": $2,\n'}       # "/text hello world"
    
    # fix array ends
    {search: /\]/g, replace: '],'}
    
    # Remove trailing comma
    {search: /\,([\t\r\n]*)\}/g, replace: '$1}'}
    {search: /\,([\t\r\n]*)\]/g, replace: '$1]'}
        
    # Dunno WTF this is
    {search: /\(\u00FE\u00FF(.*)\)/g, replace: '"$1"'}
  ]

  constructor: (@layer, @length) ->
    @file = @layer.file
    @data = {}

  parse: (legacy = false) ->
    version = @file.readShortInt()
    assert version is 1

    # 6 * 8 double numbers for transform info
    # xx, xy, yx, yy, tx, ty
    @data.transformInfo = {}
    [
      @data.transformInfo.xx
      @data.transformInfo.xy
      @data.transformInfo.yx
      @data.transformInfo.yy
      @data.transformInfo.tx
      @data.transformInfo.ty
    ] = @file.readf(">6d")

    return @parseLegacy() if legacy

    # Below is code for PS >= 6

    textVersion = @file.readShortInt()
    assert textVersion is 50

    descriptorVersion = @file.readInt()
    assert descriptorVersion is 16

    # Read descriptor (NOTE: not sure if correct...)
    @data.text = (new PSDDescriptor(@file)).parse()

    # This isn't documented, but it seems like the raw EngineData
    # can be parsed as character codes. It's not perfect, but you
    # can get a general idea. Hopefully this can be improved in the
    # future.
    engineData = ""
    for char in @data.text.EngineData
      engineData += String.fromCharCode(char)
      
    engineData = engineData.replace /\\\)/g, ""
    matches = engineData.match /\(([^\)]+)\)/g
    for match in matches
      replacement = match.replace /[\n\r]/g, "\\n"
      engineData = engineData.replace match, replacement

    matches = engineData.match /\(([^\)]+)\)/g
    
    for regex in @engineDataRegex
      engineData = engineData.replace regex.search, regex.replace
      
    last_pos = engineData.lastIndexOf(',')
    engineData = engineData.substring 0, last_pos 
    
    engineJSON = eval '(' + engineData + ')'
    @data.text.EngineData = engineJSON
    Log.debug "Text:", @data.text

    warpVersion = @file.readShortInt()
    assert warpVersion is 1

    descriptorVersion = @file.readInt()
    assert descriptorVersion is 16

    @data.warp = (new PSDDescriptor(@file)).parse()
    Log.debug "Warp:", @data.warp

    [
      @data.left
      @data.top
      @data.right
      @data.bottom
    ] = @file.readf ">4d"

    @data

  parseLegacy: ->
    #
    # Font Information
    #
    version = @file.readShortInt()
    assert version is 6

    # Count of faces
    @data.facesCount = @file.readShortInt()
    @data.face = []

    for i in [0...@data.facesCount]
      @data.face[i] = {}
      @data.face[i].mark = @file.readShortInt()
      @data.face[i].fontType = @file.readInt()
      @data.face[i].fontName = @file.readLengthWithString()
      @data.face[i].fontFamilyName = @file.readLengthWithString()
      @data.face[i].fontStyleName = @file.readLengthWithString()
      @data.face[i].script = @file.readShortInt()

      @data.face[i].numberAxesVector = @file.readInt()
      @data.face[i].vector = []

      for j in [0...@data.face[i].numberAxesVector]
        @data.face[i].vector[j] = @file.readInt()

    #
    # Style Information
    #
    @data.stylesCount = @file.readShortInt()
    @data.style = []

    for i in [0...@data.stylesCount]
      @data.style[i] = {}
      @data.style[i].mark = @file.readShortInt()
      @data.style[i].faceMark = @file.readShortInt()
      @data.style[i].size = @file.readInt()
      @data.style[i].tracking = @file.readInt()
      @data.style[i].kerning = @file.readInt()
      @data.style[i].leading = @file.readInt()
      @data.style[i].baseShift = @file.readInt()
      @data.style[i].autoKern = @file.readBoolean()

      # Only present in version <= 5
      @file.read 1

      @data.style[i].rotate = @file.readBoolean()

    #
    # Text Information
    #
    @data.type = @file.readShortInt()
    @data.scalingFactor = @file.readInt()
    @data.sharacterCount = @file.readInt()
    @data.horzPlace = @file.readInt()
    @data.vertPlace = @file.readInt()
    @data.selectStart = @file.readInt()
    @data.selectEnd = @file.readInt()
    
    @data.linesCount = @file.readShortInt()
    @data.line = []
    for i in [0...@data.linesCount]
      @data.line[i].charCount = @file.readInt()
      @data.line[i].orientation = @file.readShortInt()
      @data.line[i].alignment = @file.readShortInt()
      @data.line[i].actualChar = @file.readShortInt()
      @data.line[i].style = @file.readShortInt()

    #
    # Color Information
    #
    @data.color = @file.readSpaceColor()
    @data.antialias = @file.readBoolean()

    @data

module.exports = PSDTypeTool