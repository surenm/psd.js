class TextParser
  constructor: (@textItem) ->
    @text = @textItem.EngineDict.Editor.Text
    
  parse: () ->
    return
  
  toJSON: () ->
    return @text
  
module.exports = TextParser