###
  this file is based on coffeescript/src/command.coffee(https://github.com/jashkenas/coffeescript)
  Thanks to  Jeremy Ashkenas
  Some stuffs is added or modified for taiji langauge.
###
###
Copyright (c) 2009-2014 Jeremy Ashkenas
Copyright (c) 2014-2015 Caoxingming

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
###

# The `taiji` utility. Handles command-line compilation of taijilang
# into various forms: saved into `.js` files or printed to stdout
# printed as a token stream or as the syntax tree, or launch an interactive repl.

# taiji can be used both on the server based on Node.js/V8, or to run directly in the browser.
# This module contains the main entry functions for tokenizing, parsing, and compiling source taiji into JavaScript.

fs = require 'fs'
path = require 'path'
vm = require 'vm'
{spawn, exec} = require 'child_process'
{EventEmitter} = require 'events'
mkdirp = require 'mkdirp'

{extend, baseFileName} = utils = require './utils'
optparse = require './optparse'
taiji = require './taiji'
TaijiModule = require './module'
SourceMap = require './sourcemap'

useWinPathSep  = path.sep is '\\'

# Allow taiji to emit Node.js events.
extend taiji, new EventEmitter

printLine = (line) -> process.stdout.write line + '\n'
printWarn = (line) -> process.stderr.write line + '\n'

hidden = (file) -> /^\.|~$/.test file

# The help banner that is printed in conjunction with `-h`/`--help`.
BANNER = '''
  Usage: taiji [options] path/to/script.tj -- [args]

  If called without options, taiji will run your script.
'''

# The list of all the valid option flags that `taiji` knows how to handle.
SWITCHES = [
  ['-a', '--parse',           'print out the json list that the parser produces']
  ['-b', '--bare',            'compile without a top-level function wrapper']
  ['-c', '--compile',         'compile to JavaScript and save as .js files']
  ['-d', '--nodejs [ARGS]',  'pass options directly to the "node" binary']
  ['-e', '--eval',            'pass a string from the command line as input']
  ['-h', '--help',            'display this help message']
  ['-i', '--interactive',    'run an interactive taiji repl']
  ['-j', '--join [FILE]',    'concatenate the source taiji before compiling']
  ['-m', '--map',             'generate source map and save as .map files']
  ['-n', '--no-optimize',    'compile to javascript code without optimization']
  ['-o', '--output [DIR]',   'set the output directory for compiled JavaScript']
  ['-p', '--print',           'print out the compiled JavaScript']
  ['-r', '--no-header',       'suppress the "Generated by" header']
  ['-s', '--stdio',           'listen for and compile scripts over stdio']
  ['-t', '--transforma',      'print out the internal expression after transforming']
  ['-v', '--version',         'display the version number']
  ['-z', '--optimize',       'print out the internal expression after optimizing']
]

# Top-level objects shared by all the functions.
exports.testing = false
exports.opts = opts = {}
sourceCode = []; optionParser = null

# Run `taiji` by parsing passed options and determining what action to take Many flags cause us to divert before compiling anything.
# Flags passed after `--` will be passed verbatim to your script as arguments in `process.argv`
exports.run = ->
  parseOptions()
  # Make the repl *CLI* use the global context so as to
  # (a) be consistent with the  `node` repl CLI and, therefore,
  # (b) make packages that modify native prototypes (such as 'colors' and 'sugar') work as expected.
  replCliOpts = useGlobal: true
  return forkNode() if opts.nodejs
  return usage() if opts.help
  return version() if opts.version
  return require('./repl').start(replCliOpts) if opts.interactive
  return compileStdio() if opts.stdio
  return compileScript 'compileCode', null, opts.arguments[0]  if opts.eval
  return require('./repl').start(replCliOpts) unless opts.arguments.length
#  console.log 'in run()'+(JSON.stringify opts)
  #opts.print = true # simeon
  literals = if opts.run then opts.arguments.splice 1 else []
  process.argv = process.argv[0..1].concat literals
  process.argv[0] = 'taiji'

  opts.output = path.resolve opts.output  if opts.output
  for source in opts.arguments
    source = path.resolve(source)
    if opts.compile or opts.run
      if opts.noOptimize then compilePath 'compileCodeWithoutOptimization', source, true, source
      else compilePath 'compile', source, true, source
    if opts.parse then compilePath 'parse', source, true, source
    if opts.transform then compilePath 'transform', source, true, source
    if opts.optimize then compilePath 'optimize', source, true, source

# Compile a path, which could be a script or a directory.
# If a directory is passed, recursively compile all '.taiji', and '.tj' extension source files in it and all subdirectories.
compilePath = (action, source, topLevel, base) ->
  try stats = fs.statSync source
  catch err
    if err.code is 'ENOENT' then console.error "File not found: #{source}"; process.exit 1
    throw err
  if stats.isDirectory()
    if opts.run then compilePath action, findDirectoryIndex(source), topLevel, base; return
    try files = fs.readdirSync source
    catch err then (if err.code is 'ENOENT' then return else throw err)
    for file in files then compilePath action, (path.join source, file), no, base
  else if topLevel or utils.isTaiji source
    try code = fs.readFileSync source
    catch err then (if err.code is 'ENOENT' then return else throw err)
    compileScript(action, source, code.toString(), base)

findDirectoryIndex = (source) ->
  for ext in taiji.FILE_EXTENSIONS
    index = path.join source, "index#{ext}"
    try return index if (fs.statSync index).isFile()
    catch err then throw err unless err.code is 'ENOENT'
  console.error "Missing index.taiji or index.littaiji in #{source}"
  process.exit 1

# Compile a single source script, containing the given code, according to the requested options.
# If evaluating the script directly sets `__filename`, `__dirname` and `module.filename` to be correct relative to the script's path.
compileScript = (action, file, input, base = null) ->
  o = exports.opts; options = compileOptions file, base
  try
    t = task = {file, input, options}
    taiji.emit 'compile', task
    if o.run
      taiji.register(); runCode t.input, t.options
    else
      compiled = exports[action](t.input, new TaijiModule(file, taiji.rootModule), t.options)
      t.output = compiled
      taiji.emit 'success', task
      if o.print then printLine t.output.trim()
      else if o.compile then writeJs base, t.file, t.output, options.outputPath, t.sourceMap
      else writeResult base, t.file, t.output, options.outputPath, action
  catch err
    taiji.emit 'failure', err, task
    return if taiji.listeners('failure').length
    message = err.stack or "#{err}"
    printWarn message; process.exit 1

# Get the corresponding output JavaScript path for a source file.
outputPath = (source, base, extension=".js") ->
  basename = utils.baseFileName source, true, useWinPathSep
  srcDir = path.dirname source
  if not opts.output then dir = srcDir
  else if source is base then dir = opts.output
  else dir = path.join opts.output, path.relative base, srcDir
  path.join dir, basename + extension

# Write out a JavaScript source file with the compiled code.
# By default, files are written out in `cwd` as `.js` files with the same name,
# but the output directory can be customized with `--output`.

writeJs = (base, sourcePath, js, jsPath) ->
  jsDir  = path.dirname jsPath
  processFile = ->
    if opts.compile
      js = ' ' if js.length==0
      fs.writeFile jsPath, js, (err) ->
        if err then printLine err.message
  fs.exists jsDir, (itExists) ->
    if itExists then processFile() else mkdirp jsDir, processFile

writeResult = (base, sourcePath, obj, objPath, action) ->
  objDir  = path.dirname objPath
  objPath = path.join(objDir, baseFileName(sourcePath, true, path.sep=='\\')+'.'+action+'.taiji.json')
  write = ->
    obj = ' ' if obj.length==0
    fs.writeFile objPath, obj, (err) ->
      if err then printLine err.message
  fs.exists objDir, (itExists) -> if itExists then write() else mkdirp objDir, write

# Use the [OptionParser module](optparse.html) to extract all options from `process.argv` that are specified in `SWITCHES`.
parseOptions = ->
  optionParser  = new optparse.OptionParser SWITCHES, BANNER
  if not exports.testing
    o = exports.opts = opts = optionParser.parse process.argv[2..]
    o.compile or=  !!o.output
    o.run = not (o.compile or o.print or o.map)
    o.print = !!  (o.print or (o.eval or o.stdio and o.compile))
  else o = opts = exports.opts

# The compile-time options to pass to the taiji compiler.
compileOptions = (filename, base) ->
  answer = {filename, bare: opts.bare, header: opts.compile and not opts['no-header']}
  if filename
    if base
      cwd = process.cwd()
      outPath = outputPath filename, base
      jsDir = path.dirname outPath
      answer = utils.merge answer, {
        outputPath:outPath
        sourceRoot: path.relative jsDir, cwd
        sourceFiles: [path.relative cwd, filename]
        generatedFile: utils.baseFileName(outPath, no, useWinPathSep)
      }
    else
      answer = utils.merge answer,
        sourceRoot: "", sourceFiles: [utils.baseFileName filename, no, useWinPathSep]
        generatedFile: utils.baseFileName(filename, true, useWinPathSep) + ".js"
  answer

# Start up a new Node.js instance with the arguments in `--nodejs` passed to the `node` binary, preserving the other options.
forkNode = ->
  nodeArgs = opts.nodejs.split /\s+/
  args = process.argv[1..]
  args.splice args.indexOf('--nodejs'), 2
  p = spawn process.execPath, nodeArgs.concat(args),{cwd: process.cwd(), env: process.env, customFds: [0, 1, 2]}
  p.on 'exit', (code) -> process.exit code

# Print the `--help` usage message and exit. Deprecated switches are not shown.
usage = -> printLine (new optparse.OptionParser SWITCHES, BANNER).help()

# Print the `--version` message and exit.
version = -> printLine "taiji version #{taiji.VERSION}"

# parse, transform, optimize, compile taiji code to JavaScript

exports.parse = (code, taijiModule, options) -> taiji.parse(code, taijiModule, taiji.builtins, options)
exports.transform = (code, taijiModule, options) -> taiji.transform(code, taijiModule, taiji.builtins, options)
exports.optimize = (code, taijiModule, options) -> taiji.optimize(code, taijiModule, taiji.builtins, options)
exports.compile = (code, taijiModule, options) -> taiji.compile(code, taijiModule, taiji.builtins, options)

# Compile and execute a string of taiji (on the server), correctly setting `__filename`, `__dirname`, and relative `require()`.
exports.runCode = runCode = (code, options = {}) ->
  mainModule = require.main
  mainModule.filename = process.argv[1] =
    if options.filename then fs.realpathSync(options.filename) else '.'
  mainModule.moduleCache and= {}

  dir = if options.filename then path.dirname fs.realpathSync options.filename else fs.realpathSync '.'
  mainModule.paths = require('module')._nodeModulePaths dir
  if not utils.isTaiji(mainModule.filename) or require.extensions
    filename = options.filename or '**evaluated taijilang code**'
    answer = exports.compile code, new TaijiModule(filename, taiji.rootModule), options
    code = answer.js ? answer
  mainModule._compile code, mainModule.filename

# Compile and evaluate a string of taiji (in a Node.js-like environment), The taiji repl uses this to run the input.
exports.evalCode = (code, options = {}) ->
  return unless code = code.trim()
  Script = vm.Script
  if Script
    if options.sandbox?
      if options.sandbox instanceof Script.createContext().constructor
        sandbox = options.sandbox
      else
        sandbox = Script.createContext()
        sandbox[k] = v for own k, v of options.sandbox
      sandbox.global = sandbox.root = sandbox.GLOBAL = sandbox
    else
      sandbox = global
    sandbox.__filename = options.filename || 'eval'
    sandbox.__dirname  = path.dirname sandbox.__filename
    # define module/require only if they chose not to specify their own
    unless sandbox isnt global or sandbox.module or sandbox.require
      Module = require 'module'
      sandbox.module  = _module  = new Module(options.modulename || 'eval')
      sandbox.require = _require = (path) ->  Module._load path, _module, true
      _module.filename = sandbox.__filename
      _require[r] = require[r] for r in Object.getOwnPropertyNames require when r isnt 'paths'
      # use the same hack node currently uses for their own repl
      _require.paths = _module.paths = Module._nodeModulePaths process.cwd()
      _require.resolve = (request) -> Module._resolveFilename request, _module
  o = {}
  o[k] = v for own k, v of options
  o.bare = on # ensure return value
  js = exports.compile code, new TaijiModule('evaluated-code.tj', taiji.rootModule), o
  if sandbox is global then vm.runInThisContext js
  else vm.runInContext js, sandbox

# Based on http://v8.googlecode.com/svn/branches/bleeding_edge/src/messages.js
formatSourcePosition = (frame) ->
  fileName = undefined
  fileLocation = ''

  if frame.isNative() then fileLocation = "native"
  else
    if frame.isEval()
      fileName = frame.getScriptNameOrSourceURL()
      fileLocation = "#{frame.getEvalOrigin()}, " unless fileName
    else fileName = frame.getFileName()

    fileName or= "<anonymous>"

    line = frame.getLineNumber()
    column = frame.getColumnNumber()

    fileLocation =
      "#{fileName}:#{line}:#{column}"

  functionName = frame.getFunctionName()
  isConstructor = frame.isConstructor()
  isMethodCall = not (frame.isToplevel() or isConstructor)

  if isMethodCall
    methodName = frame.getMethodName()
    typeName = frame.getTypeName()

    if functionName
      tp = as = ''
      if typeName and functionName.indexOf typeName
        tp = "#{typeName}."
      if methodName and functionName.indexOf(".#{methodName}") isnt functionName.length - methodName.length - 1
        as = " [as #{methodName}]"

      "#{tp}#{functionName}#{as} (#{fileLocation})"
    else "#{typeName}.#{methodName or '<anonymous>'} (#{fileLocation})"
  else if isConstructor then "new #{functionName or '<anonymous>'} (#{fileLocation})"
  else if functionName then "#{functionName} (#{fileLocation})"
  else fileLocation

# Based on [michaelficarra/CoffeeScriptRedux](http://goo.gl/ZTx1p)
# NodeJS / V8 have no support for transforming positions in stack traces using sourceMap
# so we must monkey-patch Error to display taiji source positions.
Error.prepareStackTrace = (err, stack) ->
  frames = for frame in stack
    if frame.getFunction() is exports.run then break
    "  at #{formatSourcePosition frame}"
  "#{err.toString()}\n#{frames.join '\n'}\n"
