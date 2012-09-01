# "Static" utility functions
class Util
  @pad2: (i) -> Math.floor((i + 1) / 2) * 2
  @pad4: (i) -> i - (i % 4) + 3

  @toUInt16: (b1, b2) -> (b1 << 8) | b2
  @toInt16: (b1, b2) ->
    val = @toUInt16(b1, b2)
    if val >= 0x8000 then val - 0x10000 else val

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

  # Contributed by https://github.com/jrus
  @decodeMacroman = do ->
    high_chars_unicode = '''
      \u00c4\u00c5\u00c7\u00c9\u00d1\u00d6\u00dc\u00e1
      \u00e0\u00e2\u00e4\u00e3\u00e5\u00e7\u00e9\u00e8
      \u00ea\u00eb\u00ed\u00ec\u00ee\u00ef\u00f1\u00f3
      \u00f2\u00f4\u00f6\u00f5\u00fa\u00f9\u00fb\u00fc
      \u2020\u00b0\u00a2\u00a3\u00a7\u2022\u00b6\u00df
      \u00ae\u00a9\u2122\u00b4\u00a8\u2260\u00c6\u00d8
      \u221e\u00b1\u2264\u2265\u00a5\u00b5\u2202\u2211
      \u220f\u03c0\u222b\u00aa\u00ba\u03a9\u00e6\u00f8
      \u00bf\u00a1\u00ac\u221a\u0192\u2248\u2206\u00ab
      \u00bb\u2026\u00a0\u00c0\u00c3\u00d5\u0152\u0153
      \u2013\u2014\u201c\u201d\u2018\u2019\u00f7\u25ca
      \u00ff\u0178\u2044\u20ac\u2039\u203a\ufb01\ufb02
      \u2021\u00b7\u201a\u201e\u2030\u00c2\u00ca\u00c1
      \u00cb\u00c8\u00cd\u00ce\u00cf\u00cc\u00d3\u00d4
      \uf8ff\u00d2\u00da\u00db\u00d9\u0131\u02c6\u02dc
      \u00af\u02d8\u02d9\u02da\u00b8\u02dd\u02db\u02c7
      '''.replace /\n/g, ''

    (byte_array) ->
      char_array = for byte, idx in byte_array
        if byte < 0x80 then String.fromCharCode byte
        else high_chars_unicode.charAt byte - 0x80
      char_array.join ''

module.exports = Util