# Key 'obj '
class PSDObjectReference extends PSDDescriptor
  parse: ->
    num = @file.parseInt()

    for i in [0...num]
      type = @file.readString(4)

      switch type
        when 'prop'
          @getUnicodeName()
          @getObjectId()
          @getObjectId()
        when 'Clss'
          @getUnicodeName()
          @getObjectId()
        when 'Enmr'
          @getUnicodeName()
          @getObjectId()
          @getObjectId()
          @getObjectId()
        when 'rele'
          @getUnicodeName()
          @getObjectId()
          @file.readInt()
        when 'Idnt'
          @file.readInt()
        when 'indx'
          @file.readInt()
        when 'name'
          @getUnicodeName()