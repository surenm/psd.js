class Parser
  @zeroFill: (number, width=2) ->
    width -= (number.toString().length - /\./.test(number))
    if (width > 0) 
      return new Array(width + 1).join('0') + number
    return number + ""

  
  @parseColor: (color_object) ->
    # Color objects could be in many color modes. Handling RGB color modes for now
    
    if color_object.class.id == 1380401731
      rr = this.zeroFill color_object.red.toString(16)
      gg = this.zeroFill color_object.grain.toString(16)
      bb = this.zeroFill color_object.blue.toString(16)
      
      color_string = "##{rr}#{gg}#{bb}"
      return color_string
      
      