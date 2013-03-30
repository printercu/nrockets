fs      = require 'fs'
path    = require 'path'
_       = require 'underscore'
flow    = require 'flow-coffee'

HEADER = ///
(?:
  (\#\#\# .* \#\#\#\n*) |
  (// .* \n*) |
  (\# .* \n*)
)+
///

DIRECTIVE = ///
^[\W] *= \s* (\S+?) \s* (\S*?) \s* $
///gm

flow.returnIfAnyError = (results, callback) ->
  err = @anyError results
  return false unless err
  callback? err
  true

module.exports = nrockets = {}

nrockets.scan = (item, options, callback) ->
  fs.stat item, (err, stat) ->
    return callback err if err
    unless stat.isDirectory()
      return nrockets.chooseAndScanFile item, options, callback
    fs.readdir item, (err, files) ->
      return callback err if err
      flow.exec(
        ->
          files.forEach (subitem) =>
            subitem_rel = path.join item, subitem
            nrockets.scan subitem_rel, options, @MULTI()
        (results) ->
          return if flow.returnIfAnyError results, callback
          deps = []
          results.forEach (result) ->
            deps.push item for item in result[1]
            true
          callback null, deps
      )

nrockets.chooseAndScanFile = (file, options, callback) ->
  return nrockets.scanFile file, options, callback unless options.tryMinified
  ext = path.extname file
  file_min = path.join path.dirname(file), path.basename(file, ext) + '.min' + ext
  fs.stat file_min, (err, stat) ->
    return nrockets.scanFile file, options, callback if err
    nrockets.scanFile file_min, options, callback

nrockets.scanFile = (file, options, callback) ->
  fs.readFile file, (err, data) ->
    text = data.toString 'utf8'
    reqs = nrockets.parseDirectives text
    return callback null, [file] unless reqs.length
    flow.exec(
      ->
        reqs.forEach (item) =>
          return unless item[0] in ['require', 'require_tree']
          dir = options.sources || path.dirname(file)
          item_rel = path.resolve dir, item[1]
          opts = _.clone options
          delete opts.sources
          nrockets.scan item_rel, opts, @MULTI()
        @MULTI() null, []
      (results) ->
        return if flow.returnIfAnyError results, callback
        deps = []
        results.forEach (result) ->
          deps.push item for item in result[1]
          true
        deps.push path.resolve(file)
        callback null, deps
    )

nrockets.concatDeps = (deps, options, callback) ->
  flow.exec(
    ->
      deps.forEach (file, i) =>
        nrockets.getFileContent file, @MULTI()
    (results) ->
      return if flow.returnIfAnyError results, callback
      js  = ''
      js += item[1] + ";\n" for item in results
      js = minify js if options.minify
      callback null, js
  )

nrockets.concat = (file, options, callback) ->
  nrockets.scan file, options, (err, deps) ->
    return callback err if err
    nrockets.concatDeps deps, options, callback

nrockets.getFileContent = (file, callback) ->
  if (ext = path.extname file) is '.js'
    fs.readFile file, (err, data) ->
      callback err, if err then data else data.toString 'utf8'
  else
    nrockets.compilers[ext[1..]].compile file, callback

nrockets.parseDirectives = (code) ->
  code = code.replace /[\r\t ]+$/gm, '\n'  # fix for issue #2
  return [] unless match = HEADER.exec(code)
  header = match[0]
  [match[1], match[2]] while match = DIRECTIVE.exec header

nrockets.compilers =
  coffee:
    compile: (file, callback) ->
      fs.readFile file, (err, data) ->
        CoffeeScript = require 'coffee-script'
        callback err, if err then data else CoffeeScript.compile data.toString('utf8'), {filename: file}

minify = (js) ->
  uglify = require 'uglify-js'
  jsp = uglify.parser
  pro = uglify.uglify
  ast = jsp.parse js
  ast = pro.ast_mangle ast
  ast = pro.ast_squeeze ast
  pro.gen_code ast
