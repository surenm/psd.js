# Key 'Objc'
class PSDObjectDescriptor extends PSDDescriptor
  parse: ->
    @getUnicodeName()
    @getObjectId()

    data = []
    num = @file.readInt()
    for i in [0...num]
      len = @file.readInt()
      if len is 0
        @file.readInt()
      else
        @file.read len

      type = @file.readString(4)

      switch type
        when 'obj '
          data.push (new PSDObjectReference(@file)).parse()
        when 'Objc', 'GlbO'
          data.push (new PSDObjectDescriptor(@file)).parse()
        when 'VlLs'
          data.push (new PSDObjectList(@file)).parse()
        when 'doub'
          data.push (new PSDObjectDouble(@file)).parse()
        when 'UntF'
          data.push (new PSDObjectUnitFloat(@file)).parse()
        when 'TEXT'
          data.push (new PSDObjectString(@file)).parse()
        when 'enum'
          data.push (new PSDObjectEnum(@file)).parse()
        when 'long'
          data.push (new PSDObjectInteger(@file)).parse()
        when 'bool'
          data.push (new PSDObjectBoolean(@file)).parse()
        when 'type', 'GlbC'
          data.push (new PSDObjectClass(@file)).parse()
        when 'alis'
          data.push (new PSDObjectAlias(@file)).parse()

    data
