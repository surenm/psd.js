# "Static" utility functions
class Util
  @i16: (c) -> ord(c[1]) + (ord(c[0])<<8)
  @i32: (c) -> ord(c[3]) + (ord(c[2])<<8) + (ord(c[1])<<16) + (ord(c[0])<<24)

  @pad2: (i) -> Math.floor((i + 1) / 2) * 2
  @pad4: (i) -> (((i & 0xFF) + 1 + 3) & ~ 0x03) - 1

  @round: (num, sigFig = 2) ->
    return Math.round(num) if sigFig is 0
    mult = Math.pow(10, sigFig)
    Math.round(num * mult) / mult
