# psd.js

A Photoshop file format (PSD) parser written in Coffeescript/Javascript for both browsers and NodeJS implementations.

This implementation is inspired by, and in some parts directly ported, from:

  * [pypsd](http://code.google.com/p/pypsd)
  * [psdparse](https://github.com/jerem/psdparse)
  * [libpsd](http://sourceforge.net/projects/libpsd)

**Please note: this is a work in progress and is not finished yet. Do not use in production anywhere.**

## Contributing

If you would like to contribute to psd.js, you can refer to the [official PSD file format specifications](http://www.adobe.com/devnet-apps/photoshop/fileformatashtml/) for help.

### Building psd.js

psd.js comes with a handy Cakefile to build the library for you. It first searches for all dependencies in the `deps/` folder, then adds the core library afterwards in the order speciifed in the Cakefile.

To build, simply run `cake build`. If you would like the library to automatically build after any source files are saved, you can run `cake watch`.