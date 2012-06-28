# Key: 'type', 'GlbC'
class PSDObjectClass extends PSDDescriptor
  parse: ->
    @getUnicodeName()
    @getObjectId()