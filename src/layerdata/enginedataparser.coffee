class EngineDataParser
  @parseData: (data) ->
    data = data.replace(/(\r\n|\n|\r)/gm,' ')
    data = data.replace(/\s{2,}/g, ' ')
    
    tokens = data.split(' ')
    root = {}
    EngineDataParser.parseTokens tokens, root
    return root
    
  @parseTokens: (tokens, parent, parent_is_array=false) ->
    while tokens[0] == ""
      tokens.splice 0, 1
    
    currentToken = tokens[0]
    
    if currentToken == ">>" and not parent_is_array
      return 
      
module.exports = EngineDataParser