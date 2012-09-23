Util = require './util'

class TextParser
  constructor: (@textItem, @utf_encoded_string) ->
    raw_font_set = @textItem.DocumentResources.FontSet
    @text = this.parseUnicodeEncodedString utf_encoded_string
    @font_set = this.parseFontSet raw_font_set
    @style_sheets = @textItem.EngineDict.StyleRun.RunArray

  parse: () ->
    this.parseTextArray()
    this.parseStyleArray()

    @text_chunks = []
    for pos in [0..@style_array.length-1]
      text_chunk = 
        styles: @style_array[pos]
        text: @text_array[pos]
    
      @text_chunks.push text_chunk

    if @text_chunks.length == 1 or @text_chunks.length == 0
      return

    # merging happens in reverse order because otherwise you get into wierd index issues
    for pos in [@text_chunks.length-1..1]
      if TextParser.isSameStyled @text_chunks[pos], @text_chunks[pos - 1]
        new_text_object = 
          styles: @text_chunks[pos].styles
          text: @text_chunks[pos-1].text + @text_chunks[pos].text

        @text_chunks.splice pos-1, 2, new_text_object
  
  parseUnicodeEncodedString: (utf_encoded_string) ->
    text = ""
    pos = 1
    
    while pos < @utf_encoded_string.length - 1
      first_char = parseInt(@utf_encoded_string.charCodeAt(pos)).toString(16)
      second_char = parseInt(@utf_encoded_string.charCodeAt(pos+1)).toString(16)
      pos = pos + 2
      unicode_char_code = "0x#{Util.zeroFill first_char}#{Util.zeroFill second_char}"
      unicode_char = String.fromCharCode(unicode_char_code)
      text += unicode_char

    return text

  parseTextArray: () ->
    style_lengths_str = @textItem.EngineDict.StyleRun.RunLengthArray
    value = style_lengths_str.match(/\[(.*)\]/g)
    value = value[0].replace '[', ''
    value = value.replace ']', ''
    @style_lengths = value.split ' '
    @style_lengths.splice -1
    for i in [0..@style_lengths.length-1]
      @style_lengths[i] = parseInt(@style_lengths[i])

    @style_positions = [0]
    for i in [0..@style_lengths.length-1]
      @style_positions.push @style_lengths[i] + @style_positions[i]

    array_starts = @style_positions.slice 0
    array_ends = @style_positions.slice 0

    array_starts.pop()
    array_ends.shift()
    
    @text_array = []
    for i in [0..array_starts.length-1]
      str = @text.substring array_starts[i], array_ends[i]
      @text_array.push str

  parseStyleArray: () ->
    @style_array = []
    for style_sheet in @style_sheets
      stylesheet_object = style_sheet.StyleSheet.StyleSheetData
      font_id = stylesheet_object.Font
      properties = {}
    
      for key in Object.keys(@font_set[font_id])
        properties[key] = @font_set[font_id][key]
      
      font_styles = this.parseStyleObject stylesheet_object
      for key in Object.keys(font_styles)
        properties[key] = font_styles[key]

      @style_array.push properties
  
  parseFontSet: (raw_font_set) ->
    fonts = []
    for font in raw_font_set
      font_name_string = font.Name 
      parts = font_name_string.split '-'
      font_properties = {}
      font_properties['font-family'] = parts[0]
      
      font_style = parts[1] if parts[1]?

      switch font_style
        when "Bold"
          font_properties['font-weight'] = "bold"
        when 'Italic'
          font_properties['font-style'] = "italic"
        when 'BoldIt'
          font_properties['font-weight'] = "bold"
          font_properties['font-style'] = "italic"
        when 'Regular'
          font_properties['font-weight'] = "normal"

      fonts.push font_properties
    
    return fonts

  parseStyleObject: (style_object) ->
    styles = {}
        
    styles['color'] = this.parseTextColor style_object.FillColor if style_object.FillColor?
    styles['font-size'] = "#{parseInt Math.round(style_object.FontSize)}px"

    if style_object.FontCaps == 1
      styles['font-variant'] = 'small-caps'
    else if style_object.FontCaps == 2
      styles['text-transform'] = 'uppercase'

    if style_object.FauxItalic == true
      styles['font-style'] = "italic"

    if style_object.FauxBold == true
      styles['font-style'] == "bold"

    if style_object.Underline == true
      styles['text-decoration'] = "underline"
    else if style_object.Strikethrough == true
      styles['text-decoration'] = "line-through"

    if style_object.FontBaseline == 0
      styles['vertical-align'] == "super"
    else if style_object.FontBaseline == 2
      styles['vertical-align'] == "bottom"

    return styles
 
  parseTextColor: (color) ->
    color_arr_str = color.Values.match(/\[(.*)\]/g)
    value = color_arr_str[0]
    value = value.replace '[', ''
    value = value.replace ']', ''
    parts = value.split ' '
    opacity = parseFloat(parts[0])
    red = Math.round parseFloat(parts[1]) * 255
    grain = Math.round parseFloat(parts[2]) * 255
    blue = Math.round parseFloat(parts[3]) * 255
    
    if parseInt(opacity*100) == 100 or parseInt(opacity*100) == 0
      rr = Util.zeroFill parseInt(red).toString(16)
      gg = Util.zeroFill parseInt(grain).toString(16)
      bb = Util.zeroFill parseInt(blue).toString(16)
      color_string = "##{rr}#{gg}#{bb}"
    else
      rhex = parseInt(red)
      ghex = parseInt(grain)
      bhex = parseInt(blue)
      color_string = "rgba(#{rhex}, #{ghex}, #{bhex}, #{opacity})"
  
    return color_string

  @isSameStyled: (text_obj_a, text_obj_b) ->
    a_keys = Object.keys(text_obj_a.styles).sort()
    b_keys = Object.keys(text_obj_b.styles).sort()
  
    if not a_keys == b_keys
      return false
    
    for key in a_keys
      if text_obj_a.styles[key] != text_obj_b.styles[key]
        return false

    return true
  
  toJSON: () ->
    textItem = 
      full_text: @text
      chunks: @text_chunks
    return textItem
  
module.exports = TextParser