PSDDescriptor = require '../psddescriptor'
Parser = require '../parser'
assert = require '../psdassert'
Log = require '../log'

class PSDPath
  constructor: (@layer, @length) ->
    @file = @layer.file
    @size = @layer.header.size
    @image_height = @size.height
    @image_width = @size.width
  
  parse: () ->
    pathItems = []

    version = @file.readInt()    
    Log.debug "Photoshop version: #{version}"
    flags = @file.readInt()
    Log.debug "Flags: #{flags}"
    
    records = parseInt (@length - 8)/26
    record = 0
    while record < records
      selector_type = @file.readShortInt()
      switch selector_type
        when 0
          Log.debug "Closed subpath length record"
          path = this.parse_subpath_record @file
          Log.debug "Path had #{path.length} points"
          record += path.length

          Log.debug_path
          pathItem = 
            closed: true
            subPathItems: path
          
          pathItems.push pathItem
        when 3
          Log.debug "Open subpath length record"
          path =this.parse_subpath_record @file
          Log.debug "Path had #{path.length} points"
          record += path.length + 1
          
          Log.debug path
          pathItem = 
            closed: false
            subPathItems: path
            
          pathItems.push pathItem
        when 6
          Log.debug "Path fill rule record"
          filler = @file.read 24
        when 7
          Log.debug "Clipboard record"
          filler = @file.read 24
        when 8
          Log.debug "Initial fill record"
          filler = @file.read 24
      record++
      
    shapes = []
    for pathItem in pathItems
      shapes.push Parser.parsePathItem(pathItem)
    return shapes
    
  parse_subpath_record: (@file) ->
    num_subpath_records = @file.readShortInt()
    filler = @file.read 22
    subpath_records = []

    for beizer_knot in [1..num_subpath_records]
      subpath_record = this.parse_beizer_knots_record @file
      subpath_records.push subpath_record
    
    return subpath_records

  parse_beizer_knots_record: (@file) ->
    selector_type = @file.readShortInt()
    assert selector_type in [1, 2, 4, 5]
    beizer_knot = []
    for i in [1..3]
      point = this.parse_point_record @file
      beizer_knot.push point
    return beizer_knot

  parse_point_record: (@file) ->
    decimal = parseInt(@file.read(1))
    fraction = parseInt(@file.read(3))

    if decimal < 128
      y = Math.round ((decimal * 255 + fraction) * @image_height) / 255
    else 
      y = Math.round ((decimal - 255) * 255 + (fraction - 255)) * @image_height / 255

    
    decimal = parseInt(@file.read(1))
    fraction = parseInt(@file.read(3))

    if decimal < 128
      x = Math.round ((decimal * 255 + fraction) * @image_width) / 255
    else
      x = Math.round ((decimal - 255) + (fraction - 255)) * @image_width / 255

    return {x: x, y: y}

module.exports = PSDPath
