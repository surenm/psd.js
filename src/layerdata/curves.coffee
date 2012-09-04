assert = require '../psdassert'

class PSDCurves
  constructor: (@layer, @length) ->
    @file = @layer.file
    @data =
      curve: []

  parse: ->
    start = @file.tell()

    # Data padding. Docs are wrong. Maybe Photoshop is wrong.
    # I don't know what's right anymore.
    @file.seek 1

    version = @file.readShortInt()
    assert version in [1, 4]

    tag = @file.readInt()
    @data.curveCount = 0
    for i in [0...32]
      # Count of the curves in the file
      @data.curveCount++ if tag & (1 << i)

    for i in [0...@data.curveCount]
      count = 0
      for j in [0...32]
        if tag & (1 << j)
          if count is i
            @data.curve[i] = channelIndex: j
            break

          count++

      @data.curve[i].pointCount = @file.readShortInt()
      assert @data.curve[i].pointCount >= 2
      assert @data.curve[i].pointCount <= 19

      for j in [0...@data.curve[i].pointCount]
        # Curve points. Each point is a pair of short ints where the
        # first number is the output value and the second is the input.
        @data.curve[i].outputValue = [] if not @data.curve[i].outputValue?
        @data.curve[i].inputValue = [] if not @data.curve[i].inputValue?
          
        @data.curve[i].outputValue[j] = @file.readShortInt()
        @data.curve[i].inputValue[j] = @file.readShortInt()

        assert @data.curve[i].outputValue[j] >= 0
        assert @data.curve[i].outputValue[j] <= 255
        assert @data.curve[i].inputValue[j] >= 0
        assert @data.curve[i].inputValue[j] <= 255

    # If this is true, we have some additional information to parse.
    if @file.tell() - start < @length - 4
      tag = @file.readString 4
      assert.equal tag, 'Crv '

      version = @file.readShortInt()
      assert version is 4

      curveCount = @file.readInt()
      assert.equal curveCount, @data.curveCount

      for i in [0...@data.curveCount]
        @data.curve[i].channelIndex = @file.readShortInt()
        pointCount = @file.readShortInt()
        assert pointCount is @data.curve[i].pointCount

        for j in [0...pointCount]
          outputValue = @file.readShortInt()
          inputValue = @file.readShortInt()
          assert.equal outputValue, @data.curve[i].outputValue[j]
          assert.equal inputValue, @data.curve[i].inputValue[j]

    # Only returned the parsed data
    @data

module.exports = PSDCurves