# psd.js

A Photoshop file format (PSD) parser written in Coffeescript/Javascript for both browsers and NodeJS implementations.

This implementation is inspired by, and in some parts directly ported, from:

  * [pypsd](http://code.google.com/p/pypsd)
  * [psdparse](https://github.com/jerem/psdparse)
  * [libpsd](http://sourceforge.net/projects/libpsd)

**Please note!**

The PSD file format is complex, buggy, hacky, and poorly documented. Because of this, and the fact that this is a relatively new project, psd.js may or may not be able to correctly parse every PSD you throw at it. Use with caution.

## Contributing

If you would like to contribute to psd.js, you can refer to the [official PSD file format specifications](http://www.adobe.com/devnet-apps/photoshop/fileformatashtml/) for basic help.

### Installing Development Dependencies

These dependencies are only required if you are making changes to the psd.js source. If you are simply using psd.js, there is no need to install them.

In the psd.js folder, run:

```
npm install -d
```

And all of the dependencies will be installed for you automatically using npm.

### Building psd.js

psd.js comes with a handy Cakefile to build the library for you. It first searches for all dependencies in the `deps/` folder, then adds the core library afterwards in the order speciifed in the Cakefile.

To build, simply run `cake build`. If you would like the library to automatically build after any source files are saved, you can run `cake watch`.

## Using psd.js

There are two main things you can do with psd.js: parse information and export images.

### Loading a PSD

In order to load a PSD into psd.js, you have to give it the byte data in a UInt8Array buffer. psd.js has some helper methods for you to make your life easier.

``` coffeescript
# If you're in NodeJS, use this:
psd = PSD.fromFile 'path/to/file.psd'

# or if you're in the browser, you can do:
psd = PSD.fromURL 'path/to/file.psd', (psd) ->
  console.log 'PSD loaded!'

# If you already have the byte data from other means, simply do:
psd = new PSD(bytes)
```

### Parsing Information

You can parse the PSD file for valuable information such as: image size, color channels, layer and mask information, etc.

``` coffeescript
{PSD} = require 'psd.js'

psd = PSD.fromFile __dirname + '/test.psd'
psd.parse()

console.log "Header", psd.header
console.log "Resources", psd.resources
console.log "Layers", psd.layers
```

### Setting Options

**By default, psd.js will parse and format individual layer image data.** If you're working with large files, you will probably want to disable this for the time being as you may find your node.js process running out of memory for allocation.

``` coffeescript
psd = PSD.fromFile __dirname + '/test.psd'
psd.setOptions layerImages: false

psd.parse()
```

### Exporting Merged Image Data

You can easily export a merged/flattened version of the PSD image either to file (NodeJS) or canvas (browser).

``` coffeescript
{PSD} = require 'psd.js'

psd = PSD.fromFile __dirname + '/test.psd'

# In node...
psd.toFile __dirname + '/output.png', ->
  console.log "PSD flattened to output.png"

# In browser...
canvas = document.getElementById('psd-output')
psd.toCanvas(canvas)

# Get raw pixel data
pixels = canvas.image.toCanvasPixels()
```

To export individual layers, access the image object for each layer:

``` coffeescript
{PSD} = require 'psd.js'

psd = PSD.fromFile __dirname + '/test.psd'
psd.parse()

for layer in psd.layers
  continue if layer.isFolder

  do (layer) ->
    layer.image.toFile __dirname + "/output/#{layer.name}.png", ->
      console.log "Layer #{layer.name} output to file."
```