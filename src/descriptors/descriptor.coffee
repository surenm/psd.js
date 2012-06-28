class PSDDescriptor
  constructor: (@file) ->

  getUnicodeName: ->
    len = @file.readInt() * 2
    @file.read(len)

  getObjectId: ->
    len = @file.readInt()
    if len is 0
      @file.readInt()
    else
      @file.read(len)
      null