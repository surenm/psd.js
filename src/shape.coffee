PointRecord = require './pointrecord'
    
class Shape
  @LINE = "LINE"
  @RECTANGLE = "RECTANGLE"
  @ROUNDED_RECTANGLE = "ROUNDED_RECTANGLE"
  @COMPLEX = "GENERIC"
  
  constructor: (@subPathItems) ->
    # By default all Shape are complex
    @type = Shape.COMPLEX
    
    # Now find out if the Shape fall under any of this category
    switch @subPathItems.length
      when 2
        # could be a line
        if this.isLine()
          @type = Shape.LINE
      when 4
        # Could be a rectangle or ellipse
        if this.isRectangle()
          @type = Shape.RECTANGLE
      when 6
        #  could be rounded rectangle
        if this.isRoundedRectangle()
          @type = Shape.ROUNDED_RECTANGLE
      when 8
        if this.isRoundedRectangle()
          @type = Shape.ROUNDED_RECTANGLE
    
    # Calculate the bounds for this shape
    xs = []
    ys = []
    for item in @subPathItems
      xs.push item[0].x, item[1].x, item[2].x
      ys.push item[0].y, item[1].y, item[2].y
      
    x_min = Math.min.apply null, xs 
    y_min = Math.min.apply null, ys
    x_max = Math.max.apply null, xs
    y_max = Math.max.apply null, ys
    
    @bounds = 
      top: y_min
      left: x_min
      bottom: y_max
      right: x_max
    
    @width = "#{y_max - y_min}px"
    @height = "#{x_max - x_min}px"
     
  parse: () ->
    switch @type
      when Shape.LINE
        return this.parseLine()
      when Shape.RECTANGLE
        return this.parseRectangle()
      when Shape.ROUNDED_RECTANGLE
        return this.parseRoundedRectangle()
      when Shape.COMPLEX
        return this.parseGenericShape()
        
  isLine: () ->
    first_subpath = new PointRecord @subPathItems[0]
    second_subpath = new PointRecord @subPathItems[1]
    return first_subpath.isPoint() and second_subpath.isPoint()
  
  isRectangle: () ->
    first_subpath = new PointRecord @subPathItems[0]
    second_subpath = new PointRecord @subPathItems[1]
    third_subpath = new PointRecord @subPathItems[2]
    fourth_subpath = new PointRecord @subPathItems[3]

    return first_subpath.isPoint() and second_subpath.isPoint() and third_subpath.isPoint() and fourth_subpath.isPoint()
  
  isEllipse: () ->
    return false
  
  isRoundedRectangle: () ->
    if @subPathItems.length == 6
      return this.isSixPointRectangle()
    else if @subPathItems.length == 8
      return this.isEightPointRectangle()
  
  isSixPointRectangle: () ->
    for current_index in [1..@subPathItems.length]
      prev_index = current_index - 1
      current_index = current_index % 6
      
      current_item = new PointRecord @subPathItems[current_index]
      previous_item = new PointRecord @subPathItems[prev_index]
      
      flag1 = previous_item.isCurvedBoth() and current_item.isCurvedRightOnly()
      flag2 = previous_item.isCurvedRightOnly() and current_item.isCurvedLeftOnly()
      flag3 = previous_item.isCurvedLeftOnly() and current_item.isCurvedBoth()

      if not (flag1 or flag2 or flag3)
        return false
        
    return true
  
  isEightPointRectangle: () ->
    for current_index in [1..@subPathItems.length]
      prev_index = current_index - 1
      current_index = current_index % 8
      next_index = (current_index + 1) % 8
      
      current_item = new PointRecord @subPathItems[current_index]
      previous_item = new PointRecord @subPathItems[prev_index]
      next_item = new PointRecord @subPathItems[next_index]
      
      flag1 = previous_item.isCurvedRightOnly() and current_item.isCurvedLeftOnly() and next_item.isCurvedRightOnly()
      flag2 = previous_item.isCurvedLeftOnly() and current_item.isCurvedRightOnly() and next_item.isCurvedLeftOnly()
      flag3 = current_item.isPerpendicular(next_item) and current_item.isPerpendicular(previous_item)
      
      if not (flag1 or flag2 or flag3)
        return false

    return true
      
  parseLine: () ->
    first_point = (new PointRecord @subPathItems[0]).toPoint()
    second_point = (new PointRecord @subPathItems[1]).toPoint()
    
    x_min = Math.min first_point.x, second_point.x
    x_max = Math.max first_point.x, second_point.x
    y_min = Math.min first_point.y, second_point.y
    y_max = Math.max first_point.y, second_point.y
    
    length = Math.sqrt(Math.pow(x_max-x_min,2) + Math.pow(y_max-y_min,2))

    @shape = 
      type: @type
      bounds: @bounds
      length: "#{length}px"

  parseRectangle: () ->
    @shape = 
      type: @type
      bounds: @bounds
      width: @width
      height: @height

  parseRoundedRectangle: () ->
    curvature_points = [
      new PointRecord @subPathItems[0]
      new PointRecord @subPathItems[1]
    ]

    curvature = curvature_points[0].getCurvature() + curvature_points[1].getCurvature()
       
    @shape = 
      type: @type
      bounds: @bounds
      width: @width
      height: @height
      curvature: "#{curvature}px"
    
  parseGenericShape: () ->    
    @shape = 
      type: @type
      bounds: @bounds
      width: @width
      height: @height
      points: @subPathItems.length
    
    return null

  toJSON: () ->
    return @shape

module.exports = Shape