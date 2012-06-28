# Type: 'VlLs'
class PSDObjectList extends PSDDescriptor
  parse: ->
    num = @file.readInt()

    data = []
    for i in [0...num]
      type = @file.readString()

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