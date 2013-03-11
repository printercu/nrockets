fs    = require 'fs'
path  = require 'path'
flow  = require 'flow-coffee'
_     = require 'underscore'
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
        file_params = _.extend {}, params
        ext = path.extname file
        continue unless ext in ['.js', '.coffee']
        basename = path.basename file, ext
        unless file_params.minify?
          file_params.minify = '.min' == path.extname basename
        cb_file = @MULTI()
        rel_file = path.join params.config, file
        nrockets.concat rel_file, file_params, (err, js) ->
          return cb_file err if err
          target = "#{params.targets}/#{basename}.js"
          fs.writeFile target, js, cb_file
      @MULTI() null
    (results) ->
      callback flow.anyError results
  )
