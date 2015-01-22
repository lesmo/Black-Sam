module.exports = (helpers, log) ->
  async = require 'async'
  fs = require 'fs-extra'

  class FileSystemHelper
    @traverseDir = (dirpath, callback) ->
      fs.readdir dirpath, (err, files) ->
        return callback err if err

        async.series [
          # Retrieve all files' stats
          (next_step) ->
            async.map files
              , (item, next_file) ->
                fs.lstat "#{dirpath}/#{item}", (err, stat) ->
                  if stat?
                    stat.path = "#{dirpath}/#{item}"
                  else
                    stat = {}

                  next_file err, stat
              , next_step

          # Create the files' paths array
          (files_stats, next_step) ->
            async.map files_stats
              , (item, next_file) ->
                if item.isFile()
                  next_file null, item.path
                else
                  @traverseDir item.path, next_file
              , next_step
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