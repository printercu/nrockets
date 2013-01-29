fs    = require 'fs'
path  = require 'path'
flow  = require 'flow-coffee'
nrockets  = require './nrockets'

module.exports = (params, callback) ->
  if 'function' == typeof params
    [params, callback] = [{}, params]
  params.config   ||= './nrockets'
  params.targets  ||= './js'
  params.sources  ||= './source'

  flow.exec(
    -> fs.readdir params.config, @
    (err, files) ->
      return callback err if err
      for file in files
        ext = path.extname file
        continue unless ext in ['.js', '.coffee']
        basename = path.basename file, ext
        minify = '.min' == path.extname basename
        minify = false  if params.skip_minify
        minify = true   if params.force_minify
        cb_file = @MULTI()
        rel_file = path.join params.config, file
        nrockets.concat rel_file, minify: minify, sources: params.sources,
          (err, js) ->
            return cb_file err if err
            target = "#{params.targets}/#{basename}.js"
            fs.writeFile target, js, cb_file
      true
    (results) ->
      callback flow.anyError results
  )
