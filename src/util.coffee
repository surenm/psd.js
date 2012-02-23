# "Static" utility functions
class Util
  @i16: (c) -> ord(c[1]) + (ord(c[0])<<8)
  @i32: (c) -> ord(c[3]) + (ord(c[2])<<8) + (ord(c[1])<<16) + (ord(c[0])<<24)

  @pad2: (i) -> Math.floor((i + 1) / 2) * 2
  @pad4: (i) -> (((i & 0xFF) + 1 + 3) & ~ 0x03) - 1

  @rgbToHex: (c) ->
    m = /rgba?\((\d+), (\d+), (\d+)/.exec(c)
    if m then '#' + ( m[1] << 16 | m[2] << 8 | m[3] ).toString(16) else c
