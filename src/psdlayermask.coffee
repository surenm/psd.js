class PSDLayerMask
  constructor: (@file, @header, @options) ->
    # Array to hold all of the layers
    @layers = []

    # Does the first alpha channel contain the transparency data?
    @mergedAlpha = false

    # The global layer mask
    @globalMask = {}

    # Additional layer information
    @extras = []

  # Skip over this section and don't parse it
  skip: -> @file.seek @file.readUInt()

  parse: ->
    # Read the size of the entire layers and masks section
    maskSize = @file.readUInt()
    endLoc = @file.tell() + maskSize

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
          continue if layer.isFolder
          layer.image = new PSDChannelImage(@file, @header, layer)

          if @options.layerImages
            layer.image.parse()
          else
            layer.image.skip()

        # TODO : layers.reverse()

    # Parse the global layer mask
    @parseGlobalMask()

    # Temporarily skip the rest of layers & masks section
    @file.seek endLoc, false
    return

    # We have more additional info to parse, especially beacuse this is PS >= 4.0
    @parseExtraInfo(endLoc) if @file.tell() < endLoc

  parseGlobalMask: ->
    length = @file.readInt()
    return if length is 0

    end = @file.tell() + length

    Log.debug "Global mask length: #{length}"

    @globalMask.overlayColorSpace = @file.readShortInt()

    # TODO: parse color space components into actual color.
    @globalMask.colorComponents = []
    for i in [0...4]
      @globalMask.colorComponents.push(@file.readShortInt() >> 8)

    @globalMask.opacity = @file.readShortInt()

    # 0 = color selected; 1 = color protected; 128 = use value per layer
    @globalMask.kind = @file.read(1)[0]

    Log.debug "Global mask:", @globalMask

    # Filler zeros, seek to end.
    @file.seek end, false

  parseExtraInfo: (end) ->
    while @file.tell() < end
      # Temporary
      [
        sig,
        key,
        length
      ] = @file.readf ">4s4sI"

      length = Util.pad2 length

      Log.debug "Layer extra:", sig, key, length

      @file.seek length

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