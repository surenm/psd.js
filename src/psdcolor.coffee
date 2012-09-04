Util = require('./util')
# Tons of color conversion functions.
# Borrowed directly from CamanJS.
class PSDColor
  # Converts the hex representation of a color to RGB values.
  # Hex value can optionally start with the hash (#).
  #
  # <pre>
  # @param   String  hex   The colors hex value
  # @return  Array         The RGB representation
  # </pre>
  @hexToRGB: (hex) ->
    hex = hex.substr(1) if hex.charAt(0) is "#"
    r = parseInt hex.substr(0, 2), 16
    g = parseInt hex.substr(2, 2), 16
    b = parseInt hex.substr(4, 2), 16

    r: r, g: g, b: b

  @rgbToHex: (c) ->
    if arguments.length is 1
      m = /rgba?\((\d+), (\d+), (\d+)/.exec(c)
    else
      m = Array.prototype.slice.call(arguments)
      m.unshift(0)

    if m then '#' + ( m[1] << 16 | m[2] << 8 | m[3] ).toString(16) else c

  # Converts an RGB color to HSL.
  # Assumes r, g, and b are in the set [0, 255] and
  # returns h, s, and l in the set [0, 1].
  #
  # <pre>
  # @param   Number  r   Red channel
  # @param   Number  g   Green channel
  # @param   Number  b   Blue channel
  # @return              The HSL representation
  # </pre>
  @rgbToHSL: (r, g, b) ->
    r /= 255
    g /= 255
    b /= 255

    max = Math.max r, g, b
    min = Math.min r, g, b
    l = (max + min) / 2

    if max is min
      h = s = 0
    else
      d = max - min
      s = if l > 0.5 then d / (2 - max - min) else d / (max + min)
      h = switch max
        when r then (g - b) / d + (if g < b then 6 else 0)
        when g then (b - r) / d + 2
        when b then (r - g) / d + 4
      
      h /= 6

    h: Util.round(h, 3), s: Util.round(s, 3), l: Util.round(l, 3)

  # Converts an HSL color value to RGB. Conversion formula
  # adapted from http://en.wikipedia.org/wiki/HSL_color_space.
  # Assumes h, s, and l are contained in the set [0, 1] and
  # returns r, g, and b in the set [0, 255].
  #
  # <pre>
  # @param   Number  h       The hue
  # @param   Number  s       The saturation
  # @param   Number  l       The lightness
  # @return  Array           The RGB representation
  # </pre>
  @hslToRGB: (h, s, l) ->
    if s is 0
      r = g = b = l
    else
      q = if l < 0.5 then l * (1 + s) else l + s - l * s
      p = 2 * l - q
      
      r = @hueToRGB p, q, h + 1/3
      g = @hueToRGB p, q, h
      b = @hueToRGB p, q, h - 1/3

    r *= 255
    g *= 255
    b *= 255

    r: Math.round(r), g: Math.round(g), b: Math.round(b)

  # Converts from the hue color space back to RGB
  @hueToRGB: (p, q, t) ->
    if t < 0 then t += 1
    if t > 1 then t -= 1
    if t < 1/6 then return p + (q - p) * 6 * t
    if t < 1/2 then return q
    if t < 2/3 then return p + (q - p) * (2/3 - t) * 6
    return p

  # Converts an RGB color value to HSV. Conversion formula
  # adapted from http://en.wikipedia.org/wiki/HSV_color_space.
  # Assumes r, g, and b are contained in the set [0, 255] and
  # returns h, s, and v in the set [0, 1].
  #
  # <pre>
  # @param   Number  r       The red color value
  # @param   Number  g       The green color value
  # @param   Number  b       The blue color value
  # @return  Array           The HSV representation
  # </pre>
  @rgbToHSV: (r, g, b) ->
    r /= 255
    g /= 255
    b /= 255

    max = Math.max r, g, b
    min = Math.min r, g, b
    v = max
    d = max - min

    s = if max is 0 then 0 else d / max

    if max is min
      h = 0
    else
      h = switch max
        when r then (g - b) / d + (if g < b then 6 else 0)
        when g then (b - r) / d + 2
        when b then (r - g) / d + 4

      h /= 6

    h: h, s: s, v: v

  # Converts an HSV color value to RGB. Conversion formula
  # adapted from http://en.wikipedia.org/wiki/HSV_color_space.
  # Assumes h, s, and v are contained in the set [0, 1] and
  # returns r, g, and b in the set [0, 255].
  #
  # <pre>
  # @param   Number  h       The hue
  # @param   Number  s       The saturation
  # @param   Number  v       The value
  # @return  Array           The RGB representation
  # </pre>
  @hsvToRGB: (h, s, v) ->
    i = Math.floor h * 6
    f = h * 6 - i
    p = v * (1 - s)
    q = v * (1 - f * s)
    t = v * (1 - (1 - f) * s)

    switch i % 6
      when 0
        r = v
        g = t
        b = p
      when 1
        r = q
        g = v
        b = p
      when 2
        r = p
        g = v
        b = t
      when 3
        r = p
        g = q
        b = v
      when 4
        r = t
        g = p
        b = v
      when 5
        r = v
        g = p
        b = q

    Util.clamp {r: r * 255, g: g * 255, b: b * 255}, 0, 255

  # Converts a RGB color value to the XYZ color space. Formulas
  # are based on http://en.wikipedia.org/wiki/SRGB assuming that
  # RGB values are sRGB.
  #
  # Assumes r, g, and b are contained in the set [0, 255] and
  # returns x, y, and z.
  #
  # <pre>
  # @param   Number  r       The red color value
  # @param   Number  g       The green color value
  # @param   Number  b       The blue color value
  # @return  Array           The XYZ representation
  # </pre>
  @rgbToXYZ: (r, g, b) ->
    r /= 255
    g /= 255
    b /= 255

    if r > 0.04045
      r = Math.pow((r + 0.055) / 1.055, 2.4)
    else
      r /= 12.92

    if g > 0.04045
      g = Math.pow((g + 0.055) / 1.055, 2.4)
    else
      g /= 12.92

    if b > 0.04045
      b = Math.pow((b + 0.055) / 1.055, 2.4)
    else
      b /= 12.92

    x = r * 0.4124 + g * 0.3576 + b * 0.1805;
    y = r * 0.2126 + g * 0.7152 + b * 0.0722;
    z = r * 0.0193 + g * 0.1192 + b * 0.9505;
  
    x: x * 100, y: y * 100, z: z * 100

  # Converts a XYZ color value to the sRGB color space. Formulas
  # are based on http://en.wikipedia.org/wiki/SRGB and the resulting
  # RGB value will be in the sRGB color space.
  # Assumes x, y and z values are whatever they are and returns
  # r, g and b in the set [0, 255].
  #
  # <pre>
  # @param   Number  x       The X value
  # @param   Number  y       The Y value
  # @param   Number  z       The Z value
  # @return  Array           The RGB representation
  # </pre>
  @xyzToRGB: (x, y, z) ->
    x /= 100
    y /= 100
    z /= 100

    r = (3.2406  * x) + (-1.5372 * y) + (-0.4986 * z)
    g = (-0.9689 * x) + (1.8758  * y) + (0.0415  * z)
    b = (0.0557  * x) + (-0.2040 * y) + (1.0570  * z)

    if r > 0.0031308
      r = (1.055 * Math.pow(r, 0.4166666667)) - 0.055
    else
      r *= 12.92

    if g > 0.0031308
      g = (1.055 * Math.pow(g, 0.4166666667)) - 0.055
    else
      g *= 12.92

    if b > 0.0031308
      b = (1.055 * Math.pow(b, 0.4166666667)) - 0.055
    else
      b *= 12.92

    Util.clamp {r: r * 255, g: g * 255, b: b * 255}, 0, 255

  # Converts a XYZ color value to the CIELAB color space. Formulas
  # are based on http://en.wikipedia.org/wiki/Lab_color_space
  # The reference white point used in the conversion is D65.
  # Assumes x, y and z values are whatever they are and returns
  # L*, a* and b* values
  #
  # <pre>
  # @param   Number  x       The X value
  # @param   Number  y       The Y value
  # @param   Number  z       The Z value
  # @return  Array           The Lab representation
  # </pre>
  @xyzToLab: (x, y, z) ->
    whiteX = 95.047
    whiteY = 100.0
    whiteZ = 108.883

    x /= whiteX
    y /= whiteY
    z /= whiteZ

    if x > 0.008856451679
      x = Math.pow(x, 0.3333333333)
    else
      x = (7.787037037 * x) + 0.1379310345
  
    if y > 0.008856451679
      y = Math.pow(y, 0.3333333333)
    else
      y = (7.787037037 * y) + 0.1379310345
  
    if z > 0.008856451679
      z = Math.pow(z, 0.3333333333)
    else
      z = (7.787037037 * z) + 0.1379310345

    l = 116 * y - 16
    a = 500 * (x - y)
    b = 200 * (y - z)

    l: l, a: a, b: b

  # Converts a L*, a*, b* color values from the CIELAB color space
  # to the XYZ color space. Formulas are based on
  # http://en.wikipedia.org/wiki/Lab_color_space
  #
  # The reference white point used in the conversion is D65.
  # Assumes L*, a* and b* values are whatever they are and returns
  # x, y and z values.
  #
  # <pre>
  # @param   Number  l       The L* value
  # @param   Number  a       The a* value
  # @param   Number  b       The b* value
  # @return  Array           The XYZ representation
  # </pre>
  @labToXYZ: (l, a, b) ->
    y = (l + 16) / 116
    x = y + (a / 500)
    z = y - (b / 200)

    if Math.pow(x, 3) > 0.008856
      x = Math.pow(x, 3)
    else
      x = (x - 16 / 116) / 7.787
  
    if Math.pow(y, 3) > 0.008856
      y = Math.pow(y, 3)
    else
      y = (y - 16 / 116) / 7.787
  
    if Math.pow(z, 3) > 0.008856
      z = Math.pow(z, 3)
    else
      z = (z - 16 / 116) / 7.787

    # D65 reference white point
    x: x * 95.047, y: y * 100.0, z: z * 108.883

  @labToRGB: (l, a, b) ->
    xyz = @labToXYZ(l, a, b)
    Util.clamp @xyzToRGB(xyz.x, xyz.y, xyz.z), 0, 255

  # Convers CMYK color to RGB. This is not quite as accurate as what
  # Photoshop actually uses, becasue Photoshop converts using LAB color,
  # which takes into consideration the monitor white point.
  @cmykToRGB: (c, m, y, k) ->
    r = (65535 - (c * (255 - k) + (k << 8))) >> 8
    g = (65535 - (m * (255 - k) + (k << 8))) >> 8
    b = (65535 - (y * (255 - k) + (k << 8))) >> 8

    Util.clamp {r: r, g: g, b: b}, 0, 255

  @rgbToColor: (r, g, b) -> @argbToColor(255, r, g, b)
  @argbToColor: (a, r, g, b) ->
    (alpha << 24) | (r << 16) | (g << 8) | b

  @hsbToColor: (h, s, b) -> @ahsbToColor 255, h, s, b
  @ahsbToColor: (alpha, hue, saturation, brightness) ->
    if saturation is 0
      b = g = r = 255 * brightness
    else
      if brightness <= 0.5
        m2 = brightness * (1 + saturation)
      else
        m2 = brightness + saturation - brightness * saturation

      m1 = 2 * brightness - m2
      r = @hueToColor hue + 120, m1, m2
      g = @hueToColor hue, m1, m2
      b = @hueToColor hue - 120, m1, m2

    @argbToColor alpha, r, g, b

  @hueToColor: (hue, m1, m2) ->
    hue %= 360
    if hue < 60
      v = m1 + (m2 - m1) * hue / 60
    else if hue < 180
      v = m2
    else if hue < 240
      v = m1 + (m2 - m1) * (240 - hue) / 60
    else
      v = m1

    v * 255

  @cmykToColor: (cyan, magenta, yellow, black) ->
    r = 1 - (cyan * (1 - black) + black) * 255
    g = 1 - (magenta * (1 - black) + black) * 255
    b = 1 - (yellow * (1- black) + black) * 255

    r = Util.clamp r, 0, 255
    g = Util.clamp g, 0, 255
    b = Util.clamp b, 0, 255

    @rgbToColor r, g, b

  @labToColor: (l, a, b) -> @alabToColor(255, l, a, b)
  @alabToColor: (alpha, lightness, a, b) ->
    xyz = @labToXYZ(lightness, a, b)
    @axyzToColor alpha, xyz.x, xyz.y, xyz.z

  @axyzToColor: (alpha, x, y, z) ->
    rgb = @xyzToRGB(x, y, z)
    @argbToColor alpha, rgb.r, rgb.g, rgb.b

  @colorSpaceToARGB: (colorSpace, colorComponent) ->
    switch colorSpace
      when 0
        dstColor = @rgbToColor colorComponent[0],
          colorComponent[1], colorComponent[2]
      when 1
        dstColor = @hsbToColor colorComponent[0],
          colorComponent[1] / 100.0, colorComponent[2] / 100.0
      when 2
        dstColor = @cmykToColor colorComponent[0] / 100.0,
          colorComponent[1] / 100.0, colorComponent[2] / 100.0,
          colorComponent[3] / 100.0
      when 7
        dstColor = @labToColor colorComponent[0],
          colorComponent[1], colorComponent[2]
      else
        dstColor = 0x00FFFFFF

    dstColor

module.exports = PSDColor