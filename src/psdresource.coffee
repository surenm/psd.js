Log = require('./log')
Util = require('./util')

class PSDResource
  RESOURCE_DESCRIPTIONS =
    1000: 
      name: 'PS2.0 mode data'
      parse: -> 
        [
          @channels,
          @rows,
          @cols,
          @depth,
          @mode
        ] = @file.readf ">5H"

    1001: 
      # Data format missing from spec
      name: 'Macintosh print record'

    1003:
      # Obsolete
      name: 'PS2.0 indexed color table'

    1005:
      # TODO
      name: 'ResolutionInfo'

    1006:
      # TODO
      name: 'Names of the alpha channels'

    1007:
      # TODO
      name: 'DisplayInfo'

    1008:
      name: 'Caption'
      parse: -> @caption = @file.readLengthWithString()

    1009:
      name: 'Border information'
      parse: ->
        [@width, units] = @file.readf ">fH"

        @units = switch units
          when 1 then "inches"
          when 2 then "cm"
          when 3 then "points"
          when 4 then "picas"
          when 5 then "columns"

    1010:
      # TODO
      name: 'Background color'

    1011:
      name: 'Print flags'
      parse: -> 
        start = @file.tell()
        [
          # These are all simple boolean flags
          @labels,
          @cropMarks,
          @colorBars,
          @registrationMarks,
          @negative,
          @flip,
          @interpolate,
          @caption,
          # Apparently this isn't a 1 byte boolean?
          # @printFlags
        ] = @file.readf ">9B"

        @file.seek start + @size, false

    1012:
      # Missing from spec
      name: 'Grayscale/multichannel halftoning info'

    1013: 
      # Missing from spec
      name: 'Color halftoning info'

    1014:
      # Missing from spec
      name: 'Duotone halftoning info'

    1015:
      # Missing from spec
      name: 'Grayscale/multichannel transfer function'

    1016:
      # Missing from spec
      name: 'Color transfer functions'

    1017: 
      # Missing from spec
      name: 'Duotone transfer functions'

    1018:
      # Missing from spec
      name: 'Duotone image info'

    1019:
      # Not sure if 1 or 2 values. Spec unclear.
      name: 'B&W values for the dot range'
      parse: -> [@bwvalues] = @file.readf ">H"

    1021:
      # Missing from spec
      name: 'EPS options'

    1022: 
      name: 'Quick Mask info'
      parse: -> 
        [
          @quickMaskChannelID, 
          @wasMaskEmpty
        ] = @file.readf ">HB"

    1024: 
      # target = 0 means bottom layer
      name: 'Layer state info'
      parse: -> [@targetLayer] = @file.readf ">H"

    1025: 
      # TODO (not saved though, so optional?)
      name: 'Working path'

    1026: 
      name: 'Layers group info'
      parse: ->
        start = @file.tell()
        @layerGroupInfo = []
        while @file.tell() < start + @size
          [info] = @file.readf ">H"
          @layerGroupInfo.push info

    1028:
      # TODO
      name: 'IPTC-NAA record (File Info)'

    1029:
      # Missing from spec
      name: 'Image mode for raw format files'

    1030:
      # Private. Can't be parsed?
      name: 'JPEG quality'

    1032:
      # TODO
      name: 'Grid and guides info'

    1033:
      # TODO
      name: 'Thumbnail resource'

    1034:
      name: 'Copyright flag'
      parse: -> [@copyrighted] = @file.readf ">#{@size}B"

    1035:
      name: 'URL'
      parse: -> [@url] = @file.readf ">#{@size}s"

    1036:
      # TODO. Supersedes 1033.
      name: 'Thumbnail resource'

    1037:
      # Obsolete
      name: 'Global Angle'

    1038:
      # Obsolete
      name: 'Color samplers resource'

    1039:
      # TODO
      name: 'ICC Profile'

    1040:
      name: 'Watermark'
      parse: -> [@watermarked] = @file.readf ">B"

    1041:
      name: 'ICC Untagged'
      #parse: -> [@disableProfile] = @file.readf ">B"

    1042:
      name: 'Effects visible'
      parse: -> [@showEffects] = @file.readf ">B"

    1043:
      name: 'Spot Halftone'
      parse: ->
        [@halftoneVersion, length] @file.readf ">LL"
        @halftoneData = @file.read length

    1044:
      name: 'Document specific IDs seed number'
      parse: -> [@docIdSeedNumber] = @file.readf ">L"

    1045:
      # Spec is a bit unclear. TODO.
      name: 'Unicode Alpha Names'

    1046:
      name: 'Indexed Color Table Count'
      parse: -> [@indexedColorCount] = @file.readf ">H"

    1047:
      name: 'Transparent Index'
      parse: -> [@transparencyIndex] = @file.readf ">H"

    1049:
      name: 'Global Altitude'
      parse: -> [@globalAltitude] = @file.readf ">L"

    1050:
      # TODO
      name: 'Slices'

    1051:
      name: 'Workflow URL'
      parse: -> @workflowName = @file.readLengthWithString()

    1052:
      name: 'Jump To XPEP'
      parse: -> 
        [
          @majorVersion,
          @minorVersion,
          count
        ] = @file.readf ">HHL"

        @xpepBlocks = []
        for i in [0...count]
          block =
            size: @file.readf ">L"
            key: @file.readf ">4s"

          if block.key is "jtDd"
            block.dirty = @file.readBoolean()
          else
            block.modDate = @file.readf ">L"

          @xpepBlocks.push block

    1053:
      # TODO
      name: 'Alpha Identifiers'

    1054:
      name: 'URL List'

    1057:
      name: 'Version Info'

    1058:
      name: 'EXIF data 1'

    1059:
      name: 'EXIF data 3'

    1060:
      name: 'XMP metadata'

    1061:
      name: 'Caption digest'

    1062:
      name: 'Print scale'

    1064:
      name: 'Pixel Aspect Ratio'

    1065:
      name: 'Layer Comps'

    1066:
      name: 'Alternate Duotone Colors'

    1067:
      name: 'Alternate Spot Colors'

    1069:
      name: 'Layer Selection ID(s)'

    1070:
      name: 'HDR Toning information'

    1071:
      name: "Print info"

    1072:
      name: "Layer Groups Enabled"

    1073:
      name: "Color samplers resource"

    1074:
      name: "Measurement Scale"

    1075:
      name: "Timeline Information"

    1076:
      name: "Sheet Disclosure"

    1077:
      name: "DisplayInfo"

    1078:
      name: "Onion Skins"

    1080:
      name: "Count Information"

    1082:
      name: "Print Information"

    1083:
      name: "Print Style"

    1084:
      # Recommended to stay away from
      name: "Macintosh NSPrintInfo"

    1085:
      # Recommended to stay away from
      name: "Windows DEVMODE"

    2999:
      name: 'Name of clipping path'

    7000:
      # This is in XML. Yippee.
      name: "Image Ready variables"

    7001:
      name: "Image Ready data sets"

    8000:
      # If this exists, we're in the middle of a Lightroom
      # workflow. Strange.
      name: "Lightroom workflow"
      parse: @isLightroom = true

    10000:
      name: 'Print flags info'
      parse: ->
        [
          @version,
          @centerCropMarks,
          padding,
          @bleedWidth,
          @bleedWidthScale
        ] = @file.readf ">HBBLH"

  constructor: (@file) ->

  parse: ->
    @at = @file.tell()  

    [@type, @id, @namelen] = @file.readf ">4s H B"

    Log.debug "Resource ##{@id}: type=#{@type}"

    n = Util.pad2(@namelen + 1) - 1
    [@name] = @file.readf ">#{n}s"
    @name = @name.substr(0, @name.length - 1)
    @shortName = @name.substr(0, 20)

    @size = @file.readInt()
    @size = Util.pad2(@size)

    if 2000 <= @id <= 2998
      @rdesc = "[Path Information]"
      @file.seek @size
    else if @id is 2999
      assert 0
    else if 4000 <= @id < 5000
      @rdesc = "[Plug-in Resource]"
      @file.seek @size
    else if RESOURCE_DESCRIPTIONS[@id]?
      resource = RESOURCE_DESCRIPTIONS[@id]
      @rdesc = "[#{resource.name}]"

      if resource.parse?
        resource.parse.call(@)
      else
        @file.seek @size
    else
      @file.seek @size

  toJSON: ->
    sections = [
      'type'
      'id'
      'name'
      'rdesc'
    ]

    data = {}
    for section in sections
      data[section] = @[section]

    data

module.exports = PSDResource