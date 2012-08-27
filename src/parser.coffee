class Parser
  @zeroFill: (number, width=2) ->
    width -= (number.toString().length - /\./.test(number))
    if (width > 0)
      return new Array(width + 1).join('0') + number
    return number + ""

  
  @parseColor: (color_object, opacity = 1.00) ->
    # Color objects could be in many color modes. Handling RGB color modes for now
    
    if color_object.class.id == 1380401731
      
      if parseInt(opacity*100) == 100 or parseInt(opacity*100) == 0
        rr = this.zeroFill parseInt(color_object.red).toString(16)
        gg = this.zeroFill parseInt(color_object.grain).toString(16)
        bb = this.zeroFill parseInt(color_object.blue).toString(16)
        color_string = "##{rr}#{gg}#{bb}"
      else
        rhex = parseInt(color_object.red)
        ghex = parseInt(color_object.grain)
        bhex = parseInt(color_object.blue)
        color_string = "rgba(#{rhex}, #{ghex}, #{bhex}, #{opacity})"
      return color_string

  @parseGradient: (gradient_object) ->
    # TODO: Fix opacity stops level gradients as well
    gradient_type = PSDConstants.CONSTANTS[gradient_object.type]

    overall_length = gradient_object.gradient.interfaceIconFrameDimmed
    
    opacity_stops = {}
    for transparency_object in gradient_object.gradient.transparency
      location_percentage = Math.round((100*transparency_object.location)/overall_length)
      opacity_stops[location_percentage] = parseFloat(transparency_object.opacity.value/100).toFixed(2)

    color_stops =[]
    for color_object in gradient_object.gradient.colors
      location_percentage = Math.round((100*color_object.location)/overall_length)
      if opacity_stops[location_percentage]?
        color = this.parseColor color_object.color, opacity_stops[location_percentage]
      else
        color = this.parseColor color_object.color

      color_stops.push "#{color} #{location_percentage}%"
    
    switch gradient_type

      when "linear"
        gradient =
          type: gradient_type
          angle: gradient_object.angle.value
          color_stops: color_stops

      when "radial"
        gradient =
          type: gradient_type
          scale: gradient_object.scale.value
          color_stops: color_stops

      else
        console.log "Unhandled gradient type: #{gradient_type}"

    return gradient

  @parsePattern: (pattern_object) ->
    #TODO: the pattern is there somewhere. I am going to get it out one of these days
    pattern =
      uid: pattern_object.pattern.ID
      name: pattern_object.pattern.name

    return pattern

  @parseBorder: (border_object) ->
    opacity = parseFloat(border_object.opacity.value/100).toFixed(2)

    border =
      color: this.parseColor border_object.color, opacity
      width: "#{border_object.size.value}px"
      type: PSDConstants.CONSTANTS[border_object.style]
