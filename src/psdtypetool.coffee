# Parser for the PS Type Tool
# Work in progress. There are two separate structures depending
# on whether the file was saved with PS 5.0/5.5 or PS 6+
class PSDTypeTool
  constructor: (@file, @legacy = false) ->

  parse: ->
    ver = @file.readShortUInt()
    transforms = []
    transforms.push @file.readDouble() for i in [0...6]

    textVer = @file.readShortUInt()
    descrVer = @file.readUInt()
    return if ver isnt 1 or textVer isnt 50 or descrVer isnt 16

    textData = @file.readDescriptorStructure()

    wrapVer = @readShortUInt()
    descrVer = @readUInt()
    wrapData = @file.readDescriptorStructure()

    rectangle = []
    rectangle.push @file.readDouble() for i in [0...4]

    @textData = textData
    @wrapData = wrapData

    styledText = []
    psDict = @textData.EngineData.value
    text = psDict.EngineDict.Editor.Text
    styleRun = psDict.EngineDict.StyleRun
    stylesList = styleRun.RunArray
    stylesRunList = styleRun.RunLengthArray

    fontsList = psDict.DocumentResources.FontSet
    start = 0
    for own i, style of stylesList
      st = style.StyleSheet.StyleSheetData
      end = parseInt(start + stylesRunList[i], 10)
      fontI = st.Font
      fontName = fontsList[fontI].Name
      safeFontName = @getSafeFont(fontName)

      color = []
      color.push(255*j) for j in st.FillColor.Values[1..]

      lineHeight = if st.Leading is 1500 then "Auto" else st.Leading
      piece = text[start...end]
      styledText.push
        text: piece
        style:
          font: safeFontName
          size: st.FontSize
          color: Util.rgbToHex("rgb(#{color[0]}, #{color[1]}, #{color[2]})")
          underline: st.Underline
          allCaps: st.FontCaps
          italic: !!~ fontName.indexOf("Italic") or st.FauxItalic
          bold: !!~ fontName.indexOf("Bold") or st.FauxBold
          letterSpacing: st.Tracking / 20
          lineHeight: lineHeight
          paragraphEnds: piece.substr(-1) in ["\n", "\r"]

      start += stylesRunList[i]

    @styledText = styledText