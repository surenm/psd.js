class PSDLayerMask
  constructor: (@file, @header) ->
    # Array to hold all of the layers
    @layers = []

    # Does the first alpha channel contain the transparency data?
    @mergedAlpha = false

  parse: ->
    # Read the size of this section. 4 bytes.
    maskSize = @file.readUInt()

    # Store the current position in case we need to bail
    # and skip over this section.
    pos = @file.tell()

    Log.debug "Layer mask size is #{maskSize}"

    # If the mask size is > 0, then parse the section. Otherwise,
    # this section doesn't exist and the whole layers/masks data
    # is 4 bytes (the length we've already read)
    if maskSize > 0
      # Size of the layer info section. 4 bytes, rounded up by 2's.
      layerInfoSize = Util.pad2(@file.readUInt())

      # If the layer info size is > 0, then we have some layers
      if layerInfoSize > 0
        # Read the number of layers, 2 bytes.
        @numLayers = @file.readShortInt()

        # If the number of layers is negative, the absolute value is
        # the actual number of layers, and the first alpha channel contains
        # the transparency data for the merged image.
        if @numLayers < 0
          Log.debug "Note: first alpha channel contains transparency data"
          @numLayers = Math.abs @numLayers
          @mergedAlpha = true

        if @numLayers * (18 + 6 * @header.channels) > layerInfoSize
          throw "Unlikely number of #{@numLayers} layers for #{@header['channels']} with #{layerInfoSize} layer info size. Giving up."

        Log.debug "Found #{@numLayers} layer(s)"

        for i in [0...@numLayers]
          layer = new PSDLayer @file
          layer.parse(i)
          @layers.push layer

        for layer in @layers
          layer.getImageData()

        @layers.reverse()

      @file.seek maskSize

    baseLayer = new PSDLayer @file, true, @header
    rle = @file.readShortUInt() is 1
    height = baseLayer.height

    if rle
      nLines = height * baseLayer.channelsInfo.length
      lineLengths = []
      for h in [0...nLines]
        lineLengths.push @readShortUInt()

      baseLayer.getImageData(false, lineLengths)
    else
      baseLayer.getImageData(false)

    if not @layers.length
      @layers.push baseLayer

  groupLayers: ->
    parents = []
    for layer in @layers
      layer.parent = parents[parents.length - 1] or null
      layer.parents = parents[1..]

      continue if layer.layerType.code is 0

      if layer.layerType.code is 3 and parents.length > 0
        delete parents[parents.length - 1]
      else
        parents.push layer