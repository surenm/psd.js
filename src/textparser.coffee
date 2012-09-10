Util = require './util'

class TextParser
  constructor: (@textItem) ->
    @text = @textItem.EngineDict.Editor.Text
    @text = @text.substring(0, @text.length-1)
    
    raw_font_set = @textItem.DocumentResources.FontSet
    @font_set = this.parseFontSet raw_font_set
    
    @style_run = @textItem.EngineDict.StyleRun
    @style_sheets = @style_run.RunArray
    
    
  parse: () ->
    @font_styles = []
    for style_sheet in @style_sheets
       font_style = this.parseStyleSheet style_sheet.StyleSheet.StyleSheetData
       @font_styles.push font_style
    
    @font_styles
    
  
  parseStyleSheet: (stylesheet_object) ->
    font_id = stylesheet_object.Font
    properties = @font_set[font_id]
      
    properties['font-size'] = "#{stylesheet_object.FontSize}px"
    properties['color'] = this.parseTextColor stylesheet_object.FillColor
    
    return properties
  
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
  
  toJSON: () ->
    return { text: @text, styles: @font_styles }
  
module.exports = TextParser