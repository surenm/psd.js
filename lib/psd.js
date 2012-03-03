(function() {
  /*!
 *  Copyright © 2008 Fair Oaks Labs, Inc.
 *  All rights reserved.
 */

// Utility object:  Encode/Decode C-style binary primitives to/from octet arrays
function JSPack()
{
  // Module-level (private) variables
  var el,  bBE = false, m = this;


  // Raw byte arrays
  m._DeArray = function (a, p, l)
  {
    return [a.slice(p,p+l)];
  };
  m._EnArray = function (a, p, l, v)
  {
    for (var i = 0; i < l; a[p+i] = v[i]?v[i]:0, i++);
  };

  // ASCII characters
  m._DeChar = function (a, p)
  {
    return String.fromCharCode(a[p]);
  };
  m._EnChar = function (a, p, v)
  {
    a[p] = v.charCodeAt(0);
  };

  // Little-endian (un)signed N-byte integers
  m._DeInt = function (a, p)
  {
    var lsb = bBE?(el.len-1):0, nsb = bBE?-1:1, stop = lsb+nsb*el.len, rv, i, f;
    for (rv = 0, i = lsb, f = 1; i != stop; rv+=(a[p+i]*f), i+=nsb, f*=256);
    if (el.bSigned && (rv & Math.pow(2, el.len*8-1))) { rv -= Math.pow(2, el.len*8); }
    return rv;
  };
  m._EnInt = function (a, p, v)
  {
    var lsb = bBE?(el.len-1):0, nsb = bBE?-1:1, stop = lsb+nsb*el.len, i;
    v = (v<el.min)?el.min:(v>el.max)?el.max:v;
    for (i = lsb; i != stop; a[p+i]=v&0xff, i+=nsb, v>>=8);
  };

  // ASCII character strings
  m._DeString = function (a, p, l)
  {
    for (var rv = new Array(l), i = 0; i < l; rv[i] = String.fromCharCode(a[p+i]), i++);
    return rv.join('');
  };
  m._EnString = function (a, p, l, v)
  {
    for (var t, i = 0; i < l; a[p+i] = (t=v.charCodeAt(i))?t:0, i++);
  };

  // Little-endian N-bit IEEE 754 floating point
  m._De754 = function (a, p)
  {
    var s, e, m, i, d, nBits, mLen, eLen, eBias, eMax;
    mLen = el.mLen, eLen = el.len*8-el.mLen-1, eMax = (1<<eLen)-1, eBias = eMax>>1;

    i = bBE?0:(el.len-1); d = bBE?1:-1; s = a[p+i]; i+=d; nBits = -7;
    for (e = s&((1<<(-nBits))-1), s>>=(-nBits), nBits += eLen; nBits > 0; e=e*256+a[p+i], i+=d, nBits-=8);
    for (m = e&((1<<(-nBits))-1), e>>=(-nBits), nBits += mLen; nBits > 0; m=m*256+a[p+i], i+=d, nBits-=8);

    switch (e)
    {
      case 0:
        // Zero, or denormalized number
        e = 1-eBias;
        break;
      case eMax:
        // NaN, or +/-Infinity
        return m?NaN:((s?-1:1)*Infinity);
      default:
        // Normalized number
        m = m + Math.pow(2, mLen);
        e = e - eBias;
        break;
    }
    return (s?-1:1) * m * Math.pow(2, e-mLen);
  };
  m._En754 = function (a, p, v)
  {
    var s, e, m, i, d, c, mLen, eLen, eBias, eMax;
    mLen = el.mLen, eLen = el.len*8-el.mLen-1, eMax = (1<<eLen)-1, eBias = eMax>>1;

    s = v<0?1:0;
    v = Math.abs(v);
    if (isNaN(v) || (v == Infinity))
    {
      m = isNaN(v)?1:0;
      e = eMax;
    }
    else
    {
      e = Math.floor(Math.log(v)/Math.LN2);     // Calculate log2 of the value
      if (v*(c = Math.pow(2, -e)) < 1) { e--; c*=2; }   // Math.log() isn't 100% reliable

      // Round by adding 1/2 the significand's LSD
      if (e+eBias >= 1) { v += el.rt/c; }     // Normalized:  mLen significand digits
      else { v += el.rt*Math.pow(2, 1-eBias); }     // Denormalized:  <= mLen significand digits
      if (v*c >= 2) { e++; c/=2; }        // Rounding can increment the exponent

      if (e+eBias >= eMax)
      {
        // Overflow
        m = 0;
        e = eMax;
      }
      else if (e+eBias >= 1)
      {
        // Normalized - term order matters, as Math.pow(2, 52-e) and v*Math.pow(2, 52) can overflow
        m = (v*c-1)*Math.pow(2, mLen);
        e = e + eBias;
      }
      else
      {
        // Denormalized - also catches the '0' case, somewhat by chance
        m = v*Math.pow(2, eBias-1)*Math.pow(2, mLen);
        e = 0;
      }
    }

    for (i = bBE?(el.len-1):0, d=bBE?-1:1; mLen >= 8; a[p+i]=m&0xff, i+=d, m/=256, mLen-=8);
    for (e=(e<<mLen)|m, eLen+=mLen; eLen > 0; a[p+i]=e&0xff, i+=d, e/=256, eLen-=8);
    a[p+i-d] |= s*128;
  };


  // Class data
  m._sPattern = '(\\d+)?([AxcbBhHsfdiIlL])';
  m._lenLut = {'A':1, 'x':1, 'c':1, 'b':1, 'B':1, 'h':2, 'H':2, 's':1, 'f':4, 'd':8, 'i':4, 'I':4, 'l':4, 'L':4};
  m._elLut  = { 'A': {en:m._EnArray, de:m._DeArray},
        's': {en:m._EnString, de:m._DeString},
        'c': {en:m._EnChar, de:m._DeChar},
        'b': {en:m._EnInt, de:m._DeInt, len:1, bSigned:true, min:-Math.pow(2, 7), max:Math.pow(2, 7)-1},
        'B': {en:m._EnInt, de:m._DeInt, len:1, bSigned:false, min:0, max:Math.pow(2, 8)-1},
        'h': {en:m._EnInt, de:m._DeInt, len:2, bSigned:true, min:-Math.pow(2, 15), max:Math.pow(2, 15)-1},
        'H': {en:m._EnInt, de:m._DeInt, len:2, bSigned:false, min:0, max:Math.pow(2, 16)-1},
        'i': {en:m._EnInt, de:m._DeInt, len:4, bSigned:true, min:-Math.pow(2, 31), max:Math.pow(2, 31)-1},
        'I': {en:m._EnInt, de:m._DeInt, len:4, bSigned:false, min:0, max:Math.pow(2, 32)-1},
        'l': {en:m._EnInt, de:m._DeInt, len:4, bSigned:true, min:-Math.pow(2, 31), max:Math.pow(2, 31)-1},
        'L': {en:m._EnInt, de:m._DeInt, len:4, bSigned:false, min:0, max:Math.pow(2, 32)-1},
        'f': {en:m._En754, de:m._De754, len:4, mLen:23, rt:Math.pow(2, -24)-Math.pow(2, -77)},
        'd': {en:m._En754, de:m._De754, len:8, mLen:52, rt:0}};

  // Unpack a series of n elements of size s from array a at offset p with fxn
  m._UnpackSeries = function (n, s, a, p)
  {
    for (var fxn = el.de, rv = [], i = 0; i < n; rv.push(fxn(a, p+i*s)), i++);
    return rv;
  };

  // Pack a series of n elements of size s from array v at offset i to array a at offset p with fxn
  m._PackSeries = function (n, s, a, p, v, i)
  {
    for (var fxn = el.en, o = 0; o < n; fxn(a, p+o*s, v[i+o]), o++);
  };

  // Unpack the octet array a, beginning at offset p, according to the fmt string
  m.Unpack = function (fmt, a, p)
  {
    // Set the private bBE flag based on the format string - assume big-endianness
    bBE = (fmt.charAt(0) != '<');

    p = p?p:0;
    var re = new RegExp(this._sPattern, 'g'), m, n, s, rv = [];
    while (m = re.exec(fmt))
    {
      n = ((m[1]==undefined)||(m[1]==''))?1:parseInt(m[1]);
      s = this._lenLut[m[2]];
      if ((p + n*s) > a.length)
      {
        return undefined;
      }
      switch (m[2])
      {
        case 'A': case 's':
          rv.push(this._elLut[m[2]].de(a, p, n));
          break;
        case 'c': case 'b': case 'B': case 'h': case 'H':
        case 'i': case 'I': case 'l': case 'L': case 'f': case 'd':
          el = this._elLut[m[2]];
          rv.push(this._UnpackSeries(n, s, a, p));
          break;
      }
      p += n*s;
    }
    return Array.prototype.concat.apply([], rv);
  };

  // Pack the supplied values into the octet array a, beginning at offset p, according to the fmt string
  m.PackTo = function (fmt, a, p, values)
  {
    // Set the private bBE flag based on the format string - assume big-endianness
    bBE = (fmt.charAt(0) != '<');

    var re = new RegExp(this._sPattern, 'g'), m, n, s, i = 0, j;
    while (m = re.exec(fmt))
    {
      n = ((m[1]==undefined)||(m[1]==''))?1:parseInt(m[1]);
      s = this._lenLut[m[2]];
      if ((p + n*s) > a.length)
      {
        return false;
      }
      switch (m[2])
      {
        case 'A': case 's':
          if ((i + 1) > values.length) { return false; }
          this._elLut[m[2]].en(a, p, n, values[i]);
          i += 1;
          break;
        case 'c': case 'b': case 'B': case 'h': case 'H':
        case 'i': case 'I': case 'l': case 'L': case 'f': case 'd':
          el = this._elLut[m[2]];
          if ((i + n) > values.length) { return false; }
          this._PackSeries(n, s, a, p, values, i);
          i += n;
          break;
        case 'x':
          for (j = 0; j < n; j++) { a[p+j] = 0; }
          break;
      }
      p += n*s;
    }
    return a;
  };

  // Pack the supplied values into a new octet array, according to the fmt string
  m.Pack = function (fmt, values)
  {
    return this.PackTo(fmt, new Array(this.CalcLength(fmt)), 0, values);
  };

  // Determine the number of bytes represented by the format string
  m.CalcLength = function (fmt)
  {
    var re = new RegExp(this._sPattern, 'g'), m, sum = 0;
    while (m = re.exec(fmt))
    {
      sum += (((m[1]==undefined)||(m[1]==''))?1:parseInt(m[1])) * this._lenLut[m[2]];
    }
    return sum;
  };
};

var jspack = new JSPack(); ;
  function ord (string) {
    // http://kevin.vanzonneveld.net
    // +   original by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
    // +   bugfixed by: Onno Marsman
    // +   improved by: Brett Zamir (http://brett-zamir.me)
    // +   input by: incidence
    // *     example 1: ord('K');
    // *     returns 1: 75
    // *     example 2: ord('\uD800\uDC00'); // surrogate pair to create a single Unicode character
    // *     returns 2: 65536
    var str = string + '',
        code = str.charCodeAt(0);
    if (0xD800 <= code && code <= 0xDBFF) { // High surrogate (could change last hex to 0xDB7F to treat high private surrogates as single characters)
        var hi = code;
        if (str.length === 1) {
            return code; // This is just a high surrogate with no following low surrogate, so we return its value;
            // we could also throw an error as it is not a complete character, but someone may want to know
        }
        var low = str.charCodeAt(1);
        return ((hi - 0xD800) * 0x400) + (low - 0xDC00) + 0x10000;
    }
    if (0xDC00 <= code && code <= 0xDFFF) { // Low surrogate
        return code; // This is just a low surrogate with no preceding high surrogate, so we return its value;
        // we could also throw an error as it is not a complete character, but someone may want to know
    }
    return code;
}

function chr (codePt) {
    // http://kevin.vanzonneveld.net
    // +   original by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
    // +   improved by: Brett Zamir (http://brett-zamir.me)
    // *     example 1: chr(75);
    // *     returns 1: 'K'
    // *     example 1: chr(65536) === '\uD800\uDC00';
    // *     returns 1: true
    if (codePt > 0xFFFF) { // Create a four-byte string (length 2) since this code point is high
        //   enough for the UTF-16 encoding (JavaScript internal use), to
        //   require representation with two surrogates (reserved non-characters
        //   used for building other characters; the first is "high" and the next "low")
        codePt -= 0x10000;
        return String.fromCharCode(0xD800 + (codePt >> 10), 0xDC00 + (codePt & 0x3FF));
    }
    return String.fromCharCode(codePt);
};
  var arraySum;

arraySum = function(arr, from, to) {
  var i, sum;
  if (from == null) from = 0;
  if (to == null) to = arr.length - 1;
  sum = 0;
  for (i = from; from <= to ? i <= to : i >= to; from <= to ? i++ : i--) {
    sum += parseInt(arr[i], 10);
  }
  return sum;
};;
  /*
  END DEPENDENCIES
  */
  /*
  # PSD.js - A Photoshop file parser for browsers and NodeJS
  # https://github.com/meltingice/psd.js
  #
  # MIT LICENSE
  # Copyright (c) 2011 Ryan LeFevre
  # 
  # Permission is hereby granted, free of charge, to any person obtaining a copy of this 
  # software and associated documentation files (the "Software"), to deal in the Software 
  # without restriction, including without limitation the rights to use, copy, modify, merge, 
  # publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons 
  # to whom the Software is furnished to do so, subject to the following conditions:
  # 
  # The above copyright notice and this permission notice shall be included in all copies or 
  # substantial portions of the Software.
  # 
  # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING 
  # BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
  # NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
  # DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
  # OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  */
  var Log, PSD, PSDDropDownLayerEffect, PSDFile, PSDHeader, PSDImage, PSDLayer, PSDLayerEffect, PSDLayerEffectCommonStateInfo, PSDLayerMask, PSDResource, PSDTypeTool, Root, Util, fs,
    __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  if (typeof exports !== "undefined" && exports !== null) {
    Root = exports;
    fs = require('fs');
  } else {
    Root = window;
  }

  Root.PSD = PSD = (function() {

    PSD.DEBUG = false;

    PSD.fromFile = function(file, cb) {
      var data, reader;
      if (cb == null) cb = function() {};
      if (typeof exports !== "undefined" && exports !== null) {
        data = fs.readFileSync(file);
        return new PSD(data);
      } else {
        reader = new FileReader();
        reader.onload = function(f) {
          var bytes, psd;
          bytes = new Uint8Array(f.target.result);
          psd = new PSD(bytes);
          return cb(psd);
        };
        return reader.readAsArrayBuffer(file);
      }
    };

    PSD.fromURL = function(url, cb) {
      var xhr;
      if (cb == null) cb = function() {};
      xhr = new XMLHttpRequest;
      xhr.open("GET", url, true);
      xhr.responseType = "arraybuffer";
      xhr.onload = function() {
        var data, psd;
        data = new Uint8Array(xhr.response || xhr.mozResponseArrayBuffer);
        psd = new PSD(data);
        return cb(psd);
      };
      return xhr.send(null);
    };

    function PSD(data) {
      this.file = new PSDFile(data);
      this.header = null;
      this.resources = null;
      this.numLayers = 0;
      this.layers = null;
      this.images = null;
      this.image = null;
    }

    PSD.prototype.parse = function() {
      Log.debug("Beginning parsing");
      this.startTime = (new Date()).getTime();
      this.parseHeader();
      this.parseImageResources();
      this.parseLayersMasks();
      this.parseImageData();
      this.endTime = (new Date()).getTime();
      return Log.debug("Parsing finished in " + (this.endTime - this.startTime) + "ms");
    };

    PSD.prototype.parseHeader = function() {
      Log.debug("\n### Header ###");
      this.header = new PSDHeader(this.file);
      this.header.parse();
      return Log.debug(this.header);
    };

    PSD.prototype.parseImageResources = function(skip) {
      var n, resource;
      if (skip == null) skip = false;
      Log.debug("\n### Resources ###");
      this.resources = [];
      n = this.file.readf(">L")[0];
      if (skip) {
        Log.debug("Skipped!");
        return this.file.seek(n);
      }
      while (n > 0) {
        resource = new PSDResource(this.file);
        n -= resource.parse();
        this.resources.push(resource);
        Log.debug("Resource: ", resource);
      }
      if (n !== 0) {
        return Log.debug("Image resources overran expected size by " + (-n) + " bytes");
      }
    };

    PSD.prototype.parseLayersMasks = function(skip) {
      if (skip == null) skip = false;
      if (!this.header) this.parseHeader();
      if (!this.resources) this.parseImageResources(true);
      Log.debug("\n### Layers & Masks ###");
      this.layerMask = new PSDLayerMask(this.file, this.header);
      if (skip) {
        Log.debug("Skipped!");
        return this.layerMask.skip();
      } else {
        return this.layerMask.parse();
      }
    };

    PSD.prototype.parseImageData = function() {
      if (!this.header) this.parseHeader();
      if (!this.resources) this.parseImageResources(true);
      if (!this.layerMask) this.parseLayersMasks(true);
      this.image = new PSDImage(this.file, this.header);
      return this.image.parse();
    };

    PSD.prototype.toFile = function(filename, cb) {
      var Canvas, Image, canvas, context, i, imageData, pixelData, pxl, _len, _ref;
      if (cb == null) cb = function() {};
      if (!this.image) this.parseImageData();
      try {
        Canvas = require('canvas');
      } catch (e) {
        throw "Exporting PSDs to file requires the canvas library";
      }
      Image = Canvas.Image;
      canvas = new Canvas(this.header.cols, this.header.rows);
      context = canvas.getContext('2d');
      imageData = context.getImageData(0, 0, canvas.width, canvas.height);
      pixelData = imageData.data;
      _ref = this.image.toCanvasPixels();
      for (i = 0, _len = _ref.length; i < _len; i++) {
        pxl = _ref[i];
        pixelData[i] = pxl;
      }
      context.putImageData(imageData, 0, 0);
      return fs.writeFile(filename, canvas.toBuffer(), cb);
    };

    PSD.prototype.toCanvas = function(canvas, width, height) {
      var context, i, imageData, pixelData, pxl, _len, _ref;
      if (width == null) width = null;
      if (height == null) height = null;
      if (!this.image) this.parseImageData();
      if (width === null && height === null) {
        canvas.width = this.header.cols;
        canvas.height = this.header.rows;
      }
      context = canvas.getContext('2d');
      imageData = context.getImageData(0, 0, canvas.width, canvas.height);
      pixelData = imageData.data;
      _ref = this.image.toCanvasPixels();
      for (i = 0, _len = _ref.length; i < _len; i++) {
        pxl = _ref[i];
        pixelData[i] = pxl;
      }
      return context.putImageData(imageData, 0, 0);
    };

    PSD.prototype.toImage = function() {
      var canvas;
      canvas = document.createElement('canvas');
      this.toCanvas(canvas);
      return canvas.toDataURL("image/png");
    };

    return PSD;

  })();

  PSDFile = (function() {

    function PSDFile(data) {
      this.data = data;
      this.pos = 0;
    }

    PSDFile.prototype.tell = function() {
      return this.pos;
    };

    PSDFile.prototype.read = function(bytes) {
      var i, _results;
      _results = [];
      for (i = 0; 0 <= bytes ? i < bytes : i > bytes; 0 <= bytes ? i++ : i--) {
        _results.push(this.data[this.pos++]);
      }
      return _results;
    };

    PSDFile.prototype.seek = function(amount, rel) {
      if (rel == null) rel = true;
      if (rel) {
        return this.pos += amount;
      } else {
        return this.pos = amount;
      }
    };

    PSDFile.prototype.readUInt16 = function() {
      var b1, b2;
      b1 = this.data[this.pos++] << 8;
      b2 = this.data[this.pos++];
      return b1 | b2;
    };

    PSDFile.prototype.readInt = function() {
      return this.readf(">i")[0];
    };

    PSDFile.prototype.readUInt = function() {
      return this.readf(">I")[0];
    };

    PSDFile.prototype.readShortInt = function() {
      return this.readf(">h")[0];
    };

    PSDFile.prototype.readShortUInt = function() {
      return this.readf(">H")[0];
    };

    PSDFile.prototype.readLongInt = function() {
      return this.readf(">l")[0];
    };

    PSDFile.prototype.readLongUInt = function() {
      return this.readf(">L")[0];
    };

    PSDFile.prototype.readDouble = function() {
      return this.readf(">d")[0];
    };

    PSDFile.prototype.readBoolean = function() {
      return this.read(1)[0] !== 0;
    };

    PSDFile.prototype.readUnicodeString = function(strlen) {
      var charCode, i, str;
      if (strlen == null) strlen = null;
      str = "";
      if (!strlen) strlen = this.readUInt();
      for (i = 0; 0 <= strlen ? i < strlen : i > strlen; 0 <= strlen ? i++ : i--) {
        charCode = this.readShortUInt();
        if (charCode > 0) str += chr(Util.i16(charCode));
      }
      return str;
    };

    PSDFile.prototype.readDescriptorStructure = function() {
      var classID, descriptors, i, items, key, name;
      name = this.readUnicodeString();
      classID = this.readLengthWithString();
      items = this.readUInt();
      descriptors = {};
      for (i = 0; 0 <= items ? i < items : i > items; 0 <= items ? i++ : i--) {
        key = this.readLengthWithString().trim();
        descriptors[key] = this.readOsType();
      }
      return descriptors;
    };

    PSDFile.prototype.readString = function(length) {
      return this.readf(">" + length + "s")[0];
    };

    PSDFile.prototype.readLengthWithString = function(defaultLen) {
      var length, str;
      if (defaultLen == null) defaultLen = 4;
      length = this.read(1)[0];
      if (length === 0) {
        str = this.readString(defaultLen);
      } else {
        str = this.readString(length);
      }
      return str;
    };

    PSDFile.prototype.readOsType = function() {
      var i, length, listSize, num, osType, type, value;
      osType = this.readString(4);
      value = null;
      switch (osType) {
        case "TEXT":
          value = this.readUnicodeString();
          break;
        case "enum":
        case "Objc":
        case "GlbO":
          value = {
            typeID: this.readLengthWithString(),
            "enum": this.readLengthWithString()
          };
          break;
        case "VlLs":
          listSize = this.readUInt();
          value = [];
          for (i = 0; 0 <= listSize ? i < listSize : i > listSize; 0 <= listSize ? i++ : i--) {
            value.push(this.readOsType());
          }
          break;
        case "doub":
          value = this.readDouble();
          break;
        case "UntF":
          value = {
            type: this.readString(4),
            value: this.readDouble()
          };
          break;
        case "long":
          value = this.readUInt();
          break;
        case "bool":
          value = this.readBoolean();
          break;
        case "alis":
          length = this.readUInt();
          value = this.readString(length);
          break;
        case "obj":
          num = this.readUInt();
          for (i = 0; 0 <= num ? i < num : i > num; 0 <= num ? i++ : i--) {
            type = this.readString(4);
            switch (type) {
              case "prop":
                value = {
                  name: this.readUnicodeString(),
                  classID: this.readLengthWithString(),
                  keyID: this.readLengthWithString()
                };
                break;
              case "Clss":
                value = {
                  name: this.readUnicodeString(),
                  classID: this.readLengthWithString()
                };
                break;
              case "Enmr":
                value = {
                  name: this.readUnicodeString(),
                  classID: this.readLengthWithString(),
                  typeID: this.readLengthWithString(),
                  "enum": this.readLengthWithString()
                };
                break;
              case "rele":
                value = {
                  name: this.readUnicodeString(),
                  classID: this.readLengthWithString(),
                  offsetValue: this.readUInt()
                };
                break;
              case "Idnt":
              case "indx":
              case "name":
                value = null;
            }
          }
          break;
        case "tdta":
          length = this.readUInt();
          this.seek(length);
      }
      return {
        type: osType,
        value: value
      };
    };

    PSDFile.prototype.readBytesList = function(size) {
      return this.read(size);
    };

    PSDFile.prototype.readf = function(format) {
      return jspack.Unpack(format, this.read(jspack.CalcLength(format)));
    };

    PSDFile.prototype.skipBlock = function(desc) {
      var n;
      if (desc == null) desc = "unknown";
      n = this.readf('>L')[0];
      if (n) this.seek(n);
      return Log.debug("Skipped " + desc + " with " + n + " bytes");
    };

    return PSDFile;

  })();

  PSDHeader = (function() {
    var HEADER_SECTIONS, MODES;

    HEADER_SECTIONS = ["sig", "version", "r0", "r1", "r2", "r3", "r4", "r5", "channels", "rows", "cols", "depth", "mode"];

    MODES = {
      0: 'Bitmap',
      1: 'GrayScale',
      2: 'IndexedColor',
      3: 'RGBColor',
      4: 'CMYKColor',
      5: 'HSLColor',
      6: 'HSBColor',
      7: 'Multichannel',
      8: 'Duotone',
      9: 'LabColor',
      10: 'Gray16',
      11: 'RGB48',
      12: 'Lab48',
      13: 'CMYK64',
      14: 'DeepMultichannel',
      15: 'Duotone16'
    };

    function PSDHeader(file) {
      this.file = file;
    }

    PSDHeader.prototype.parse = function() {
      var data, section, _i, _len, _ref;
      data = this.file.readf(">4sH 6B HLLHH");
      for (_i = 0, _len = HEADER_SECTIONS.length; _i < _len; _i++) {
        section = HEADER_SECTIONS[_i];
        this[section] = data.shift();
      }
      this.size = [this.rows, this.cols];
      if (this.sig !== "8BPS") throw "Not a PSD signature: " + this.header['sig'];
      if (this.version !== 1) {
        throw "Can not handle PSD version " + this.header['version'];
      }
      if ((0 <= (_ref = this.mode) && _ref < 16)) {
        this.modename = MODES[this.mode];
      } else {
        this.modename = "(" + this.mode + ")";
      }
      this.colormodepos = this.file.pos;
      return this.file.skipBlock("color mode data");
    };

    return PSDHeader;

  })();

  PSDImage = (function() {
    var COMPRESSIONS;

    COMPRESSIONS = {
      0: 'Raw',
      1: 'RLE',
      2: 'ZIP',
      3: 'ZIPPrediction'
    };

    function PSDImage(file, header) {
      var x, _ref;
      this.file = file;
      this.header = header;
      this.width = this.header.cols;
      this.height = this.header.rows;
      this.length = (function() {
        switch (this.header.depth) {
          case 1:
            return (this.width + 7) / 8 * this.height;
          case 16:
            return this.width * this.height * 2;
          default:
            return this.width * this.height;
        }
      }).call(this);
      this.channelLength = this.length;
      this.length *= this.header.channels;
      this.startPos = this.file.tell();
      this.endPos = this.startPos + this.length;
      this.compression = this.file.readShortInt();
      this.channelData = [];
      for (x = 0, _ref = this.length; 0 <= _ref ? x < _ref : x > _ref; 0 <= _ref ? x++ : x--) {
        this.channelData.push(0);
      }
      this.pixelData = {
        r: [],
        g: [],
        b: [],
        a: []
      };
    }

    PSDImage.prototype.parse = function() {
      var _ref;
      if ((_ref = this.compression) === 2 || _ref === 3) {
        throw "Image with ZIP compression. Don't know how to parse this. Giving up.";
      } else {
        Log.debug("Image compression: id=" + this.compression + ", name=" + COMPRESSIONS[this.compression]);
        Log.debug("Image size: " + this.length + " (" + this.width + "x" + this.height + ")");
      }
      switch (this.compression) {
        case 0:
          return this.parseRaw.apply(this, Array.prototype.slice.call(arguments));
        case 1:
          return this.parseRLE.apply(this, Array.prototype.slice.call(arguments));
      }
    };

    PSDImage.prototype.parseRaw = function() {
      var i, _ref;
      Log.debug("Attempting to parse RAW encoded image...");
      for (i = 0, _ref = this.length; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
        this.channelData.push(this.file.read(1)[0]);
      }
      return this.processImageData();
    };

    PSDImage.prototype.parseRLE = function() {
      var byteCount, byteCounts, chanPos, data, i, j, len, lineIndex, start, val, z, _ref, _ref2, _ref3, _ref4;
      Log.debug("Attempting to parse RLE encoded image...");
      byteCounts = [];
      for (i = 0, _ref = this.header.channels; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
        for (j = 0, _ref2 = this.height; 0 <= _ref2 ? j < _ref2 : j > _ref2; 0 <= _ref2 ? j++ : j--) {
          byteCounts.push(this.file.readShortInt());
        }
      }
      Log.debug("Read byte counts. Current pos = " + (this.file.tell()) + ", Pixels = " + this.length);
      chanPos = 0;
      lineIndex = 0;
      for (i = 0, _ref3 = this.header.channels; 0 <= _ref3 ? i < _ref3 : i > _ref3; 0 <= _ref3 ? i++ : i--) {
        Log.debug("Parsing channel #" + i + ", Start = " + (this.file.tell()));
        for (j = 0, _ref4 = this.height; 0 <= _ref4 ? j < _ref4 : j > _ref4; 0 <= _ref4 ? j++ : j--) {
          byteCount = byteCounts[lineIndex++];
          start = this.file.tell();
          while (this.file.tell() < start + byteCount) {
            len = this.file.read(1)[0];
            if (len < 128) {
              len++;
              data = this.file.read(len);
              [].splice.apply(this.channelData, [chanPos, (chanPos + len) - chanPos].concat(data)), data;
              chanPos += len;
            } else if (len > 128) {
              len ^= 0xff;
              len += 2;
              val = this.file.read(1)[0];
              data = [];
              for (z = 0; 0 <= len ? z < len : z > len; 0 <= len ? z++ : z--) {
                data.push(val);
              }
              [].splice.apply(this.channelData, [chanPos, (chanPos + len) - chanPos].concat(data)), data;
              chanPos += len;
            }
          }
        }
      }
      return this.processImageData();
    };

    PSDImage.prototype.processImageData = function() {
      switch (this.header.mode) {
        case 1:
          if (this.header.depth === 8) this.combineGreyscale8Channel();
          if (this.header.depth === 16) return this.combineGreyscale16Channel();
          break;
        case 3:
          if (this.header.depth === 8) this.combineRGB8Channel();
          if (this.header.depth === 16) return this.combineRGB16Channel();
      }
    };

    PSDImage.prototype.combineGreyscale8Channel = function() {
      var alpha, grey, i, _ref, _ref2, _results, _results2;
      if (this.header.channels === 2) {
        _results = [];
        for (i = 0, _ref = this.width * this.height; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
          alpha = this.channelData[i];
          grey = this.channelData[this.channelLength + i];
          this.pixelData.r[i] = grey;
          this.pixelData.g[i] = grey;
          this.pixelData.b[i] = grey;
          _results.push(this.pixelData.a[i] = alpha);
        }
        return _results;
      } else {
        _results2 = [];
        for (i = 0, _ref2 = this.width * this.height; 0 <= _ref2 ? i < _ref2 : i > _ref2; 0 <= _ref2 ? i++ : i--) {
          this.pixelData.r[i] = this.channelData[i];
          this.pixelData.g[i] = this.channelData[i];
          this.pixelData.b[i] = this.channelData[i];
          _results2.push(this.pixelData.a[i] = 255);
        }
        return _results2;
      }
    };

    PSDImage.prototype.combineGreyscale16Channel = function() {
      var alpha, grey, i, _ref, _ref2, _results, _results2;
      if (this.header.channels === 2) {
        _results = [];
        for (i = 0, _ref = this.width * this.height; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
          alpha = this.channelData[i] >> 8;
          grey = this.channelData[this.channelLength + i] >> 8;
          this.pixelData.r[i] = grey;
          this.pixelData.g[i] = grey;
          this.pixelData.b[i] = grey;
          _results.push(this.pixelData.a[i] = alpha);
        }
        return _results;
      } else {
        _results2 = [];
        for (i = 0, _ref2 = this.width * this.height; 0 <= _ref2 ? i < _ref2 : i > _ref2; 0 <= _ref2 ? i++ : i--) {
          this.pixelData.r[i] = this.channelData[i];
          this.pixelData.g[i] = this.channelData[i];
          this.pixelData.b[i] = this.channelData[i];
          _results2.push(this.pixelData.a[i] = 255);
        }
        return _results2;
      }
    };

    PSDImage.prototype.combineRGB8Channel = function() {
      var i, _ref, _results;
      _results = [];
      for (i = 0, _ref = this.channelLength; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
        this.pixelData.r[i] = this.channelData[i];
        this.pixelData.g[i] = this.channelData[i + this.channelLength];
        this.pixelData.b[i] = this.channelData[i + (this.channelLength * 2)];
        if (this.header.channels === 4) {
          _results.push(this.pixelData.a[i] = this.channelData[i + (this.channelLength * 3)]);
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    PSDImage.prototype.combineRGB16Channel = function() {
      var i, _ref, _results;
      _results = [];
      for (i = 0, _ref = this.channelLength; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
        this.pixelData.r[i] = this.channelData[i] >> 8;
        this.pixelData.g[i] = this.channelData[i + this.channelLength] >> 8;
        this.pixelData.b[i] = this.channelData[i + (this.channelLength * 2)] >> 8;
        if (this.header.channels === 4) {
          _results.push(this.pixelData.a[i] = this.channelData[i + (this.channelLength * 3)] >> 8);
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    PSDImage.prototype.toCanvasPixels = function() {
      var alpha, i, result, _ref;
      result = [];
      for (i = 0, _ref = this.pixelData.r.length; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
        alpha = this.pixelData.a[i];
        if (alpha == null) alpha = 255;
        result.push(this.pixelData.r[i], this.pixelData.g[i], this.pixelData.b[i], alpha);
      }
      return result;
    };

    return PSDImage;

  })();

  PSDLayer = (function() {
    var BLEND_FLAGS, BLEND_MODES, CHANNEL_SUFFIXES, MASK_FLAGS, SAFE_FONTS, SECTION_DIVIDER_TYPES;

    CHANNEL_SUFFIXES = {
      '-2': 'layer mask',
      '-1': 'A',
      0: 'R',
      1: 'G',
      2: 'B',
      3: 'RGB',
      4: 'CMYK',
      5: 'HSL',
      6: 'HSB',
      9: 'Lab',
      11: 'RGB',
      12: 'Lab',
      13: 'CMYK'
    };

    SECTION_DIVIDER_TYPES = {
      0: "other",
      1: "open folder",
      2: "closed folder",
      3: "bounding section divider"
    };

    BLEND_MODES = {
      "norm": "normal",
      "dark": "darken",
      "lite": "lighten",
      "hue": "hue",
      "sat": "saturation",
      "colr": "color",
      "lum": "luminosity",
      "mul": "multiply",
      "scrn": "screen",
      "diss": "dissolve",
      "over": "overlay",
      "hLit": "hard light",
      "sLit": "soft light",
      "diff": "difference",
      "smud": "exclusion",
      "div": "color dodge",
      "idiv": "color burn",
      "lbrn": "linear burn",
      "lddg": "linear dodge",
      "vLit": "vivid light",
      "lLit": "linear light",
      "pLit": "pin light",
      "hMix": "hard mix"
    };

    BLEND_FLAGS = {
      0: "transparency protected",
      1: "visible",
      2: "obsolete",
      3: "bit 4 useful",
      4: "pixel data irrelevant"
    };

    MASK_FLAGS = {
      0: "position relative",
      1: "layer mask disabled",
      2: "invert layer mask"
    };

    SAFE_FONTS = ["Arial", "Courier New", "Georgia", "Times New Roman", "Verdana", "Trebuchet MS", "Lucida Sans", "Tahoma"];

    function PSDLayer(file, header) {
      this.file = file;
      this.header = header != null ? header : null;
      this.images = [];
      this.mask = {};
      this.blendingRanges = {};
      this.effects = [];
    }

    PSDLayer.prototype.parse = function(layerIndex) {
      var extralen, extrastart, namelen, result;
      if (layerIndex == null) layerIndex = null;
      this.parseInfo(layerIndex);
      this.parseBlendModes();
      extralen = this.file.readUInt();
      this.layerEnd = this.file.tell() + extralen;
      extrastart = this.file.tell();
      result = this.parseMaskData();
      if (!result) {
        throw "Error parsing mask data for layer #" + this.idx + ". Quitting";
      }
      this.parseBlendingRanges();
      namelen = Util.pad4(this.file.read(1)[0]);
      this.name = this.file.readString(namelen);
      Log.debug("Layer name: " + this.name);
      this.parseExtraData();
      if (this.file.tell() !== this.layerEnd) {
        throw "Error parsing layer - unexpected end";
      }
    };

    PSDLayer.prototype.parseInfo = function(layerIndex) {
      var channelID, channelLength, i, _ref, _ref2, _ref3, _ref4, _results;
      this.idx = layerIndex;
      /*
          Layer Info
      */
      _ref = this.file.readf(">LLLLH"), this.top = _ref[0], this.left = _ref[1], this.bottom = _ref[2], this.right = _ref[3], this.channels = _ref[4];
      _ref2 = [this.bottom - this.top, this.right - this.left], this.rows = _ref2[0], this.cols = _ref2[1];
      Log.debug("Layer " + this.idx + ":", this);
      if (this.bottom < this.top || this.right < this.left || this.channels > 64) {
        Log.debug("Somethings not right, attempting to skip layer.");
        this.file.seek(6 * this.channels + 12);
        this.file.skipBlock("layer info: extra data");
        return;
      }
      this.channelsInfo = [];
      _results = [];
      for (i = 0, _ref3 = this.channels; 0 <= _ref3 ? i < _ref3 : i > _ref3; 0 <= _ref3 ? i++ : i--) {
        _ref4 = this.file.readf(">hL"), channelID = _ref4[0], channelLength = _ref4[1];
        Log.debug("Channel " + i + ": id=" + channelID + ", " + channelLength + " bytes, type=" + CHANNEL_SUFFIXES[channelID]);
        _results.push(this.channelsInfo.push([channelID, channelLength]));
      }
      return _results;
    };

    PSDLayer.prototype.parseBlendModes = function() {
      var _ref;
      this.blendMode = {};
      _ref = this.file.readf(">4s4sBBBB"), this.blendMode.sig = _ref[0], this.blendMode.key = _ref[1], this.blendMode.opacity = _ref[2], this.blendMode.clipping = _ref[3], this.blendMode.flags = _ref[4], this.blendMode.filler = _ref[5];
      this.blendMode.key = this.blendMode.key.trim();
      this.blendMode.opacityPercentage = (this.blendMode.opacity * 100) / 255;
      this.blendMode.blender = BLEND_MODES[this.blendMode.key];
      return Log.debug("Blending mode:", this.blendMode);
    };

    PSDLayer.prototype.parseMaskData = function() {
      var _ref, _ref2, _ref3;
      this.mask.size = this.file.readUInt();
      if ((_ref = this.mask.size) !== 36 && _ref !== 20 && _ref !== 0) {
        return false;
      }
      if (this.mask.size === 0) return true;
      _ref2 = this.file.readf(">LLLLBB"), this.mask.top = _ref2[0], this.mask.left = _ref2[1], this.mask.bottom = _ref2[2], this.mask.right = _ref2[3], this.mask.defaultColor = _ref2[4], this.mask.flags = _ref2[5];
      if (this.mask.size === 20) {
        this.file.seek(2);
      } else {
        _ref3 = this.file.readf(">BB"), this.mask.realFlags = _ref3[0], this.mask.realMaskBackground = _ref3[1];
      }
      this.file.seek(16);
      return true;
    };

    PSDLayer.prototype.parseBlendingRanges = function() {
      var length, pos;
      length = this.file.readUInt();
      this.blendingRanges.grey = {
        source: {
          black: this.file.readf(">BB"),
          white: this.file.readf(">BB")
        },
        dest: {
          black: this.file.readf(">BB"),
          white: this.file.readf(">BB")
        }
      };
      pos = this.file.tell();
      this.blendingRanges.channels = [];
      while (this.file.tell() < pos + length - 8) {
        this.blendingRanges.channels.push({
          source: this.file.readf(">BB"),
          dest: this.file.readf(">BB")
        });
      }
      return Log.debug("Blending ranges:", this.blendingRanges);
    };

    PSDLayer.prototype.parseExtraData = function() {
      var key, length, pos, signature, _ref, _results;
      _results = [];
      while (this.file.tell() < this.layerEnd) {
        _ref = this.file.readf(">4s4s"), signature = _ref[0], key = _ref[1];
        length = this.file.readUInt();
        pos = this.file.tell();
        Log.debug("Found additional layer info with key " + key + " and length " + length);
        switch (key) {
          case "lyid":
            this.layerId = this.file.readUInt();
            break;
          case "shmd":
            this.file.seek(length);
            break;
          case "lsct":
            this.readLayerSectionDivider();
            break;
          case "luni":
            this.file.seek(length);
            break;
          case "vmsk":
            this.file.seek(length);
            break;
          case "tySh":
            this.readTypeTool(true);
            break;
          case "lrFX":
            this.parseEffectsLayer();
            this.file.read(2);
            break;
          default:
            this.file.seek(length);
            Log.debug("Skipping additional layer info with key " + key);
        }
        if (this.file.tell() !== (pos + length)) {
          Log.debug("Error parsing additional layer info with key " + key + " - unexpected end");
          _results.push(this.file.seek(pos + length, false));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    PSDLayer.prototype.parseEffectsLayer = function() {
      var count, effect, left, pos, signature, size, type, v, _ref, _ref2, _results;
      _ref = this.file.readf(">HH"), v = _ref[0], count = _ref[1];
      _results = [];
      while (count-- > 0) {
        _ref2 = this.file.readf(">4s4s"), signature = _ref2[0], type = _ref2[1];
        size = this.file.readf(">i")[0];
        pos = this.file.tell();
        Log.debug("Parsing effect layer with type " + type + " and size " + size);
        effect = (function() {
          switch (type) {
            case "cmnS":
              return new PSDLayerEffectCommonStateInfo(this.file);
            case "dsdw":
              return new PSDDropDownLayerEffect(this.file);
            case "isdw":
              return new PSDDropDownLayerEffect(this.file, true);
          }
        }).call(this);
        if (effect != null) effect.parse();
        left = (pos + size) - this.file.tell();
        if (left !== 0) {
          Log.debug("Failed to parse effect layer with type " + type);
          _results.push(this.file.seek(left));
        } else {
          if (type !== "cmnS") {
            _results.push(this.effects.push(effect));
          } else {
            _results.push(void 0);
          }
        }
      }
      return _results;
    };

    PSDLayer.prototype.parseImageData = function() {
      var _results;
      _results = [];
      while (this.file.tell() < this.layerEnd) {
        this.compression = this.file.readShortInt();
        Log.debug("Image compression: id=" + this.compression.id + ", name=" + this.compression.name);
        this.image = new PSDImage(this.file, this.compression);
        _results.push(this.image.parse());
      }
      return _results;
    };

    PSDLayer.prototype.readMetadata = function() {
      var count, i, key, padding, sig, _ref, _results;
      Log.debug("Parsing layer metadata...");
      count = this.file.readUInt16();
      _results = [];
      for (i = 0; 0 <= count ? i < count : i > count; 0 <= count ? i++ : i--) {
        _ref = this.file.readf(">4s4s4s"), sig = _ref[0], key = _ref[1], padding = _ref[2];
        _results.push(this.file.skipBlock("image metadata"));
      }
      return _results;
    };

    PSDLayer.prototype.readLayerSectionDivider = function() {
      var code;
      code = this.file.readUInt16();
      return this.layerType = SECTION_DIVIDER_TYPES[code];
    };

    PSDLayer.prototype.readVectorMask = function() {
      var flags, version;
      version = this.file.readUInt();
      return flags = this.file.read(4);
    };

    PSDLayer.prototype.readTypeTool = function(legacy) {
      if (legacy == null) legacy = false;
      this.typeTool = new PSDTypeTool(this.file, legacy);
      return this.typeTool.parse();
    };

    PSDLayer.prototype.getSafeFont = function(font) {
      var it, safeFont, word, _i, _j, _len, _len2, _ref;
      for (_i = 0, _len = SAFE_FONTS.length; _i < _len; _i++) {
        safeFont = SAFE_FONTS[_i];
        it = true;
        _ref = safeFont.split(" ");
        for (_j = 0, _len2 = _ref.length; _j < _len2; _j++) {
          word = _ref[_j];
          if (!!!~font.indexOf(word)) it = false;
        }
        if (it) return safeFont;
      }
      return font;
    };

    PSDLayer.prototype.getImageData = function(readPlaneInfo, lineLengths) {
      var ch, channel, channelId, channelTuple, height, i, length, opacity, opacityDivider, result, width, _i, _len, _ref, _ref2;
      if (readPlaneInfo == null) readPlaneInfo = true;
      if (lineLengths == null) lineLengths = [];
      this.channels = {
        a: [],
        r: [],
        g: [],
        b: []
      };
      opacity = this.blendMode.opacityPercentage;
      opacityDivider = opacity / 255;
      _ref = this.channelsInfo;
      for (i in _ref) {
        if (!__hasProp.call(_ref, i)) continue;
        channelTuple = _ref[i];
        channelId = channelTuple[0], length = channelTuple[1];
        if (channelId < -1) {
          width = this.mask.cols;
          height = this.mask.rows;
        } else {
          width = this.cols;
          height = this.rows;
        }
        Log.debug("Reading channel " + channelId + " from layer " + this.name);
        channel = this.readColorPlane(readPlaneInfo, lineLengths, i, height, width);
        switch (channelId) {
          case -1:
            this.channels.a = [];
            for (_i = 0, _len = channel.length; _i < _len; _i++) {
              ch = channel[_i];
              this.channels.a.push((ch * opacityDivider) & 255);
            }
            break;
          case 0:
            this.channels.r = channel;
            break;
          case 1:
            this.channels.g = channel;
            break;
          case 2:
            this.channels.b = channel;
            break;
          default:
            result = [];
            for (i = 0, _ref2 = channel.length; 0 <= _ref2 ? i < _ref2 : i > _ref2; 0 <= _ref2 ? i++ : i--) {
              result.push(this.channels.a[i] * (channel[i] / 255));
            }
            this.channels.a = result;
        }
      }
      return this.makeImage();
    };

    PSDLayer.prototype.readColorPlane = function(readPlaneInfo, lineLengths, planeNum, height, width) {
      var a, compression, imageData, rleEncoded, size;
      size = width * height;
      imageData = [];
      rleEncoded = false;
      if (readPlaneInfo) {
        compression = this.file.readShortUInt();
        rleEncoded = compression === 1;
        if (rleEncoded) {
          lineLengths = [];
          for (a = 0; 0 <= height ? a < height : a > height; 0 <= height ? a++ : a--) {
            lineLengths.push(this.file.readShortInt());
          }
        } else {
          Log.debug("ERROR: compression not implemented yet. Skipping.");
        }
        planeNum = 0;
      } else {
        rleEncoded = lineLengths.length !== 0;
      }
      if (rleEncoded) {
        imageData = this.readPlaneCompressed(lineLengths, planeNum, height, width);
      } else {
        imageData = this.file.readBytesList(size);
      }
      return imageData;
    };

    PSDLayer.prototype.readPlaneCompressed = function(lineLengths, planeNum, height, width) {
      var b, i, len, lineIndex, pos, s, x, _ref, _ref2;
      b = [];
      for (x = 0, _ref = width * height; 0 <= _ref ? x < _ref : x > _ref; 0 <= _ref ? x++ : x--) {
        b.push(0);
      }
      s = [];
      pos = 0;
      lineIndex = planeNum * height;
      for (i = 0; 0 <= height ? i < height : i > height; 0 <= height ? i++ : i--) {
        len = lineLengths[lineIndex++];
        s = this.file.readBytesList(len);
        for (x = 0, _ref2 = width * 2 - len; 0 <= _ref2 ? x < _ref2 : x > _ref2; 0 <= _ref2 ? x++ : x--) {
          s.push(0);
        }
        this.decodeRLE(s, 0, len, b, pos);
        pos += width;
      }
      return b;
    };

    PSDLayer.prototype.decodeRLE = function(src, sindex, slen, dst, dindex) {
      var b, i, max, n, _ref, _results;
      max = sindex + slen;
      _results = [];
      while (sindex < max) {
        b = src[sindex];
        sindex++;
        n = b;
        if (b > 127) {
          n = 255 - n + 2;
          b = src[sindex];
          sindex++;
          _results.push((function() {
            var _results2;
            _results2 = [];
            for (i = 0; 0 <= n ? i < n : i > n; 0 <= n ? i++ : i--) {
              dst[dindex] = b;
              _results2.push(dindex++);
            }
            return _results2;
          })());
        } else {
          n++;
          [].splice.apply(dst, [dindex, (dindex + n) - dindex].concat(_ref = src.slice(sindex, (sindex + n)))), _ref;
          dindex += n;
          _results.push(sindex += n);
        }
      }
      return _results;
    };

    PSDLayer.prototype.makeImage = function() {
      var image, type;
      if (!(this.cols != null) || !(this.rows != null)) return;
      type = isNaN(this.channels.a[0]) ? "RGB" : "RGBA";
      image = new PSDImage(this.file, 0, {
        cols: this.cols,
        rows: this.rows
      }, this.cols * this.rows);
      image.pixelData = this.channels;
      Log.debug("Image: type=" + type + ", width=" + this.cols + ", height=" + this.rows);
      return this.images.push(image);
    };

    PSDLayer.prototype.isFolder = function() {
      return this.layerType === SECTION_DIVIDER_TYPES[1] || this.layerType === SECTION_DIVIDER_TYPES[2];
    };

    PSDLayer.prototype.isHidden = function() {
      return this.layerType === SECTION_DIVIDER_TYPES[3];
    };

    return PSDLayer;

  })();

  PSDLayerMask = (function() {

    function PSDLayerMask(file, header) {
      this.file = file;
      this.header = header;
      this.layers = [];
      this.mergedAlpha = false;
      this.globalMask = {};
      this.extras = [];
    }

    PSDLayerMask.prototype.skip = function() {
      return this.file.seek(this.file.readUInt());
    };

    PSDLayerMask.prototype.parse = function() {
      var endLoc, i, layer, layerInfoSize, maskSize, pos, _i, _len, _ref, _ref2;
      maskSize = this.file.readUInt();
      endLoc = this.file.tell() + maskSize;
      pos = this.file.tell();
      Log.debug("Layer mask size is " + maskSize);
      if (maskSize > 0) {
        layerInfoSize = Util.pad2(this.file.readUInt());
        if (layerInfoSize > 0) {
          this.numLayers = this.file.readShortInt();
          if (this.numLayers < 0) {
            Log.debug("Note: first alpha channel contains transparency data");
            this.numLayers = Math.abs(this.numLayers);
            this.mergedAlpha = true;
          }
          if (this.numLayers * (18 + 6 * this.header.channels) > layerInfoSize) {
            throw "Unlikely number of " + this.numLayers + " layers for " + this.header['channels'] + " with " + layerInfoSize + " layer info size. Giving up.";
          }
          Log.debug("Found " + this.numLayers + " layer(s)");
          for (i = 0, _ref = this.numLayers; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
            layer = new PSDLayer(this.file);
            layer.parse(i);
            this.layers.push(layer);
          }
          _ref2 = this.layers;
          for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
            layer = _ref2[_i];
            layer.getImageData(true);
          }
        }
      }
      this.file.seek(endLoc, false);
      return;
      this.parseGlobalMask();
      if (this.file.tell() < endLoc) return this.parseExtraInfo(endLoc);
    };

    PSDLayerMask.prototype.parseGlobalMask = function() {
      var end, length;
      length = this.file.readInt();
      end = this.file.tell() + length;
      Log.debug("Global mask length: " + length);
      this.globalMask.overlayColorSpace = this.file.read(2);
      this.globalMask.colorComponents = this.file.readf(">HHHH");
      this.globalMask.opacity = this.file.readShortUInt();
      this.globalMask.kind = this.file.read(1)[0];
      Log.debug("Global mask:", this.globalMask);
      return this.file.seek(end, false);
    };

    PSDLayerMask.prototype.parseExtraInfo = function(end) {
      var key, length, sig, _ref, _results;
      _results = [];
      while (this.file.tell() < end) {
        _ref = this.file.readf(">4s4sI"), sig = _ref[0], key = _ref[1], length = _ref[2];
        length = Util.pad2(length);
        Log.debug("Layer extra:", sig, key, length);
        _results.push(this.file.seek(length));
      }
      return _results;
    };

    PSDLayerMask.prototype.groupLayers = function() {
      var layer, parents, _i, _len, _ref, _results;
      parents = [];
      _ref = this.layers;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        layer = _ref[_i];
        layer.parent = parents[parents.length - 1] || null;
        layer.parents = parents.slice(1);
        if (layer.layerType.code === 0) continue;
        if (layer.layerType.code === 3 && parents.length > 0) {
          _results.push(delete parents[parents.length - 1]);
        } else {
          _results.push(parents.push(layer));
        }
      }
      return _results;
    };

    return PSDLayerMask;

  })();

  PSDLayerEffect = (function() {

    function PSDLayerEffect(file) {
      this.file = file;
    }

    PSDLayerEffect.prototype.parse = function() {
      var _ref;
      return _ref = this.file.readf(">i"), this.version = _ref[0], _ref;
    };

    PSDLayerEffect.prototype.getSpaceColor = function() {
      this.file.read(2);
      return this.file.readf(">HHHH");
    };

    return PSDLayerEffect;

  })();

  PSDLayerEffectCommonStateInfo = (function(_super) {

    __extends(PSDLayerEffectCommonStateInfo, _super);

    function PSDLayerEffectCommonStateInfo() {
      PSDLayerEffectCommonStateInfo.__super__.constructor.apply(this, arguments);
    }

    PSDLayerEffectCommonStateInfo.prototype.parse = function() {
      PSDLayerEffectCommonStateInfo.__super__.parse.call(this);
      this.visible = this.file.readBoolean();
      return this.file.read(2);
    };

    return PSDLayerEffectCommonStateInfo;

  })(PSDLayerEffect);

  PSDDropDownLayerEffect = (function(_super) {

    __extends(PSDDropDownLayerEffect, _super);

    function PSDDropDownLayerEffect(file, inner) {
      this.inner = inner != null ? inner : false;
      PSDDropDownLayerEffect.__super__.constructor.call(this, file);
      this.blendMode = "mul";
      this.color = this.nativeColor = [0, 0, 0, 0];
      this.opacity = 191;
      this.angle = 120;
      this.useGlobalLight = true;
      this.distance = 5;
      this.spread = 0;
      this.size = 5;
      this.antiAliased = false;
      this.knocksOut = false;
    }

    PSDDropDownLayerEffect.prototype.parse = function() {
      var _ref, _ref2;
      PSDDropDownLayerEffect.__super__.parse.call(this);
      _ref = this.file.readf(">hiii"), this.blur = _ref[0], this.intensity = _ref[1], this.angle = _ref[2], this.distance = _ref[3];
      this.file.read(2);
      this.color = this.getSpaceColor();
      _ref2 = this.file.readf(">4s4s"), this.signature = _ref2[0], this.blendMode = _ref2[1];
      this.enabled = this.file.readBoolean();
      this.useAngleInAllFX = this.file.readBoolean();
      this.opacity = this.file.read(1)[0];
      if (this.version === 2) return this.nativeColor = this.getSpaceColor();
    };

    return PSDDropDownLayerEffect;

  })(PSDLayerEffect);

  PSDResource = (function() {
    var RESOURCE_DESCRIPTIONS;

    RESOURCE_DESCRIPTIONS = {
      1000: {
        name: 'PS2.0 mode data',
        parse: function() {
          var _ref;
          return _ref = this.file.readf(">5H"), this.channels = _ref[0], this.rows = _ref[1], this.cols = _ref[2], this.depth = _ref[3], this.mode = _ref[4], _ref;
        }
      },
      1001: {
        name: 'Macintosh print record'
      },
      1003: {
        name: 'PS2.0 indexed color table'
      },
      1005: {
        name: 'ResolutionInfo'
      },
      1006: {
        name: 'Names of the alpha channels'
      },
      1007: {
        name: 'DisplayInfo'
      },
      1008: {
        name: 'Caption',
        parse: function() {
          return this.caption = this.file.readLengthWithString();
        }
      },
      1009: {
        name: 'Border information',
        parse: function() {
          var units, _ref;
          _ref = this.file.readf(">fH"), this.width = _ref[0], units = _ref[1];
          return this.units = (function() {
            switch (units) {
              case 1:
                return "inches";
              case 2:
                return "cm";
              case 3:
                return "points";
              case 4:
                return "picas";
              case 5:
                return "columns";
            }
          })();
        }
      },
      1010: {
        name: 'Background color'
      },
      1011: {
        name: 'Print flags',
        parse: function() {
          var start, _ref;
          start = this.file.tell();
          _ref = this.file.readf(">9B"), this.labels = _ref[0], this.cropMarks = _ref[1], this.colorBars = _ref[2], this.registrationMarks = _ref[3], this.negative = _ref[4], this.flip = _ref[5], this.interpolate = _ref[6], this.caption = _ref[7];
          return this.file.seek(start + this.size, false);
        }
      },
      1012: {
        name: 'Grayscale/multichannel halftoning info'
      },
      1013: {
        name: 'Color halftoning info'
      },
      1014: {
        name: 'Duotone halftoning info'
      },
      1015: {
        name: 'Grayscale/multichannel transfer function'
      },
      1016: {
        name: 'Color transfer functions'
      },
      1017: {
        name: 'Duotone transfer functions'
      },
      1018: {
        name: 'Duotone image info'
      },
      1019: {
        name: 'B&W values for the dot range',
        parse: function() {
          var _ref;
          return _ref = this.file.readf(">H"), this.bwvalues = _ref[0], _ref;
        }
      },
      1021: {
        name: 'EPS options'
      },
      1022: {
        name: 'Quick Mask info',
        parse: function() {
          var _ref;
          return _ref = this.file.readf(">HB"), this.quickMaskChannelID = _ref[0], this.wasMaskEmpty = _ref[1], _ref;
        }
      },
      1024: {
        name: 'Layer state info',
        parse: function() {
          var _ref;
          return _ref = this.file.readf(">H"), this.targetLayer = _ref[0], _ref;
        }
      },
      1025: {
        name: 'Working path'
      },
      1026: {
        name: 'Layers group info',
        parse: function() {
          var info, start, _results;
          start = this.file.tell();
          this.layerGroupInfo = [];
          _results = [];
          while (this.file.tell() < start + this.size) {
            info = this.file.readf(">H")[0];
            _results.push(this.layerGroupInfo.push(info));
          }
          return _results;
        }
      },
      1028: {
        name: 'IPTC-NAA record (File Info)'
      },
      1029: {
        name: 'Image mode for raw format files'
      },
      1030: {
        name: 'JPEG quality'
      },
      1032: {
        name: 'Grid and guides info'
      },
      1033: {
        name: 'Thumbnail resource'
      },
      1034: {
        name: 'Copyright flag',
        parse: function() {
          var _ref;
          return _ref = this.file.readf(">" + this.size + "B"), this.copyrighted = _ref[0], _ref;
        }
      },
      1035: {
        name: 'URL',
        parse: function() {
          var _ref;
          return _ref = this.file.readf(">" + this.size + "s"), this.url = _ref[0], _ref;
        }
      },
      1036: {
        name: 'Thumbnail resource'
      },
      1037: {
        name: 'Global Angle'
      },
      1038: {
        name: 'Color samplers resource'
      },
      1039: {
        name: 'ICC Profile'
      },
      1040: {
        name: 'Watermark',
        parse: function() {
          var _ref;
          return _ref = this.file.readf(">B"), this.watermarked = _ref[0], _ref;
        }
      },
      1041: {
        name: 'ICC Untagged',
        parse: function() {
          var _ref;
          return _ref = this.file.readf(">B"), this.disableProfile = _ref[0], _ref;
        }
      },
      1042: {
        name: 'Effects visible',
        parse: function() {
          var _ref;
          return _ref = this.file.readf(">B"), this.showEffects = _ref[0], _ref;
        }
      },
      1043: {
        name: 'Spot Halftone',
        parse: function() {
          [this.halftoneVersion, length](this.file.readf(">LL"));
          return this.halftoneData = this.file.read(length);
        }
      },
      1044: {
        name: 'Document specific IDs seed number',
        parse: function() {
          var _ref;
          return _ref = this.file.readf(">L"), this.docIdSeedNumber = _ref[0], _ref;
        }
      },
      1045: {
        name: 'Unicode Alpha Names'
      },
      1046: {
        name: 'Indexed Color Table Count',
        parse: function() {
          var _ref;
          return _ref = this.file.readf(">H"), this.indexedColorCount = _ref[0], _ref;
        }
      },
      1047: {
        name: 'Transparent Index',
        parse: function() {
          var _ref;
          return _ref = this.file.readf(">H"), this.transparencyIndex = _ref[0], _ref;
        }
      },
      1049: {
        name: 'Global Altitude',
        parse: function() {
          var _ref;
          return _ref = this.file.readf(">L"), this.globalAltitude = _ref[0], _ref;
        }
      },
      1050: {
        name: 'Slices'
      },
      1051: {
        name: 'Workflow URL',
        parse: function() {
          return this.workflowName = this.file.readLengthWithString();
        }
      },
      1052: {
        name: 'Jump To XPEP',
        parse: function() {
          var block, count, i, _ref, _results;
          _ref = this.file.readf(">HHL"), this.majorVersion = _ref[0], this.minorVersion = _ref[1], count = _ref[2];
          this.xpepBlocks = [];
          _results = [];
          for (i = 0; 0 <= count ? i < count : i > count; 0 <= count ? i++ : i--) {
            block = {
              size: this.file.readf(">L"),
              key: this.file.readf(">4s")
            };
            if (block.key === "jtDd") {
              block.dirty = this.file.readBoolean();
            } else {
              block.modDate = this.file.readf(">L");
            }
            _results.push(this.xpepBlocks.push(block));
          }
          return _results;
        }
      },
      1053: {
        name: 'Alpha Identifiers'
      },
      1054: {
        name: 'URL List'
      },
      1057: {
        name: 'Version Info'
      },
      1058: {
        name: 'EXIF data 1'
      },
      1059: {
        name: 'EXIF data 3'
      },
      1060: {
        name: 'XMP metadata'
      },
      1061: {
        name: 'Caption digest'
      },
      1062: {
        name: 'Print scale'
      },
      1064: {
        name: 'Pixel Aspect Ratio'
      },
      1065: {
        name: 'Layer Comps'
      },
      1066: {
        name: 'Alternate Duotone Colors'
      },
      1067: {
        name: 'Alternate Spot Colors'
      },
      1069: {
        name: 'Layer Selection ID(s)'
      },
      1070: {
        name: 'HDR Toning information'
      },
      1071: {
        name: "Print info"
      },
      1072: {
        name: "Layer Groups Enabled"
      },
      1073: {
        name: "Color samplers resource"
      },
      1074: {
        name: "Measurement Scale"
      },
      1075: {
        name: "Timeline Information"
      },
      1076: {
        name: "Sheet Disclosure"
      },
      1077: {
        name: "DisplayInfo"
      },
      1078: {
        name: "Onion Skins"
      },
      1080: {
        name: "Count Information"
      },
      1082: {
        name: "Print Information"
      },
      1083: {
        name: "Print Style"
      },
      1084: {
        name: "Macintosh NSPrintInfo"
      },
      1085: {
        name: "Windows DEVMODE"
      },
      2999: {
        name: 'Name of clipping path'
      },
      7000: {
        name: "Image Ready variables"
      },
      7001: {
        name: "Image Ready data sets"
      },
      8000: {
        name: "Lightroom workflow",
        parse: PSDResource.isLightroom = true
      },
      10000: {
        name: 'Print flags info',
        parse: function() {
          var padding, _ref;
          return _ref = this.file.readf(">HBBLH"), this.version = _ref[0], this.centerCropMarks = _ref[1], padding = _ref[2], this.bleedWidth = _ref[3], this.bleedWidthScale = _ref[4], _ref;
        }
      }
    };

    function PSDResource(file) {
      this.file = file;
    }

    PSDResource.prototype.parse = function() {
      var n, resource, _ref, _ref2, _ref3;
      this.at = this.file.tell();
      _ref = this.file.readf(">4s H B"), this.type = _ref[0], this.id = _ref[1], this.namelen = _ref[2];
      Log.debug("Resource #" + this.id + ": type=" + this.type);
      n = Util.pad2(this.namelen + 1) - 1;
      this.name = this.file.readf(">" + n + "s")[0];
      this.name = this.name.substr(0, this.name.length - 1);
      this.shortName = this.name.substr(0, 20);
      this.size = this.file.readf(">L")[0];
      this.size = Util.pad2(this.size);
      if ((2000 <= (_ref2 = this.id) && _ref2 <= 2997)) {
        this.rdesc = "[Path Information]";
        this.file.seek(this.size);
      } else if ((4000 <= (_ref3 = this.id) && _ref3 < 5000)) {
        this.rdesc = "[Plug-in Resource]";
        this.file.seek(this.size);
      } else if (RESOURCE_DESCRIPTIONS[this.id] != null) {
        resource = RESOURCE_DESCRIPTIONS[this.id];
        this.rdesc = "[" + resource.name + "]";
        if (resource.parse != null) {
          resource.parse.call(this);
        } else {
          this.file.seek(this.size);
        }
      }
      return 4 + 2 + Util.pad2(1 + this.namelen) + 4 + Util.pad2(this.size);
    };

    return PSDResource;

  })();

  PSDTypeTool = (function() {

    function PSDTypeTool(file, legacy) {
      this.file = file;
      this.legacy = legacy != null ? legacy : false;
    }

    PSDTypeTool.prototype.parse = function() {
      var color, descrVer, end, fontI, fontName, fontsList, i, j, lineHeight, piece, psDict, rectangle, safeFontName, st, start, style, styleRun, styledText, stylesList, stylesRunList, text, textData, textVer, transforms, ver, wrapData, wrapVer, _i, _len, _ref, _ref2;
      ver = this.file.readShortUInt();
      transforms = [];
      for (i = 0; i < 6; i++) {
        transforms.push(this.file.readDouble());
      }
      textVer = this.file.readShortUInt();
      descrVer = this.file.readUInt();
      if (ver !== 1 || textVer !== 50 || descrVer !== 16) return;
      textData = this.file.readDescriptorStructure();
      wrapVer = this.readShortUInt();
      descrVer = this.readUInt();
      wrapData = this.file.readDescriptorStructure();
      rectangle = [];
      for (i = 0; i < 4; i++) {
        rectangle.push(this.file.readDouble());
      }
      this.textData = textData;
      this.wrapData = wrapData;
      styledText = [];
      psDict = this.textData.EngineData.value;
      text = psDict.EngineDict.Editor.Text;
      styleRun = psDict.EngineDict.StyleRun;
      stylesList = styleRun.RunArray;
      stylesRunList = styleRun.RunLengthArray;
      fontsList = psDict.DocumentResources.FontSet;
      start = 0;
      for (i in stylesList) {
        if (!__hasProp.call(stylesList, i)) continue;
        style = stylesList[i];
        st = style.StyleSheet.StyleSheetData;
        end = parseInt(start + stylesRunList[i], 10);
        fontI = st.Font;
        fontName = fontsList[fontI].Name;
        safeFontName = this.getSafeFont(fontName);
        color = [];
        _ref = st.FillColor.Values.slice(1);
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          j = _ref[_i];
          color.push(255 * j);
        }
        lineHeight = st.Leading === 1500 ? "Auto" : st.Leading;
        piece = text.slice(start, end);
        styledText.push({
          text: piece,
          style: {
            font: safeFontName,
            size: st.FontSize,
            color: Util.rgbToHex("rgb(" + color[0] + ", " + color[1] + ", " + color[2] + ")"),
            underline: st.Underline,
            allCaps: st.FontCaps,
            italic: !!~fontName.indexOf("Italic") || st.FauxItalic,
            bold: !!~fontName.indexOf("Bold") || st.FauxBold,
            letterSpacing: st.Tracking / 20,
            lineHeight: lineHeight,
            paragraphEnds: (_ref2 = piece.substr(-1)) === "\n" || _ref2 === "\r"
          }
        });
        start += stylesRunList[i];
      }
      return this.styledText = styledText;
    };

    return PSDTypeTool;

  })();

  Util = (function() {

    function Util() {}

    Util.i16 = function(c) {
      return ord(c[1]) + (ord(c[0]) << 8);
    };

    Util.i32 = function(c) {
      return ord(c[3]) + (ord(c[2]) << 8) + (ord(c[1]) << 16) + (ord(c[0]) << 24);
    };

    Util.pad2 = function(i) {
      return Math.floor((i + 1) / 2) * 2;
    };

    Util.pad4 = function(i) {
      return (((i & 0xFF) + 1 + 3) & ~0x03) - 1;
    };

    Util.rgbToHex = function(c) {
      var m;
      m = /rgba?\((\d+), (\d+), (\d+)/.exec(c);
      if (m) {
        return '#' + (m[1] << 16 | m[2] << 8 | m[3]).toString(16);
      } else {
        return c;
      }
    };

    return Util;

  })();

  Log = (function() {

    function Log() {}

    Log.debug = Log.log = function() {
      return this.output("log", arguments);
    };

    Log.output = function(method, data) {
      if (typeof exports !== "undefined" && exports !== null) {
        if (PSD.DEBUG) return console[method].apply(null, data);
      } else {
        if (PSD.DEBUG) return console[method]("[PSD]", data);
      }
    };

    return Log;

  })();

}).call(this);
