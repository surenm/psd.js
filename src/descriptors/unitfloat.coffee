# Key: 'UntF'
class PSDObjectUnitFloat extends PSDDescriptor
  parse: ->
    @file.readInt()
    @file.readDouble()