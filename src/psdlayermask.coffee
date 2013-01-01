Log = require './log'
Util = require './util'
PSDLayer = require './psdlayer'
PSDChannelImage = require './psdchannelimage'
assert = require './psdassert'
  
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
  skip: -> @file.seek @file.readInt()

  parse: ->
    # Read the size of the entire layers and masks section
    maskSize = @file.readInt()
      
    endLoc = @file.tell() + maskSize

    Log.debug "Layer mask size is #{maskSize}"

    # If the mask size is > 0, then parse the section. Otherwise,
    # this section doesn't exist and the whole layers/masks data
    # is 4 bytes (the length we've already read)
    return if maskSize <= 0

    # Size of the layer info section. 4 bytes, rounded up by 2's.
    layerInfoSize = Util.pad2 @file.readInt()

    flag = true
    flag = false if layerInfoSize != 0 
    skip_count = 0
    while flag
      skip_count++
      layerInfoSize = @file.readInt()
      if layerInfoSize != 0 and layerInfoSize < maskSize
        flag = false
    
    if skip_count > 0
      console.log "Skipped #{skip_count} times..."

    # Store the current position in case we need to bail
    # and skip over this section.
    pos = @file.tell()

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

      console.log "Found #{@numLayers} layer(s)"
      
      layers_copy = []
      for i in [0...@numLayers]
        layer = new PSDLayer @file, @header
        layer.parse(i)
        @layers.push layer
        layers_copy.push layer

      if @layers[0].name == "Background"
        @layers.splice 0, 1
        layers_copy.splice 0, 1
        for i in [0..@layers.length-1]
          @layers[i].idx = @layers[i].idx - 1
      
      for layer in @layers
        if layer.isFolder or layer.isHidden
          # Layer contains no image data. Skip ahead.
          @file.seek 8
          continue

        layer.image = new PSDChannelImage(@file, @header, layer)

        if @options.layerImages and ((@options.onlyVisibleLayers and layer.visible) or !@options.onlyVisibleLayers)
          layer.image.parse()
        else
          layer.image.skip()

      # Layers are parsed in reverse order
      #@layers.reverse()

    # In case there are filler zeros
    @file.seek pos + layerInfoSize, false

    # Parse the global layer mask
    @parseGlobalMask()
  
    # Temporarily skip the rest of layers & masks section
    @file.seek endLoc, false
      
    @visible_layers = this.prune_hidden_layers layers_copy
    return

    # We have more additional info to parse, especially beacuse this is PS >= 4.0
    @parseExtraInfo(endLoc) if @file.tell() < endLoc

  parseGlobalMask: ->
    length = @file.readInt()
    return if length is 0

    start = @file.tell()
    end = @file.tell() + length

    Log.debug "Global mask length: #{length}"

    # Undocumented
    @globalMask.overlayColorSpace = @file.readShortInt()

    # TODO: parse color space components into actual color.
    @globalMask.colorComponents = []
    for i in [0...4]
      @globalMask.colorComponents.push(@file.readShortInt() >> 8)

    # 0 = transparent, 100 = opaque
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

      console.log "Layer extra:", sig, key, length

      @file.seek length

  groupLayers: ->
    groupLayer = null
    for layer in @layers
      if layer.isFolder
        groupLayer = layer
      else if layer.isHidden
        groupLayer = null
      else
        layer.groupLayer = groupLayer
  
  prune_hidden_layers: (layers) ->
    layers.reverse()
    layer_sets = {}
    layer_visibility_status = {}
    layer_names = {}
    
        
    current_layer_sets = [0] # 0th layer actually denotes the entire psd file
    
    for layer in layers
      layer_id = layer.layerId

      layer_visibility_status[layer_id] = layer.visible
      layer_names[layer_id] = layer.name

      # if this is a layerset end, then remove the last layerset from current_layer_sets
      if layer.layerType == "bounding section divider"
        layer_visibility_status[layer_id] = 0
        current_layer_sets.pop()
        continue

      # Its a regular layer, push all the layers into the last item in the current_layer_set
      current_layer_set = current_layer_sets[current_layer_sets.length - 1]
      if not layer_sets[current_layer_set]?
        layer_sets[current_layer_set] = []

      layer_sets[current_layer_set].push layer_id

      # if the current layer is folder, add to current_layer_sets
      if layer.isFolder
        current_layer_sets.push layer.layerId
    
    layer_keys = Object.keys layer_visibility_status
    for layer in layer_keys
      visible = layer_visibility_status[layer]
      if visible == 0
        layer_visibility_status[layer] = 0
        children_layers = layer_sets[layer] || []
        for child_layer in children_layers 
          layer_visibility_status[child_layer] = 0

    layers_after_pruning = []
    for layer in layers
      layer_id = layer.layerId
      if layer_visibility_status[layer_id] == 1 and layer.layerType != "open folder" and layer.layerType != "closed folder"
        layers_after_pruning.push layer
    
    console.log "#{layers_after_pruning.length} Layers are visible"
    return layers_after_pruning

  toJSON: ->
    data =
      numLayers: @numLayers
      visibleLayers: @visible_layers.length
      layers: []

    for layer in @visible_layers
      data.layers.push layer.toJSON()

    data

module.exports = PSDLayerMask