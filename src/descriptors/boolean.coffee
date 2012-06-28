# Key: 'bool'
class PSDObjectBoolean extends PSDDescriptor
  parse: -> @file.readBoolean()