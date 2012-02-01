# Simulation and abstraction of a disk-based file.
# Provides methods to read the raw binary file data, which is stored in a 
# variable instead of read from disk. A lot of these functions are from C,
# but some of them are helper functions to make things a bit easier to
# understand.
class PSDFile
  constructor: (@data) ->
    # Track our current position in the file data. This is analogous to the
    # file pointer in C.
    @pos = 0

  # Get the current position in the file. This is here to parallel the C method
  tell: -> @pos

  # Read one or more bytes from the file. Note that this moves the file pointer
  # forward the number of bytes specified.
  read: (bytes) -> (@data[@pos++] for i in [0...bytes])

  # Move the file pointer to a new position. By default, this is done relative
  # to the current file pointer position. Setting the 2nd argument to false
  # causes the file pointer to move to the absolute location specified.
  seek: (amount, rel = true) ->
    if rel then @pos += amount else @pos = amount
      
  # Helper function to read an unsigned 16-bit integer
  readUInt16: ->
    b1 = @data[@pos++] << 8
    b2 = @data[@pos++]
    b1 | b2

  # Reads an unsigned 4 byte int
  readInt: -> @readf(">I")[0]

  # Reads an unsigned 2 byte int
  readShortInt: -> @readf(">h")[0]

  # Reads a double/float
  readDouble: -> @readf(">d")[0]

  # Reads a boolean flag and returns true/false
  readBoolean: -> @read(1)[0] isnt 0

  # Safely reads a unicode string
  readUnicodeString: ->
    str = ""
    strlen = @readInt()
    for i in [0...strlen]
      charCode = @readShortInt()
      str += chr(Util.i16(charCode)) if charCode > 0

    str

  # Parses the structure of a descriptor
  readDescriptorStructure: ->
    name = @readUnicodeString()
    classID = @readLengthWithString()
    items = @readInt()

    descriptors = {}
    for i in [0...items]
      key = @readLengthWithString().trim()
      descriptors[key] = @readOsType()

    descriptors

  # Reads a string with the given length. Note that the length is given in 
  # bytes, not characters.
  readString: (length) -> @readf ">#{length}s"

  # Used for reading pascal strings, which are strings that have their length # prepended to the chunk of character bytes. If a length isn't found, a 
  # string with the default length will be read instead.
  readLengthWithString: (defaultLen = 4) ->
    length = @readInt()
    if length is 0
      [str] = @readf ">#{defaultLen}s"
    else
      [str] = @readf ">#{length}s"

    str

  # Parses a special OS variable type
  readOsType: ->
    osType = @readString(4)
    value = null
    switch osType
      when "TEXT" then value = @readUnicodeString()
      when "enum", "Objc", "GlbO"
        value =
          typeID: @readLengthWithString()
          enum: @readLengthWithString()
      when "VlLs"
        listSize = @readInt()
        value = []
        value.push(@readOsType()) for i in [0...listSize]
      when "doub" then value = @readDouble()
      when "UntF"
        value =
          type: @readString(4)
          value: @readDouble()
      when "long" then value = @readInt()
      when "bool" then value = @readBoolean()
      when "alis"
        length = @readInt()
        value = @readString(length)
      when "obj"
        num = @readInt()
        for i in [0...num]
          type = @readString(4)
          switch type
            when "prop"
              value =
                name: @readUnicodeString()
                classID: @readLengthWithString()
                keyID: @readLengthWithString()
            when "Clss"
              value =
                name: @readUnicodeString()
                classID: @readLengthWithString()
            when "Enmr"
              value =
                name: @readUnicodeString()
                classID: @readLengthWithString()
                typeID: @readLengthWithString()
                enum: @readLengthWithString()
            when "rele"
              value =
                name: @readUnicodeString()
                classID: @readLengthWithString()
                offsetValue: @readInt()
            when "Idnt", "indx", "name" then value = null
      when "tdta"
        # Skip this
        length = @readInt()
        @seek length

    {type: osType, value: value}

  # Reads a byte list
  readBytesList: (size) ->
    bytesRead = @read size
    result = []
    result.push ord(b) for b in bytesRead
    result
  
  # Reads from the file given the unpack format string. Format string codes 
  # can be easily referenced 
  # [from the Python docs](http://docs.python.org/library/struct.html#format-characters)
  readf: (format) -> jspack.Unpack format, @read(jspack.CalcLength(format))

  # Skips a block, assuming the next byte describes the size of the section.
  # An optional description is given to explain why we are skipping this block
  # instead of parsing it.
  skipBlock: (desc = "unknown") ->
    [n] = @readf('>L')
    @seek(n) if n # relative

    Log.debug "Skipped #{desc} with #{n} bytes"