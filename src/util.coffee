# "Static" utility functions
class Util
  @i16: (c) -> ord(c[1]) + (ord(c[0])<<8)
  @i32: (c) -> ord(c[3]) + (ord(c[2])<<8) + (ord(c[1])<<16) + (ord(c[0])<<24)

  @pad2: (i) -> Math.floor((i + 1) / 2) * 2
  @pad4: (i) -> (((i & 0xFF) + 1 + 3) & ~ 0x03) - 1

  # Round a number to a specific number of significant figures.
  @round: (num, sigFig = 2) ->
    return Math.round(num) if sigFig is 0
    mult = Math.pow(10, sigFig)
    Math.round(num * mult) / mult

  # Clamp a number between a maximum and minimum value.
  @clamp: (num, min = Number.MIN_VALUE, max = Number.MAX_VALUE) ->
    if typeof num is "object" and num.length?
      num[i] = Math.max(Math.min(val, max), min) for val, i in num
    else if typeof num is "object"
      num[i] = Math.max( Math.min(val, max), min ) for own i, val of num
    else
      num = Math.max(Math.min(num, max), min)

    num
