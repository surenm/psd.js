(function() {
  /*
 Copyright (c) 2012 Gildas Lormeau. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright 
 notice, this list of conditions and the following disclaimer in 
 the documentation and/or other materials provided with the distribution.

 3. The names of the authors may not be used to endorse or promote products
 derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED ''AS IS'' AND ANY EXPRESSED OR IMPLIED WARRANTIES,
 INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL JCRAFT,
 INC. OR ANY CONTRIBUTORS TO THIS SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT,
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * This program is based on JZlib 1.0.2 ymnk, JCraft,Inc.
 * JZlib is based on zlib-1.1.3, so all credit should go authors
 * Jean-loup Gailly(jloup@gzip.org) and Mark Adler(madler@alumni.caltech.edu)
 * and contributors of zlib.
 */


// Global
var MAX_BITS = 15;

var Z_OK = 0;
var Z_STREAM_END = 1;
var Z_NEED_DICT = 2;
var Z_STREAM_ERROR = -2;
var Z_DATA_ERROR = -3;
var Z_MEM_ERROR = -4;
var Z_BUF_ERROR = -5;

var inflate_mask = [ 0x00000000, 0x00000001, 0x00000003, 0x00000007, 0x0000000f, 0x0000001f, 0x0000003f, 0x0000007f, 0x000000ff, 0x000001ff, 0x000003ff,
    0x000007ff, 0x00000fff, 0x00001fff, 0x00003fff, 0x00007fff, 0x0000ffff ];

var MANY = 1440;

var MAX_WBITS = 15; // 32K LZ77 window
var DEF_WBITS = MAX_WBITS;

// JZlib version : "1.0.2"
var Z_NO_FLUSH = 0;
var Z_FINISH = 4;

// InfTree
var fixed_bl = 9;
var fixed_bd = 5;

var fixed_tl = [ 96, 7, 256, 0, 8, 80, 0, 8, 16, 84, 8, 115, 82, 7, 31, 0, 8, 112, 0, 8, 48, 0, 9, 192, 80, 7, 10, 0, 8, 96, 0, 8, 32, 0, 9, 160, 0, 8, 0,
    0, 8, 128, 0, 8, 64, 0, 9, 224, 80, 7, 6, 0, 8, 88, 0, 8, 24, 0, 9, 144, 83, 7, 59, 0, 8, 120, 0, 8, 56, 0, 9, 208, 81, 7, 17, 0, 8, 104, 0, 8, 40,
    0, 9, 176, 0, 8, 8, 0, 8, 136, 0, 8, 72, 0, 9, 240, 80, 7, 4, 0, 8, 84, 0, 8, 20, 85, 8, 227, 83, 7, 43, 0, 8, 116, 0, 8, 52, 0, 9, 200, 81, 7, 13,
    0, 8, 100, 0, 8, 36, 0, 9, 168, 0, 8, 4, 0, 8, 132, 0, 8, 68, 0, 9, 232, 80, 7, 8, 0, 8, 92, 0, 8, 28, 0, 9, 152, 84, 7, 83, 0, 8, 124, 0, 8, 60,
    0, 9, 216, 82, 7, 23, 0, 8, 108, 0, 8, 44, 0, 9, 184, 0, 8, 12, 0, 8, 140, 0, 8, 76, 0, 9, 248, 80, 7, 3, 0, 8, 82, 0, 8, 18, 85, 8, 163, 83, 7,
    35, 0, 8, 114, 0, 8, 50, 0, 9, 196, 81, 7, 11, 0, 8, 98, 0, 8, 34, 0, 9, 164, 0, 8, 2, 0, 8, 130, 0, 8, 66, 0, 9, 228, 80, 7, 7, 0, 8, 90, 0, 8,
    26, 0, 9, 148, 84, 7, 67, 0, 8, 122, 0, 8, 58, 0, 9, 212, 82, 7, 19, 0, 8, 106, 0, 8, 42, 0, 9, 180, 0, 8, 10, 0, 8, 138, 0, 8, 74, 0, 9, 244, 80,
    7, 5, 0, 8, 86, 0, 8, 22, 192, 8, 0, 83, 7, 51, 0, 8, 118, 0, 8, 54, 0, 9, 204, 81, 7, 15, 0, 8, 102, 0, 8, 38, 0, 9, 172, 0, 8, 6, 0, 8, 134, 0,
    8, 70, 0, 9, 236, 80, 7, 9, 0, 8, 94, 0, 8, 30, 0, 9, 156, 84, 7, 99, 0, 8, 126, 0, 8, 62, 0, 9, 220, 82, 7, 27, 0, 8, 110, 0, 8, 46, 0, 9, 188, 0,
    8, 14, 0, 8, 142, 0, 8, 78, 0, 9, 252, 96, 7, 256, 0, 8, 81, 0, 8, 17, 85, 8, 131, 82, 7, 31, 0, 8, 113, 0, 8, 49, 0, 9, 194, 80, 7, 10, 0, 8, 97,
    0, 8, 33, 0, 9, 162, 0, 8, 1, 0, 8, 129, 0, 8, 65, 0, 9, 226, 80, 7, 6, 0, 8, 89, 0, 8, 25, 0, 9, 146, 83, 7, 59, 0, 8, 121, 0, 8, 57, 0, 9, 210,
    81, 7, 17, 0, 8, 105, 0, 8, 41, 0, 9, 178, 0, 8, 9, 0, 8, 137, 0, 8, 73, 0, 9, 242, 80, 7, 4, 0, 8, 85, 0, 8, 21, 80, 8, 258, 83, 7, 43, 0, 8, 117,
    0, 8, 53, 0, 9, 202, 81, 7, 13, 0, 8, 101, 0, 8, 37, 0, 9, 170, 0, 8, 5, 0, 8, 133, 0, 8, 69, 0, 9, 234, 80, 7, 8, 0, 8, 93, 0, 8, 29, 0, 9, 154,
    84, 7, 83, 0, 8, 125, 0, 8, 61, 0, 9, 218, 82, 7, 23, 0, 8, 109, 0, 8, 45, 0, 9, 186, 0, 8, 13, 0, 8, 141, 0, 8, 77, 0, 9, 250, 80, 7, 3, 0, 8, 83,
    0, 8, 19, 85, 8, 195, 83, 7, 35, 0, 8, 115, 0, 8, 51, 0, 9, 198, 81, 7, 11, 0, 8, 99, 0, 8, 35, 0, 9, 166, 0, 8, 3, 0, 8, 131, 0, 8, 67, 0, 9, 230,
    80, 7, 7, 0, 8, 91, 0, 8, 27, 0, 9, 150, 84, 7, 67, 0, 8, 123, 0, 8, 59, 0, 9, 214, 82, 7, 19, 0, 8, 107, 0, 8, 43, 0, 9, 182, 0, 8, 11, 0, 8, 139,
    0, 8, 75, 0, 9, 246, 80, 7, 5, 0, 8, 87, 0, 8, 23, 192, 8, 0, 83, 7, 51, 0, 8, 119, 0, 8, 55, 0, 9, 206, 81, 7, 15, 0, 8, 103, 0, 8, 39, 0, 9, 174,
    0, 8, 7, 0, 8, 135, 0, 8, 71, 0, 9, 238, 80, 7, 9, 0, 8, 95, 0, 8, 31, 0, 9, 158, 84, 7, 99, 0, 8, 127, 0, 8, 63, 0, 9, 222, 82, 7, 27, 0, 8, 111,
    0, 8, 47, 0, 9, 190, 0, 8, 15, 0, 8, 143, 0, 8, 79, 0, 9, 254, 96, 7, 256, 0, 8, 80, 0, 8, 16, 84, 8, 115, 82, 7, 31, 0, 8, 112, 0, 8, 48, 0, 9,
    193, 80, 7, 10, 0, 8, 96, 0, 8, 32, 0, 9, 161, 0, 8, 0, 0, 8, 128, 0, 8, 64, 0, 9, 225, 80, 7, 6, 0, 8, 88, 0, 8, 24, 0, 9, 145, 83, 7, 59, 0, 8,
    120, 0, 8, 56, 0, 9, 209, 81, 7, 17, 0, 8, 104, 0, 8, 40, 0, 9, 177, 0, 8, 8, 0, 8, 136, 0, 8, 72, 0, 9, 241, 80, 7, 4, 0, 8, 84, 0, 8, 20, 85, 8,
    227, 83, 7, 43, 0, 8, 116, 0, 8, 52, 0, 9, 201, 81, 7, 13, 0, 8, 100, 0, 8, 36, 0, 9, 169, 0, 8, 4, 0, 8, 132, 0, 8, 68, 0, 9, 233, 80, 7, 8, 0, 8,
    92, 0, 8, 28, 0, 9, 153, 84, 7, 83, 0, 8, 124, 0, 8, 60, 0, 9, 217, 82, 7, 23, 0, 8, 108, 0, 8, 44, 0, 9, 185, 0, 8, 12, 0, 8, 140, 0, 8, 76, 0, 9,
    249, 80, 7, 3, 0, 8, 82, 0, 8, 18, 85, 8, 163, 83, 7, 35, 0, 8, 114, 0, 8, 50, 0, 9, 197, 81, 7, 11, 0, 8, 98, 0, 8, 34, 0, 9, 165, 0, 8, 2, 0, 8,
    130, 0, 8, 66, 0, 9, 229, 80, 7, 7, 0, 8, 90, 0, 8, 26, 0, 9, 149, 84, 7, 67, 0, 8, 122, 0, 8, 58, 0, 9, 213, 82, 7, 19, 0, 8, 106, 0, 8, 42, 0, 9,
    181, 0, 8, 10, 0, 8, 138, 0, 8, 74, 0, 9, 245, 80, 7, 5, 0, 8, 86, 0, 8, 22, 192, 8, 0, 83, 7, 51, 0, 8, 118, 0, 8, 54, 0, 9, 205, 81, 7, 15, 0, 8,
    102, 0, 8, 38, 0, 9, 173, 0, 8, 6, 0, 8, 134, 0, 8, 70, 0, 9, 237, 80, 7, 9, 0, 8, 94, 0, 8, 30, 0, 9, 157, 84, 7, 99, 0, 8, 126, 0, 8, 62, 0, 9,
    221, 82, 7, 27, 0, 8, 110, 0, 8, 46, 0, 9, 189, 0, 8, 14, 0, 8, 142, 0, 8, 78, 0, 9, 253, 96, 7, 256, 0, 8, 81, 0, 8, 17, 85, 8, 131, 82, 7, 31, 0,
    8, 113, 0, 8, 49, 0, 9, 195, 80, 7, 10, 0, 8, 97, 0, 8, 33, 0, 9, 163, 0, 8, 1, 0, 8, 129, 0, 8, 65, 0, 9, 227, 80, 7, 6, 0, 8, 89, 0, 8, 25, 0, 9,
    147, 83, 7, 59, 0, 8, 121, 0, 8, 57, 0, 9, 211, 81, 7, 17, 0, 8, 105, 0, 8, 41, 0, 9, 179, 0, 8, 9, 0, 8, 137, 0, 8, 73, 0, 9, 243, 80, 7, 4, 0, 8,
    85, 0, 8, 21, 80, 8, 258, 83, 7, 43, 0, 8, 117, 0, 8, 53, 0, 9, 203, 81, 7, 13, 0, 8, 101, 0, 8, 37, 0, 9, 171, 0, 8, 5, 0, 8, 133, 0, 8, 69, 0, 9,
    235, 80, 7, 8, 0, 8, 93, 0, 8, 29, 0, 9, 155, 84, 7, 83, 0, 8, 125, 0, 8, 61, 0, 9, 219, 82, 7, 23, 0, 8, 109, 0, 8, 45, 0, 9, 187, 0, 8, 13, 0, 8,
    141, 0, 8, 77, 0, 9, 251, 80, 7, 3, 0, 8, 83, 0, 8, 19, 85, 8, 195, 83, 7, 35, 0, 8, 115, 0, 8, 51, 0, 9, 199, 81, 7, 11, 0, 8, 99, 0, 8, 35, 0, 9,
    167, 0, 8, 3, 0, 8, 131, 0, 8, 67, 0, 9, 231, 80, 7, 7, 0, 8, 91, 0, 8, 27, 0, 9, 151, 84, 7, 67, 0, 8, 123, 0, 8, 59, 0, 9, 215, 82, 7, 19, 0, 8,
    107, 0, 8, 43, 0, 9, 183, 0, 8, 11, 0, 8, 139, 0, 8, 75, 0, 9, 247, 80, 7, 5, 0, 8, 87, 0, 8, 23, 192, 8, 0, 83, 7, 51, 0, 8, 119, 0, 8, 55, 0, 9,
    207, 81, 7, 15, 0, 8, 103, 0, 8, 39, 0, 9, 175, 0, 8, 7, 0, 8, 135, 0, 8, 71, 0, 9, 239, 80, 7, 9, 0, 8, 95, 0, 8, 31, 0, 9, 159, 84, 7, 99, 0, 8,
    127, 0, 8, 63, 0, 9, 223, 82, 7, 27, 0, 8, 111, 0, 8, 47, 0, 9, 191, 0, 8, 15, 0, 8, 143, 0, 8, 79, 0, 9, 255 ];
var fixed_td = [ 80, 5, 1, 87, 5, 257, 83, 5, 17, 91, 5, 4097, 81, 5, 5, 89, 5, 1025, 85, 5, 65, 93, 5, 16385, 80, 5, 3, 88, 5, 513, 84, 5, 33, 92, 5,
    8193, 82, 5, 9, 90, 5, 2049, 86, 5, 129, 192, 5, 24577, 80, 5, 2, 87, 5, 385, 83, 5, 25, 91, 5, 6145, 81, 5, 7, 89, 5, 1537, 85, 5, 97, 93, 5,
    24577, 80, 5, 4, 88, 5, 769, 84, 5, 49, 92, 5, 12289, 82, 5, 13, 90, 5, 3073, 86, 5, 193, 192, 5, 24577 ];

// Tables for deflate from PKZIP's appnote.txt.
var cplens = [ // Copy lengths for literal codes 257..285
3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258, 0, 0 ];

// see note #13 above about 258
var cplext = [ // Extra bits for literal codes 257..285
0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0, 112, 112 // 112==invalid
];

var cpdist = [ // Copy offsets for distance codes 0..29
1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 ];

var cpdext = [ // Extra bits for distance codes
0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 ];

// If BMAX needs to be larger than 16, then h and x[] should be uLong.
var BMAX = 15; // maximum bit length of any code

function InfTree() {
  var that = this;

  var hn; // hufts used in space
  var v; // work area for huft_build
  var c; // bit length count table
  var r; // table entry for structure assignment
  var u; // table stack
  var x; // bit offsets, then code stack

  function huft_build(b, // code lengths in bits (all assumed <=
  // BMAX)
  bindex, n, // number of codes (assumed <= 288)
  s, // number of simple-valued codes (0..s-1)
  d, // list of base values for non-simple codes
  e, // list of extra bits for non-simple codes
  t, // result: starting table
  m, // maximum lookup bits, returns actual
  hp,// space for trees
  hn,// hufts used in space
  v // working area: values in order of bit length
  ) {
    // Given a list of code lengths and a maximum table size, make a set of
    // tables to decode that set of codes. Return Z_OK on success,
    // Z_BUF_ERROR
    // if the given code set is incomplete (the tables are still built in
    // this
    // case), Z_DATA_ERROR if the input is invalid (an over-subscribed set
    // of
    // lengths), or Z_MEM_ERROR if not enough memory.

    var a; // counter for codes of length k
    var f; // i repeats in table every f entries
    var g; // maximum code length
    var h; // table level
    var i; // counter, current code
    var j; // counter
    var k; // number of bits in current code
    var l; // bits per table (returned in m)
    var mask; // (1 << w) - 1, to avoid cc -O bug on HP
    var p; // pointer into c[], b[], or v[]
    var q; // points to current table
    var w; // bits before this table == (l * h)
    var xp; // pointer into x
    var y; // number of dummy codes added
    var z; // number of entries in current table

    // Generate counts for each bit length

    p = 0;
    i = n;
    do {
      c[b[bindex + p]]++;
      p++;
      i--; // assume all entries <= BMAX
    } while (i !== 0);

    if (c[0] == n) { // null input--all zero length codes
      t[0] = -1;
      m[0] = 0;
      return Z_OK;
    }

    // Find minimum and maximum length, bound *m by those
    l = m[0];
    for (j = 1; j <= BMAX; j++)
      if (c[j] !== 0)
        break;
    k = j; // minimum code length
    if (l < j) {
      l = j;
    }
    for (i = BMAX; i !== 0; i--) {
      if (c[i] !== 0)
        break;
    }
    g = i; // maximum code length
    if (l > i) {
      l = i;
    }
    m[0] = l;

    // Adjust last length count to fill out codes, if needed
    for (y = 1 << j; j < i; j++, y <<= 1) {
      if ((y -= c[j]) < 0) {
        return Z_DATA_ERROR;
      }
    }
    if ((y -= c[i]) < 0) {
      return Z_DATA_ERROR;
    }
    c[i] += y;

    // Generate starting offsets into the value table for each length
    x[1] = j = 0;
    p = 1;
    xp = 2;
    while (--i !== 0) { // note that i == g from above
      x[xp] = (j += c[p]);
      xp++;
      p++;
    }

    // Make a table of values in order of bit lengths
    i = 0;
    p = 0;
    do {
      if ((j = b[bindex + p]) !== 0) {
        v[x[j]++] = i;
      }
      p++;
    } while (++i < n);
    n = x[g]; // set n to length of v

    // Generate the Huffman codes and for each, make the table entries
    x[0] = i = 0; // first Huffman code is zero
    p = 0; // grab values in bit order
    h = -1; // no tables yet--level -1
    w = -l; // bits decoded == (l * h)
    u[0] = 0; // just to keep compilers happy
    q = 0; // ditto
    z = 0; // ditto

    // go through the bit lengths (k already is bits in shortest code)
    for (; k <= g; k++) {
      a = c[k];
      while (a-- !== 0) {
        // here i is the Huffman code of length k bits for value *p
        // make tables up to required level
        while (k > w + l) {
          h++;
          w += l; // previous table always l bits
          // compute minimum size table less than or equal to l bits
          z = g - w;
          z = (z > l) ? l : z; // table size upper limit
          if ((f = 1 << (j = k - w)) > a + 1) { // try a k-w bit table
            // too few codes for
            // k-w bit table
            f -= a + 1; // deduct codes from patterns left
            xp = k;
            if (j < z) {
              while (++j < z) { // try smaller tables up to z bits
                if ((f <<= 1) <= c[++xp])
                  break; // enough codes to use up j bits
                f -= c[xp]; // else deduct codes from patterns
              }
            }
          }
          z = 1 << j; // table entries for j-bit table

          // allocate new table
          if (hn[0] + z > MANY) { // (note: doesn't matter for fixed)
            return Z_DATA_ERROR; // overflow of MANY
          }
          u[h] = q = /* hp+ */hn[0]; // DEBUG
          hn[0] += z;

          // connect to last table, if there is one
          if (h !== 0) {
            x[h] = i; // save pattern for backing up
            r[0] = /* (byte) */j; // bits in this table
            r[1] = /* (byte) */l; // bits to dump before this table
            j = i >>> (w - l);
            r[2] = /* (int) */(q - u[h - 1] - j); // offset to this table
            hp.set(r, (u[h - 1] + j) * 3);
            // to
            // last
            // table
          } else {
            t[0] = q; // first table is returned result
          }
        }

        // set up table entry in r
        r[1] = /* (byte) */(k - w);
        if (p >= n) {
          r[0] = 128 + 64; // out of values--invalid code
        } else if (v[p] < s) {
          r[0] = /* (byte) */(v[p] < 256 ? 0 : 32 + 64); // 256 is
          // end-of-block
          r[2] = v[p++]; // simple code is just the value
        } else {
          r[0] = /* (byte) */(e[v[p] - s] + 16 + 64); // non-simple--look
          // up in lists
          r[2] = d[v[p++] - s];
        }

        // fill code-like entries with r
        f = 1 << (k - w);
        for (j = i >>> w; j < z; j += f) {
          hp.set(r, (q + j) * 3);
        }

        // backwards increment the k-bit code i
        for (j = 1 << (k - 1); (i & j) !== 0; j >>>= 1) {
          i ^= j;
        }
        i ^= j;

        // backup over finished tables
        mask = (1 << w) - 1; // needed on HP, cc -O bug
        while ((i & mask) != x[h]) {
          h--; // don't need to update q
          w -= l;
          mask = (1 << w) - 1;
        }
      }
    }
    // Return Z_BUF_ERROR if we were given an incomplete table
    return y !== 0 && g != 1 ? Z_BUF_ERROR : Z_OK;
  }

  function initWorkArea(vsize) {
    var i;
    if (!hn) {
      hn = []; // []; //new Array(1);
      v = []; // new Array(vsize);
      c = new Int32Array(BMAX + 1); // new Array(BMAX + 1);
      r = []; // new Array(3);
      u = new Int32Array(BMAX); // new Array(BMAX);
      x = new Int32Array(BMAX + 1); // new Array(BMAX + 1);
    }
    if (v.length < vsize) {
      v = []; // new Array(vsize);
    }
    for (i = 0; i < vsize; i++) {
      v[i] = 0;
    }
    for (i = 0; i < BMAX + 1; i++) {
      c[i] = 0;
    }
    for (i = 0; i < 3; i++) {
      r[i] = 0;
    }
    // for(int i=0; i<BMAX; i++){u[i]=0;}
    u.set(c.subarray(0, BMAX), 0);
    // for(int i=0; i<BMAX+1; i++){x[i]=0;}
    x.set(c.subarray(0, BMAX + 1), 0);
  }

  that.inflate_trees_bits = function(c, // 19 code lengths
  bb, // bits tree desired/actual depth
  tb, // bits tree result
  hp, // space for trees
  z // for messages
  ) {
    var result;
    initWorkArea(19);
    hn[0] = 0;
    result = huft_build(c, 0, 19, 19, null, null, tb, bb, hp, hn, v);

    if (result == Z_DATA_ERROR) {
      z.msg = "oversubscribed dynamic bit lengths tree";
    } else if (result == Z_BUF_ERROR || bb[0] === 0) {
      z.msg = "incomplete dynamic bit lengths tree";
      result = Z_DATA_ERROR;
    }
    return result;
  };

  that.inflate_trees_dynamic = function(nl, // number of literal/length codes
  nd, // number of distance codes
  c, // that many (total) code lengths
  bl, // literal desired/actual bit depth
  bd, // distance desired/actual bit depth
  tl, // literal/length tree result
  td, // distance tree result
  hp, // space for trees
  z // for messages
  ) {
    var result;

    // build literal/length tree
    initWorkArea(288);
    hn[0] = 0;
    result = huft_build(c, 0, nl, 257, cplens, cplext, tl, bl, hp, hn, v);
    if (result != Z_OK || bl[0] === 0) {
      if (result == Z_DATA_ERROR) {
        z.msg = "oversubscribed literal/length tree";
      } else if (result != Z_MEM_ERROR) {
        z.msg = "incomplete literal/length tree";
        result = Z_DATA_ERROR;
      }
      return result;
    }

    // build distance tree
    initWorkArea(288);
    result = huft_build(c, nl, nd, 0, cpdist, cpdext, td, bd, hp, hn, v);

    if (result != Z_OK || (bd[0] === 0 && nl > 257)) {
      if (result == Z_DATA_ERROR) {
        z.msg = "oversubscribed distance tree";
      } else if (result == Z_BUF_ERROR) {
        z.msg = "incomplete distance tree";
        result = Z_DATA_ERROR;
      } else if (result != Z_MEM_ERROR) {
        z.msg = "empty distance tree with lengths";
        result = Z_DATA_ERROR;
      }
      return result;
    }

    return Z_OK;
  };

}

InfTree.inflate_trees_fixed = function(bl, // literal desired/actual bit depth
bd, // distance desired/actual bit depth
tl,// literal/length tree result
td,// distance tree result
z // for memory allocation
) {
  bl[0] = fixed_bl;
  bd[0] = fixed_bd;
  tl[0] = fixed_tl;
  td[0] = fixed_td;
  return Z_OK;
};

// InfCodes

// waiting for "i:"=input,
// "o:"=output,
// "x:"=nothing
var START = 0; // x: set up for LEN
var LEN = 1; // i: get length/literal/eob next
var LENEXT = 2; // i: getting length extra (have base)
var DIST = 3; // i: get distance next
var DISTEXT = 4;// i: getting distance extra
var COPY = 5; // o: copying bytes in window, waiting
// for space
var LIT = 6; // o: got literal, waiting for output
// space
var WASH = 7; // o: got eob, possibly still output
// waiting
var END = 8; // x: got eob and all data flushed
var BADCODE = 9;// x: got error

function InfCodes() {
  var that = this;

  var mode; // current inflate_codes mode

  // mode dependent information
  var len = 0;

  var tree; // pointer into tree
  var tree_index = 0;
  var need = 0; // bits needed

  var lit = 0;

  // if EXT or COPY, where and how much
  var get = 0; // bits to get for extra
  var dist = 0; // distance back to copy from

  var lbits = 0; // ltree bits decoded per branch
  var dbits = 0; // dtree bits decoder per branch
  var ltree; // literal/length/eob tree
  var ltree_index = 0; // literal/length/eob tree
  var dtree; // distance tree
  var dtree_index = 0; // distance tree

  // Called with number of bytes left to write in window at least 258
  // (the maximum string length) and number of input bytes available
  // at least ten. The ten bytes are six bytes for the longest length/
  // distance pair plus four bytes for overloading the bit buffer.

  function inflate_fast(bl, bd, tl, tl_index, td, td_index, s, z) {
    var t; // temporary pointer
    var tp; // temporary pointer
    var tp_index; // temporary pointer
    var e; // extra bits or operation
    var b; // bit buffer
    var k; // bits in bit buffer
    var p; // input data pointer
    var n; // bytes available there
    var q; // output window write pointer
    var m; // bytes to end of window or read pointer
    var ml; // mask for literal/length tree
    var md; // mask for distance tree
    var c; // bytes to copy
    var d; // distance back to copy from
    var r; // copy source pointer

    var tp_index_t_3; // (tp_index+t)*3

    // load input, output, bit values
    p = z.next_in_index;
    n = z.avail_in;
    b = s.bitb;
    k = s.bitk;
    q = s.write;
    m = q < s.read ? s.read - q - 1 : s.end - q;

    // initialize masks
    ml = inflate_mask[bl];
    md = inflate_mask[bd];

    // do until not enough input or output space for fast loop
    do { // assume called with m >= 258 && n >= 10
      // get literal/length code
      while (k < (20)) { // max bits for literal/length code
        n--;
        b |= (z.read_byte(p++) & 0xff) << k;
        k += 8;
      }

      t = b & ml;
      tp = tl;
      tp_index = tl_index;
      tp_index_t_3 = (tp_index + t) * 3;
      if ((e = tp[tp_index_t_3]) === 0) {
        b >>= (tp[tp_index_t_3 + 1]);
        k -= (tp[tp_index_t_3 + 1]);

        s.window[q++] = /* (byte) */tp[tp_index_t_3 + 2];
        m--;
        continue;
      }
      do {

        b >>= (tp[tp_index_t_3 + 1]);
        k -= (tp[tp_index_t_3 + 1]);

        if ((e & 16) !== 0) {
          e &= 15;
          c = tp[tp_index_t_3 + 2] + (/* (int) */b & inflate_mask[e]);

          b >>= e;
          k -= e;

          // decode distance base of block to copy
          while (k < (15)) { // max bits for distance code
            n--;
            b |= (z.read_byte(p++) & 0xff) << k;
            k += 8;
          }

          t = b & md;
          tp = td;
          tp_index = td_index;
          tp_index_t_3 = (tp_index + t) * 3;
          e = tp[tp_index_t_3];

          do {

            b >>= (tp[tp_index_t_3 + 1]);
            k -= (tp[tp_index_t_3 + 1]);

            if ((e & 16) !== 0) {
              // get extra bits to add to distance base
              e &= 15;
              while (k < (e)) { // get extra bits (up to 13)
                n--;
                b |= (z.read_byte(p++) & 0xff) << k;
                k += 8;
              }

              d = tp[tp_index_t_3 + 2] + (b & inflate_mask[e]);

              b >>= (e);
              k -= (e);

              // do the copy
              m -= c;
              if (q >= d) { // offset before dest
                // just copy
                r = q - d;
                if (q - r > 0 && 2 > (q - r)) {
                  s.window[q++] = s.window[r++]; // minimum
                  // count is
                  // three,
                  s.window[q++] = s.window[r++]; // so unroll
                  // loop a
                  // little
                  c -= 2;
                } else {
                  s.window.set(s.window.subarray(r, r + 2), q);
                  q += 2;
                  r += 2;
                  c -= 2;
                }
              } else { // else offset after destination
                r = q - d;
                do {
                  r += s.end; // force pointer in window
                } while (r < 0); // covers invalid distances
                e = s.end - r;
                if (c > e) { // if source crosses,
                  c -= e; // wrapped copy
                  if (q - r > 0 && e > (q - r)) {
                    do {
                      s.window[q++] = s.window[r++];
                    } while (--e !== 0);
                  } else {
                    s.window.set(s.window.subarray(r, r + e), q);
                    q += e;
                    r += e;
                    e = 0;
                  }
                  r = 0; // copy rest from start of window
                }

              }

              // copy all or what's left
              if (q - r > 0 && c > (q - r)) {
                do {
                  s.window[q++] = s.window[r++];
                } while (--c !== 0);
              } else {
                s.window.set(s.window.subarray(r, r + c), q);
                q += c;
                r += c;
                c = 0;
              }
              break;
            } else if ((e & 64) === 0) {
              t += tp[tp_index_t_3 + 2];
              t += (b & inflate_mask[e]);
              tp_index_t_3 = (tp_index + t) * 3;
              e = tp[tp_index_t_3];
            } else {
              z.msg = "invalid distance code";

              c = z.avail_in - n;
              c = (k >> 3) < c ? k >> 3 : c;
              n += c;
              p -= c;
              k -= c << 3;

              s.bitb = b;
              s.bitk = k;
              z.avail_in = n;
              z.total_in += p - z.next_in_index;
              z.next_in_index = p;
              s.write = q;

              return Z_DATA_ERROR;
            }
          } while (true);
          break;
        }

        if ((e & 64) === 0) {
          t += tp[tp_index_t_3 + 2];
          t += (b & inflate_mask[e]);
          tp_index_t_3 = (tp_index + t) * 3;
          if ((e = tp[tp_index_t_3]) === 0) {

            b >>= (tp[tp_index_t_3 + 1]);
            k -= (tp[tp_index_t_3 + 1]);

            s.window[q++] = /* (byte) */tp[tp_index_t_3 + 2];
            m--;
            break;
          }
        } else if ((e & 32) !== 0) {

          c = z.avail_in - n;
          c = (k >> 3) < c ? k >> 3 : c;
          n += c;
          p -= c;
          k -= c << 3;

          s.bitb = b;
          s.bitk = k;
          z.avail_in = n;
          z.total_in += p - z.next_in_index;
          z.next_in_index = p;
          s.write = q;

          return Z_STREAM_END;
        } else {
          z.msg = "invalid literal/length code";

          c = z.avail_in - n;
          c = (k >> 3) < c ? k >> 3 : c;
          n += c;
          p -= c;
          k -= c << 3;

          s.bitb = b;
          s.bitk = k;
          z.avail_in = n;
          z.total_in += p - z.next_in_index;
          z.next_in_index = p;
          s.write = q;

          return Z_DATA_ERROR;
        }
      } while (true);
    } while (m >= 258 && n >= 10);

    // not enough input or output--restore pointers and return
    c = z.avail_in - n;
    c = (k >> 3) < c ? k >> 3 : c;
    n += c;
    p -= c;
    k -= c << 3;

    s.bitb = b;
    s.bitk = k;
    z.avail_in = n;
    z.total_in += p - z.next_in_index;
    z.next_in_index = p;
    s.write = q;

    return Z_OK;
  }

  that.init = function(bl, bd, tl, tl_index, td, td_index, z) {
    mode = START;
    lbits = /* (byte) */bl;
    dbits = /* (byte) */bd;
    ltree = tl;
    ltree_index = tl_index;
    dtree = td;
    dtree_index = td_index;
    tree = null;
  };

  that.proc = function(s, z, r) {
    var j; // temporary storage
    var t; // temporary pointer
    var tindex; // temporary pointer
    var e; // extra bits or operation
    var b = 0; // bit buffer
    var k = 0; // bits in bit buffer
    var p = 0; // input data pointer
    var n; // bytes available there
    var q; // output window write pointer
    var m; // bytes to end of window or read pointer
    var f; // pointer to copy strings from

    // copy input/output information to locals (UPDATE macro restores)
    p = z.next_in_index;
    n = z.avail_in;
    b = s.bitb;
    k = s.bitk;
    q = s.write;
    m = q < s.read ? s.read - q - 1 : s.end - q;

    // process input and output based on current state
    while (true) {
      switch (mode) {
      // waiting for "i:"=input, "o:"=output, "x:"=nothing
      case START: // x: set up for LEN
        if (m >= 258 && n >= 10) {

          s.bitb = b;
          s.bitk = k;
          z.avail_in = n;
          z.total_in += p - z.next_in_index;
          z.next_in_index = p;
          s.write = q;
          r = inflate_fast(lbits, dbits, ltree, ltree_index, dtree, dtree_index, s, z);

          p = z.next_in_index;
          n = z.avail_in;
          b = s.bitb;
          k = s.bitk;
          q = s.write;
          m = q < s.read ? s.read - q - 1 : s.end - q;

          if (r != Z_OK) {
            mode = r == Z_STREAM_END ? WASH : BADCODE;
            break;
          }
        }
        need = lbits;
        tree = ltree;
        tree_index = ltree_index;

        mode = LEN;
      case LEN: // i: get length/literal/eob next
        j = need;

        while (k < (j)) {
          if (n !== 0)
            r = Z_OK;
          else {

            s.bitb = b;
            s.bitk = k;
            z.avail_in = n;
            z.total_in += p - z.next_in_index;
            z.next_in_index = p;
            s.write = q;
            return s.inflate_flush(z, r);
          }
          n--;
          b |= (z.read_byte(p++) & 0xff) << k;
          k += 8;
        }

        tindex = (tree_index + (b & inflate_mask[j])) * 3;

        b >>>= (tree[tindex + 1]);
        k -= (tree[tindex + 1]);

        e = tree[tindex];

        if (e === 0) { // literal
          lit = tree[tindex + 2];
          mode = LIT;
          break;
        }
        if ((e & 16) !== 0) { // length
          get = e & 15;
          len = tree[tindex + 2];
          mode = LENEXT;
          break;
        }
        if ((e & 64) === 0) { // next table
          need = e;
          tree_index = tindex / 3 + tree[tindex + 2];
          break;
        }
        if ((e & 32) !== 0) { // end of block
          mode = WASH;
          break;
        }
        mode = BADCODE; // invalid code
        z.msg = "invalid literal/length code";
        r = Z_DATA_ERROR;

        s.bitb = b;
        s.bitk = k;
        z.avail_in = n;
        z.total_in += p - z.next_in_index;
        z.next_in_index = p;
        s.write = q;
        return s.inflate_flush(z, r);

      case LENEXT: // i: getting length extra (have base)
        j = get;

        while (k < (j)) {
          if (n !== 0)
            r = Z_OK;
          else {

            s.bitb = b;
            s.bitk = k;
            z.avail_in = n;
            z.total_in += p - z.next_in_index;
            z.next_in_index = p;
            s.write = q;
            return s.inflate_flush(z, r);
          }
          n--;
          b |= (z.read_byte(p++) & 0xff) << k;
          k += 8;
        }

        len += (b & inflate_mask[j]);

        b >>= j;
        k -= j;

        need = dbits;
        tree = dtree;
        tree_index = dtree_index;
        mode = DIST;
      case DIST: // i: get distance next
        j = need;

        while (k < (j)) {
          if (n !== 0)
            r = Z_OK;
          else {

            s.bitb = b;
            s.bitk = k;
            z.avail_in = n;
            z.total_in += p - z.next_in_index;
            z.next_in_index = p;
            s.write = q;
            return s.inflate_flush(z, r);
          }
          n--;
          b |= (z.read_byte(p++) & 0xff) << k;
          k += 8;
        }

        tindex = (tree_index + (b & inflate_mask[j])) * 3;

        b >>= tree[tindex + 1];
        k -= tree[tindex + 1];

        e = (tree[tindex]);
        if ((e & 16) !== 0) { // distance
          get = e & 15;
          dist = tree[tindex + 2];
          mode = DISTEXT;
          break;
        }
        if ((e & 64) === 0) { // next table
          need = e;
          tree_index = tindex / 3 + tree[tindex + 2];
          break;
        }
        mode = BADCODE; // invalid code
        z.msg = "invalid distance code";
        r = Z_DATA_ERROR;

        s.bitb = b;
        s.bitk = k;
        z.avail_in = n;
        z.total_in += p - z.next_in_index;
        z.next_in_index = p;
        s.write = q;
        return s.inflate_flush(z, r);

      case DISTEXT: // i: getting distance extra
        j = get;

        while (k < (j)) {
          if (n !== 0)
            r = Z_OK;
          else {

            s.bitb = b;
            s.bitk = k;
            z.avail_in = n;
            z.total_in += p - z.next_in_index;
            z.next_in_index = p;
            s.write = q;
            return s.inflate_flush(z, r);
          }
          n--;
          b |= (z.read_byte(p++) & 0xff) << k;
          k += 8;
        }

        dist += (b & inflate_mask[j]);

        b >>= j;
        k -= j;

        mode = COPY;
      case COPY: // o: copying bytes in window, waiting for space
        f = q - dist;
        while (f < 0) { // modulo window size-"while" instead
          f += s.end; // of "if" handles invalid distances
        }
        while (len !== 0) {

          if (m === 0) {
            if (q == s.end && s.read !== 0) {
              q = 0;
              m = q < s.read ? s.read - q - 1 : s.end - q;
            }
            if (m === 0) {
              s.write = q;
              r = s.inflate_flush(z, r);
              q = s.write;
              m = q < s.read ? s.read - q - 1 : s.end - q;

              if (q == s.end && s.read !== 0) {
                q = 0;
                m = q < s.read ? s.read - q - 1 : s.end - q;
              }

              if (m === 0) {
                s.bitb = b;
                s.bitk = k;
                z.avail_in = n;
                z.total_in += p - z.next_in_index;
                z.next_in_index = p;
                s.write = q;
                return s.inflate_flush(z, r);
              }
            }
          }

          s.window[q++] = s.window[f++];
          m--;

          if (f == s.end)
            f = 0;
          len--;
        }
        mode = START;
        break;
      case LIT: // o: got literal, waiting for output space
        if (m === 0) {
          if (q == s.end && s.read !== 0) {
            q = 0;
            m = q < s.read ? s.read - q - 1 : s.end - q;
          }
          if (m === 0) {
            s.write = q;
            r = s.inflate_flush(z, r);
            q = s.write;
            m = q < s.read ? s.read - q - 1 : s.end - q;

            if (q == s.end && s.read !== 0) {
              q = 0;
              m = q < s.read ? s.read - q - 1 : s.end - q;
            }
            if (m === 0) {
              s.bitb = b;
              s.bitk = k;
              z.avail_in = n;
              z.total_in += p - z.next_in_index;
              z.next_in_index = p;
              s.write = q;
              return s.inflate_flush(z, r);
            }
          }
        }
        r = Z_OK;

        s.window[q++] = /* (byte) */lit;
        m--;

        mode = START;
        break;
      case WASH: // o: got eob, possibly more output
        if (k > 7) { // return unused byte, if any
          k -= 8;
          n++;
          p--; // can always return one
        }

        s.write = q;
        r = s.inflate_flush(z, r);
        q = s.write;
        m = q < s.read ? s.read - q - 1 : s.end - q;

        if (s.read != s.write) {
          s.bitb = b;
          s.bitk = k;
          z.avail_in = n;
          z.total_in += p - z.next_in_index;
          z.next_in_index = p;
          s.write = q;
          return s.inflate_flush(z, r);
        }
        mode = END;
      case END:
        r = Z_STREAM_END;
        s.bitb = b;
        s.bitk = k;
        z.avail_in = n;
        z.total_in += p - z.next_in_index;
        z.next_in_index = p;
        s.write = q;
        return s.inflate_flush(z, r);

      case BADCODE: // x: got error

        r = Z_DATA_ERROR;

        s.bitb = b;
        s.bitk = k;
        z.avail_in = n;
        z.total_in += p - z.next_in_index;
        z.next_in_index = p;
        s.write = q;
        return s.inflate_flush(z, r);

      default:
        r = Z_STREAM_ERROR;

        s.bitb = b;
        s.bitk = k;
        z.avail_in = n;
        z.total_in += p - z.next_in_index;
        z.next_in_index = p;
        s.write = q;
        return s.inflate_flush(z, r);
      }
    }
  };

  that.free = function(z) {
    // ZFREE(z, c);
  };

}

// InfBlocks

// Table for deflate from PKZIP's appnote.txt.
var border = [ // Order of the bit length code lengths
16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 ];

var TYPE = 0; // get type bits (3, including end bit)
var LENS = 1; // get lengths for stored
var STORED = 2;// processing stored block
var TABLE = 3; // get table lengths
var BTREE = 4; // get bit lengths tree for a dynamic
// block
var DTREE = 5; // get length, distance trees for a
// dynamic block
var CODES = 6; // processing fixed or dynamic block
var DRY = 7; // output remaining window bytes
var DONELOCKS = 8; // finished last block, done
var BADBLOCKS = 9; // ot a data error--stuck here

function InfBlocks(z, w) {
  var that = this;

  var mode = TYPE; // current inflate_block mode

  var left = 0; // if STORED, bytes left to copy

  var table = 0; // table lengths (14 bits)
  var index = 0; // index into blens (or border)
  var blens; // bit lengths of codes
  var bb = [ 0 ]; // bit length tree depth
  var tb = [ 0 ]; // bit length decoding tree

  var codes = new InfCodes(); // if CODES, current state

  var last = 0; // true if this block is the last block

  var hufts = new Int32Array(MANY * 3); // single malloc for tree space
  var check = 0; // check on output
  var inftree = new InfTree();

  that.bitk = 0; // bits in bit buffer
  that.bitb = 0; // bit buffer
  that.window = new Uint8Array(w); // sliding window
  that.end = w; // one byte after sliding window
  that.read = 0; // window read pointer
  that.write = 0; // window write pointer

  that.reset = function(z, c) {
    if (c)
      c[0] = check;
    // if (mode == BTREE || mode == DTREE) {
    // }
    if (mode == CODES) {
      codes.free(z);
    }
    mode = TYPE;
    that.bitk = 0;
    that.bitb = 0;
    that.read = that.write = 0;
  };

  that.reset(z, null);

  // copy as much as possible from the sliding window to the output area
  that.inflate_flush = function(z, r) {
    var n;
    var p;
    var q;

    // local copies of source and destination pointers
    p = z.next_out_index;
    q = that.read;

    // compute number of bytes to copy as far as end of window
    n = /* (int) */((q <= that.write ? that.write : that.end) - q);
    if (n > z.avail_out)
      n = z.avail_out;
    if (n !== 0 && r == Z_BUF_ERROR)
      r = Z_OK;

    // update counters
    z.avail_out -= n;
    z.total_out += n;

    // copy as far as end of window
    z.next_out.set(that.window.subarray(q, q + n), p);
    p += n;
    q += n;

    // see if more to copy at beginning of window
    if (q == that.end) {
      // wrap pointers
      q = 0;
      if (that.write == that.end)
        that.write = 0;

      // compute bytes to copy
      n = that.write - q;
      if (n > z.avail_out)
        n = z.avail_out;
      if (n !== 0 && r == Z_BUF_ERROR)
        r = Z_OK;

      // update counters
      z.avail_out -= n;
      z.total_out += n;

      // copy
      z.next_out.set(that.window.subarray(q, q + n), p);
      p += n;
      q += n;
    }

    // update pointers
    z.next_out_index = p;
    that.read = q;

    // done
    return r;
  };

  that.proc = function(z, r) {
    var t; // temporary storage
    var b; // bit buffer
    var k; // bits in bit buffer
    var p; // input data pointer
    var n; // bytes available there
    var q; // output window write pointer
    var m; // bytes to end of window or read pointer

    var i;

    // copy input/output information to locals (UPDATE macro restores)
    // {
    p = z.next_in_index;
    n = z.avail_in;
    b = that.bitb;
    k = that.bitk;
    // }
    // {
    q = that.write;
    m = /* (int) */(q < that.read ? that.read - q - 1 : that.end - q);
    // }

    // process input based on current state
    // DEBUG dtree
    while (true) {
      switch (mode) {
      case TYPE:

        while (k < (3)) {
          if (n !== 0) {
            r = Z_OK;
          } else {
            that.bitb = b;
            that.bitk = k;
            z.avail_in = n;
            z.total_in += p - z.next_in_index;
            z.next_in_index = p;
            that.write = q;
            return that.inflate_flush(z, r);
          }
          n--;
          b |= (z.read_byte(p++) & 0xff) << k;
          k += 8;
        }
        t = /* (int) */(b & 7);
        last = t & 1;

        switch (t >>> 1) {
        case 0: // stored
          // {
          b >>>= (3);
          k -= (3);
          // }
          t = k & 7; // go to byte boundary

          // {
          b >>>= (t);
          k -= (t);
          // }
          mode = LENS; // get length of stored block
          break;
        case 1: // fixed
          // {
          var bl = []; // new Array(1);
          var bd = []; // new Array(1);
          var tl = [ [] ]; // new Array(1);
          var td = [ [] ]; // new Array(1);

          InfTree.inflate_trees_fixed(bl, bd, tl, td, z);
          codes.init(bl[0], bd[0], tl[0], 0, td[0], 0, z);
          // }

          // {
          b >>>= (3);
          k -= (3);
          // }

          mode = CODES;
          break;
        case 2: // dynamic

          // {
          b >>>= (3);
          k -= (3);
          // }

          mode = TABLE;
          break;
        case 3: // illegal

          // {
          b >>>= (3);
          k -= (3);
          // }
          mode = BADBLOCKS;
          z.msg = "invalid block type";
          r = Z_DATA_ERROR;

          that.bitb = b;
          that.bitk = k;
          z.avail_in = n;
          z.total_in += p - z.next_in_index;
          z.next_in_index = p;
          that.write = q;
          return that.inflate_flush(z, r);
        }
        break;
      case LENS:

        while (k < (32)) {
          if (n !== 0) {
            r = Z_OK;
          } else {
            that.bitb = b;
            that.bitk = k;
            z.avail_in = n;
            z.total_in += p - z.next_in_index;
            z.next_in_index = p;
            that.write = q;
            return that.inflate_flush(z, r);
          }
          n--;
          b |= (z.read_byte(p++) & 0xff) << k;
          k += 8;
        }

        if ((((~b) >>> 16) & 0xffff) != (b & 0xffff)) {
          mode = BADBLOCKS;
          z.msg = "invalid stored block lengths";
          r = Z_DATA_ERROR;

          that.bitb = b;
          that.bitk = k;
          z.avail_in = n;
          z.total_in += p - z.next_in_index;
          z.next_in_index = p;
          that.write = q;
          return that.inflate_flush(z, r);
        }
        left = (b & 0xffff);
        b = k = 0; // dump bits
        mode = left !== 0 ? STORED : (last !== 0 ? DRY : TYPE);
        break;
      case STORED:
        if (n === 0) {
          that.bitb = b;
          that.bitk = k;
          z.avail_in = n;
          z.total_in += p - z.next_in_index;
          z.next_in_index = p;
          that.write = q;
          return that.inflate_flush(z, r);
        }

        if (m === 0) {
          if (q == that.end && that.read !== 0) {
            q = 0;
            m = /* (int) */(q < that.read ? that.read - q - 1 : that.end - q);
          }
          if (m === 0) {
            that.write = q;
            r = that.inflate_flush(z, r);
            q = that.write;
            m = /* (int) */(q < that.read ? that.read - q - 1 : that.end - q);
            if (q == that.end && that.read !== 0) {
              q = 0;
              m = /* (int) */(q < that.read ? that.read - q - 1 : that.end - q);
            }
            if (m === 0) {
              that.bitb = b;
              that.bitk = k;
              z.avail_in = n;
              z.total_in += p - z.next_in_index;
              z.next_in_index = p;
              that.write = q;
              return that.inflate_flush(z, r);
            }
          }
        }
        r = Z_OK;

        t = left;
        if (t > n)
          t = n;
        if (t > m)
          t = m;
        that.window.set(z.read_buf(p, t), q);
        p += t;
        n -= t;
        q += t;
        m -= t;
        if ((left -= t) !== 0)
          break;
        mode = last !== 0 ? DRY : TYPE;
        break;
      case TABLE:

        while (k < (14)) {
          if (n !== 0) {
            r = Z_OK;
          } else {
            that.bitb = b;
            that.bitk = k;
            z.avail_in = n;
            z.total_in += p - z.next_in_index;
            z.next_in_index = p;
            that.write = q;
            return that.inflate_flush(z, r);
          }

          n--;
          b |= (z.read_byte(p++) & 0xff) << k;
          k += 8;
        }

        table = t = (b & 0x3fff);
        if ((t & 0x1f) > 29 || ((t >> 5) & 0x1f) > 29) {
          mode = BADBLOCKS;
          z.msg = "too many length or distance symbols";
          r = Z_DATA_ERROR;

          that.bitb = b;
          that.bitk = k;
          z.avail_in = n;
          z.total_in += p - z.next_in_index;
          z.next_in_index = p;
          that.write = q;
          return that.inflate_flush(z, r);
        }
        t = 258 + (t & 0x1f) + ((t >> 5) & 0x1f);
        if (!blens || blens.length < t) {
          blens = []; // new Array(t);
        } else {
          for (i = 0; i < t; i++) {
            blens[i] = 0;
          }
        }

        // {
        b >>>= (14);
        k -= (14);
        // }

        index = 0;
        mode = BTREE;
      case BTREE:
        while (index < 4 + (table >>> 10)) {
          while (k < (3)) {
            if (n !== 0) {
              r = Z_OK;
            } else {
              that.bitb = b;
              that.bitk = k;
              z.avail_in = n;
              z.total_in += p - z.next_in_index;
              z.next_in_index = p;
              that.write = q;
              return that.inflate_flush(z, r);
            }
            n--;
            b |= (z.read_byte(p++) & 0xff) << k;
            k += 8;
          }

          blens[border[index++]] = b & 7;

          // {
          b >>>= (3);
          k -= (3);
          // }
        }

        while (index < 19) {
          blens[border[index++]] = 0;
        }

        bb[0] = 7;
        t = inftree.inflate_trees_bits(blens, bb, tb, hufts, z);
        if (t != Z_OK) {
          r = t;
          if (r == Z_DATA_ERROR) {
            blens = null;
            mode = BADBLOCKS;
          }

          that.bitb = b;
          that.bitk = k;
          z.avail_in = n;
          z.total_in += p - z.next_in_index;
          z.next_in_index = p;
          that.write = q;
          return that.inflate_flush(z, r);
        }

        index = 0;
        mode = DTREE;
      case DTREE:
        while (true) {
          t = table;
          if (!(index < 258 + (t & 0x1f) + ((t >> 5) & 0x1f))) {
            break;
          }

          var h;
          var j, c;

          t = bb[0];

          while (k < (t)) {
            if (n !== 0) {
              r = Z_OK;
            } else {
              that.bitb = b;
              that.bitk = k;
              z.avail_in = n;
              z.total_in += p - z.next_in_index;
              z.next_in_index = p;
              that.write = q;
              return that.inflate_flush(z, r);
            }
            n--;
            b |= (z.read_byte(p++) & 0xff) << k;
            k += 8;
          }

          // if (tb[0] == -1) {
          // System.err.println("null...");
          // }

          t = hufts[(tb[0] + (b & inflate_mask[t])) * 3 + 1];
          c = hufts[(tb[0] + (b & inflate_mask[t])) * 3 + 2];

          if (c < 16) {
            b >>>= (t);
            k -= (t);
            blens[index++] = c;
          } else { // c == 16..18
            i = c == 18 ? 7 : c - 14;
            j = c == 18 ? 11 : 3;

            while (k < (t + i)) {
              if (n !== 0) {
                r = Z_OK;
              } else {
                that.bitb = b;
                that.bitk = k;
                z.avail_in = n;
                z.total_in += p - z.next_in_index;
                z.next_in_index = p;
                that.write = q;
                return that.inflate_flush(z, r);
              }
              n--;
              b |= (z.read_byte(p++) & 0xff) << k;
              k += 8;
            }

            b >>>= (t);
            k -= (t);

            j += (b & inflate_mask[i]);

            b >>>= (i);
            k -= (i);

            i = index;
            t = table;
            if (i + j > 258 + (t & 0x1f) + ((t >> 5) & 0x1f) || (c == 16 && i < 1)) {
              blens = null;
              mode = BADBLOCKS;
              z.msg = "invalid bit length repeat";
              r = Z_DATA_ERROR;

              that.bitb = b;
              that.bitk = k;
              z.avail_in = n;
              z.total_in += p - z.next_in_index;
              z.next_in_index = p;
              that.write = q;
              return that.inflate_flush(z, r);
            }

            c = c == 16 ? blens[i - 1] : 0;
            do {
              blens[i++] = c;
            } while (--j !== 0);
            index = i;
          }
        }

        tb[0] = -1;
        // {
        var bl_ = []; // new Array(1);
        var bd_ = []; // new Array(1);
        var tl_ = []; // new Array(1);
        var td_ = []; // new Array(1);
        bl_[0] = 9; // must be <= 9 for lookahead assumptions
        bd_[0] = 6; // must be <= 9 for lookahead assumptions

        t = table;
        t = inftree.inflate_trees_dynamic(257 + (t & 0x1f), 1 + ((t >> 5) & 0x1f), blens, bl_, bd_, tl_, td_, hufts, z);

        if (t != Z_OK) {
          if (t == Z_DATA_ERROR) {
            blens = null;
            mode = BADBLOCKS;
          }
          r = t;

          that.bitb = b;
          that.bitk = k;
          z.avail_in = n;
          z.total_in += p - z.next_in_index;
          z.next_in_index = p;
          that.write = q;
          return that.inflate_flush(z, r);
        }
        codes.init(bl_[0], bd_[0], hufts, tl_[0], hufts, td_[0], z);
        // }
        mode = CODES;
      case CODES:
        that.bitb = b;
        that.bitk = k;
        z.avail_in = n;
        z.total_in += p - z.next_in_index;
        z.next_in_index = p;
        that.write = q;

        if ((r = codes.proc(that, z, r)) != Z_STREAM_END) {
          return that.inflate_flush(z, r);
        }
        r = Z_OK;
        codes.free(z);

        p = z.next_in_index;
        n = z.avail_in;
        b = that.bitb;
        k = that.bitk;
        q = that.write;
        m = /* (int) */(q < that.read ? that.read - q - 1 : that.end - q);

        if (last === 0) {
          mode = TYPE;
          break;
        }
        mode = DRY;
      case DRY:
        that.write = q;
        r = that.inflate_flush(z, r);
        q = that.write;
        m = /* (int) */(q < that.read ? that.read - q - 1 : that.end - q);
        if (that.read != that.write) {
          that.bitb = b;
          that.bitk = k;
          z.avail_in = n;
          z.total_in += p - z.next_in_index;
          z.next_in_index = p;
          that.write = q;
          return that.inflate_flush(z, r);
        }
        mode = DONELOCKS;
      case DONELOCKS:
        r = Z_STREAM_END;

        that.bitb = b;
        that.bitk = k;
        z.avail_in = n;
        z.total_in += p - z.next_in_index;
        z.next_in_index = p;
        that.write = q;
        return that.inflate_flush(z, r);
      case BADBLOCKS:
        r = Z_DATA_ERROR;

        that.bitb = b;
        that.bitk = k;
        z.avail_in = n;
        z.total_in += p - z.next_in_index;
        z.next_in_index = p;
        that.write = q;
        return that.inflate_flush(z, r);

      default:
        r = Z_STREAM_ERROR;

        that.bitb = b;
        that.bitk = k;
        z.avail_in = n;
        z.total_in += p - z.next_in_index;
        z.next_in_index = p;
        that.write = q;
        return that.inflate_flush(z, r);
      }
    }
  };

  that.free = function(z) {
    that.reset(z, null);
    that.window = null;
    hufts = null;
    // ZFREE(z, s);
  };

  that.set_dictionary = function(d, start, n) {
    that.window.set(d.subarray(start, start + n), 0);
    that.read = that.write = n;
  };

  // Returns true if inflate is currently at the end of a block generated
  // by Z_SYNC_FLUSH or Z_FULL_FLUSH.
  that.sync_point = function() {
    return mode == LENS ? 1 : 0;
  };

}

// Inflate

// preset dictionary flag in zlib header
var PRESET_DICT = 0x20;

var Z_DEFLATED = 8;

var METHOD = 0; // waiting for method byte
var FLAG = 1; // waiting for flag byte
var DICT4 = 2; // four dictionary check bytes to go
var DICT3 = 3; // three dictionary check bytes to go
var DICT2 = 4; // two dictionary check bytes to go
var DICT1 = 5; // one dictionary check byte to go
var DICT0 = 6; // waiting for inflateSetDictionary
var BLOCKS = 7; // decompressing blocks
var DONE = 12; // finished check, done
var BAD = 13; // got an error--stay here

var mark = [ 0, 0, 0xff, 0xff ];

function Inflate() {
  var that = this;

  that.mode = 0; // current inflate mode

  // mode dependent information
  that.method = 0; // if FLAGS, method byte

  // if CHECK, check values to compare
  that.was = [ 0 ]; // new Array(1); // computed check value
  that.need = 0; // stream check value

  // if BAD, inflateSync's marker bytes count
  that.marker = 0;

  // mode independent information
  that.wbits = 0; // log2(window size) (8..15, defaults to 15)

  // this.blocks; // current inflate_blocks state

  function inflateReset(z) {
    if (!z || !z.istate)
      return Z_STREAM_ERROR;

    z.total_in = z.total_out = 0;
    z.msg = null;
    z.istate.mode = BLOCKS;
    z.istate.blocks.reset(z, null);
    return Z_OK;
  }

  that.inflateEnd = function(z) {
    if (that.blocks)
      that.blocks.free(z);
    that.blocks = null;
    // ZFREE(z, z->state);
    return Z_OK;
  };

  that.inflateInit = function(z, w) {
    z.msg = null;
    that.blocks = null;

    // set window size
    if (w < 8 || w > 15) {
      that.inflateEnd(z);
      return Z_STREAM_ERROR;
    }
    that.wbits = w;

    z.istate.blocks = new InfBlocks(z, 1 << w);

    // reset state
    inflateReset(z);
    return Z_OK;
  };

  that.inflate = function(z, f) {
    var r;
    var b;

    if (!z || !z.istate || !z.next_in)
      return Z_STREAM_ERROR;
    f = f == Z_FINISH ? Z_BUF_ERROR : Z_OK;
    r = Z_BUF_ERROR;
    while (true) {
      // System.out.println("mode: "+z.istate.mode);
      switch (z.istate.mode) {
      case METHOD:

        if (z.avail_in === 0)
          return r;
        r = f;

        z.avail_in--;
        z.total_in++;
        if (((z.istate.method = z.read_byte(z.next_in_index++)) & 0xf) != Z_DEFLATED) {
          z.istate.mode = BAD;
          z.msg = "unknown compression method";
          z.istate.marker = 5; // can't try inflateSync
          break;
        }
        if ((z.istate.method >> 4) + 8 > z.istate.wbits) {
          z.istate.mode = BAD;
          z.msg = "invalid window size";
          z.istate.marker = 5; // can't try inflateSync
          break;
        }
        z.istate.mode = FLAG;
      case FLAG:

        if (z.avail_in === 0)
          return r;
        r = f;

        z.avail_in--;
        z.total_in++;
        b = (z.read_byte(z.next_in_index++)) & 0xff;

        if ((((z.istate.method << 8) + b) % 31) !== 0) {
          z.istate.mode = BAD;
          z.msg = "incorrect header check";
          z.istate.marker = 5; // can't try inflateSync
          break;
        }

        if ((b & PRESET_DICT) === 0) {
          z.istate.mode = BLOCKS;
          break;
        }
        z.istate.mode = DICT4;
      case DICT4:

        if (z.avail_in === 0)
          return r;
        r = f;

        z.avail_in--;
        z.total_in++;
        z.istate.need = ((z.read_byte(z.next_in_index++) & 0xff) << 24) & 0xff000000;
        z.istate.mode = DICT3;
      case DICT3:

        if (z.avail_in === 0)
          return r;
        r = f;

        z.avail_in--;
        z.total_in++;
        z.istate.need += ((z.read_byte(z.next_in_index++) & 0xff) << 16) & 0xff0000;
        z.istate.mode = DICT2;
      case DICT2:

        if (z.avail_in === 0)
          return r;
        r = f;

        z.avail_in--;
        z.total_in++;
        z.istate.need += ((z.read_byte(z.next_in_index++) & 0xff) << 8) & 0xff00;
        z.istate.mode = DICT1;
      case DICT1:

        if (z.avail_in === 0)
          return r;
        r = f;

        z.avail_in--;
        z.total_in++;
        z.istate.need += (z.read_byte(z.next_in_index++) & 0xff);
        z.istate.mode = DICT0;
        return Z_NEED_DICT;
      case DICT0:
        z.istate.mode = BAD;
        z.msg = "need dictionary";
        z.istate.marker = 0; // can try inflateSync
        return Z_STREAM_ERROR;
      case BLOCKS:

        r = z.istate.blocks.proc(z, r);
        if (r == Z_DATA_ERROR) {
          z.istate.mode = BAD;
          z.istate.marker = 0; // can try inflateSync
          break;
        }
        if (r == Z_OK) {
          r = f;
        }
        if (r != Z_STREAM_END) {
          return r;
        }
        r = f;
        z.istate.blocks.reset(z, z.istate.was);
        z.istate.mode = DONE;
      case DONE:
        return Z_STREAM_END;
      case BAD:
        return Z_DATA_ERROR;
      default:
        return Z_STREAM_ERROR;
      }
    }
  };

  that.inflateSetDictionary = function(z, dictionary, dictLength) {
    var index = 0;
    var length = dictLength;
    if (!z || !z.istate || z.istate.mode != DICT0)
      return Z_STREAM_ERROR;

    if (length >= (1 << z.istate.wbits)) {
      length = (1 << z.istate.wbits) - 1;
      index = dictLength - length;
    }
    z.istate.blocks.set_dictionary(dictionary, index, length);
    z.istate.mode = BLOCKS;
    return Z_OK;
  };

  that.inflateSync = function(z) {
    var n; // number of bytes to look at
    var p; // pointer to bytes
    var m; // number of marker bytes found in a row
    var r, w; // temporaries to save total_in and total_out

    // set up
    if (!z || !z.istate)
      return Z_STREAM_ERROR;
    if (z.istate.mode != BAD) {
      z.istate.mode = BAD;
      z.istate.marker = 0;
    }
    if ((n = z.avail_in) === 0)
      return Z_BUF_ERROR;
    p = z.next_in_index;
    m = z.istate.marker;

    // search
    while (n !== 0 && m < 4) {
      if (z.read_byte(p) == mark[m]) {
        m++;
      } else if (z.read_byte(p) !== 0) {
        m = 0;
      } else {
        m = 4 - m;
      }
      p++;
      n--;
    }

    // restore
    z.total_in += p - z.next_in_index;
    z.next_in_index = p;
    z.avail_in = n;
    z.istate.marker = m;

    // return no joy or set up to restart on a new block
    if (m != 4) {
      return Z_DATA_ERROR;
    }
    r = z.total_in;
    w = z.total_out;
    inflateReset(z);
    z.total_in = r;
    z.total_out = w;
    z.istate.mode = BLOCKS;
    return Z_OK;
  };

  // Returns true if inflate is currently at the end of a block generated
  // by Z_SYNC_FLUSH or Z_FULL_FLUSH. This function is used by one PPP
  // implementation to provide an additional safety check. PPP uses
  // Z_SYNC_FLUSH
  // but removes the length bytes of the resulting empty stored block. When
  // decompressing, PPP checks that at the end of input packet, inflate is
  // waiting for these length bytes.
  that.inflateSyncPoint = function(z) {
    if (!z || !z.istate || !z.istate.blocks)
      return Z_STREAM_ERROR;
    return z.istate.blocks.sync_point();
  };
}

// ZStream

function ZStream() {
}

ZStream.prototype = {
  inflateInit : function(bits) {
    var that = this;
    that.istate = new Inflate();
    if (!bits)
      bits = MAX_BITS;
    return that.istate.inflateInit(that, bits);
  },

  inflate : function(f) {
    var that = this;
    if (!that.istate)
      return Z_STREAM_ERROR;
    return that.istate.inflate(that, f);
  },

  inflateEnd : function() {
    var that = this;
    if (!that.istate)
      return Z_STREAM_ERROR;
    var ret = that.istate.inflateEnd(that);
    that.istate = null;
    return ret;
  },

  inflateSync : function() {
    var that = this;
    if (!that.istate)
      return Z_STREAM_ERROR;
    return that.istate.inflateSync(that);
  },
  inflateSetDictionary : function(dictionary, dictLength) {
    var that = this;
    if (!that.istate)
      return Z_STREAM_ERROR;
    return that.istate.inflateSetDictionary(that, dictionary, dictLength);
  },
  read_byte : function(start) {
    var that = this;
    return that.next_in.subarray(start, start + 1)[0];
  },
  read_buf : function(start, size) {
    var that = this;
    return that.next_in.subarray(start, start + size);
  }
};

// Inflater

function Inflater() {
  var that = this;
  var z = new ZStream();
  var bufsize = 512;
  var flush = Z_NO_FLUSH;
  var buf = new Uint8Array(bufsize);
  var nomoreinput = false;

  z.inflateInit();
  z.next_out = buf;

  that.append = function(data, onprogress) {
    var err, buffers = [], lastIndex = 0, bufferIndex = 0, bufferSize = 0, array;
    if (data.length === 0)
      return;
    z.next_in_index = 0;
    z.next_in = data;
    z.avail_in = data.length;
    do {
      z.next_out_index = 0;
      z.avail_out = bufsize;
      if ((z.avail_in === 0) && (!nomoreinput)) { // if buffer is empty and more input is available, refill it
        z.next_in_index = 0;
        nomoreinput = true;
      }
      err = z.inflate(flush);
      if (nomoreinput && (err == Z_BUF_ERROR))
        return -1;
      if (err != Z_OK && err != Z_STREAM_END)
        throw "inflating: " + z.msg;
      if ((nomoreinput || err == Z_STREAM_END) && (z.avail_out == data.length))
        return -1;
      if (z.next_out_index)
        if (z.next_out_index == bufsize)
          buffers.push(new Uint8Array(buf));
        else
          buffers.push(new Uint8Array(buf.subarray(0, z.next_out_index)));
      bufferSize += z.next_out_index;
      if (onprogress && z.next_in_index > 0 && z.next_in_index != lastIndex) {
        onprogress(z.next_in_index);
        lastIndex = z.next_in_index;
      }
    } while (z.avail_in > 0 || z.avail_out === 0);
    array = new Uint8Array(bufferSize);
    buffers.forEach(function(chunk) {
      array.set(chunk, bufferIndex);
      bufferIndex += chunk.length;
    });
    return array;
  };
  that.flush = function() {
    z.inflateEnd();
  };
}

var inflater = new Inflater();;
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
  var Log, PSD, PSDColor, PSDDropDownLayerEffect, PSDFile, PSDHeader, PSDImage, PSDLayer, PSDLayerEffect, PSDLayerEffectCommonStateInfo, PSDLayerMask, PSDResource, PSDTypeTool, Root, Util, fs,
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

    PSD.ZIP_ENABLED = typeof inflater !== "undefined" && inflater !== null;

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
      this.layers = this.layerMask.layers;
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

  PSDColor = (function() {

    function PSDColor() {}

    PSDColor.hexToRGB = function(hex) {
      var b, g, r;
      if (hex.charAt(0) === "#") hex = hex.substr(1);
      r = parseInt(hex.substr(0, 2), 16);
      g = parseInt(hex.substr(2, 2), 16);
      b = parseInt(hex.substr(4, 2), 16);
      return {
        r: r,
        g: g,
        b: b
      };
    };

    PSDColor.rgbToHSL = function(r, g, b) {
      var d, h, l, max, min, s;
      r /= 255;
      g /= 255;
      b /= 255;
      max = Math.max(r, g, b);
      min = Math.min(r, g, b);
      l = (max + min) / 2;
      if (max === min) {
        h = s = 0;
      } else {
        d = max - min;
        s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
        h = (function() {
          switch (max) {
            case r:
              return (g - b) / d + (g < b ? 6 : 0);
            case g:
              return (b - r) / d + 2;
            case b:
              return (r - g) / d + 4;
          }
        })();
        h /= 6;
      }
      return {
        h: h,
        s: s,
        l: l
      };
    };

    PSDColor.hslToRGB = function(h, s, l) {
      var b, g, p, q, r;
      if (s === 0) {
        r = g = b = l;
      } else {
        q = l < 0.5 ? l * (1 + s) : l + s - l * s;
        p = 2 * l - q;
        r = this.hueToRGB(p, q, h + 1 / 3);
        g = this.hueToRGB(p, q, h);
        b = this.hueToRGB(p, q, h - 1 / 3);
      }
      return {
        r: r * 255,
        g: g * 255,
        b: b * 255
      };
    };

    PSDColor.hueToRGB = function(p, q, t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    };

    PSDColor.rgbToHSV = function(r, g, b) {
      var d, h, max, min, s, v;
      r /= 255;
      g /= 255;
      b /= 255;
      max = Math.max(r, g, b);
      min = Math.min(r, g, b);
      v = max;
      d = max - min;
      s = max === 0 ? 0 : d / max;
      if (max === min) {
        h = 0;
      } else {
        h = (function() {
          switch (max) {
            case r:
              return (g - b) / d + (g < b ? 6 : 0);
            case g:
              return (b - r) / d + 2;
            case b:
              return (r - g) / d + 4;
          }
        })();
        h /= 6;
      }
      return {
        h: h,
        s: s,
        v: v
      };
    };

    PSDColor.hsvToRGB = function(h, s, v) {
      var b, f, g, i, p, q, r, t;
      i = Math.floor(h * 6);
      f = h * 6 - i;
      p = v * (1 - s);
      q = v * (1 - f * s);
      t = v * (1 - (1 - f) * s);
      switch (i % 6) {
        case 0:
          r = v;
          g = t;
          b = p;
          break;
        case 1:
          r = q;
          g = v;
          b = p;
          break;
        case 2:
          r = p;
          g = v;
          b = t;
          break;
        case 3:
          r = p;
          g = q;
          b = v;
          break;
        case 4:
          r = t;
          g = p;
          b = v;
          break;
        case 5:
          r = v;
          g = p;
          b = q;
      }
      return {
        r: r * 255,
        g: g * 255,
        b: b * 255
      };
    };

    PSDColor.rgbToXYZ = function(r, g, b) {
      var x, y, z;
      r /= 255;
      g /= 255;
      b /= 255;
      if (r > 0.04045) {
        r = Math.pow((r + 0.055) / 1.055, 2.4);
      } else {
        r /= 12.92;
      }
      if (g > 0.04045) {
        g = Math.pow((g + 0.055) / 1.055, 2.4);
      } else {
        g /= 12.92;
      }
      if (b > 0.04045) {
        b = Math.pow((b + 0.055) / 1.055, 2.4);
      } else {
        b /= 12.92;
      }
      x = r * 0.4124 + g * 0.3576 + b * 0.1805;
      y = r * 0.2126 + g * 0.7152 + b * 0.0722;
      z = r * 0.0193 + g * 0.1192 + b * 0.9505;
      return {
        x: x * 100,
        y: y * 100,
        z: z * 100
      };
    };

    PSDColor.xyzToRGB = function(x, y, z) {
      var b, g, r;
      x /= 100;
      y /= 100;
      z /= 100;
      r = (3.2406 * x) + (-1.5372 * y) + (-0.4986 * z);
      g = (-0.9689 * x) + (1.8758 * y) + (0.0415 * z);
      b = (0.0557 * x) + (-0.2040 * y) + (1.0570 * z);
      if (r > 0.0031308) {
        r = (1.055 * Math.pow(r, 0.4166666667)) - 0.055;
      } else {
        r *= 12.92;
      }
      if (g > 0.0031308) {
        g = (1.055 * Math.pow(g, 0.4166666667)) - 0.055;
      } else {
        g *= 12.92;
      }
      if (b > 0.0031308) {
        b = (1.055 * Math.pow(b, 0.4166666667)) - 0.055;
      } else {
        b *= 12.92;
      }
      return {
        r: r * 255,
        g: g * 255,
        b: b * 255
      };
    };

    PSDColor.xyzToLab = function(x, y, z) {
      var a, b, l, whiteX, whiteY, whiteZ;
      whiteX = 95.047;
      whiteY = 100.0;
      whiteZ = 108.883;
      x /= whiteX;
      y /= whiteY;
      z /= whiteZ;
      if (x > 0.008856451679) {
        x = Math.pow(x, 0.3333333333);
      } else {
        x = (7.787037037 * x) + 0.1379310345;
      }
      if (y > 0.008856451679) {
        y = Math.pow(y, 0.3333333333);
      } else {
        y = (7.787037037 * y) + 0.1379310345;
      }
      if (z > 0.008856451679) {
        z = Math.pow(z, 0.3333333333);
      } else {
        z = (7.787037037 * z) + 0.1379310345;
      }
      l = 116 * y - 16;
      a = 500 * (x - y);
      b = 200 * (y - z);
      return {
        l: l,
        a: a,
        b: b
      };
    };

    PSDColor.labToXYZ = function(l, a, b) {
      var x, y, z;
      y = (l + 16) / 116;
      x = y + (a / 500);
      z = y - (b / 200);
      if (x > 0.2068965517) {
        x = x * x * x;
      } else {
        x = 0.1284185493 * (x - 0.1379310345);
      }
      if (y > 0.2068965517) {
        y = y * y * y;
      } else {
        y = 0.1284185493 * (y - 0.1379310345);
      }
      if (z > 0.2068965517) {
        z = z * z * z;
      } else {
        z = 0.1284185493 * (z - 0.1379310345);
      }
      return {
        x: x * 95.047,
        y: y * 100.0,
        z: z * 108.883
      };
    };

    PSDColor.rgbToCMY = function(r, g, b) {
      var c, m, y;
      c = 1 - (r / 255);
      m = 1 - (g / 255);
      y = 1 - (b / 255);
      return {
        c: c,
        m: m,
        y: y
      };
    };

    PSDColor.cmyToRGB = function(c, m, y) {
      var b, g, r;
      r = (1 - c) * 255;
      g = (1 - m) * 255;
      b = (1 - y) * 255;
      return {
        r: r,
        g: g,
        b: b
      };
    };

    PSDColor.cmyToCMYK = function(c, m, y) {
      var _k;
      _k = 1;
      if (c < _k) _k = c;
      if (m < _k) _k = m;
      if (y < _k) _k = y;
      if (k === 1) {
        c = 0;
        m = 0;
        y = 0;
      } else {
        c = (c - _k) / (1 - _k);
        m = (m - _k) / (1 - _k);
        y = (y - _k) / (1 - _k);
      }
      return {
        c: c,
        m: m,
        y: y,
        k: k
      };
    };

    PSDColor.cmykToCMY = function(c, m, y, k) {
      c = c * (1 - k) + k;
      m = m * (1 - k) + k;
      y = y * (1 - k) + k;
      return {
        c: c,
        m: m,
        y: y
      };
    };

    PSDColor.rgbToCMYK = function(r, g, b) {
      var cmy;
      cmy = this.rgbToCMY(r, g, b);
      return this.cmyToCMYK(cmy.c, cmy.m, cmy.y);
    };

    PSDColor.cmykToRGB = function(c, m, y, k) {
      var cmy;
      cmy = this.cmykToCMY(c, m, y, k);
      return this.cmyToRGB(cmy.c, cmy.m, cmy.y);
    };

    return PSDColor;

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
      if (!strlen) strlen = this.readInt();
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
      return this.readf(">" + length + "s")[0].replace(/\u0000/g, "");
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
    var COMPRESSIONS, MIN_TEMP_CHANNEL_LENGTH;

    COMPRESSIONS = {
      0: 'Raw',
      1: 'RLE',
      2: 'ZIP',
      3: 'ZIPPrediction'
    };

    MIN_TEMP_CHANNEL_LENGTH = 12288;

    function PSDImage(file, header, layer) {
      var compression, i, length, maskChannelLength, maskPixels, x, _ref, _ref2, _ref3;
      this.file = file;
      this.header = header;
      this.layer = layer != null ? layer : null;
      this.width = this.header.cols;
      this.height = this.header.rows;
      this.numPixels = this.width * this.height;
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
      if (this.layer && !this.layer.isFolder) {
        maskChannelLength = (function() {
          switch (this.header.depth) {
            case 8:
              return this.layer.mask.width * this.layer.mask.height;
            case 16:
              return this.layer.mask.width * this.layer.mask.height * 2;
            default:
              return 0;
          }
        }).call(this);
        maskPixels = this.layer.mask.width * this.layer.mask.height;
        if (this.header.depth === 16) maskPixels *= 2;
        this.maxChannelLength = Math.max(maskChannelLength, this.channelLength);
        if (this.maxChannelLength <= 0) {
          for (i = 0, _ref = this.header.channels; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
            this.file.seek(this.layer.channelsInfo[i].length);
          }
          return;
        }
      }
      this.startPos = this.file.tell();
      this.endPos = this.startPos + this.length;
      this.channelData = [];
      if (this.layer) {
        for (i = 0, _ref2 = this.header.channels; 0 <= _ref2 ? i < _ref2 : i > _ref2; 0 <= _ref2 ? i++ : i--) {
          compression = this.file.readShortInt();
          this.layer.channelsInfo[i].compression = compression;
          length = this.layer.channelsInfo[i].length - 2;
          length = Math.max(length, MIN_TEMP_CHANNEL_LENGTH);
          this.layer.channelsInfo[i].data = this.file.read(length);
        }
      } else {
        this.compression = this.file.readShortInt();
      }
      for (x = 0, _ref3 = this.length; 0 <= _ref3 ? x < _ref3 : x > _ref3; 0 <= _ref3 ? x++ : x--) {
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
      var args, _ref;
      if (this.layer) return this.parseLayerChannels();
      Log.debug("Image compression: id=" + this.compression + ", name=" + COMPRESSIONS[this.compression]);
      Log.debug("Image size: " + this.length + " (" + this.width + "x" + this.height + ")");
      args = Array.prototype.slice.call(arguments);
      if ((_ref = this.compression) === 2 || _ref === 3) {
        if (!PSD.ZIP_ENABLED) {
          Log.debug("ZIP library not included, skipping.");
          return this.file.seek(this.endPos, false);
        }
        args.unshift(this.compression === 3);
      }
      switch (this.compression) {
        case 0:
          return this.parseRaw.apply(this, args);
        case 1:
          return this.parseRLE.apply(this, args);
        case 2:
        case 3:
          return this.parseZip.apply(this, args);
        default:
          Log.debug("Unknown image compression. Attempting to skip.");
          return this.file.seek(this.endPos, false);
      }
    };

    PSDImage.prototype.parseLayerChannels = function() {
      var channel, i, _ref, _results;
      _results = [];
      for (i = 0, _ref = this.header.channels; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
        channel = this.layer.channelsInfo[i];
        switch (channel.compression) {
          case 0:
            if (channel.id === -2) {
              _results.push(this.parseRaw.call(this, channel.length));
            } else {
              _results.push(this.parseRaw.call(this, this.channelLength));
            }
            break;
          case 1:
            _results.push(this.parseRLE.call(this, new PSDFile(channel.data), channel));
            break;
          default:
            _results.push(void 0);
        }
      }
      return _results;
    };

    PSDImage.prototype.parseRaw = function(length) {
      var i;
      if (length == null) length = this.length;
      Log.debug("Attempting to parse RAW encoded image...");
      for (i = 0; 0 <= length ? i < length : i > length; 0 <= length ? i++ : i--) {
        this.channelData.push(this.file.read(1)[0]);
      }
      return this.processImageData();
    };

    PSDImage.prototype.parseRLE = function(file, channelInfo) {
      var byteCounts, chanPos, height, i, j, lineIndex, parseChannel, _ref, _ref2,
        _this = this;
      if (file == null) file = this.file;
      if (channelInfo == null) channelInfo = null;
      Log.debug("Attempting to parse RLE encoded image...");
      if (channelInfo) {
        if (channelInfo.id === -2) {
          height = this.layer.mask.height;
        } else {
          height = this.layer.rows;
        }
      } else {
        height = this.height;
      }
      byteCounts = [];
      if (channelInfo) {
        for (j = 0; 0 <= height ? j < height : j > height; 0 <= height ? j++ : j--) {
          byteCounts.push(file.readShortInt());
        }
      } else {
        for (i = 0, _ref = this.header.channels; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
          for (j = 0; 0 <= height ? j < height : j > height; 0 <= height ? j++ : j--) {
            byteCounts.push(file.readShortInt());
          }
        }
      }
      Log.debug("Read byte counts. Current pos = " + (file.tell()) + ", Pixels = " + this.length);
      chanPos = 0;
      lineIndex = 0;
      parseChannel = function() {
        var byteCount, data, j, len, start, val, z, _results;
        _results = [];
        for (j = 0; 0 <= height ? j < height : j > height; 0 <= height ? j++ : j--) {
          byteCount = byteCounts[lineIndex++];
          start = file.tell();
          _results.push((function() {
            var _results2;
            _results2 = [];
            while (file.tell() < start + byteCount) {
              len = file.read(1)[0];
              if (len < 128) {
                len++;
                data = file.read(len);
                [].splice.apply(this.channelData, [chanPos, (chanPos + len) - chanPos].concat(data)), data;
                _results2.push(chanPos += len);
              } else if (len > 128) {
                len ^= 0xff;
                len += 2;
                val = file.read(1)[0];
                data = [];
                for (z = 0; 0 <= len ? z < len : z > len; 0 <= len ? z++ : z--) {
                  data.push(val);
                }
                [].splice.apply(this.channelData, [chanPos, (chanPos + len) - chanPos].concat(data)), data;
                _results2.push(chanPos += len);
              } else {
                _results2.push(void 0);
              }
            }
            return _results2;
          }).call(_this));
        }
        return _results;
      };
      if (channelInfo) {
        Log.debug("Parsing layer channel...");
        parseChannel();
      } else {
        for (i = 0, _ref2 = this.header.channels; 0 <= _ref2 ? i < _ref2 : i > _ref2; 0 <= _ref2 ? i++ : i--) {
          Log.debug("Parsing channel #" + i + ", Start = " + (file.tell()));
          parseChannel();
        }
      }
      return this.processImageData();
    };

    PSDImage.prototype.parseZip = function(prediction) {
      if (prediction == null) prediction = false;
      return this.file.seek(this.endPos, false);
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
          break;
        case 4:
          return this.combineCMYK8Channel();
      }
    };

    PSDImage.prototype.combineGreyscale8Channel = function() {
      var alpha, grey, i, _ref, _ref2, _results, _results2;
      if (this.header.channels === 2) {
        _results = [];
        for (i = 0, _ref = this.numPixels; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
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
        for (i = 0, _ref2 = this.numPixels; 0 <= _ref2 ? i < _ref2 : i > _ref2; 0 <= _ref2 ? i++ : i--) {
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
        for (i = 0, _ref = this.numPixels; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
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
        for (i = 0, _ref2 = this.numPixels; 0 <= _ref2 ? i < _ref2 : i > _ref2; 0 <= _ref2 ? i++ : i--) {
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
      for (i = 0, _ref = this.numPixels; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
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
      for (i = 0, _ref = this.numPixels; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
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

    PSDImage.prototype.combineCMYK8Channel = function() {
      var c, i, k, m, rgb, y, _ref, _results;
      _results = [];
      for (i = 0, _ref = this.numPixels; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
        c = this.channelData[i];
        m = this.channelData[i + this.channelLength];
        y = this.channelData[i + this.channelLength * 2];
        k = this.channelData[i + this.channelLength * 3];
        rgb = PSDColor.cmykToRGB(c, m, y, k);
        this.pixelData.r[i] = rgb.r;
        this.pixelData.g[i] = rgb.g;
        this.pixelData.b[i] = rgb.b;
        if (this.header.channels === 5) {
          _results.push(this.pixelData.a[i] = this.channelData[i + this.channelData * 4]);
        } else {
          _results.push(this.pixelData.a[i] = 255);
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
      this.isFolder = false;
      this.isHidden = false;
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
        Log.debug("Error parsing mask data for layer #" + this.idx + ". Skipping.");
        return this.file.seek(this.layerEnd, false);
      }
      this.parseBlendingRanges();
      namelen = Util.pad4(this.file.read(1)[0]);
      this.name = this.file.readString(namelen);
      Log.debug("Layer name: " + this.name);
      this.parseExtraData();
      Log.debug("Layer " + layerIndex + ":", this);
      if (this.file.tell() !== this.layerEnd) {
        console.log("Error parsing layer - unexpected end. Attempting to recover...");
        return this.file.seek(this.layerEnd, false);
      }
    };

    PSDLayer.prototype.parseInfo = function(layerIndex) {
      var channelID, channelLength, i, _ref, _ref2, _ref3, _ref4, _results;
      this.idx = layerIndex;
      /*
          Layer Info
      */
      _ref = this.file.readf(">iiiih"), this.top = _ref[0], this.left = _ref[1], this.bottom = _ref[2], this.right = _ref[3], this.channels = _ref[4];
      _ref2 = [this.bottom - this.top, this.right - this.left], this.rows = _ref2[0], this.cols = _ref2[1];
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
        _results.push(this.channelsInfo.push({
          id: channelID,
          length: channelLength
        }));
      }
      return _results;
    };

    PSDLayer.prototype.parseBlendModes = function() {
      var filler, flags, _ref;
      this.blendMode = {};
      _ref = this.file.readf(">4s4sBBBB"), this.blendMode.sig = _ref[0], this.blendMode.key = _ref[1], this.blendMode.opacity = _ref[2], this.blendMode.clipping = _ref[3], flags = _ref[4], filler = _ref[5];
      this.blendMode.key = this.blendMode.key.trim();
      this.blendMode.opacityPercentage = (this.blendMode.opacity * 100) / 255;
      this.blendMode.blender = BLEND_MODES[this.blendMode.key];
      this.blendMode.transparencyProtected = flags & 0x01;
      this.blendMode.visible = (flags & (0x01 << 1)) > 0;
      this.blendMode.visible = 1 - this.blendMode.visible;
      this.blendMode.obsolete = (flags & (0x01 << 2)) > 0;
      if ((flags & (0x01 << 3)) > 0) {
        this.blendMode.pixelDataIrrelevant = (flags & (0x01 << 4)) > 0;
      }
      return Log.debug("Blending mode:", this.blendMode);
    };

    PSDLayer.prototype.parseMaskData = function() {
      var flags, _ref, _ref2, _ref3;
      this.mask.size = this.file.readUInt();
      if ((_ref = this.mask.size) !== 36 && _ref !== 20 && _ref !== 0) {
        return false;
      }
      if (this.mask.size === 0) return true;
      _ref2 = this.file.readf(">LLLLBB"), this.mask.top = _ref2[0], this.mask.left = _ref2[1], this.mask.bottom = _ref2[2], this.mask.right = _ref2[3], this.mask.defaultColor = _ref2[4], flags = _ref2[5];
      this.mask.width = this.mask.right - this.mask.left;
      this.mask.height = this.mask.bottom - this.mask.top;
      this.mask.relative = flags & 0x01;
      this.mask.disabled = (flags & (0x01 << 1)) > 0;
      this.mask.invert = (flags & (0x01 << 2)) > 0;
      if (this.mask.size === 20) {
        this.file.seek(2);
      } else {
        _ref3 = this.file.readf(">BB"), flags = _ref3[0], this.mask.defaultColor = _ref3[1];
        this.mask.relative = flags & 0x01;
        this.mask.disabled = (flags & (0x01 << 1)) > 0;
        this.mask.invert = (flags & (0x01 << 2)) > 0;
      }
      this.file.seek(16);
      return true;
    };

    PSDLayer.prototype.parseBlendingRanges = function() {
      var length, pos, _results;
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
      _results = [];
      while (this.file.tell() < pos + length - 8) {
        _results.push(this.blendingRanges.channels.push({
          source: this.file.readf(">BB"),
          dest: this.file.readf(">BB")
        }));
      }
      return _results;
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
      code = this.file.readInt();
      this.layerType = SECTION_DIVIDER_TYPES[code];
      Log.debug("Layer type:", this.layerType);
      switch (code) {
        case 1:
        case 2:
          return this.isFolder = true;
        case 3:
          return this.isHidden = true;
      }
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
            layer.image = new PSDImage(this.file, this.header, layer);
            layer.image.parse();
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
