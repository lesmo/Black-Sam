module.exports = (helpers, log) ->
  async = require 'async'
  fs = require 'fs-extra'

  class FileSystemHelper
    @traverseDir = (dirpath, callback) ->
      fs.readdir dirpath, (err, files) ->
        return callback err if err

        async.series [
          (next_step) -> # Retreive all files' stats
            async.map files
              , (item, next_file) ->
                fs.lstat "#{dirpath}/#{item}", (err, stat) ->
                  if stat?
                    stat.path = "#{dirpath}/#{item}"
                  else
                    stat = {}

                  next_file err, stat
              , (err, files) ->
                next_step err, files
          (next_step, files_stats) -> # Create the files' paths array
            async.map files_stats
              , (item, next_file) ->
                if item.isFile()
                  next_file null, item.path
                else
                  @traverseDir item.path, next_file
              , (err, files) ->
                callback err, files
        ], (err, files_paths) ->
          if files_paths?
            files_paths = files_paths.flatten()

          callback err, files_paths

    @traverseDirSync = (dirpath) ->
      files = []

      for item in fs.readdirSync dirpath
        stat = fs.lstatSync "#{dirpath}/#{item}"

        if stat.isDirectory()
          files.push @traverseDirSync "#{dirpath}/#{item}"
        else if stat.isFile()
          files.push "#{dirpath}/#{item}"

      return files.flatten()

  # We make helpers.fs be magical
  return Object.merge fs, FileSystemHelper