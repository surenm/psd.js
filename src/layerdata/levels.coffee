assert = require '../psdassert'

class PSDLevels
  constructor: (@layer, @length) ->
    @file = @layer.file
    @data =
      records: []

  parse: ->
    start = @file.tell()

    version = @file.readShortInt()
    assert version is 1

    @parseLevelRecords()

    # PS CS (8.0) additional information
    if @file.tell() - start < @length - 4
      tag = @file.readf ">4s"
      assert.equal tag, "Lvls"

      version = @file.readShortInt()
      assert.equal version, 3

      # Figure out the total number of level record structures
      # Subtract the legacy number of level record structures (29)
      # to determine how many are remaining in the file for reading.
      @data.levelCount = @file.readShortInt() - 29
      assert levelCount >= 0
      @parseLevelRecords(levelCount)

      # Only return the important data. Don't need to hold on to this
      # entire class.
      return @data


  parseLevelRecords: (count = 29) ->
    # 29 sets of level records. each level has 5 short ints
    for i in [0...count]
      record = {}
      [
        record.inputFloor,     # (0...253)
        record.inputCeiling,   # (2...255)
        record.outputFloor,    # (0...255)
        record.outputCeiling,  # (0...255)
        record.gamma           # (10...999)
      ] = @file.readf ">hhhhh"

      record.gamma /= 100

      # Sets 28 and 29 are reserved
      if i < 27
        assert record.inputFloor >= 0 and record.inputFloor <= 255
        assert record.inputCeiling >= 2 and record.inputCeiling <= 255
        assert record.outputFloor >= 0 and record.outputFloor <= 255
        assert record.outputCeiling >= 0 and record.outputCeiling <= 255
        assert record.gamma >= 0.1 and record.gamma <= 9.99

      @data.records.push record

module.exports = PSDLevels