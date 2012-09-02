# The PSD header describes all kinds of important information pertaining to 
# the PSD file such as size, color channels, color depth, and so on.
class PSDHeader
  # All of the sections that the header contains. These will become properties 
  # of the instantiated header object once parsed.
  HEADER_SECTIONS = [
    "sig"
    "version"
    
    # These are reserved bytes, always zero
    "r0"
    "r1"
    "r2"
    "r3"
    "r4"
    "r5"

    "channels"
    "rows"
    "cols"
    "depth"
    "mode"
  ]

  # Common names for various color modes, which are specified by an integer in 
  # the header.
  MODES =
    0:  'Bitmap'
    1:  'GrayScale'
    2:  'IndexedColor'
    3:  'RGBColor'
    4:  'CMYKColor'
    5:  'HSLColor'
    6:  'HSBColor'
    7:  'Multichannel'
    8:  'Duotone'
    9:  'LabColor'
    10: 'Gray16'
    11: 'RGB48'
    12: 'Lab48'
    13: 'CMYK64'
    14: 'DeepMultichannel'
    15: 'Duotone16'

  constructor: (@file) ->

  parse: ->
    # Read the header section
    data = @file.readf ">4sH 6B HLLHH"

    # Add all of the header sections as properties of this object.
    @[section] = data.shift() for section in HEADER_SECTIONS

    # Store size in an easy to use place for later
    @size = 
      height: @rows
      width: @cols

    # This must be 8BPS according to the spec, or else this is not a valid PSD 
    # file.
    if @sig isnt "8BPS"
      throw "Not a PSD signature: #{@sig}"
    
    # The spec only covers version 1 of PSDs. I believe this is the only 
    # version available at this time, anyways.
    if @version isnt 1
      throw "Can not handle PSD version #{@version}"

    # Store the common mode name
    if 0 <= @mode < 16
      @modename = MODES[@mode]
    else
      @modename = "(#{@mode})"

    # Information about the color mode is a bit complex. We're skipping this 
    # for now. TODO.
    @colormodepos = @file.pos
    @file.skipBlock "color mode data"

  toJSON: ->
    data =
      height: @rows
      width: @cols
      modename: @modename

    return data
    
module.exports = PSDHeader