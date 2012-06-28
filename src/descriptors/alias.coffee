# Key: 'alis'
class PSDObjectAlias extends PSDDescriptor
  parse: ->
    len = @file.getInt()
    @file.readString(len)