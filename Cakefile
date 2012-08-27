fs      = require 'fs'
{exec, spawn}  = require 'child_process'
util    = require 'util'
sys = require "sys"
path = require "path"

targetName    = "psd"

###
CoffeeScript Options
###
strictMode    = false
csSrcDir      = "src"
csTargetDir   = "lib"

depsDir        = "deps"

targetCoffee  = "#{csSrcDir}/build"

targetCoreJS      = "#{csTargetDir}/#{targetName}.js"
targetCoreMinJS   = "#{csTargetDir}/#{targetName}.min.js"
coffeeCoreOpts    = "-j #{targetName}.js -o #{csTargetDir} -c #{targetCoffee}.coffee"

# All source files listed in include order
coffeeFiles   = [
  "psdassert"
  "psdconstants"
  "parser"
  
  "psd"
  "psdcolor"
  "psddescriptor"
  "psdfile"
  "psdheader"
  "psdimage"
  "psdchannelimage"
  "psdlayer"
  "psdlayermask"

  "layerdata/enginedataparser"
  "layerdata/blackwhite"
  "layerdata/brightnesscontrast"
  "layerdata/colorbalance"
  "layerdata/curves"
  "layerdata/exposure"
  "layerdata/gradient"
  "layerdata/huesaturation"
  "layerdata/invert"
  "layerdata/layereffect"
  "layerdata/levels"
  "layerdata/pattern"
  "layerdata/photofilter"
  "layerdata/posterize"
  "layerdata/selectivecolor"
  "layerdata/solidcolor"
  "layerdata/threshold"
  "layerdata/typetool"
  "layerdata/vibrance"

  "psdresource"
  "util"
  "log"
]

###
Event System
###
finishedCallback = {}
finished = (type) ->      
  finishedCallback[type]() if finishedCallback[type]?

finishListener = (type, cb) ->
  finishedCallback[type] = cb

###
Options
###
option '-f', '--file [FILE]', 'Test file to load (for debugging)'

###
Tasks
###
task 'debug', 'Run psd.js in debug mode with node-inspector', (opts) ->
  throw "Must specify a file with -f" if not opts.file

  debug = spawn 'coffee', ['--nodejs', '--debug-brk', opts.file]
  debug.stdout.on 'data', (data) -> console.log data

  insp = spawn 'node-inspector'
  insp.stdout.on 'data', (data) -> util.log data

  exec 'open http://127.0.0.1:8080/debug?port=5858'

task 'docs', 'Generates documentation for the coffee files', ->
  util.log 'Invoking docco on the CoffeeScript source files'
  
  files = coffeeFiles
  files[i] = "#{csSrcDir}/#{files[i]}.coffee" for i in [0...files.length]

  exec "./node_modules/docco/bin/docco #{files.join(' ')}", (err, stdout, stderr) ->
    util.log err if err
    util.log "Documentation built into docs/ folder."

task 'test', 'Run all unit tests', ->
  reporter = require('nodeunit').reporters.default
  process.chdir __dirname

  console.log "=> Running unit tests"
  reporter.run ['test/unit_tests'], null, ->

    {TargetPractice} = require './test/targetpractice'
    tp = new TargetPractice "psd.tp/**/*.json"

    console.log "\n=> Running TargetPractice"
    tp.runTests()
        
task 'watch', 'Automatically recompile the CoffeeScript files when updated', ->
  util.log "Watching for changes in #{csSrcDir}"
  
  for jsFile in coffeeFiles then do (jsFile) ->
    fs.watchFile "#{csSrcDir}/#{jsFile}.coffee", (curr, prev) ->
      if +curr.mtime isnt +prev.mtime
        util.log "#{csSrcDir}/#{jsFile}.coffee updated"
        invoke 'build'

  invoke 'deploy'
        
task 'build', 'Compile and minify all CoffeeScript source files', ->
  invoke 'compile'

task 'compile', 'Compile all CoffeeScript source files', (opts) ->
  util.log "Building #{targetCoreJS}"
  contents = []
  remaining = coffeeFiles.length

  util.log "Appending #{coffeeFiles.length} files to #{targetCoffee}.coffee"
  
  for file, index in coffeeFiles then do (file, index) ->
    fs.readFile "#{csSrcDir}/#{file}.coffee", "utf8", (err, fileContents) ->
      util.log err if err
      
      contents[index] = fileContents
      util.log "[#{index + 1}] #{file}.coffee"
      process() if --remaining is 0
      
  process = ->
    contents.unshift "###\nEND DEPENDENCIES\n###\n\n"
    deps = fs.readdirSync depsDir
    for dep in deps
      util.log "Adding dependency #{dep}"
      contents.unshift "`" + fs.readFileSync("#{depsDir}/#{dep}", "utf8") + "`\n\n"

    contents.unshift fs.readFileSync("#{csSrcDir}/license.coffee") + "\n\n"
    contents.unshift "\"use strict\"" if strictMode
    core = contents.join("\n\n")

    fs.writeFile "#{targetCoffee}.coffee", core, "utf8", (err) ->
      util.log err if err
      
      exec "./node_modules/.bin/coffee #{coffeeCoreOpts}", (err, stdout, stderr) ->
        util.log err if err
        util.log "Compiled #{targetCoreJS}"
        fs.unlink "#{targetCoffee}.coffee"

        finished('js')
        
task 'minify', 'Minify the CoffeeScript files', ->
  util.log "Minifying #{targetCoreJS}"
  fs.readFile targetCoreJS, "utf8", (err, contents) ->
    fs.writeFile targetCoreMinJS, jsmin(contents), "utf8", (err) ->
      util.log err if err
  
task 'run:worker', 'Run workers by listening to global redis queue', ->
  ResqueTasks = require "./tasks"
  Resque = require "./src/resque"

  connection = Resque.get_connection()
  worker = connection.worker "psdjs_processor", ResqueTasks
  worker.on 'error', (err, worker, queue, job) ->
    if jobs?
      console.log "#{err} on running #{JSON.stringify(job.args)} on #{queue}"
    else
      console.log err
  worker.on 'success', (worker, queue, job, result) ->
    console.log "Successfully ran #{JSON.stringify(job.args)} on #{queue}."

  worker.start()  
    
task 'test:enqueue', 'Testing resque job queue by populating dummy objects', ->
  Resque = require "coffee-resque"
  connection = Resque.connect()
  design_data = {
    "user": "suren@goyaka.com"
    "design": "Social_Media_Buttons_PSD_psd-5015d36e4588ce0008000001"
    "store": "store_production"
  }
  connection.enqueue 'psdjs_processor', 'PsdjsProcessorJob', [design_data]
  
task 'test:walk', 'walking', ->
  FileUtils = require "file"
  test_folder = '/tmp/store/suren@goyaka.com/Social_Media_Buttons_PSD_psd-5015d36e4588ce0008000001/psdjsprocessed'
  FileUtils.walk test_folder, (dummy, dirPath, dirs, files) ->
    for file in files
      relative_path = path.relative(path.join("/tmp", "store"), file)
    
task 'test:config', 'config variables', ->
  yaml = require "js-yaml"
  config_file = require "./local_constants.yml"
  console.log config_file

task 'deploy', 'Copy files to transformer-web project', ->
  exec 'cp lib/psd.js ../transformers-web/lib/psdjs'
  exec 'cp package.json ../transformers-web/lib/psdjs'