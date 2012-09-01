Log = require './log'
PSDConstants = require './psdconstants'
class PSDDescriptor
  constructor: (@file) ->

  # Main entry point for parsing a descriptor
  parse: ->
    Log.debug "Parsing descriptor..."

    data = {}
    data.class = @parseClass()

    numItems = @file.readInt()
    Log.debug "Descriptor contains #{numItems} items"
    constants = PSDConstants.CONSTANTS
    for i in [0...numItems]
      item = @parseKeyItem()
      item_key = constants[item.id]
      if item_key?
        data[item_key] = item.value
      else 
        data[item.id] = item.value

    data

  parseID: ->
    len = @file.readInt()
    if len is 0
      @file.readInt()
    else
      @file.readString(len)

  parseClass: ->
    name: @file.readUnicodeString()
    id: @parseID()

  parseKeyItem: ->
    id = @parseID()
    value = @parseItem(id)

    id: id, value: value

  parseItem: (id, type = null) ->
    type = @file.readString(4) unless type
    Log.debug "Found descriptor type: #{type}"

    value = switch type
      when 'bool' then @parseBoolean()
      when 'type', 'GlbC' then @parseClass()
      when 'Objc', 'GlbO' then @parse()
      when 'doub' then @parseDouble()
      when 'enum' then @parseEnum()
      when 'alis' then @parseAlias()
      when 'Pth ' then @parseFilePath()
      when 'long' then @parseInteger()
      when 'comp' then @parseLargeInteger()
      when 'VlLs' then @parseList()
      when 'ObAr' then @parseObjectArray()
      when 'tdta' then @parseRawData()
      when 'obj ' then @parseReference()
      when 'TEXT' then @file.readUnicodeString()
      when 'UntF' then @parseUnitDouble()

    value

  parseBoolean: -> @file.readBoolean()
  parseDouble: -> @file.readDouble()
  parseInteger: -> @file.readInt()
  parseLargeInteger: -> @file.readLongLong()
  parseIdentifier: -> @file.readInt()
  parseIndex: -> @file.readInt()
  parseOffset: -> @file.readInt()
  parseProperty: -> @parseID()

  # We discard the first ID because it's the same as the key
  # parsed from the Key/Item.
  parseEnum: ->
    @parseID()
    @parseID()

  # File Alias
  # This data is opaque and unique to Mac OS
  parseAlias: ->
    len = @file.readInt()
    @file.read(len)

  parseFilePath: ->
    len = @file.readInt()

    # Little-endian?!?
    [
      sig,
      pathSize,
      numChars
    ] = @file.readf("<4s2i")

    charBytes = numChars * 2
    path = @file.read(charBytes)

    sig: sig, path: path

  parseList: ->
    numItems = @file.readInt()
    items = []
    items.push @parseItem() for i in [0...numItems]
    items

  parseObjectArray: ->
    numItems = @file.readInt()
    klass = @parseClass()
    itemsInObj = @file.readInt()

    obj = []
    for i in [0...numItems]
      item = []
      for j in [0...itemsInObj]
        item.push @parseObjectArray()

      obj.push item

    obj

  parseObjectArray: ->
    id = @parseID()
    type = @file.readString(4)
    unitID = @file.readString()
    num = @file.readInt()

    values = []
    values.push @file.readDouble() for i in [0...num]
    values

  parseRawData: ->
    len = @file.readInt()
    @file.read(len)

  parseReference: ->
    form = @file.readString(4)
    klass = @parseClass()

    value = switch form
      when "Clss" then null
      when "Enmr" then @parseEnum()
      when "Idnt" then @parseIdentifier()
      when "indx" then @parseIndex()
      when "name" then @file.readUnicodeString()
      when "rele" then @parseOffset()
      when "prop" then @parseProperty()

    value

  parseUnitDouble: ->
    unitID = @file.readString(4)
    unit = switch unitID
      when "#Ang" then "Angle"
      when "#Rsl" then "Density"
      when "#Rlt" then "Distance"
      when "#Nne" then "None"
      when "#Prc" then "Percent"
      when "#Pxl" then "Pixels"
      when "#Mlm" then "Millimeters"
      when "#Pnt" then "Points"

    value = @file.readDouble()

    id: unitID, unit: unit, value: value

module.exports = PSDDescriptor