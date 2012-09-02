class PointRecord
  constructor: (subPathItem) ->
    @right_point = subPathItem[0]
    @anchor_point = subPathItem[1]
    @left_point = subPathItem[2]
    
  isPoint: () ->
    x1 = @right_point.x
    x2 = @anchor_point.x
    x3 = @left_point.x
    
    y1 = @right_point.y
    y2 = @anchor_point.y
    y3 = @left_point.y
    
    return x1 == x2 and x2 == x3 and y1 == y2 and y2 == y3
  
  toPoint: () ->
    if this.isPoint()
      return @anchor_point
  
  isCurvedLeft: () ->
    return (@left_point.x != @anchor_point.x) or (@left_point.y != @anchor_point.y)
    
  isCurvedRight: () ->
    return (@right_point.x != @anchor_point.x) or (@right_point.y != @anchor_point.y)
    
  isCurvedLeftOnly: () ->
    return this.isCurvedLeft() and not this.isCurvedRight()
  
  isCurvedRightOnly: () ->
    return this.isCurvedRight() and not this.isCurvedLeft()  
  
  isCurvedBoth: () ->
    return this.isCurvedLeft() and this.isCurvedRight()
  
  isAbcissalCurvature: () ->    
    xs = [@right_point.x, @anchor_point.x, @left_point.x]
    return  (xs[0] > xs[1] and xs[1] >= xs[2]) or (xs[0] < xs[1] and xs[1] < xs[2])
    
  isOrdinatalCurvature: () ->      
    ys = [@right_point.y, @anchor_point.y, @left_point.y]
    return  (ys[0] > ys[1] and ys[1] > ys[2]) or (ys[0] < ys[1] and ys[1] < ys[2])
    
  getCurvature: () ->
    return 0 if this.isPoint()
    
    curvature = -1
    if this.isCurvedBoth()
      if this.isOrdinatalCurvature()
        curvature = (Math.abs(@right_point.y - @anchor_point.y) + Math.abs(@anchor_point.y - @left_point.y))/2
      else if this.isAbcissalCurvature()
        curvature = (Math.abs(@right_point.x - @anchor_point.x) + Math.abs(@anchor_point.x - @left_point.x))/2
    else
      changing_point = null
      if this.isCurvedRightOnly()
        changing_point = @right_point
      else
        changing_point = @left_point
      
      if changing_point.y != @anchor_point.y
        curvature = Math.abs(changing_point.y - @anchor_point.y)
      else if changing_point.x != @anchor_point.x
        curvature = Math.abs(changing_point.x - @anchor_point.x)
        
    return Math.round(curvature)
  
  isPerpendicular: (otherSubPathItem) ->
    flag1 = this.isAbcissalCurvature() and otherSubPathItem.isOrdinatalCurvature()
    flag2 = this.isOrdinatalCurvature() and otherSubPathItem.isAbcissalCurvature()
    return (flag1 or flag2)
    
module.exports = PointRecord