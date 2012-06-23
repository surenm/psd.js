class PSDTypeTool
  constructor: (@layer, @length) ->
    @file = @layer.file
    @data = {}

  parse: (legacy = false) ->
    version = @file.readShortInt()
    assert version is 1

    # 6 * 8 double numbers for transform info
    # xx, xy, yx, yy, tx, ty
    @data.transformInfo = []
    @data.transformInfo.push @file.readDouble() for i in [0...6]

    return @parseLegacy() if legacy

    # TODO: finish implementing below

    textVersion = @file.readShortInt()
    assert textVersion is 50

    descriptorVersion = @file.readInt()
    assert descriptorVersion is 16

    # Read descriptor
    @data.name = @file.readLengthWithString()

    len = @file.readInt()
    if len is 0
      @data.classID = @file.readInt()
    else
      @data.classID = @file.readString(len)

    # Number of items in the descriptor
    @data.text = (new PSDDescriptor(@file)).parse()

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
